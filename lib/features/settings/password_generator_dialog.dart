import 'package:flutter/material.dart';

/// Einstellungen des Passwort-Generators.
class PasswordGeneratorDialogData {
  /// Eingestellte Länge für den Passwortgenerator.
  final int pwLength;

  /// Der aktuell gewählte Satz an Sonderzeichen für generierte Passwörter.
  final String pwSpecialChars;

  /// Gibt an, ob optisch ähnliche Zeichen ('I', 'l', 'O', '0') ausgelassen werden.
  final bool pwAvoidIlO0;

  /// Konstruktor
  const PasswordGeneratorDialogData({
    this.pwLength = 16,
    this.pwSpecialChars = '',
    this.pwAvoidIlO0 = false,
  });

  /// Daten aktualisieren (immutable)
  PasswordGeneratorDialogData copyWith({
    int? pwLength,
    String? pwSpecialChars,
    bool? pwAvoidIlO0,
  }) {
    return PasswordGeneratorDialogData(
      pwLength: pwLength ?? this.pwLength,
      pwSpecialChars: pwSpecialChars ?? this.pwSpecialChars,
      pwAvoidIlO0: pwAvoidIlO0 ?? this.pwAvoidIlO0,
    );
  }

  // @formatter:off
  /// Operator `==` für das Objekt anpassen
  @override
  bool operator == (Object other) =>
    identical(this, other) ||
      other is PasswordGeneratorDialogData && (
        runtimeType == other.runtimeType &&
          pwLength == other.pwLength &&
          pwSpecialChars == other.pwSpecialChars &&
          pwAvoidIlO0 == other.pwAvoidIlO0
    );

  /// Liefert den HashCode für das Objekt
  /// (erforderlich, wenn ein Operators überschrieben wird)
  @override
  int get hashCode =>
    pwLength.hashCode ^
    pwSpecialChars.hashCode ^
    pwAvoidIlO0.hashCode;
// @formatter:on
}

/// Ein modaler Dialog zum Konfigurieren des Passwort-Generators.
class PasswortGeneratorDialog {

  /// Öffnet den Dialog und gibt bei Bestätigung die Einstellungen zurück.
  static Future<PasswordGeneratorDialogData?> show(BuildContext context, {
        int? pwLength,
        String? pwSpecialChars,
        bool? pwAvoidIlO0,
        String? pwLengthErrorText,
        String? pwSpecialCharsErrorText,
  }) {
    final pwLengthController = TextEditingController(text: pwLength.toString());
    final pwSpecialCharsController = TextEditingController(text: pwSpecialChars);
    //var newPwAvoidIlO0 = pwAvoidIlO0;
    return showDialog<PasswordGeneratorDialogData>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Passwort-Generator'),
            content: SizedBox(
              width: 450,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // --- Länge ---
                  TextField(
                    controller: pwLengthController,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: 'Länge',
                      prefixIcon: const Icon(Icons.onetwothree_outlined),
                      errorText: pwLengthErrorText,
                      border: const OutlineInputBorder(),
                      // Minus- und Plus-Button für die Länge
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove),
                            onPressed: () {
                              final val = int.tryParse(pwLengthController.text) ?? 0;
                              if (val > 1) {
                                final newVal = val - 1;
                                pwLengthController.text = newVal.toString();
                                if (pwLengthErrorText != null) {
                                  setDialogState(() => pwLengthErrorText = null);
                                }
                              }
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.add),
                            onPressed: () {
                              final val = int.tryParse(pwLengthController.text) ?? 0;
                              final newVal = val + 1;
                              pwLengthController.text = newVal.toString();
                              if (pwLengthErrorText != null) {
                                setDialogState(() => pwLengthErrorText = null);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    onChanged: (_) {
                      // Sobald getippt wird, Fehlermeldung löschen
                      if (pwLengthErrorText != null) {
                        setDialogState(() => pwLengthErrorText = null);
                      }
                    },
                  ),
                  const SizedBox(height: 16),

                  // --- Sonderzeichen ---
                  TextField(
                    controller: pwSpecialCharsController,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: 'Sonderzeichen',
                      prefixIcon: Icon(Icons.emoji_symbols_outlined),
                      errorText: pwSpecialCharsErrorText,
                      border: OutlineInputBorder(),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.star),
                            tooltip: 'Standard',
                            onPressed: () {
                              pwSpecialCharsController.text = '!@#\$%^&*()_+-=[]{}|;:,.<>?';
                              if (pwSpecialCharsErrorText != null) {
                                setDialogState(() => pwSpecialCharsErrorText = null);
                              }
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.all_inclusive),
                            tooltip: 'Alle',
                            onPressed: () {
                              pwSpecialCharsController.text = '!"#\$%&\'()*+,-./:;<=>?@[\\]^_`{|}~';
                              if (pwSpecialCharsErrorText != null) {
                                setDialogState(() => pwSpecialCharsErrorText = null);
                              }
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.remove_circle),
                            tooltip: 'Keine',
                            onPressed: () {
                              pwSpecialCharsController.text = '';
                              if (pwSpecialCharsErrorText != null) {
                                setDialogState(() => pwSpecialCharsErrorText = null);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    onChanged: (_) {
                      // Sobald getippt wird, Fehlermeldung löschen
                      if (pwSpecialCharsErrorText != null) {
                        setDialogState(() => pwSpecialCharsErrorText = null);
                      }
                    },
                  ),
                  const SizedBox(height: 16),

                  // --- Lesbarkeit optimieren ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Lesbarkeit optimieren (I, l, O, 0 ausschließen)'),
                      Switch(
                        value: pwAvoidIlO0 ?? false,
                        onChanged: (val) {
                          setDialogState(() {
                            pwAvoidIlO0 = val;
                          });
                        },
                      ),
                    ],
                  ),

                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(null),
                child: const Text('Abbrechen'),
              ),
              ElevatedButton(
                onPressed: () {
                  final length = int.tryParse(pwLengthController.text);
                  if (length != null) {
                    final formData = PasswordGeneratorDialogData(
                      pwLength: length,
                      pwSpecialChars: pwSpecialCharsController.text,
                      pwAvoidIlO0: pwAvoidIlO0 ?? false,
                    );
                    Navigator.of(ctx).pop(formData);
                  }
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      },
    );
  }
}
