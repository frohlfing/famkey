import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:famkey/features/settings/log_file/log_file_notifier.dart';
import 'package:famkey/widgets/confirm_dialog.dart';
import 'package:famkey/widgets/snack.dart';

/// Modaler Dialog zum Anzeigen der Logdatei.
class LogFileDialog extends ConsumerStatefulWidget {

  /// Konstruktor
  const LogFileDialog({super.key});

  /// Statische Methode zum Anzeigen des Dialogs.
  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => const LogFileDialog(),
    );
  }

  @override
  ConsumerState<LogFileDialog> createState() => _LogFileDialogState();
}

class _LogFileDialogState extends ConsumerState<LogFileDialog> {

  // ------------------------------------------------------------------------
  // --- Konstanten ---
  // ------------------------------------------------------------------------

  static const _isTerminalStyle = true;

  // ------------------------------------------------------------------------
  // --- Interne Variablen ---
  // ------------------------------------------------------------------------

  final _scrollController = ScrollController();

  // ------------------------------------------------------------------------
  // --- Initialisierung & Lifecycle ---
  // ------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(logFileProvider.notifier).load();
      _scrollToBottom();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------------------
  // --- Benutzeroberfläche ---
  // ------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {

    // Gezielte Watches für maximale Performance
    final isBusy = ref.watch(logFileProvider.select((s) => s.isBusy));

    return AlertDialog(
      title: const Text('Logdatei'),
      insetPadding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 16.0),
      contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      content: SizedBox(
        width: 600,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  // --- Terminal ---
                  Container(
                    width: double.infinity, // Stack ausfüllen
                    height: double.infinity,
                    decoration: BoxDecoration(
                      color: _isTerminalStyle ? Color(0xFF0D0D0D) : Colors.white,
                      border: _isTerminalStyle ? Border.all(color: Color(0xFF2A2A2A)) : Border.all(color: Colors.black26),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: isBusy
                      ? const Center(child: CircularProgressIndicator())
                      : _buildLogContent(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),

      // --- Buttons ---
      actions: [
        Consumer(
          builder: (ctx, ref, _) {
            final content = ref.watch(logFileProvider.select((s) => s.content));
            return TextButton(
              onPressed: content.isEmpty ? null : () => _handleCopy(content),
              child: const Text('Kopieren'),
            );
          },
        ),
        TextButton(
          onPressed: _handleClearFile,
          child: const Text('Löschen'),
        ),
        // Schließen
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Schließen'),
        ),
      ],

    );
  }

  // ------------------------------------------------------------------------
  // --- Widgets ---
  // ------------------------------------------------------------------------

  /// Scrollbarer Logdatei-Inhalt mit monospace-Schrift
  Widget _buildLogContent() {
    return Consumer(
      builder: (ctx, ref, _) {
        final content = ref.watch(logFileProvider.select((s) => s.content));

        if (content.isEmpty) {
          return const Center(
            child: Text(
              '(Keine Logeinträge vorhanden)',
              style: TextStyle(fontFamily: 'monospace', fontSize: 12, color: _isTerminalStyle ? Color(0xFF666666) : Colors.grey),
            ),
          );
        }

        final scrollbar = Scrollbar(
          controller: _scrollController,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsets.all(12),
            child: SelectableText(
              content,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12, height: 1.4, color: _isTerminalStyle ? Color(0xFFCCCCCC) : null),
            ),
          ),
        );

        if (!_isTerminalStyle) return scrollbar;

        return ScrollbarTheme(
          data: ScrollbarThemeData(
            // Farbe der Scrollbar für den Terminal-Stil anpassen (sonst sieht man sie nicht)
            thumbColor: WidgetStateProperty.all(Color(0xFF555555)),
            trackColor: WidgetStateProperty.all(Colors.transparent),
            trackBorderColor: WidgetStateProperty.all(Colors.transparent),
          ),
          child: scrollbar,
        );
      },
    );
  }

  // ------------------------------------------------------------------------
  // --- Handler ---
  // ------------------------------------------------------------------------

  /// Scrollt ans Ende der Logdatei (neueste Einträge).
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  /// Kopiert den Loginhalt in die Zwischenablage.
  Future<void> _handleCopy(String content) async {
    await Clipboard.setData(ClipboardData(text: content));
    if (mounted) {
      Snack.show(context, 'Logdatei in die Zwischenablage kopiert', success: true);
    }
  }

  /// Löscht nach Bestätigung die Einträge aus der Logdatei.
  Future<void> _handleClearFile() async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Logdatei leeren',
      text: 'Möchtest du die Logeinträge löschen?',
      ok: 'Ja, löschen',
    );
    if (mounted && confirmed == true) {
      final notifier = ref.read(logFileProvider.notifier);
      notifier.clearFile();
    }
  }
}