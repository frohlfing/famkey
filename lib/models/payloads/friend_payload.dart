class FriendPayload {
  final String uuid;
  final String name;
  final bool isVerified;
  final bool isHidden;
  final DateTime updatedAt;

  FriendPayload({
    required this.uuid,
    required this.name,
    required this.isVerified,
    required this.isHidden,
    required this.updatedAt,
  });

  factory FriendPayload.fromJson(Map<String, dynamic> json) {
    return FriendPayload(
      uuid: json['uuid'] as String,
      name: json['name'] as String,
      isVerified: json['isVerified'] as bool,
      isHidden: json['isHidden'] as bool,
      updatedAt: DateTime.parse(json['updatedAt'] as String).toUtc(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uuid': uuid,
      'name': name,
      'isVerified': isVerified,
      'isHidden': isHidden,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}