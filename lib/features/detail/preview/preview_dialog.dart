import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:privault/core/app_file.dart';
import 'package:privault/features/detail/preview/preview_notifier.dart';
import 'package:privault/features/detail/preview/preview_state.dart';

/// Ein modaler Dialog zur Vorschau von Dateianhängen.
///
/// Unterstützt die Anzeige von:
/// - Bildern,
/// - Text-Dateien
/// - PDF-Dokumenten – todo: noch nicht implementiert
/// - HTML-Dateien – todo: noch nicht implementiert
/// - Alle anderen Formate: Fallback mit Download-Button
class PreviewDialog extends ConsumerStatefulWidget {

  /// Initiale Parameter
  final AppFile file;

  /// Konstruktor
  const PreviewDialog({super.key, required this.file});

  /// Statische Methode zum Anzeigen des Dialogs.
  static Future<void> show(BuildContext context, AppFile file) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // User muss explizit Speichern oder Abbrechen
      builder: (context) => PreviewDialog(file: file),
    );
  }

  @override
  ConsumerState<PreviewDialog> createState() => _PreviewDialogState();
}

class _PreviewDialogState extends ConsumerState<PreviewDialog> {

  // ------------------------------------------------------------------------
  // --- Initialisierung & Lifecycle ---
  // ------------------------------------------------------------------------

