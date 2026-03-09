import 'package:flutter/material.dart';

class PasswordStrengthBar extends StatelessWidget {
  final int score;

  /// Konstruktor
  const PasswordStrengthBar({super.key, required this.score});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: (score + 1) / 5,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(_getStrengthColor(score)),
              minHeight: 4,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          _getStrengthText(score),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: _getStrengthColor(score),
          ),
        ),
      ],
    );
  }

  /// Bestimmt die Farbe der Stärke-Anzeige basierend auf der Bewertung des Passworts.
  ///
  /// Die Skala reicht von dezentem Grau (keine Eingabe) über Rot (sehr schwach)
  /// bis hin zu sattem Grün (stark).
  Color _getStrengthColor(int score) {
    // @formatter:off
    switch (score) {
      case 1: return const Color(0xFFDC2626);
      case 2: return const Color(0xFFF59E0B);
      case 3: return const Color(0xFF84CC16);
      case 4: return const Color(0xFF16A34A);
      default: return const Color(0xFFCBD5E1);
    }
    // @formatter:on
  }

  /// Liefert den passenden Beschreibungstext für die visuelle Passwort-Stärke-Anzeige.
  String _getStrengthText(int score) {
    // @formatter:off
    switch (score) {
      case 1: return "Sehr schwach";
      case 2: return "Schwach";
      case 3: return "Gut";
      case 4: return "Stark";
      default: return "";
    }
    // @formatter:on
  }
}