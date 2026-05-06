import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:famkey/core/service_locator.dart';
import 'package:famkey/features/settings/autotype_hotkey/autotype_hotkey_notifier.dart';
import 'package:famkey/features/settings/autotype_hotkey/autotype_hotkey_state.dart';
import 'package:famkey/services/autotype_service.dart';
import 'package:famkey/widgets/confirm_dialog.dart';

/// Ein modaler Dialog zum Ändern des Autotype-Tastenkürzels.
class AutotypeHotkeyDialog extends ConsumerStatefulWidget {

  /// Initiale Parameter
  // (keine)

  /// Konstruktor
  const AutotypeHotkeyDialog({super.key});

  /// Statische Methode zum Anzeigen des Dialogs.
  /// Gibt [true] zurück, wenn gespeichert wurde, andernfalls [false] oder [null].
  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false, // User muss explizit Speichern oder Abbrechen
      builder: (_) => const AutotypeHotkeyDialog(),
    );
  }

  @override
  ConsumerState<AutotypeHotkeyDialog> createState() => _AutotypeHotkeyDialogState();
}

class _AutotypeHotkeyDialogState extends ConsumerState<AutotypeHotkeyDialog> {

  // ------------------------------------------------------------------------
  // --- TextEditingController ---
  // ------------------------------------------------------------------------

  final _controller = TextEditingController();

  // ------------------------------------------------------------------------
  // --- Initialisierung & Lifecycle ---
  // ------------------------------------------------------------------------

  /// Initialisiert den Dialog und lädt die Daten, sobald der erste Frame gerendert wurde.
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Hotkey deregistrieren, damit die Kombination als normales Key-Event
      // an Flutter weitergeleitet wird und onKeyEvent sie erkennen kann.
      getIt<AutotypeService>().unregisterHotkey();
      // Daten laden
      final notifier = ref.read(autotypeHotkeyProvider.notifier);
      await notifier.load();
    });
  }

  /// Gibt Ressourcen frei und reaktiviert den Hotkey.
  @override
  void dispose() {
    _controller.dispose();
    // Hotkey aus der (ggf. aktualisierten) ConfigService-Konfiguration neu registrieren.
    // Bei Speichern: neuer Hotkey ist bereits in ConfigService → neuer Hotkey wird aktiv.
    // Bei Abbrechen: alter Hotkey ist noch in ConfigService → alter Hotkey bleibt aktiv.
    getIt<AutotypeService>().reregisterHotkey();
    super.dispose();
  }

  // ------------------------------------------------------------------------
  // --- Benutzeroberfläche ---
  // ------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {

    // Listener für Status-Änderungen
    ref.listen(autotypeHotkeyProvider.select((s) => s.status), (previous, next) {
      switch (next) {
        case AutotypeHotkeyStatus.saved:
          Navigator.of(context).pop(true); // Zurück zur Detailseite
          break;

        default:
          break;
      }
    });

    // Listener, der die Controller nur bei Initialladung oder Generierung füllt
    ref.listen(autotypeHotkeyProvider, (previous, next) {
      if (previous == next) return;
      final value = next.hotkey;
      if (_controller.text != value) _controller.text = value;
    });

    // Gezielte Watches für maximale Performance
    final isBusy = ref.watch(autotypeHotkeyProvider.select((s) => s.isBusy));

    // Notifier holen
    final notifier = ref.read(autotypeHotkeyProvider.notifier);

    return AlertDialog(
      title: const Text('Autotype Tastenkürzel'),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16.0), // Abstand zum Bildschirmrand verringern
      content: SizedBox(
        width: 450,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // --- Hotkey ---
            Consumer(
              builder: (ctx, ref, _) {
                final errorText = ref.watch(autotypeHotkeyProvider.select((state) => state.error.field == 'hotkey' ? state.error.text : null));
                return Focus(
                  onKeyEvent: (node, event) {
                    _handleTextFieldKeyEvent(event);
                    return KeyEventResult.handled; // Verhindert, dass das Zeichen im Textfeld normal getippt wird
                  },
                  child: TextField(
                    controller: _controller,
                    autofocus: true,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: 'Tastenkürzel',
                      prefixIcon: const Icon(Icons.keyboard_outlined),
                      errorText: errorText,
                      hintText: 'z.B. Strg+Shift+A',
                      helperText: 'Kombinationen mit Strg, Shift, Alt, Win und einem Buchstaben oder Ziffer, durch "+" getrennt. Beispiel: Strg+Shift+A',
                      helperMaxLines: 4,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                );
              },
            ),

            // --- Allgemeine Fehlermeldung (error.field == null) ---
            Consumer(builder: (context, ref, _) {
              final error = ref.watch(autotypeHotkeyProvider.select((s) => s.error));
              if (error.text.isEmpty || error.field != null) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start, // Icon oben ausrichten bei Mehrzeilern
                  children: [
                    Icon(Icons.error, color: Theme.of(context).colorScheme.error),
                    const SizedBox(width: 8),
                    Expanded(child: Text(error.text, softWrap: true, style: TextStyle(color: Theme.of(context).colorScheme.error))),
                  ],
                ),
              );
            }),

          ],
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
          child: isBusy
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
            : const Text('OK'),
        ),
      ],
    );
  }

  // ------------------------------------------------------------------------
  // --- Handler ---
  // ------------------------------------------------------------------------

  void _handleTextFieldKeyEvent(KeyEvent event) {
    // Wir reagieren nur auf den Tastendruck (KeyDown), nicht auf das Loslassen
    if (event is! KeyDownEvent) return;

    final key = event.logicalKey;
    final label = key.keyLabel.toUpperCase();

    // Prüfen, ob die Taste ein Buchstabe (A-Z) oder eine Ziffer (0-9) ist
    final isLetterOrDigit = label.length == 1 && RegExp(r'[A-Z0-9]').hasMatch(label);
    if (!isLetterOrDigit) {
      return; // Alles andere (F1, Space, Enter, etc.) ignorieren wir
    }

    // Modifikatoren sammeln
    final modifiers = <String>[];
    final hardware = HardwareKeyboard.instance;
    if (hardware.isControlPressed) modifiers.add('Strg');
    if (hardware.isAltPressed) modifiers.add('Alt');
    if (hardware.isShiftPressed) modifiers.add('Shift');
    if (hardware.isMetaPressed) modifiers.add('Win');

    // String zusammenbauen (z.B. "Strg+Shift+A")
    final hotkeyString = [...modifiers, label].join('+');

    // Controller und State aktualisieren
    _controller.text = hotkeyString;
    ref.read(autotypeHotkeyProvider.notifier).setHotkey(hotkeyString);
  }

  /// Speichert erst die Änderungen, wenn gewünscht und springt dann zurück.
  Future<void> _handleCancel() async {
    final state = ref.read(autotypeHotkeyProvider);
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
        final notifier = ref.read(autotypeHotkeyProvider.notifier);
        notifier.save(); // Statt Cancel die Save-Action ausführen
        return;
      }
    }

    Navigator.of(context).pop(false); // Zur vorherigen Seite navigieren
  }
}
