import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:privault/features/settings/log_file/log_file_notifier.dart';
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
      title: const Text('Fehlerprotokoll'),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      content: SizedBox(
        width: 600,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  // --- Logdatei-Inhalt ---
                  Container(
                    width: double.infinity, // Stack ausfüllen
                    height: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.black26),
                    ),
                    child: isBusy ? const Center(child: CircularProgressIndicator()) : _buildLogContent(),
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
            return TextButton.icon(
              onPressed: content.isEmpty ? null : () => _handleCopy(content),
              icon: const Icon(Icons.copy, size: 18),
              label: const Text('Kopieren'),
            );
          },
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