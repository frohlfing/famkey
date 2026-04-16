import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../renderer.dart';

// ---------------------------------------------------------------------------
// Interne Block-Datenklassen
// ---------------------------------------------------------------------------

sealed class _Block {}

class _Heading extends _Block {
  final int level;
  final String text;
  _Heading(this.level, this.text);
}

class _Paragraph extends _Block {
  final String text;
  _Paragraph(this.text);
}

class _CodeBlock extends _Block {
  final String code;
  _CodeBlock(this.code);
}

class _Rule extends _Block {}

class _Table extends _Block {
  final List<String> headers;
  final List<List<String>> rows;
  _Table(this.headers, this.rows);
}

class _ImageBlock extends _Block {
  final String alt;
  final Uint8List data;
  _ImageBlock(this.alt, this.data);
}

class _ListBlock extends _Block {
  final List<_ListItem> items;
  _ListBlock(this.items);
}

// ---------------------------------------------------------------------------
// Hilfsdatenklassen
// ---------------------------------------------------------------------------

class _ListItem {
  final int depth; // 0 = erste Ebene, 1 = eingerückt, …
  final String text;
  _ListItem(this.depth, this.text);
}

class _Span {
  final String text;
  final bool bold;
  final bool italic;
  final bool code;
  const _Span(this.text, {this.bold = false, this.italic = false, this.code = false});
}

// ---------------------------------------------------------------------------
// MarkdownRenderer
// ---------------------------------------------------------------------------

/// Minimalistischer Renderer für Markdown-Inhalte.
///
/// Unterstützte Syntax:
/// - Überschriften `#`, `##`, `###`
/// - Fette Schrift `**text**`, auch `**mit \`code\`**`
/// - Kursive Schrift `*text*`
/// - Inline-Code `` `code` ``
/// - Code-Blöcke ` ``` `
/// - Horizontale Linien `---`
/// - Aufzählungslisten `- item` mit Einrückung für Verschachtelung
/// - Tabellen `| col | col |`
/// - Block-Bilder `![alt](data:image/...;base64,...)`
class MarkdownRenderer implements Renderer {
  final Uint8List? bytes;

  const MarkdownRenderer(this.bytes);

  @override
  bool get isPrintable => bytes != null && bytes!.isNotEmpty;

  /// Druckt das Markdown mit [pw.MultiPage] – mehrere Seiten, Seitenrand,
  /// und Unicode-fähige Schrift via [PdfGoogleFonts].
  ///
  /// Verwendet Noto Sans für korrekte Darstellung von Sonderzeichen
  /// (Umlaute, En-Dash `–`, etc.). Schriften werden nach dem ersten Download
  /// automatisch gecacht.
  @override
  Future<bool> printNatively(String jobName) async {
    final content = markdown;
    if (content == null || content.isEmpty) return false;

    final blocks = _parseBlocks(content);

    // Unicode-fähige Schriften laden
    final regular = await PdfGoogleFonts.notoSansRegular();
    final bold    = await PdfGoogleFonts.notoSansBold();
    final italic  = await PdfGoogleFonts.notoSansItalic();

    await Printing.layoutPdf(
      name: jobName,
      onLayout: (format) async {
        final doc = pw.Document();
        doc.addPage(
          pw.MultiPage(
            pageFormat: format,
            margin: const pw.EdgeInsets.symmetric(horizontal: 48, vertical: 48),
            theme: pw.ThemeData.withFont(
              base:   regular,
              bold:   bold,
              italic: italic,
            ),
            // Jedes Block-Widget als eigenes Top-Level-Element übergeben –
            // pw.MultiPage bricht automatisch auf mehrere Seiten um.
            build: (context) => blocks.map(_toPwWidget).toList(),
          ),
        );
        return doc.save();
      },
    );

    return true;
  }

  String? get markdown =>
      bytes == null ? null : utf8.decode(bytes!, allowMalformed: true);

  // --------------------------------------------------------------------------
  // Parser – Blöcke
  // --------------------------------------------------------------------------

