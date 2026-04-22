import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:privault/features/settings/log_file/log_file_notifier.dart';
import 'package:privault/features/settings/log_file/log_file_state.dart';
import 'package:privault/widgets/snack.dart';

/// Modaler Dialog, der den Inhalt der Logdatei anzeigt und
/// die Log-Einstellungen (minLevel, maxDays) bearbeitbar macht.
///
/// Öffnung via [LogFileDialog.show].
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
  // --- Interne Variablen ---
  // ------------------------------------------------------------------------

  final ScrollController _scrollController = ScrollController();

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

    // Listener für Statusänderungen
    ref.listen(logFileProvider.select((s) => s.status), (previous, next) {
      switch (next) {
        case LogFileStatus.saved:
          Snack.show(context, 'Log-Einstellungen gespeichert!', success: true);
          break;
        case LogFileStatus.failure:
          final error = ref.read(logFileProvider).error.text;
          Snack.show(context, error);
          break;
        default:
          break;
      }
    });

    final isBusy = ref.watch(logFileProvider.select((s) => s.isBusy));

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 700,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [

            // --- Titelleiste ---
            _buildTitleBar(context),

            // --- Logdatei-Inhalt ---
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.black26),
                  ),
                  child: isBusy
                      ? const Center(child: CircularProgressIndicator())
                      : _buildLogContent(),
                ),
              ),
            ),

            // --- Aktionszeile ---
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: OverflowBar(
                alignment: MainAxisAlignment.end,
                children: [

                  // --- Copy-Button ---
                  Consumer(
                    builder: (ctx, ref, _) {
                      final content = ref.watch(logFileProvider.select((s) => s.content));
                      return TextButton.icon(
                        onPressed: content.isEmpty ? null : () => _handleCopy(content),
                        icon: const Icon(Icons.copy, size: 18),
                        label: const Text('Kopieren'),
                      );
                    },
                  ),

                  // --- Schließen ---
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Schließen'),
                  ),

                ],
              ),
            ),

          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------------------
  // --- Widgets ---
  // ------------------------------------------------------------------------

  /// Titelleiste mit Titel und Schließen-Button
  Widget _buildTitleBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 8, 12),
      child: Row(
        children: [
          const Icon(Icons.article_outlined, size: 22),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Logdatei',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Schließen',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  /// Scrollbarer Logdatei-Inhalt mit monospace-Schrift
  Widget _buildLogContent() {
    return Consumer(
      builder: (ctx, ref, _) {
        final content = ref.watch(logFileProvider.select((s) => s.content));

        if (content.isEmpty) {
          return const Center(
            child: Text(
              '(Keine Logeinträge vorhanden)',
              style: TextStyle(color: Colors.grey),
            ),
          );
        }

        return Scrollbar(
          controller: _scrollController,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsets.all(12),
            child: SelectableText(
              content,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ),
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
}