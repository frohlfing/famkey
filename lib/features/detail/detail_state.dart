import 'package:privault/core/app_error.dart';
import 'package:privault/database/database.dart';
import 'package:flutter/material.dart';

class DetailState {
  /// Gibt an, ob ein Ladesymbol angezeigt wird
  final bool isBusy;

  // --- Stammdaten ---

  /// Die Kategorie des Eintrags.
  final String category;

  /// Der Anzeigename des Eintrags.
  final String title;

  /// Der Benutzername des Eintrag.
  final String username;

  /// Der Passwort des Eintrag.
  final String password;

  /// Die zugehörige Adresse der Webseite oder des Dienstes.
  final String url;

  /// Ergänzende Notiz (Metadaten).
  final String notes;

  /// Der binäre Dateninhalt des Website-Icons, gespeichert als Base64-kodierter String.
  /// Ermöglicht die visuelle Identifikation in der Liste ohne zusätzliche Netzwerkanfragen.
  final String favicon;

  /// Ein Text-Hinweis über den Ersteller und den Zeitpunkt der letzten Änderung.
  final String auditHint;

  // --- Anhänge ---

  /// Liste der Dateianhänge
  final List<AttachmentEntity> attachments;

  // --- Geteilt mit ---

  /// Liste der Freunde mit Zugriff auf diesen Eintrag
  final List<UserEntity> sharedFriends;

  // --- Teilen mit ---

  final bool canEdit;
  final bool canManageShares;

  // --- Änderungsstatus ---

  /// Gibt an, ob während der Ansicht editiert wurde
  final bool hasChanged;

  // --- Error ---

  /// Der Fehler der letzten Operation.
  final FormError error;

  /// Konstruktor
  const DetailState({
    this.isBusy = false,
    this.title = '',
    this.category = '',
    this.username = '',
    this.password = '',
    this.url = '',
    this.notes = '',
    this.favicon = '',
    this.auditHint = '',
    this.attachments = const [],
    this.sharedFriends = const [],
    this.canEdit = false,
    this.canManageShares = false,
    this.hasChanged = false,
    this.error = const FormError.none(),
  });

  /// Status aktualisieren (immutable)
  DetailState copyWith({
    bool? isBusy,
    String? title,
    String? category,
    String? username,
    String? password,
    String? url,
    String? notes,
    String? favicon,
    String? auditHint,
    List<AttachmentEntity>? attachments,
    List<UserEntity>? sharedFriends,
    bool? canEdit,
    bool? canManageShares,
    bool? hasChanged,
    FormError? error,
  }) {
    return DetailState(
      isBusy: isBusy ?? this.isBusy,
      title: title ?? this.title,
      category: category ?? this.category,
      username: username ?? this.username,
      password: password ?? this.password,
      url: url ?? this.url,
      notes: notes ?? this.notes,
      favicon: favicon ?? this.favicon,
      auditHint: auditHint ?? this.auditHint,
      attachments: attachments ?? this.attachments,
      sharedFriends: sharedFriends ?? this.sharedFriends,
      canEdit: canEdit ?? this.canEdit,
      canManageShares: canManageShares ?? this.canManageShares,
      hasChanged: hasChanged ?? this.hasChanged,
      error: error ?? this.error,
    );
  }
}