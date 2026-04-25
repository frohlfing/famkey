import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:privault/core/logger.dart';
import 'package:privault/features/settings/log_config/log_config_notifier.dart';
import 'package:privault/features/settings/log_config/log_config_state.dart';
import 'package:privault/widgets/confirm_dialog.dart';

/// Modaler Dialog, der den Inhalt der Logdatei anzeigt und
/// die Log-Einstellungen (minLevel, maxDays) bearbeitbar macht.
///
/// Öffnung via [LogConfigDialog.show].
class LogConfigDialog extends ConsumerStatefulWidget {

  /// Konstruktor
  const LogConfigDialog({super.key});

  /// Statische Methode zum Anzeigen des Dialogs.
  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
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

  final _maxDaysController = TextEditingController();

  // ------------------------------------------------------------------------
  // --- Initialisierung & Lifecycle ---
  // ------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Daten laden
      final notifier = ref.read(logConfigProvider.notifier);
      await notifier.load();
    });
  }

  @override
  void dispose() {
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
          Navigator.of(context).pop(true); // Zurück zu Einstellungen
          break;

        default:
          break;
      }
    });

    // Listener, der die Controller bei einer Änderung füllt
    ref.listen(logConfigProvider, (previous, next) {
      if (previous == next) return;
      final formData = next.formData;
      if (_maxDaysController.text != formData.maxDays.toString()) {
        _maxDaysController.text = formData.maxDays.toString();
      }
    });

    // Gezielte Watches für maximale Performance
    final isBusy = ref.watch(logConfigProvider.select((s) => s.isBusy));

    // Notifier holen
    final notifier = ref.read(logConfigProvider.notifier);

    return AlertDialog(
      title: const Text('Logging'),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16.0), // Abstand zum Bildschirmrand verringern
      content: SizedBox(
        width: 450,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // --- Log-Level ---
                Consumer(
                  builder: (ctx, ref, _) {
                    final errorText = ref.watch(logConfigProvider.select((state) => state.error.field == 'minLevel' ? state.error.text : null));
                    final minLevel = ref.watch(logConfigProvider.select((s) => s.formData.minLevel));
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Expanded(
                          child:DropdownButtonFormField<LogLevel>(
                            initialValue: minLevel,
                            decoration: InputDecoration(
                              labelText: 'Log-Level',
                              prefixIcon: const Icon(Icons.edit_notifications_outlined),
                              errorText: errorText,
                              border: const OutlineInputBorder(),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                            ),
                            //hint: const Text('Log-Level'),
                            items: LogLevel.values.map((lvl) => DropdownMenuItem(value: lvl, child: Text(lvl.name.toUpperCase()))).toList(),
                            onChanged: isBusy ? null : (val) => notifier.setMinLevel(val ?? LogLevel.info),
                          ),
                        ),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 16),

                // --- Aufbewahrungsdauer ---
                Consumer(
                  builder: (ctx, ref, _) {
                    final errorText = ref.watch(logConfigProvider.select((state) => state.error.field == 'pwLength' ? state.error.text : null));
                    return TextField(
                      controller: _maxDaysController,
                      autofocus: true,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: 'Aufbewahrungsdauer (Tage)',
                        prefixIcon: const Icon(Icons.timelapse_outlined),
                        errorText: errorText,
                        border: const OutlineInputBorder(),
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove),
                              onPressed: isBusy ? null : notifier.decrementMaxDays,
                            ),
                            IconButton(
                              icon: const Icon(Icons.add),
                              onPressed: isBusy ? null : notifier.incrementMaxDays,
                            ),
                          ],
                        ),
                      ),
                      onChanged: isBusy ? null : (val) => notifier.setMaxDays(int.tryParse(val) ?? 0),
                    );
                  },
                ),

                // --- Allgemeine Fehlermeldung (error.field == null) ---
                Consumer(
                  builder: (context, ref, _) {
                    final error = ref.watch(logConfigProvider.select((s) => s.error));
                    if (error.text.isEmpty || error.field != null) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start, // Icon oben ausrichten bei Mehrzeilern
                        children: [
                          Icon(Icons.error, color: Theme.of(context).colorScheme.error),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(error.text, softWrap: true, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),

      // --- Buttons ---
      actions: [
        TextButton(
          onPressed: isBusy ? null : _handleCancel,
          child: const Text('Abbrechen'),
        ),
        ElevatedButton(
          onPressed: isBusy ? null : notifier.save,
          child: isBusy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('OK'),
        ),
      ],
    );
  }

  // ------------------------------------------------------------------------
  // --- Handler ---
  // ------------------------------------------------------------------------

  /// Speichert erst die Änderungen, wenn gewünscht und springt dann zurück.
  Future<void> _handleCancel() async {
    final state = ref.read(logConfigProvider);
    if (state.isDirty) {
      final confirmed = await ConfirmDialog.show(
        context,
        title: 'Speichern',
        text: 'Möchtest du die Änderungen speichern?',
        ok: 'Ja, speichern',
        cancel: 'Nein, verwerfen',
      );

      if (!mounted) return;

      if (confirmed == true) {
        final notifier = ref.read(logConfigProvider.notifier);
        notifier.save(); // Statt Cancel die Save-Action ausführen
        return;
      }
    }

    Navigator.of(context).pop(false); // Zur vorherigen Seite navigieren
  }

}