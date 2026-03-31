import 'package:flutter/cupertino.dart';

/// Repräsentiert einen verschlüsselten Tresoreintrag.
/// Dieses Objekt wird als JSON serialisiert und anschließend mittels AES-256-GCM verschlüsselt
/// in der Spalte `encryptedData` der `EntryEntity` gespeichert.
class EntryPayload {
  /// Die Kategorie des Eintrags.
  final String category;

  /// Der Anzeigename oder Titel des Eintrags.
  final String title;

  /// Der Benutzername für diesen Eintrag.
  final String username;

  /// Das Passwort des Eintrags.
  final String password;

  /// Der Zeitstempel des Passworts (UTC).
  final DateTime? passwordTimestamp;

  /// Die zugehörige Web-Adresse.
  final String url;

  /// Ergänzende Notizen zum Eintrag.
  final String notes;

  /// Der binäre Dateninhalt des Website-Icons (Favicon) als Base64-String.
  final String favicon;

  /// Konstruktor
  EntryPayload({
    required this.category,
    required this.title,
    required this.username,
    required this.password,
    required this.passwordTimestamp,
    required this.url,
    required this.notes,
    required this.favicon,
  });

  /// Erstellt eine [EntryPayload] aus einer JSON-Map.
  factory EntryPayload.fromJson(Map<String, dynamic> json) {
    return EntryPayload(
      category: json['category'] as String? ?? '',
      title: json['title'] as String? ?? '',
      username: json['username'] as String? ?? '',
      password: json['password'] as String? ?? '',
      passwordTimestamp: DateTime.tryParse(json['password_timestamp'] ?? '')?.toUtc(),
      url: json['url'] as String? ?? '',
      notes: json['notes'] as String? ?? '',
      favicon: json['favicon'] as String? ?? '',
    );
  }

  /// Konvertiert eine [EntryPayload] in eine Map für die JSON-Serialisierung.
  Map<String, dynamic> toJson() {
    return {
      'category': category,
      'title': title,
      'username': username,
      'password': password,
      'password_timestamp': passwordTimestamp?.toIso8601String(),
      'url': url,
      'notes': notes,
      'favicon': favicon,
    };
  }
}
