class SyncPullResponse {
  final List<SyncEntryDto> updates;
  final List<SyncDeleteDto> deletes;
  final DateTime serverTime;

  SyncPullResponse({
    required this.updates,
    required this.deletes,
    required this.serverTime,
  });

  factory SyncPullResponse.fromJson(Map<String, dynamic> json) {
    return SyncPullResponse(
      updates: (json['updates'] as List)
          .map((e) => SyncEntryDto.fromJson(e as Map<String, dynamic>))
          .toList(),
      deletes: (json['deletes'] as List)
          .map((e) => SyncDeleteDto.fromJson(e as Map<String, dynamic>))
          .toList(),
      serverTime: DateTime.parse(json['server_time'] as String).toUtc(),
    );
  }
}

class FriendPermissionDto {
  final String userUuid;
  final String? encryptedKey;
  final int accessLevel;

  FriendPermissionDto({
    required this.userUuid,
    this.encryptedKey,
    required this.accessLevel,
  });

  factory FriendPermissionDto.fromJson(Map<String, dynamic> json) {
    return FriendPermissionDto(
      userUuid: json['user_uuid'] as String,
      encryptedKey: json['encrypted_key'] as String?,
      accessLevel: json['access_level'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_uuid': userUuid,
      'encrypted_key': encryptedKey,
      'access_level': accessLevel,
    };
  }
}

class SyncEntryDto {
  final String entryUuid;
  final String encryptedData;
  final String? encryptedKey; // Local user's key
  final int accessLevel;
  final List<String> attachmentUuids;
  final List<FriendPermissionDto> friends;
  final String creatorUuid;
  final String updaterUuid;
  final DateTime updatedAt;

  SyncEntryDto({
    required this.entryUuid,
    required this.encryptedData,
    this.encryptedKey,
    required this.accessLevel,
    required this.attachmentUuids,
    required this.friends,
    required this.creatorUuid,
    required this.updaterUuid,
    required this.updatedAt,
  });

  factory SyncEntryDto.fromJson(Map<String, dynamic> json) {
    return SyncEntryDto(
      entryUuid: json['entry_uuid'] as String,
      encryptedData: json['encrypted_data'] as String,
      encryptedKey: json['encrypted_key'] as String?,
      accessLevel: json['access_level'] as int,
      attachmentUuids: List<String>.from(json['attachment_uuids'] ?? []),
      friends: (json['friends'] as List?)
              ?.map((e) => FriendPermissionDto.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      creatorUuid: json['creator_uuid'] as String,
      updaterUuid: json['updater_uuid'] as String,
      updatedAt: DateTime.parse(json['updated_at'] as String).toUtc(),
    );
  }

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

class SyncDeleteDto {
  final String entryUuid;
  final DateTime deletedAt;

  SyncDeleteDto({required this.entryUuid, required this.deletedAt});

  factory SyncDeleteDto.fromJson(Map<String, dynamic> json) {
    return SyncDeleteDto(
      entryUuid: json['entry_uuid'] as String,
      deletedAt: DateTime.parse(json['deleted_at'] as String).toUtc(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'entry_uuid': entryUuid,
      'deleted_at': deletedAt.toIso8601String(),
    };
  }
}

class SyncPushRequest {
  final List<SyncEntryDto> updates;
  final List<SyncDeleteDto> deletes;

  SyncPushRequest({required this.updates, required this.deletes});

  Map<String, dynamic> toJson() {
    return {
      'updates': updates.map((e) => e.toJson()).toList(),
      'deletes': deletes.map((e) => e.toJson()).toList(),
    };
  }
}