  static List<_Block> _parseBlocks(String input) {
    final blocks = <_Block>[];
    // CR+LF und CR normalisieren → robustes Handling aller Zeilenenden
    final lines = input
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .split('\n');
    int i = 0;

    while (i < lines.length) {
      // Trailing-Whitespace entfernen (inkl. evt. übrig gebliebenes \r)
      final line = lines[i].trimRight();

      // --- Leerzeile ---
      if (line.trim().isEmpty) { i++; continue; }

      // --- Überschrift: zeichenbasiert statt Regex (robuster) ---
      if (line.startsWith('#')) {
        int level = 0;
        while (level < line.length && line[level] == '#') {
          level++;
        }
        if (level <= 3 && level < line.length && line[level] == ' ') {
          final text = line.substring(level + 1).trim();
          if (text.isNotEmpty) {
            blocks.add(_Heading(level, text));
            i++; continue;
          }
        }
      }

      // --- Horizontale Linie ---
      if (RegExp(r'^[-*_]{3,}$').hasMatch(line.trim())) {
        blocks.add(_Rule()); i++; continue;
      }

      // --- Code-Block ---
      if (line.trimLeft().startsWith('```')) {
        final code = <String>[];
        i++;
        while (i < lines.length && !lines[i].trimRight().trimLeft().startsWith('```')) {
          code.add(lines[i].trimRight()); i++;
        }
        blocks.add(_CodeBlock(code.join('\n')));
        i++; continue;
      }

      // --- Aufzählungsliste ---
      final listMatch = RegExp(r'^(\s*)[-*]\s(.+)').firstMatch(line);
      if (listMatch != null) {
        final items = <_ListItem>[];
        var j = i;
        while (j < lines.length) {
          final l = lines[j].trimRight();
          final m = RegExp(r'^(\s*)[-*]\s(.+)').firstMatch(l);
          if (m == null) break;
          final depth = (m.group(1)!.length / 2).floor().clamp(0, 4);
          items.add(_ListItem(depth, m.group(2)!.trim()));
          j++;
        }
        blocks.add(_ListBlock(items));
        i = j; continue;
      }

      // --- Tabelle ---
      if (line.trim().startsWith('|')) {
        final tableLines = <String>[];
        while (i < lines.length && lines[i].trimRight().trim().startsWith('|')) {
          tableLines.add(lines[i].trimRight()); i++;
        }
        // Trennzeilen (|---|---|) herausfiltern
        final content = tableLines
            .where((l) => !RegExp(r'^\|[\s\-|:]+\|$').hasMatch(l.trim()))
            .toList();
        if (content.isNotEmpty) {
          blocks.add(_Table(
            _parseTableRow(content.first),
            content.skip(1).map(_parseTableRow).toList(),
          ));
        }
        continue;
      }

      // --- Block-Bild (einziger Inhalt der Zeile) ---
      final imgMatch = RegExp(r'^!\[([^\]]*)\]\(([^)]+)\)\s*$').firstMatch(line.trim());
      if (imgMatch != null) {
        final data = _parseDataUri(imgMatch.group(2)!);
        if (data != null) blocks.add(_ImageBlock(imgMatch.group(1)!, data));
        i++; continue;
      }

      // --- Absatz ---
      final text = <String>[];
      while (i < lines.length) {
        final l = lines[i].trimRight();
        if (l.trim().isEmpty) break;
        if (l.startsWith('#')) break;
        if (RegExp(r'^[-*_]{3,}$').hasMatch(l.trim())) break;
        if (l.trimLeft().startsWith('```')) break;
        if (l.trim().startsWith('|')) break;
        if (RegExp(r'^\s*[-*]\s').hasMatch(l)) break;
        text.add(l); i++;
      }
      if (text.isNotEmpty) {
        blocks.add(_Paragraph(text.join(' ')));
      } else {
        i++; // Unbekannte Zeile überspringen – verhindert Endlosschleife
      }
    }

    return blocks;
  }

  static List<String> _parseTableRow(String line) {
    var l = line.trim();
    if (l.startsWith('|')) l = l.substring(1);
    if (l.endsWith('|')) l = l.substring(0, l.length - 1);
    return l.split('|').map((s) => s.trim()).toList();
  }

  static Uint8List? _parseDataUri(String src) {
    if (!src.startsWith('data:')) return null;
    final comma = src.indexOf(',');
    if (comma < 0) return null;
    try { return base64Decode(src.substring(comma + 1)); } catch (_) { return null; }
  }

  // --------------------------------------------------------------------------
  // Parser – Inline-Spans
  // --------------------------------------------------------------------------

