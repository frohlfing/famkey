/// Repräsentiert die Antwort des Servers beim Herunterladen von Änderungen (Pull-Vorgang).
/// Enthält neue oder aktualisierte Einträge sowie Informationen über gelöschte Objekte.
class SyncPullResponse {
  /// Eine Liste von neuen oder aktualisierten Tresoreinträgen.
  final List<SyncEntryDto> updates;

  /// Eine Liste von gelöschten Einträgen (Tombstones).
  final List<SyncDeleteDto> deletes;

  /// Der aktuelle Zeitstempel des Servers zum Zeitpunkt der Anfrage.
  /// Dient als Basis für den nächsten inkrementellen Synchronisationsvorgang.
  final DateTime serverTime;

  /// Konstruktor
  SyncPullResponse({required this.updates, required this.deletes, required this.serverTime});

  /// Wandelt ein JSON-Objekt in ein [SyncPullResponse] Objekt um.
  factory SyncPullResponse.fromJson(Map<String, dynamic> json) {
    return SyncPullResponse(
      updates: (json['updates'] as List).map((e) => SyncEntryDto.fromJson(e as Map<String, dynamic>)).toList(),
      deletes: (json['deletes'] as List).map((e) => SyncDeleteDto.fromJson(e as Map<String, dynamic>)).toList(),
      serverTime: DateTime.tryParse(json['server_time'])?.toUtc() ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true), // Fallback: 1970‑01‑01 00:00:00 UTC
    );
  }
}

/// Transportobjekt für eine Zugriffsberechtigung eines Freundes innerhalb eines Eintrags.
class FriendPermissionDto {
  /// Die globale UUID des Freundes.
  final String userUuid;

  /// Der für diesen Freund RSA-verschlüsselte Entry-Key.
  final String encryptedKey;

  /// Die Berechtigungsstufe (1=Lesen, 2=Schreiben).
  final int accessLevel;

  /// Konstruktor
  FriendPermissionDto({required this.userUuid, required this.encryptedKey, required this.accessLevel});

  factory FriendPermissionDto.fromJson(Map<String, dynamic> json) {
    return FriendPermissionDto(
      userUuid: json['user_uuid'] as String,
      encryptedKey: json['encrypted_key'] as String,
      accessLevel: (json['access_level'] ?? 0) as int,
    );
  }

  /// Wandelt ein [FriendPermissionDto] Objekt in ein JSON-Objekt um.
  Map<String, dynamic> toJson() {
    return {'user_uuid': userUuid, 'encrypted_key': encryptedKey, 'access_level': accessLevel};
  }
}

/// Datenübertragungsobjekt für einen Tresoreintrag auf API-Ebene.
/// Bündelt verschlüsselte Daten, Metadaten und Freigabeinformationen.
class SyncEntryDto {
  /// Die globale eindeutige Identifikationsnummer (UUID v4) des Eintrags.
  final String entryUuid;

  /// Der AES-256-GCM verschlüsselte Daten-Container (Base64).
  final String encryptedData;

  /// Der für den aktuellen Benutzer verschlüsselte Entry-Key (RSA-Umschlag, Base64).
  final String encryptedKey;

  /// Die Zugriffsebene des anfragenden Benutzers für diesen Eintrag.
  final int accessLevel;

  /// Eine Liste von UUIDs zugehöriger Dateianhänge.
  final List<String> attachmentUuids;

  /// Eine Liste von Freigaben für andere Freunde.
  final List<FriendPermissionDto> friends;

  /// Die globale UUID des Benutzers, der diesen Eintrag ursprünglich erstellt hat.
  final String creatorUuid;

  /// Die globale UUID des Benutzers, der die letzte Änderung vorgenommen hat.
  final String updaterUuid;

  /// Zeitpunkt der letzten Änderung (UTC).
  final DateTime updatedAt;

  /// Konstruktor
  SyncEntryDto({
    required this.entryUuid,
    required this.encryptedData,
    required this.encryptedKey,
    required this.accessLevel,
    required this.attachmentUuids,
    required this.friends,
    required this.creatorUuid,
    required this.updaterUuid,
    required this.updatedAt,
  });

  /// Wandelt ein JSON-Objekt in ein [SyncEntryDto] Objekt um.
  factory SyncEntryDto.fromJson(Map<String, dynamic> json) {
    return SyncEntryDto(
      entryUuid: json['entry_uuid'] as String,
      encryptedData: json['encrypted_data'] as String,
      encryptedKey: json['encrypted_key'] as String,
      accessLevel: json['access_level'] as int,
      attachmentUuids: List<String>.from(json['attachment_uuids'] ?? []),
      friends: (json['friends'] as List?)?.map((e) => FriendPermissionDto.fromJson(e as Map<String, dynamic>)).toList() ?? [],
      creatorUuid: json['creator_uuid'] as String,
      updaterUuid: json['updater_uuid'] as String,
      updatedAt: DateTime.tryParse(json['updated_at'])?.toUtc() ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true), // Fallback: 1970‑01‑01 00:00:00 UTC
    );
  }

  /// Wandelt ein [SyncEntryDto] Objekt in ein JSON-Objekt um.
  Map<String, dynamic> toJson() {
    return {
      'entry_uuid': entryUuid,
      'encrypted_data': encryptedData,
      'encrypted_key': encryptedKey,
      'access_level': accessLevel,
      'attachment_uuids': attachmentUuids,
      'friends': friends.map((e) => e.toJson()).toList(),
      'creator_uuid': creatorUuid,
      'updater_uuid': updaterUuid,
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

/// Transportobjekt für einen gelöschten Eintrag (Tombstone).
/// Entspricht `TombstoneDto.cs` aus MAUI.
class SyncDeleteDto {
  /// Die globale UUID des gelöschten Eintrags.
  final String entryUuid;

  /// Zeitpunkt der Löschung (UTC).
  final DateTime deletedAt;

  /// Konstruktor
  SyncDeleteDto({required this.entryUuid, required this.deletedAt});

  /// Wandelt ein JSON-Objekt in ein [SyncDeleteDto] Objekt um.
  factory SyncDeleteDto.fromJson(Map<String, dynamic> json) {
    return SyncDeleteDto(
      entryUuid: json['entry_uuid'] as String,
      deletedAt: DateTime.tryParse(json['deleted_at'])?.toUtc() ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true), // Fallback: 1970‑01‑01 00:00:00 UTC
    );
  }

  /// Wandelt ein [SyncDeleteDto] Objekt in ein JSON-Objekt um.
  Map<String, dynamic> toJson() {
    return {
      'entry_uuid': entryUuid,
      'deleted_at': deletedAt.toIso8601String(),
    };
  }
}

/// Repräsentiert die Anfrage an den Server beim Hochladen lokaler Änderungen (Push-Vorgang).
class SyncPushRequest {
  /// Eine Liste neuer oder lokal geänderter Tresoreinträge.
  final List<SyncEntryDto> updates;

  /// Eine Liste lokaler Löschungen, die auf dem Server nachvollzogen werden sollen.
  final List<SyncDeleteDto> deletes;

  /// Konstruktor
  SyncPushRequest({required this.updates, required this.deletes});

  /// Wandelt ein JSON-Objekt in ein [SyncPushRequest] Objekt um.
  Map<String, dynamic> toJson() {
    return {
      'updates': updates.map((e) => e.toJson()).toList(),
      'deletes': deletes.map((e) => e.toJson()).toList(),
    };
  }
}
