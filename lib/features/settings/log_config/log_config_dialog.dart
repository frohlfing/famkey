import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:privault/core/logger.dart';
import 'package:privault/features/settings/log_config/log_config_notifier.dart';
import 'package:privault/features/settings/log_config/log_config_state.dart';
import 'package:privault/widgets/snack.dart';

/// Modaler Dialog, der den Inhalt der Logdatei anzeigt und
/// die Log-Einstellungen (minLevel, maxDays) bearbeitbar macht.
///
/// Öffnung via [LogConfigDialog.show].
class LogConfigDialog extends ConsumerStatefulWidget {

  /// Konstruktor
  const LogConfigDialog({super.key});

  /// Statische Methode zum Anzeigen des Dialogs.
  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => const LogConfigDialog(),
    );
  }

  @override
  ConsumerState<LogConfigDialog> createState() => _LogConfigDialogState();
}

class _LogConfigDialogState extends ConsumerState<LogConfigDialog> {

  // ------------------------------------------------------------------------
  // --- Interne Variablen ---
  // ------------------------------------------------------------------------

  final ScrollController _scrollController = ScrollController();
  final TextEditingController _maxDaysController = TextEditingController();

  // ------------------------------------------------------------------------
  // --- Initialisierung & Lifecycle ---
  // ------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(logConfigProvider.notifier).load();
      _scrollToBottom();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _maxDaysController.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------------------
  // --- Benutzeroberfläche ---
  // ------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {

    // Listener für Statusänderungen
    ref.listen(logConfigProvider.select((s) => s.status), (previous, next) {
      switch (next) {
        case LogConfigStatus.saved:
          Snack.show(context, 'Log-Einstellungen gespeichert!', success: true);
          break;
        case LogConfigStatus.failure:
          final error = ref.read(logConfigProvider).error.text;
          Snack.show(context, error);
          break;
        default:
          break;
      }
    });

    // maxDays-Controller mit State synchronisieren (nur bei Änderung von außen)
    ref.listen(logConfigProvider.select((s) => s.formData.maxDays), (previous, next) {
      final text = next.toString();
      if (_maxDaysController.text != text) {
        _maxDaysController.text = text;
      }
    });

    final isBusy = ref.watch(logConfigProvider.select((s) => s.isBusy));
    final notifier = ref.read(logConfigProvider.notifier);

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

            const Divider(height: 1),

            // --- Einstellungen ---
            _buildSettings(notifier),

            const Divider(height: 1),

            // --- Aktionszeile ---
            _buildActions(context, notifier, isBusy),

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

  /// Einstellungszeile: minLevel-Dropdown + maxDays-Eingabe
  Widget _buildSettings(LogConfigNotifier notifier) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Wrap(
        spacing: 16,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [

          // --- Min-Level Dropdown ---
          Consumer(
            builder: (ctx, ref, _) {
              final minLevel = ref.watch(logConfigProvider.select((s) => s.formData.minLevel));
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Min. Level:'),
                  const SizedBox(width: 8),
                  DropdownButton<LogLevel>(
                    value: minLevel,
                    isDense: true,
                    items: LogLevel.values.map((lvl) {
                      return DropdownMenuItem(
                        value: lvl,
                        child: Text(lvl.name.toUpperCase()),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) notifier.setMinLevel(value);
                    },
                  ),
                ],
              );
            },
          ),

          // --- Max-Days Eingabe ---
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Aufbewahrung (Tage):'),
              const SizedBox(width: 8),
              SizedBox(
                width: 56,
                child: TextField(
                  controller: _maxDaysController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  ),
                  onChanged: (value) {
                    final days = int.tryParse(value);
                    if (days != null && days > 0) notifier.setMaxDays(days);
                  },
                ),
              ),
            ],
          ),

        ],
      ),
    );
  }

  /// Aktionszeile: Copy-Button links, Speichern + Schließen rechts
  Widget _buildActions(BuildContext context, LogConfigNotifier notifier, bool isBusy) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [

          // --- Einstellungen speichern ---
          Consumer(
            builder: (ctx, ref, _) {
              final isDirty = ref.watch(logConfigProvider.select((s) => s.isDirty));
              return ElevatedButton(
                onPressed: (isBusy || !isDirty) ? null : notifier.save,
                child: const Text('Einstellungen speichern'),
              );
            },
          ),

          const SizedBox(width: 8),

          // --- Schließen ---
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Schließen'),
          ),

        ],
      ),
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
}