  /// Parst Inline-Formatierung: `**fett**`, `*kursiv*`, `` `code` ``.
  ///
  /// Reihenfolge: `**` vor `*`, damit Bold korrekt priorisiert wird.
  /// Fett und Kursiv werden intern nach Code-Spans durchsucht,
  /// sodass `**Text mit \`code\`**` korrekt gerendert wird.
  static List<_Span> _parseInline(String text) {
    final spans = <_Span>[];
    final pattern = RegExp(
      r'\*\*(.+?)\*\*'    // **fett**
      r'|\*([^*\n]+?)\*'  // *kursiv*
      r'|`([^`\n]+)`'     // `code`
      r'|([^*`]+)'        // Klartext
      r'|([*`])',          // einzelnes * oder ` (Catch-all)
    );
    for (final m in pattern.allMatches(text)) {
      if (m.group(1) != null) {
        // Fett: inneren Text nach Code-Spans durchsuchen
        spans.addAll(_parseInnerCode(m.group(1)!, bold: true));
      } else if (m.group(2) != null) {
        // Kursiv: inneren Text nach Code-Spans durchsuchen
        spans.addAll(_parseInnerCode(m.group(2)!, italic: true));
      } else if (m.group(3) != null) {
        spans.add(_Span(m.group(3)!, code: true));
      } else if (m.group(4) != null) {
        spans.add(_Span(m.group(4)!));
      } else if (m.group(5) != null) {
        spans.add(_Span(m.group(5)!));
      }
    }
    return spans;
  }

  /// Parst nur Code-Spans innerhalb von bereits erkanntem Fett/Kursiv.
  ///
  /// Ermöglicht `**Text mit \`code\`**` → [bold(Text mit ), bold+code(code)].
  static List<_Span> _parseInnerCode(String text, {bool bold = false, bool italic = false}) {
    final spans = <_Span>[];
    final pattern = RegExp(r'`([^`\n]+)`|([^`]+)|([`])');
    for (final m in pattern.allMatches(text)) {
      if (m.group(1) != null) {
        spans.add(_Span(m.group(1)!, bold: bold, italic: italic, code: true));
      } else if (m.group(2) != null) {
        spans.add(_Span(m.group(2)!, bold: bold, italic: italic));
      } else if (m.group(3) != null) {
        spans.add(_Span(m.group(3)!, bold: bold, italic: italic));
      }
    }
    return spans;
  }

  // --------------------------------------------------------------------------
  // Flutter-Widget (Vorschau)
  // --------------------------------------------------------------------------

