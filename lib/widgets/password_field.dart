import 'package:flutter/material.dart';

// Das StatefulWidget-Pattern
//
// Die Unterteilung in zwei Klassen in Flutter absolut üblich und sogar technisch notwendig, sobald
// ein Widget einen eigenen Zustand (State) verwalten muss, der sich während der Laufzeit ändert.
//
// 1. Die PasswordField-Klasse (Das Widget):
// - Diese Klasse ist immutable (unveränderlich). Sie dient als "Bauplan" oder Konfiguration.
// - Hier liegen alle Parameter, die du von außen übergibst (z.B. das Label oder der Controller).
// - Flutter kann dieses Widget sehr schnell zerstören und neu erstellen, wenn sich im übergeordneten Screen etwas ändert.
//
// 2. Die _PasswordFieldState-Klasse (Der State):
// - Diese Klasse ist persistent. Sie bleibt im Speicher erhalten, auch wenn das PasswordField oben drüber neu gebaut wird.
// - Hier liegt die Variable bool _obscureText. Ohne diese zweite Klasse würde das Passwort-Feld bei jedem Neuzeichnen des Screens (z. B. durch eine Animation oder eine andere Änderung) vergessen, ob das Passwort gerade sichtbar ist oder nicht.

class PasswordField extends StatefulWidget {
  // Interne Variablen

  // Damit kannst du von außen den Text auslesen oder setzen (z.B. wenn du ein Passwort generierst).
  final TextEditingController controller;

  // Der Text, der oben im Feld steht (z. B. "Master-Passwort"), um dem Nutzer zu sagen, was er eingeben soll.
  final String label;

  // Ein optionales Icon am Anfang des Feldes (z.B. `Icons.lock`). Wenn du `null` übergibst, wird kein Icon angezeigt.
  final IconData? prefixIcon;

  // Wenn dieser String nicht null ist, färbt sich das Feld rot und zeigt die Fehlermeldung darunter an (wichtig für Validierungen).
  final String? errorText;

  // Steuert, welcher Button auf der Tastatur unten rechts erscheint (z.B. "Weiter", "Fertig" oder "Suchen").
  final TextInputAction? textInputAction;

  // Damit kannst du steuern, wann das Feld den Fokus erhält oder verliert (hilfreich, um den Cursor per Code ins Feld zu springen zu lassen).
  final FocusNode? focusNode;

  // Wenn auf true gesetzt, springt der Cursor sofort beim Öffnen des Screens in dieses Feld.
  final bool autofocus;

  // Eine Funktion, die jedes Mal aufgerufen wird, wenn der Nutzer ein Zeichen tippt oder löscht.
  final ValueChanged<String>? onChanged;

  // Eine Funktion, die aufgerufen wird, wenn der Nutzer den Ok-Button auf der Tastatur drückt.
  final ValueChanged<String>? onSubmitted;

  /// Zusätzliche Buttons wie Würfel, Kopieren, oder Fingerprint
  final List<Widget>? suffixActions;

  /// Konstruktor
  const PasswordField({
    super.key,
    required this.controller,
    required this.label,
    this.prefixIcon,
    this.errorText,
    this.textInputAction,
    this.focusNode,
    this.autofocus = false,
    this.onChanged,
    this.onSubmitted,
    this.suffixActions,
  });

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscureText = true;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      obscureText: _obscureText,
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      textInputAction: widget.textInputAction,
      decoration: InputDecoration(
        labelText: widget.label,
        prefixIcon: widget.prefixIcon != null ? Icon(widget.prefixIcon) : null,
        border: const OutlineInputBorder(),
        errorText: widget.errorText,
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            // Der Standard-Toggle für die Sichtbarkeit
            IconButton(
              icon: Icon(_obscureText ? Icons.visibility : Icons.visibility_off),
              tooltip: _obscureText ? 'Anzeigen' : 'Verbergen',
              onPressed: () => setState(() => _obscureText = !_obscureText),
            ),
            // Hier kommen die speziellen Buttons rein (Würfel, Kopieren, etc.)
            ...?widget.suffixActions,
          ],
        ),
      ),
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
    );
  }
}