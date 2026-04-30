import 'package:famkey/core/app_error.dart';
import 'package:famkey/core/app_file.dart';
import 'package:famkey/database/database.dart';
import 'package:famkey/models/payloads/attachment_meta_payload.dart';

/// Ein Enum für den Status von Aktionen
enum DetailActionStatus {
  initial, // Der Ausgangszustand
  progress, // Aktion läuft
  loaded, // Eintrag wurde erfolgreich geladen
  attachmentAdded, // Dateianhang wurde erfolgreich hinzugefügt
  attachmentDeleted, // Dateianhang wurde erfolgreich gelöscht
  attachmentReady,  // Anhang entschlüsselt, bereit zur Anzeige
  shareUpdated, // Freigabe wurde erfolgreich aktualisiert
  accessRevoked, // Zugriffsrecht wurde erfolgreich entzogen
  failure, // Aktion mit Fehler beendet
}

class DetailState {

  // --- Stammdaten ---

  /// Die Kategorie des Eintrags.
  final String category;

  /// Der Anzeigename des Eintrags.
  final String title;

  /// Der Benutzername des Eintrag.
  final String username;

  /// Der Passwort des Eintrag.
  final String password;

  /// Die berechnete Passwortstärke
  final int passwordStrength;

  /// Ein Text-Hinweis über das Alter des Passworts.
  final String passwordHint;

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

  /// Liste der Dateianhänge inkl. Metadaten.
  final List<({AttachmentEntity attachment, AttachmentMetaPayload meta})> attachments;

  /// Die Datei für die Vorschau.
  final AppFile previewFile;

  // --- Teilen mit ---

  /// Gibt an, ob unter Einstellungen Freunde eingepflegt sind.
  final bool canShare;

  /// Alle sichtbaren Freunde zusammen mit den Zugriffsrechten auf diesen Eintrag.
  final List<({UserEntity user, int accessLevel})> friends;

  // --- Zugriffsrecht ---

  /// Das Zugriffsrecht des aktuelle Benutzer auf diesen Eintrag
  /// (0=kein Zugriffsrecht, 1=Lesen, 2=Schreiben, 3=Besitzer).
  final int myAccessLevel;

  // --- Status ---

  /// Der Status der letzten Aktion.
  final DetailActionStatus status;

  // --- Error ---

  /// Der Fehler der letzten Operation.
  final AppError error;

  // --- Getter ---

  /// Gibt an, ob gerade eine Hintergrundaktion läuft.
  bool get isBusy => status == DetailActionStatus.progress;

  /// Gibt an, ob der aktuelle Benutzer Schreibrechte besitzt.
  bool get canEdit => myAccessLevel >= 2;

  /// Gibt an, ob der aktuelle Benutzer Anhänge verwalten darf.
  bool get canManageAttachments => myAccessLevel >= 2;

  /// Gibt an, ob der aktuelle Benutzer die Freigaben verwalten darf (nur Besitzer).
  bool get canManageShares => myAccessLevel >= 3;

  /// Liste der Freunde, mit denen der Eintrag geteilt wurde.
  List<({UserEntity user, int accessLevel})> get sharedFriends {
    return friends.where((f) => f.accessLevel > 0).toList();
  }

  /// Liste der Freunde, mit denen der Eintrag noch nicht geteilt wurde.
  List<UserEntity> get unsharedFriends {
    return friends.where((f) => f.accessLevel == 0).map((f) => f.user).toList();
  }

  /// Konstruktor
  const DetailState({
    this.category = '',
    this.title = '',
    this.username = '',
    this.password = '',
    this.passwordStrength = 0,
    this.passwordHint = '',
    this.url = '',
    this.notes = '',
    this.favicon = '',
    this.auditHint = '',
    this.attachments = const [],
    this.previewFile = const AppFile.none(),
    this.canShare = false,
    this.friends = const [],
    this.myAccessLevel = 1,
    this.status = DetailActionStatus.initial,
    this.error = const AppError.none(),
  });

  /// Status aktualisieren (immutable)
  DetailState copyWith({
    String? category,
    String? title,
    String? username,
    String? password,
    int? passwordStrength,
    String? passwordHint,
    String? url,
    String? notes,
    String? favicon,
    String? auditHint,
    List<({AttachmentEntity attachment, AttachmentMetaPayload meta})>? attachments,
    AppFile? previewFile,
    bool? canShare,
    List<({UserEntity user, int accessLevel})>? friends,
    int? myAccessLevel,
    DetailActionStatus? status,
    AppError? error,
  }) {
    return DetailState(
      category: category ?? this.category,
      title: title ?? this.title,
      username: username ?? this.username,
      password: password ?? this.password,
      passwordStrength: passwordStrength ?? this.passwordStrength,
      passwordHint: passwordHint ?? this.passwordHint,
      url: url ?? this.url,
      notes: notes ?? this.notes,
      favicon: favicon ?? this.favicon,
      auditHint: auditHint ?? this.auditHint,
      attachments: attachments ?? this.attachments,
      previewFile: previewFile ?? this.previewFile,
      canShare: canShare ?? this.canShare,
      friends: friends ?? this.friends,
      myAccessLevel: myAccessLevel ?? this.myAccessLevel,
      status: status ?? this.status,
      error: error ?? this.error,
    );
  }
}