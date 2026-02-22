class SettingsEntity {
  final int id;
  final String salt;
  final String encryptedPrivateKey;
  final String host;
  final String apiToken;
  final bool useBiometric;
  final int pwLength;
  final String pwSpecialChars;
  final bool pwAvoidIlO0;
  final String categoryPlaceholder;
  final DateTime lastSyncAt;

  SettingsEntity({
    this.id = 1,
    this.salt = '',
    this.encryptedPrivateKey = '',
    this.host = '',
    this.apiToken = '',
    this.useBiometric = false, // DEFAULT: Deaktiviert
    this.pwLength = 16,
    this.pwSpecialChars = '',
    this.pwAvoidIlO0 = true,
    this.categoryPlaceholder = '',
    required this.lastSyncAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'salt': salt,
      'encrypted_private_key': encryptedPrivateKey,
      'host': host,
      'api_token': apiToken,
      'use_bi_ometric': useBiometric ? 1 : 0, // Matching Drift mapping if needed
      'use_biometric': useBiometric ? 1 : 0,
      'pw_length': pwLength,
      'pw_special_chars': pwSpecialChars,
      'pw_avoid_ilo0': pwAvoidIlO0 ? 1 : 0,
      'category_placeholder': categoryPlaceholder,
      'last_sync_at': lastSyncAt.toIso8601String(),
    };
  }

  factory SettingsEntity.fromMap(Map<String, dynamic> map) {
    return SettingsEntity(
      id: map['id'] as int? ?? 1,
      salt: map['salt'] as String? ?? '',
      encryptedPrivateKey: map['encrypted_private_key'] as String? ?? '',
      host: map['host'] as String? ?? '',
      apiToken: map['api_token'] as String? ?? '',
      useBiometric: (map['use_biometric'] as int? ?? 0) == 1,
      pwLength: map['pw_length'] as int? ?? 16,
      pwSpecialChars: map['pw_special_chars'] as String? ?? '',
      pwAvoidIlO0: (map['pw_avoid_ilo0'] as int? ?? 1) == 1,
      categoryPlaceholder: map['category_placeholder'] as String? ?? '',
      lastSyncAt: DateTime.parse(map['last_sync_at'] as String).toUtc(),
    );
  }

  SettingsEntity copyWith({
    int? id,
    String? salt,
    String? encryptedPrivateKey,
    String? host,
    String? apiToken,
    bool? useBiometric,
    int? pwLength,
    String? pwSpecialChars,
    bool? pwAvoidIlO0,
    String? categoryPlaceholder,
    DateTime? lastSyncAt,
  }) {
    return SettingsEntity(
      id: id ?? this.id,
      salt: salt ?? this.salt,
      encryptedPrivateKey: encryptedPrivateKey ?? this.encryptedPrivateKey,
      host: host ?? this.host,
      apiToken: apiToken ?? this.apiToken,
      useBiometric: useBiometric ?? this.useBiometric,
      pwLength: pwLength ?? this.pwLength,
      pwSpecialChars: pwSpecialChars ?? this.pwSpecialChars,
      pwAvoidIlO0: pwAvoidIlO0 ?? this.pwAvoidIlO0,
      categoryPlaceholder: categoryPlaceholder ?? this.categoryPlaceholder,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
    );
  }
}