  /// Initialisiert den Dialog und lädt die Daten, sobald der erste Frame gerendert wurde.
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Daten laden
      final notifier = ref.read(previewProvider.notifier);
      await notifier.load(widget.file);
    });
  }

  // /// Gibt Ressourcen frei.
  // @override
  // void dispose() {
  //   super.dispose();
  // }

  // ------------------------------------------------------------------------
  // --- Benutzeroberfläche ---
  // ------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {

    // // Listener für Status-Änderungen
    // ref.listen(previewProvider.select((s) => s.status), (previous, next) {
    //   switch (next) {
    //     case PreviewActionStatus.saved:
    //       Navigator.of(context).pop(true); // Zurück zur Detailseite
    //       break;
    //
    //     default:
    //       break;
    //   }
    // });

    // // Listener, der die Controller nur bei Initialladung oder Generierung füllt
    // ref.listen(previewProvider, (previous, next) {
    //   if (previous == next) return;
    //   final formData = next.formData;
    //   if (_passwordController.text != formData.password) _passwordController.text = formData.password;
    // });

    // Gezielte Watches für maximale Performance
    final isBusy = ref.watch(previewProvider.select((s) => s.isBusy));

    // Notifier holen
    final notifier = ref.read(previewProvider.notifier);

    final state = ref.watch(previewProvider);

    return AlertDialog(
      title: Row(
        children: [
          Expanded(
            child: Text(
              state.file.name,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      //insetPadding: const EdgeInsets.all(16.0), // Abstand zum Bildschirmrand überall verringern
      //insetPadding: const EdgeInsets.symmetric(horizontal: 16.0), // Abstand zum Bildschirmrand links und rechts verringern
      insetPadding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 16.0), // Abstand zum Bildschirmrand verringern
      contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      content: SizedBox(
        width: 450,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [

            // --- Fehleranzeige ---
            if (state.status == PreviewActionStatus.failure) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start, // Icon oben ausrichten bei Mehrzeilern
                  children: [
                    Icon(Icons.error, color: Theme.of(context).colorScheme.error),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        state.error.text,
                        softWrap: true,
                        style: TextStyle(color: Theme.of(context).colorScheme.error),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // --- Vorschau-Inhalt ---
            Expanded(child: _buildContent()),
          ],
        ),
      ),

      // --- Buttons ---
      actions: [
        // Download
        TextButton.icon(
          onPressed: state.isBusy ? null : notifier.download,
          icon: state.status == PreviewActionStatus.progress
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.download_outlined),
          label: const Text('Herunterladen'),
        ),

        // Drucken – todo: package:printing integrieren
        TextButton.icon(
          onPressed: state.isBusy ? null : notifier.print,
          icon: const Icon(Icons.print_outlined),
          label: const Text('Drucken'),
        ),

        // Schließen
        ElevatedButton(
          autofocus: true,
          onPressed: isBusy ? null : () => Navigator.of(context).pop(false),
          child: const Text('Schließen'),
        ),
      ],
    );
  }

  // ------------------------------------------------------------------------
  // --- Handler ---
  // ------------------------------------------------------------------------

  // /// Ruft den Drucker auf.
  // Future<void> _handleUpload() async {
  //   final notifier = ref.read(previewProvider.notifier);
  //   notifier.download();
  // }
  //
  // /// Ruft den Drucker auf.
  // Future<void> _handlePrint() async {
  //   final notifier = ref.read(previewProvider.notifier);
  //   notifier.print();
  // }
  //
  // /// Schließt den Dialog.
  // Future<void> _handleClose() async {
  //   Navigator.of(context).pop(false); // Zur vorherigen Seite navigieren
  // }

  // --- Vorschau-Inhalt ---

  /// Wählt den passenden Viewer anhand des MIME-Typs aus.
  Widget _buildContent() {
    final state = ref.watch(previewProvider);
    final parts = state.file.mime.split('/');
    final type = parts.first;
    final subtype = parts.last;
    // @formatter:off
    switch (type) {
      // Bild
      case 'image': return _buildImageViewer();
      // Text
      case 'text':
        switch (subtype) {
          //case 'md': return _buildMarkdownViewer();
          case 'html': return _buildHtmlViewer();
          //case 'csv': return _buildCsvViewer();
          //case 'vcf': return _buildVCardViewer();
          default: return _buildTextViewer();
        }
      // Audio
      case 'audio': return _buildAudioViewer();
      // Video
      case 'video': return _buildVideoViewer();
      case 'application':
        switch (subtype) {
          // PDF
          case 'pdf': return _buildPdfViewer();
          // Word
          case 'msword':
          case 'vnd.openxmlformats-officedocument.wordprocessingml.document': return _buildDocViewer();
          // Excel
          case 'vnd.ms-excel':
          case 'vnd.openxmlformats-officedocument.spreadsheetml.sheet': return _buildExcelViewer();
          // Powerpoint
          case 'vnd.ms-powerpoint':
          case 'application/vnd.openxmlformats-officedocument.presentationml.presentation': _buildPowerpointViewer();
          // Archiv
          case 'zip':
          case 'vnd.rar':
          case 'x-tar':
          case 'x-7z-compressed': return _buildArchiveViewer();
        }
    }
    // Fallback
    return _buildFallback('Vorschau nicht verfügbar');
    // @formatter:on
  }

  /// Zeigt ein Bild an.
  Widget _buildImageViewer() {
    final state = ref.watch(previewProvider);
    return InteractiveViewer(
      child: Center(
        child: Image.memory(
          state.bytes ?? Uint8List.fromList([]),
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => _buildError('Das Bild konnte nicht geladen werden.'),
        ),
      ),
    );
  }

  /// Zeigt Text an.
  Widget _buildTextViewer() {
    final state = ref.watch(previewProvider);
    return SingleChildScrollView(
      child: SelectableText(
        state.text ?? '',
        style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
      ),
    );
  }

  /// Zeigt HTML an.
  Widget _buildHtmlViewer() {
    // todo: HTML-Viewer implementieren
    return _buildFallback('HTML-Vorschau ist noch nicht verfügbar.');
  }

  /// Erzeugt einen Audio-Player.
  Widget _buildAudioViewer() {
    return _buildFallback('Audio-Vorschau ist nicht verfügbar.');
  }

  /// Erzeugt einen Video-Player.
  Widget _buildVideoViewer() {
    return _buildFallback('Video-Vorschau ist nicht verfügbar.');
  }

  /// Zeigt ein PDF an.
  Widget _buildPdfViewer() {
    // todo: PDF-Viewer implementieren (z.B. package:pdfx oder package:flutter_pdfview)
    return _buildFallback('PDF-Vorschau ist noch nicht verfügbar.');
  }

  /// Zeigt ein Word-Dokument an.
  Widget _buildDocViewer() {
    return _buildFallback('Word-Vorschau ist nicht verfügbar.');
  }

  /// Zeigt ein Excel-Dokumente an.
  Widget _buildExcelViewer() {
    return _buildFallback('Excel-Vorschau ist nicht verfügbar.');
  }

  /// Zeigt ein PDF an.
  Widget _buildPowerpointViewer() {
    return _buildFallback('Powerpoint-Vorschau ist nicht verfügbar.');
  }

  /// Zeigt ein Archiv an.
  Widget _buildArchiveViewer() {
    return _buildFallback('Archiv-Vorschau ist nicht verfügbar.');
  }

  /// Fallback wenn kein Viewer verfügbar ist.
  Widget _buildFallback(String message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.insert_drive_file_outlined, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Nutze "Herunterladen" um die Datei zu öffnen.',
            style: TextStyle(color: Colors.grey, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// Fehlermeldung innerhalb des Vorschaubereichs.
  Widget _buildError(String message) {
    return Center(
      child: Text(message, style: const TextStyle(color: Colors.red)),
    );
  }
}