  @override
  Widget buildWidget() {
    final content = markdown;
    if (content == null || content.isEmpty) {
      return const Center(child: Text('Kein Inhalt verfügbar.'));
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _parseBlocks(content).map(_toFlutterWidget).toList(),
      ),
    );
  }

  static Widget _toFlutterWidget(_Block block) => switch (block) {
    _Heading() => Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Text(
        block.text,
        style: TextStyle(
          fontSize: block.level == 1 ? 22 : block.level == 2 ? 18 : 15,
          fontWeight: FontWeight.bold,
        ),
      ),
    ),
    _Rule() => const Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Divider(),
    ),
    _CodeBlock() => Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFDDDDDD)),
      ),
      child: Text(
        block.code,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
      ),
    ),
    _Paragraph() => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Text.rich(
        TextSpan(children: _parseInline(block.text).map(_toFlutterSpan).toList()),
      ),
    ),
    _ListBlock() => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: block.items.map((item) => Padding(
          padding: EdgeInsets.only(
            left: 4.0 + item.depth * 20.0,
            top: 2, bottom: 2,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 16,
                child: Text(
                  item.depth == 0 ? '•' : item.depth == 1 ? '◦' : '▸',
                  style: const TextStyle(fontSize: 14),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text.rich(
                  TextSpan(children: _parseInline(item.text).map(_toFlutterSpan).toList()),
                ),
              ),
            ],
          ),
        )).toList(),
      ),
    ),
    _Table() => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: _toFlutterTable(block),
    ),
    _ImageBlock() => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Image.memory(block.data, fit: BoxFit.contain),
    ),
  };

  static InlineSpan _toFlutterSpan(_Span span) {
    if (span.code) {
      return WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          decoration: BoxDecoration(
            color: const Color(0xFFEEEEEE),
            borderRadius: BorderRadius.circular(3),
          ),
          child: Text(
            span.text,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              fontWeight: span.bold ? FontWeight.bold : null,
              fontStyle: span.italic ? FontStyle.italic : null,
            ),
          ),
        ),
      );
    }
    return TextSpan(
      text: span.text,
      style: TextStyle(
        fontWeight: span.bold ? FontWeight.bold : null,
        fontStyle: span.italic ? FontStyle.italic : null,
      ),
    );
  }

  static Widget _toFlutterTable(_Table table) {
    final n = table.headers.length;
    final rows = table.rows.map((row) {
      if (row.length >= n) return row.sublist(0, n);
      return [...row, ...List.filled(n - row.length, '')];
    }).toList();

    return Table(
      border: TableBorder.all(color: const Color(0xFFBBBBBB)),
      defaultColumnWidth: const FlexColumnWidth(),
      children: [
        TableRow(
          decoration: const BoxDecoration(color: Color(0xFFEEEEEE)),
          children: table.headers.map((h) => _flutterCell(h, bold: true)).toList(),
        ),
        ...rows.map((row) => TableRow(
          children: row.map(_flutterCell).toList(),
        )),
      ],
    );
  }

  static Widget _flutterCell(String text, {bool bold = false}) => Padding(
    padding: const EdgeInsets.all(6),
    child: Text(text, style: TextStyle(fontWeight: bold ? FontWeight.bold : null)),
  );

  // --------------------------------------------------------------------------
  // PDF-Widget (Druck)
  // --------------------------------------------------------------------------

  @override
  pw.Widget buildPrintableWidget() {
    final content = markdown;
    if (content == null || content.isEmpty) {
      return pw.Center(child: pw.Text('Kein Inhalt verfügbar.'));
    }
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: _parseBlocks(content).map(_toPwWidget).toList(),
    );
  }

  static pw.Widget _toPwWidget(_Block block) => switch (block) {
    _Heading() => pw.Padding(
      padding: const pw.EdgeInsets.only(top: 12, bottom: 4),
      child: pw.Text(
        block.text,
        style: pw.TextStyle(
          fontSize: block.level == 1 ? 22 : block.level == 2 ? 16 : 13,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    ),
    _Rule() => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 8),
      child: pw.Divider(color: PdfColors.grey),
    ),
    _CodeBlock() => pw.Container(
      width: double.infinity,
      margin: const pw.EdgeInsets.symmetric(vertical: 6),
      padding: const pw.EdgeInsets.all(10),
      decoration: const pw.BoxDecoration(
        color: PdfColors.grey200,
        border: pw.Border(
          top:    pw.BorderSide(color: PdfColors.grey400),
          bottom: pw.BorderSide(color: PdfColors.grey400),
          left:   pw.BorderSide(color: PdfColors.grey400),
          right:  pw.BorderSide(color: PdfColors.grey400),
        ),
      ),
      child: pw.Text(block.code, style: pw.TextStyle(font: pw.Font.courier(), fontSize: 10)),
    ),
    _Paragraph() => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.RichText(
        text: pw.TextSpan(
          children: _parseInline(block.text).map(_toPwSpan).toList(),
        ),
      ),
    ),
    _ListBlock() => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: block.items.map((item) => pw.Padding(
          padding: pw.EdgeInsets.only(
            left: 4.0 + item.depth * 20.0,
            top: 2, bottom: 2,
          ),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.SizedBox(
                width: 16,
                child: pw.Text(
                  item.depth == 0 ? '\u2022' : item.depth == 1 ? '\u25E6' : '\u25B8',
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ),
              pw.SizedBox(width: 4),
              pw.Expanded(
                child: pw.RichText(
                  text: pw.TextSpan(
                    children: _parseInline(item.text).map(_toPwSpan).toList(),
                  ),
                ),
              ),
            ],
          ),
        )).toList(),
      ),
    ),
    _Table() => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 6),
      child: _toPwTable(block),
    ),
    _ImageBlock() => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 6),
      child: pw.Center(
        child: pw.Image(pw.MemoryImage(block.data), fit: pw.BoxFit.contain),
      ),
    ),
  };

  static pw.TextSpan _toPwSpan(_Span span) => pw.TextSpan(
    text: span.text,
    style: pw.TextStyle(
      fontWeight: span.bold ? pw.FontWeight.bold : null,
      fontStyle: span.italic ? pw.FontStyle.italic : null,
      font: span.code ? pw.Font.courier() : null,
      fontSize: span.code ? 10 : null,
    ),
  );

  static pw.Widget _toPwTable(_Table table) {
    final n = table.headers.length;
    final rows = table.rows.map((row) {
      if (row.length >= n) return row.sublist(0, n);
      return [...row, ...List.filled(n - row.length, '')];
    }).toList();

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey),
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: table.headers.map((h) => _pwCell(h, bold: true)).toList(),
        ),
        ...rows.map((row) => pw.TableRow(
          children: row.map(_pwCell).toList(),
        )),
      ],
    );
  }

  static pw.Widget _pwCell(String text, {bool bold = false}) => pw.Padding(
    padding: const pw.EdgeInsets.all(4),
    child: pw.Text(text, style: bold ? pw.TextStyle(fontWeight: pw.FontWeight.bold) : null),
  );
}