// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $UsersTable extends Users with TableInfo<$UsersTable, UserData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UsersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _uuidMeta = const VerificationMeta('uuid');
  @override
  late final GeneratedColumn<String> uuid = GeneratedColumn<String>(
    'uuid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _publicKeyMeta = const VerificationMeta(
    'publicKey',
  );
  @override
  late final GeneratedColumn<String> publicKey = GeneratedColumn<String>(
    'public_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isVerifiedMeta = const VerificationMeta(
    'isVerified',
  );
  @override
  late final GeneratedColumn<bool> isVerified = GeneratedColumn<bool>(
    'is_verified',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_verified" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isHiddenMeta = const VerificationMeta(
    'isHidden',
  );
  @override
  late final GeneratedColumn<bool> isHidden = GeneratedColumn<bool>(
    'is_hidden',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_hidden" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    uuid,
    name,
    publicKey,
    isVerified,
    isHidden,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'users';
  @override
  VerificationContext validateIntegrity(
    Insertable<UserData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('uuid')) {
      context.handle(
        _uuidMeta,
        uuid.isAcceptableOrUnknown(data['uuid']!, _uuidMeta),
      );
    } else if (isInserting) {
      context.missing(_uuidMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('public_key')) {
      context.handle(
        _publicKeyMeta,
        publicKey.isAcceptableOrUnknown(data['public_key']!, _publicKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_publicKeyMeta);
    }
    if (data.containsKey('is_verified')) {
      context.handle(
        _isVerifiedMeta,
        isVerified.isAcceptableOrUnknown(data['is_verified']!, _isVerifiedMeta),
      );
    }
    if (data.containsKey('is_hidden')) {
      context.handle(
        _isHiddenMeta,
        isHidden.isAcceptableOrUnknown(data['is_hidden']!, _isHiddenMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  UserData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UserData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      uuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}uuid'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      publicKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}public_key'],
      )!,
      isVerified: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_verified'],
      )!,
      isHidden: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_hidden'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $UsersTable createAlias(String alias) {
    return $UsersTable(attachedDatabase, alias);
  }
}

class UserData extends DataClass implements Insertable<UserData> {
  final int id;
  final String uuid;
  final String name;
  final String publicKey;
  final bool isVerified;
  final bool isHidden;
  final DateTime updatedAt;
  const UserData({
    required this.id,
    required this.uuid,
    required this.name,
    required this.publicKey,
    required this.isVerified,
    required this.isHidden,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['uuid'] = Variable<String>(uuid);
    map['name'] = Variable<String>(name);
    map['public_key'] = Variable<String>(publicKey);
    map['is_verified'] = Variable<bool>(isVerified);
    map['is_hidden'] = Variable<bool>(isHidden);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  UsersCompanion toCompanion(bool nullToAbsent) {
    return UsersCompanion(
      id: Value(id),
      uuid: Value(uuid),
      name: Value(name),
      publicKey: Value(publicKey),
      isVerified: Value(isVerified),
      isHidden: Value(isHidden),
      updatedAt: Value(updatedAt),
    );
  }

  factory UserData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UserData(
      id: serializer.fromJson<int>(json['id']),
      uuid: serializer.fromJson<String>(json['uuid']),
      name: serializer.fromJson<String>(json['name']),
      publicKey: serializer.fromJson<String>(json['publicKey']),
      isVerified: serializer.fromJson<bool>(json['isVerified']),
      isHidden: serializer.fromJson<bool>(json['isHidden']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'uuid': serializer.toJson<String>(uuid),
      'name': serializer.toJson<String>(name),
      'publicKey': serializer.toJson<String>(publicKey),
      'isVerified': serializer.toJson<bool>(isVerified),
      'isHidden': serializer.toJson<bool>(isHidden),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  UserData copyWith({
    int? id,
    String? uuid,
    String? name,
    String? publicKey,
    bool? isVerified,
    bool? isHidden,
    DateTime? updatedAt,
  }) => UserData(
    id: id ?? this.id,
    uuid: uuid ?? this.uuid,
    name: name ?? this.name,
    publicKey: publicKey ?? this.publicKey,
    isVerified: isVerified ?? this.isVerified,
    isHidden: isHidden ?? this.isHidden,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  UserData copyWithCompanion(UsersCompanion data) {
    return UserData(
      id: data.id.present ? data.id.value : this.id,
      uuid: data.uuid.present ? data.uuid.value : this.uuid,
      name: data.name.present ? data.name.value : this.name,
      publicKey: data.publicKey.present ? data.publicKey.value : this.publicKey,
      isVerified: data.isVerified.present
          ? data.isVerified.value
          : this.isVerified,
      isHidden: data.isHidden.present ? data.isHidden.value : this.isHidden,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UserData(')
          ..write('id: $id, ')
          ..write('uuid: $uuid, ')
          ..write('name: $name, ')
          ..write('publicKey: $publicKey, ')
          ..write('isVerified: $isVerified, ')
          ..write('isHidden: $isHidden, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, uuid, name, publicKey, isVerified, isHidden, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserData &&
          other.id == this.id &&
          other.uuid == this.uuid &&
          other.name == this.name &&
          other.publicKey == this.publicKey &&
          other.isVerified == this.isVerified &&
          other.isHidden == this.isHidden &&
          other.updatedAt == this.updatedAt);
}

class UsersCompanion extends UpdateCompanion<UserData> {
  final Value<int> id;
  final Value<String> uuid;
  final Value<String> name;
  final Value<String> publicKey;
  final Value<bool> isVerified;
  final Value<bool> isHidden;
  final Value<DateTime> updatedAt;
  const UsersCompanion({
    this.id = const Value.absent(),
    this.uuid = const Value.absent(),
    this.name = const Value.absent(),
    this.publicKey = const Value.absent(),
    this.isVerified = const Value.absent(),
    this.isHidden = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  UsersCompanion.insert({
    this.id = const Value.absent(),
    required String uuid,
    required String name,
    required String publicKey,
    this.isVerified = const Value.absent(),
    this.isHidden = const Value.absent(),
    required DateTime updatedAt,
  }) : uuid = Value(uuid),
       name = Value(name),
       publicKey = Value(publicKey),
       updatedAt = Value(updatedAt);
  static Insertable<UserData> custom({
    Expression<int>? id,
    Expression<String>? uuid,
    Expression<String>? name,
    Expression<String>? publicKey,
    Expression<bool>? isVerified,
    Expression<bool>? isHidden,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (uuid != null) 'uuid': uuid,
      if (name != null) 'name': name,
      if (publicKey != null) 'public_key': publicKey,
      if (isVerified != null) 'is_verified': isVerified,
      if (isHidden != null) 'is_hidden': isHidden,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  UsersCompanion copyWith({
    Value<int>? id,
    Value<String>? uuid,
    Value<String>? name,
    Value<String>? publicKey,
    Value<bool>? isVerified,
    Value<bool>? isHidden,
    Value<DateTime>? updatedAt,
  }) {
    return UsersCompanion(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      name: name ?? this.name,
      publicKey: publicKey ?? this.publicKey,
      isVerified: isVerified ?? this.isVerified,
      isHidden: isHidden ?? this.isHidden,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (uuid.present) {
      map['uuid'] = Variable<String>(uuid.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (publicKey.present) {
      map['public_key'] = Variable<String>(publicKey.value);
    }
    if (isVerified.present) {
      map['is_verified'] = Variable<bool>(isVerified.value);
    }
    if (isHidden.present) {
      map['is_hidden'] = Variable<bool>(isHidden.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UsersCompanion(')
          ..write('id: $id, ')
          ..write('uuid: $uuid, ')
          ..write('name: $name, ')
          ..write('publicKey: $publicKey, ')
          ..write('isVerified: $isVerified, ')
          ..write('isHidden: $isHidden, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $EntriesTable extends Entries with TableInfo<$EntriesTable, EntryData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _uuidMeta = const VerificationMeta('uuid');
  @override
  late final GeneratedColumn<String> uuid = GeneratedColumn<String>(
    'uuid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _urlMeta = const VerificationMeta('url');
  @override
  late final GeneratedColumn<String> url = GeneratedColumn<String>(
    'url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _faviconMeta = const VerificationMeta(
    'favicon',
  );
  @override
  late final GeneratedColumn<String> favicon = GeneratedColumn<String>(
    'favicon',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _encryptedDataMeta = const VerificationMeta(
    'encryptedData',
  );
  @override
  late final GeneratedColumn<String> encryptedData = GeneratedColumn<String>(
    'encrypted_data',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _creatorIdMeta = const VerificationMeta(
    'creatorId',
  );
  @override
  late final GeneratedColumn<int> creatorId = GeneratedColumn<int>(
    'creator_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updaterIdMeta = const VerificationMeta(
    'updaterId',
  );
  @override
  late final GeneratedColumn<int> updaterId = GeneratedColumn<int>(
    'updater_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    uuid,
    category,
    title,
    url,
    notes,
    favicon,
    encryptedData,
    creatorId,
    updaterId,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<EntryData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('uuid')) {
      context.handle(
        _uuidMeta,
        uuid.isAcceptableOrUnknown(data['uuid']!, _uuidMeta),
      );
    } else if (isInserting) {
      context.missing(_uuidMeta);
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('url')) {
      context.handle(
        _urlMeta,
        url.isAcceptableOrUnknown(data['url']!, _urlMeta),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('favicon')) {
      context.handle(
        _faviconMeta,
        favicon.isAcceptableOrUnknown(data['favicon']!, _faviconMeta),
      );
    }
    if (data.containsKey('encrypted_data')) {
      context.handle(
        _encryptedDataMeta,
        encryptedData.isAcceptableOrUnknown(
          data['encrypted_data']!,
          _encryptedDataMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_encryptedDataMeta);
    }
    if (data.containsKey('creator_id')) {
      context.handle(
        _creatorIdMeta,
        creatorId.isAcceptableOrUnknown(data['creator_id']!, _creatorIdMeta),
      );
    } else if (isInserting) {
      context.missing(_creatorIdMeta);
    }
    if (data.containsKey('updater_id')) {
      context.handle(
        _updaterIdMeta,
        updaterId.isAcceptableOrUnknown(data['updater_id']!, _updaterIdMeta),
      );
    } else if (isInserting) {
      context.missing(_updaterIdMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  EntryData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EntryData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      uuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}uuid'],
      )!,
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      url: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}url'],
      )!,
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      )!,
      favicon: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}favicon'],
      )!,
      encryptedData: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}encrypted_data'],
      )!,
      creatorId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}creator_id'],
      )!,
      updaterId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updater_id'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $EntriesTable createAlias(String alias) {
    return $EntriesTable(attachedDatabase, alias);
  }
}

class EntryData extends DataClass implements Insertable<EntryData> {
  final int id;
  final String uuid;
  final String category;
  final String title;
  final String url;
  final String notes;
  final String favicon;
  final String encryptedData;
  final int creatorId;
  final int updaterId;
  final DateTime updatedAt;
  const EntryData({
    required this.id,
    required this.uuid,
    required this.category,
    required this.title,
    required this.url,
    required this.notes,
    required this.favicon,
    required this.encryptedData,
    required this.creatorId,
    required this.updaterId,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['uuid'] = Variable<String>(uuid);
    map['category'] = Variable<String>(category);
    map['title'] = Variable<String>(title);
    map['url'] = Variable<String>(url);
    map['notes'] = Variable<String>(notes);
    map['favicon'] = Variable<String>(favicon);
    map['encrypted_data'] = Variable<String>(encryptedData);
    map['creator_id'] = Variable<int>(creatorId);
    map['updater_id'] = Variable<int>(updaterId);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  EntriesCompanion toCompanion(bool nullToAbsent) {
    return EntriesCompanion(
      id: Value(id),
      uuid: Value(uuid),
      category: Value(category),
      title: Value(title),
      url: Value(url),
      notes: Value(notes),
      favicon: Value(favicon),
      encryptedData: Value(encryptedData),
      creatorId: Value(creatorId),
      updaterId: Value(updaterId),
      updatedAt: Value(updatedAt),
    );
  }

  factory EntryData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EntryData(
      id: serializer.fromJson<int>(json['id']),
      uuid: serializer.fromJson<String>(json['uuid']),
      category: serializer.fromJson<String>(json['category']),
      title: serializer.fromJson<String>(json['title']),
      url: serializer.fromJson<String>(json['url']),
      notes: serializer.fromJson<String>(json['notes']),
      favicon: serializer.fromJson<String>(json['favicon']),
      encryptedData: serializer.fromJson<String>(json['encryptedData']),
      creatorId: serializer.fromJson<int>(json['creatorId']),
      updaterId: serializer.fromJson<int>(json['updaterId']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'uuid': serializer.toJson<String>(uuid),
      'category': serializer.toJson<String>(category),
      'title': serializer.toJson<String>(title),
      'url': serializer.toJson<String>(url),
      'notes': serializer.toJson<String>(notes),
      'favicon': serializer.toJson<String>(favicon),
      'encryptedData': serializer.toJson<String>(encryptedData),
      'creatorId': serializer.toJson<int>(creatorId),
      'updaterId': serializer.toJson<int>(updaterId),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  EntryData copyWith({
    int? id,
    String? uuid,
    String? category,
    String? title,
    String? url,
    String? notes,
    String? favicon,
    String? encryptedData,
    int? creatorId,
    int? updaterId,
    DateTime? updatedAt,
  }) => EntryData(
    id: id ?? this.id,
    uuid: uuid ?? this.uuid,
    category: category ?? this.category,
    title: title ?? this.title,
    url: url ?? this.url,
    notes: notes ?? this.notes,
    favicon: favicon ?? this.favicon,
    encryptedData: encryptedData ?? this.encryptedData,
    creatorId: creatorId ?? this.creatorId,
    updaterId: updaterId ?? this.updaterId,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  EntryData copyWithCompanion(EntriesCompanion data) {
    return EntryData(
      id: data.id.present ? data.id.value : this.id,
      uuid: data.uuid.present ? data.uuid.value : this.uuid,
      category: data.category.present ? data.category.value : this.category,
      title: data.title.present ? data.title.value : this.title,
      url: data.url.present ? data.url.value : this.url,
      notes: data.notes.present ? data.notes.value : this.notes,
      favicon: data.favicon.present ? data.favicon.value : this.favicon,
      encryptedData: data.encryptedData.present
          ? data.encryptedData.value
          : this.encryptedData,
      creatorId: data.creatorId.present ? data.creatorId.value : this.creatorId,
      updaterId: data.updaterId.present ? data.updaterId.value : this.updaterId,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EntryData(')
          ..write('id: $id, ')
          ..write('uuid: $uuid, ')
          ..write('category: $category, ')
          ..write('title: $title, ')
          ..write('url: $url, ')
          ..write('notes: $notes, ')
          ..write('favicon: $favicon, ')
          ..write('encryptedData: $encryptedData, ')
          ..write('creatorId: $creatorId, ')
          ..write('updaterId: $updaterId, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    uuid,
    category,
    title,
    url,
    notes,
    favicon,
    encryptedData,
    creatorId,
    updaterId,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EntryData &&
          other.id == this.id &&
          other.uuid == this.uuid &&
          other.category == this.category &&
          other.title == this.title &&
          other.url == this.url &&
          other.notes == this.notes &&
          other.favicon == this.favicon &&
          other.encryptedData == this.encryptedData &&
          other.creatorId == this.creatorId &&
          other.updaterId == this.updaterId &&
          other.updatedAt == this.updatedAt);
}

class EntriesCompanion extends UpdateCompanion<EntryData> {
  final Value<int> id;
  final Value<String> uuid;
  final Value<String> category;
  final Value<String> title;
  final Value<String> url;
  final Value<String> notes;
  final Value<String> favicon;
  final Value<String> encryptedData;
  final Value<int> creatorId;
  final Value<int> updaterId;
  final Value<DateTime> updatedAt;
  const EntriesCompanion({
    this.id = const Value.absent(),
    this.uuid = const Value.absent(),
    this.category = const Value.absent(),
    this.title = const Value.absent(),
    this.url = const Value.absent(),
    this.notes = const Value.absent(),
    this.favicon = const Value.absent(),
    this.encryptedData = const Value.absent(),
    this.creatorId = const Value.absent(),
    this.updaterId = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  EntriesCompanion.insert({
    this.id = const Value.absent(),
    required String uuid,
    this.category = const Value.absent(),
    this.title = const Value.absent(),
    this.url = const Value.absent(),
    this.notes = const Value.absent(),
    this.favicon = const Value.absent(),
    required String encryptedData,
    required int creatorId,
    required int updaterId,
    required DateTime updatedAt,
  }) : uuid = Value(uuid),
       encryptedData = Value(encryptedData),
       creatorId = Value(creatorId),
       updaterId = Value(updaterId),
       updatedAt = Value(updatedAt);
  static Insertable<EntryData> custom({
    Expression<int>? id,
    Expression<String>? uuid,
    Expression<String>? category,
    Expression<String>? title,
    Expression<String>? url,
    Expression<String>? notes,
    Expression<String>? favicon,
    Expression<String>? encryptedData,
    Expression<int>? creatorId,
    Expression<int>? updaterId,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (uuid != null) 'uuid': uuid,
      if (category != null) 'category': category,
      if (title != null) 'title': title,
      if (url != null) 'url': url,
      if (notes != null) 'notes': notes,
      if (favicon != null) 'favicon': favicon,
      if (encryptedData != null) 'encrypted_data': encryptedData,
      if (creatorId != null) 'creator_id': creatorId,
      if (updaterId != null) 'updater_id': updaterId,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  EntriesCompanion copyWith({
    Value<int>? id,
    Value<String>? uuid,
    Value<String>? category,
    Value<String>? title,
    Value<String>? url,
    Value<String>? notes,
    Value<String>? favicon,
    Value<String>? encryptedData,
    Value<int>? creatorId,
    Value<int>? updaterId,
    Value<DateTime>? updatedAt,
  }) {
    return EntriesCompanion(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      category: category ?? this.category,
      title: title ?? this.title,
      url: url ?? this.url,
      notes: notes ?? this.notes,
      favicon: favicon ?? this.favicon,
      encryptedData: encryptedData ?? this.encryptedData,
      creatorId: creatorId ?? this.creatorId,
      updaterId: updaterId ?? this.updaterId,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (uuid.present) {
      map['uuid'] = Variable<String>(uuid.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (url.present) {
      map['url'] = Variable<String>(url.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (favicon.present) {
      map['favicon'] = Variable<String>(favicon.value);
    }
    if (encryptedData.present) {
      map['encrypted_data'] = Variable<String>(encryptedData.value);
    }
    if (creatorId.present) {
      map['creator_id'] = Variable<int>(creatorId.value);
    }
    if (updaterId.present) {
      map['updater_id'] = Variable<int>(updaterId.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EntriesCompanion(')
          ..write('id: $id, ')
          ..write('uuid: $uuid, ')
          ..write('category: $category, ')
          ..write('title: $title, ')
          ..write('url: $url, ')
          ..write('notes: $notes, ')
          ..write('favicon: $favicon, ')
          ..write('encryptedData: $encryptedData, ')
          ..write('creatorId: $creatorId, ')
          ..write('updaterId: $updaterId, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $PermissionsTable extends Permissions
    with TableInfo<$PermissionsTable, PermissionData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PermissionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _entryIdMeta = const VerificationMeta(
    'entryId',
  );
  @override
  late final GeneratedColumn<int> entryId = GeneratedColumn<int>(
    'entry_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES entries (id)',
    ),
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<int> userId = GeneratedColumn<int>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES users (id)',
    ),
  );
  static const VerificationMeta _encryptedKeyMeta = const VerificationMeta(
    'encryptedKey',
  );
  @override
  late final GeneratedColumn<String> encryptedKey = GeneratedColumn<String>(
    'encrypted_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _accessLevelMeta = const VerificationMeta(
    'accessLevel',
  );
  @override
  late final GeneratedColumn<int> accessLevel = GeneratedColumn<int>(
    'access_level',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    entryId,
    userId,
    encryptedKey,
    accessLevel,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'permissions';
  @override
  VerificationContext validateIntegrity(
    Insertable<PermissionData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('entry_id')) {
      context.handle(
        _entryIdMeta,
        entryId.isAcceptableOrUnknown(data['entry_id']!, _entryIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entryIdMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('encrypted_key')) {
      context.handle(
        _encryptedKeyMeta,
        encryptedKey.isAcceptableOrUnknown(
          data['encrypted_key']!,
          _encryptedKeyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_encryptedKeyMeta);
    }
    if (data.containsKey('access_level')) {
      context.handle(
        _accessLevelMeta,
        accessLevel.isAcceptableOrUnknown(
          data['access_level']!,
          _accessLevelMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_accessLevelMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {entryId, userId},
  ];
  @override
  PermissionData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PermissionData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      entryId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}entry_id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}user_id'],
      )!,
      encryptedKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}encrypted_key'],
      )!,
      accessLevel: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}access_level'],
      )!,
    );
  }

  @override
  $PermissionsTable createAlias(String alias) {
    return $PermissionsTable(attachedDatabase, alias);
  }
}

class PermissionData extends DataClass implements Insertable<PermissionData> {
  final int id;
  final int entryId;
  final int userId;
  final String encryptedKey;
  final int accessLevel;
  const PermissionData({
    required this.id,
    required this.entryId,
    required this.userId,
    required this.encryptedKey,
    required this.accessLevel,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['entry_id'] = Variable<int>(entryId);
    map['user_id'] = Variable<int>(userId);
    map['encrypted_key'] = Variable<String>(encryptedKey);
    map['access_level'] = Variable<int>(accessLevel);
    return map;
  }

  PermissionsCompanion toCompanion(bool nullToAbsent) {
    return PermissionsCompanion(
      id: Value(id),
      entryId: Value(entryId),
      userId: Value(userId),
      encryptedKey: Value(encryptedKey),
      accessLevel: Value(accessLevel),
    );
  }

  factory PermissionData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PermissionData(
      id: serializer.fromJson<int>(json['id']),
      entryId: serializer.fromJson<int>(json['entryId']),
      userId: serializer.fromJson<int>(json['userId']),
      encryptedKey: serializer.fromJson<String>(json['encryptedKey']),
      accessLevel: serializer.fromJson<int>(json['accessLevel']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'entryId': serializer.toJson<int>(entryId),
      'userId': serializer.toJson<int>(userId),
      'encryptedKey': serializer.toJson<String>(encryptedKey),
      'accessLevel': serializer.toJson<int>(accessLevel),
    };
  }

  PermissionData copyWith({
    int? id,
    int? entryId,
    int? userId,
    String? encryptedKey,
    int? accessLevel,
  }) => PermissionData(
    id: id ?? this.id,
    entryId: entryId ?? this.entryId,
    userId: userId ?? this.userId,
    encryptedKey: encryptedKey ?? this.encryptedKey,
    accessLevel: accessLevel ?? this.accessLevel,
  );
  PermissionData copyWithCompanion(PermissionsCompanion data) {
    return PermissionData(
      id: data.id.present ? data.id.value : this.id,
      entryId: data.entryId.present ? data.entryId.value : this.entryId,
      userId: data.userId.present ? data.userId.value : this.userId,
      encryptedKey: data.encryptedKey.present
          ? data.encryptedKey.value
          : this.encryptedKey,
      accessLevel: data.accessLevel.present
          ? data.accessLevel.value
          : this.accessLevel,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PermissionData(')
          ..write('id: $id, ')
          ..write('entryId: $entryId, ')
          ..write('userId: $userId, ')
          ..write('encryptedKey: $encryptedKey, ')
          ..write('accessLevel: $accessLevel')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, entryId, userId, encryptedKey, accessLevel);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PermissionData &&
          other.id == this.id &&
          other.entryId == this.entryId &&
          other.userId == this.userId &&
          other.encryptedKey == this.encryptedKey &&
          other.accessLevel == this.accessLevel);
}

class PermissionsCompanion extends UpdateCompanion<PermissionData> {
  final Value<int> id;
  final Value<int> entryId;
  final Value<int> userId;
  final Value<String> encryptedKey;
  final Value<int> accessLevel;
  const PermissionsCompanion({
    this.id = const Value.absent(),
    this.entryId = const Value.absent(),
    this.userId = const Value.absent(),
    this.encryptedKey = const Value.absent(),
    this.accessLevel = const Value.absent(),
  });
  PermissionsCompanion.insert({
    this.id = const Value.absent(),
    required int entryId,
    required int userId,
    required String encryptedKey,
    required int accessLevel,
  }) : entryId = Value(entryId),
       userId = Value(userId),
       encryptedKey = Value(encryptedKey),
       accessLevel = Value(accessLevel);
  static Insertable<PermissionData> custom({
    Expression<int>? id,
    Expression<int>? entryId,
    Expression<int>? userId,
    Expression<String>? encryptedKey,
    Expression<int>? accessLevel,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (entryId != null) 'entry_id': entryId,
      if (userId != null) 'user_id': userId,
      if (encryptedKey != null) 'encrypted_key': encryptedKey,
      if (accessLevel != null) 'access_level': accessLevel,
    });
  }

  PermissionsCompanion copyWith({
    Value<int>? id,
    Value<int>? entryId,
    Value<int>? userId,
    Value<String>? encryptedKey,
    Value<int>? accessLevel,
  }) {
    return PermissionsCompanion(
      id: id ?? this.id,
      entryId: entryId ?? this.entryId,
      userId: userId ?? this.userId,
      encryptedKey: encryptedKey ?? this.encryptedKey,
      accessLevel: accessLevel ?? this.accessLevel,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (entryId.present) {
      map['entry_id'] = Variable<int>(entryId.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<int>(userId.value);
    }
    if (encryptedKey.present) {
      map['encrypted_key'] = Variable<String>(encryptedKey.value);
    }
    if (accessLevel.present) {
      map['access_level'] = Variable<int>(accessLevel.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PermissionsCompanion(')
          ..write('id: $id, ')
          ..write('entryId: $entryId, ')
          ..write('userId: $userId, ')
          ..write('encryptedKey: $encryptedKey, ')
          ..write('accessLevel: $accessLevel')
          ..write(')'))
        .toString();
  }
}

class $AttachmentsTable extends Attachments
    with TableInfo<$AttachmentsTable, AttachmentData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AttachmentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _uuidMeta = const VerificationMeta('uuid');
  @override
  late final GeneratedColumn<String> uuid = GeneratedColumn<String>(
    'uuid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _entryIdMeta = const VerificationMeta(
    'entryId',
  );
  @override
  late final GeneratedColumn<int> entryId = GeneratedColumn<int>(
    'entry_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES entries (id)',
    ),
  );
  static const VerificationMeta _encryptedMetaMeta = const VerificationMeta(
    'encryptedMeta',
  );
  @override
  late final GeneratedColumn<String> encryptedMeta = GeneratedColumn<String>(
    'encrypted_meta',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _encryptedContentMeta = const VerificationMeta(
    'encryptedContent',
  );
  @override
  late final GeneratedColumn<String> encryptedContent = GeneratedColumn<String>(
    'encrypted_content',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isSyncedMeta = const VerificationMeta(
    'isSynced',
  );
  @override
  late final GeneratedColumn<bool> isSynced = GeneratedColumn<bool>(
    'is_synced',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_synced" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    uuid,
    entryId,
    encryptedMeta,
    encryptedContent,
    isSynced,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'attachments';
  @override
  VerificationContext validateIntegrity(
    Insertable<AttachmentData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('uuid')) {
      context.handle(
        _uuidMeta,
        uuid.isAcceptableOrUnknown(data['uuid']!, _uuidMeta),
      );
    } else if (isInserting) {
      context.missing(_uuidMeta);
    }
    if (data.containsKey('entry_id')) {
      context.handle(
        _entryIdMeta,
        entryId.isAcceptableOrUnknown(data['entry_id']!, _entryIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entryIdMeta);
    }
    if (data.containsKey('encrypted_meta')) {
      context.handle(
        _encryptedMetaMeta,
        encryptedMeta.isAcceptableOrUnknown(
          data['encrypted_meta']!,
          _encryptedMetaMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_encryptedMetaMeta);
    }
    if (data.containsKey('encrypted_content')) {
      context.handle(
        _encryptedContentMeta,
        encryptedContent.isAcceptableOrUnknown(
          data['encrypted_content']!,
          _encryptedContentMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_encryptedContentMeta);
    }
    if (data.containsKey('is_synced')) {
      context.handle(
        _isSyncedMeta,
        isSynced.isAcceptableOrUnknown(data['is_synced']!, _isSyncedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AttachmentData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AttachmentData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      uuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}uuid'],
      )!,
      entryId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}entry_id'],
      )!,
      encryptedMeta: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}encrypted_meta'],
      )!,
      encryptedContent: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}encrypted_content'],
      )!,
      isSynced: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_synced'],
      )!,
    );
  }

  @override
  $AttachmentsTable createAlias(String alias) {
    return $AttachmentsTable(attachedDatabase, alias);
  }
}

class AttachmentData extends DataClass implements Insertable<AttachmentData> {
  final int id;
  final String uuid;
  final int entryId;
  final String encryptedMeta;
  final String encryptedContent;
  final bool isSynced;
  const AttachmentData({
    required this.id,
    required this.uuid,
    required this.entryId,
    required this.encryptedMeta,
    required this.encryptedContent,
    required this.isSynced,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['uuid'] = Variable<String>(uuid);
    map['entry_id'] = Variable<int>(entryId);
    map['encrypted_meta'] = Variable<String>(encryptedMeta);
    map['encrypted_content'] = Variable<String>(encryptedContent);
    map['is_synced'] = Variable<bool>(isSynced);
    return map;
  }

  AttachmentsCompanion toCompanion(bool nullToAbsent) {
    return AttachmentsCompanion(
      id: Value(id),
      uuid: Value(uuid),
      entryId: Value(entryId),
      encryptedMeta: Value(encryptedMeta),
      encryptedContent: Value(encryptedContent),
      isSynced: Value(isSynced),
    );
  }

  factory AttachmentData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AttachmentData(
      id: serializer.fromJson<int>(json['id']),
      uuid: serializer.fromJson<String>(json['uuid']),
      entryId: serializer.fromJson<int>(json['entryId']),
      encryptedMeta: serializer.fromJson<String>(json['encryptedMeta']),
      encryptedContent: serializer.fromJson<String>(json['encryptedContent']),
      isSynced: serializer.fromJson<bool>(json['isSynced']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'uuid': serializer.toJson<String>(uuid),
      'entryId': serializer.toJson<int>(entryId),
      'encryptedMeta': serializer.toJson<String>(encryptedMeta),
      'encryptedContent': serializer.toJson<String>(encryptedContent),
      'isSynced': serializer.toJson<bool>(isSynced),
    };
  }

  AttachmentData copyWith({
    int? id,
    String? uuid,
    int? entryId,
    String? encryptedMeta,
    String? encryptedContent,
    bool? isSynced,
  }) => AttachmentData(
    id: id ?? this.id,
    uuid: uuid ?? this.uuid,
    entryId: entryId ?? this.entryId,
    encryptedMeta: encryptedMeta ?? this.encryptedMeta,
    encryptedContent: encryptedContent ?? this.encryptedContent,
    isSynced: isSynced ?? this.isSynced,
  );
  AttachmentData copyWithCompanion(AttachmentsCompanion data) {
    return AttachmentData(
      id: data.id.present ? data.id.value : this.id,
      uuid: data.uuid.present ? data.uuid.value : this.uuid,
      entryId: data.entryId.present ? data.entryId.value : this.entryId,
      encryptedMeta: data.encryptedMeta.present
          ? data.encryptedMeta.value
          : this.encryptedMeta,
      encryptedContent: data.encryptedContent.present
          ? data.encryptedContent.value
          : this.encryptedContent,
      isSynced: data.isSynced.present ? data.isSynced.value : this.isSynced,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AttachmentData(')
          ..write('id: $id, ')
          ..write('uuid: $uuid, ')
          ..write('entryId: $entryId, ')
          ..write('encryptedMeta: $encryptedMeta, ')
          ..write('encryptedContent: $encryptedContent, ')
          ..write('isSynced: $isSynced')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, uuid, entryId, encryptedMeta, encryptedContent, isSynced);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AttachmentData &&
          other.id == this.id &&
          other.uuid == this.uuid &&
          other.entryId == this.entryId &&
          other.encryptedMeta == this.encryptedMeta &&
          other.encryptedContent == this.encryptedContent &&
          other.isSynced == this.isSynced);
}

class AttachmentsCompanion extends UpdateCompanion<AttachmentData> {
  final Value<int> id;
  final Value<String> uuid;
  final Value<int> entryId;
  final Value<String> encryptedMeta;
  final Value<String> encryptedContent;
  final Value<bool> isSynced;
  const AttachmentsCompanion({
    this.id = const Value.absent(),
    this.uuid = const Value.absent(),
    this.entryId = const Value.absent(),
    this.encryptedMeta = const Value.absent(),
    this.encryptedContent = const Value.absent(),
    this.isSynced = const Value.absent(),
  });
  AttachmentsCompanion.insert({
    this.id = const Value.absent(),
    required String uuid,
    required int entryId,
    required String encryptedMeta,
    required String encryptedContent,
    this.isSynced = const Value.absent(),
  }) : uuid = Value(uuid),
       entryId = Value(entryId),
       encryptedMeta = Value(encryptedMeta),
       encryptedContent = Value(encryptedContent);
  static Insertable<AttachmentData> custom({
    Expression<int>? id,
    Expression<String>? uuid,
    Expression<int>? entryId,
    Expression<String>? encryptedMeta,
    Expression<String>? encryptedContent,
    Expression<bool>? isSynced,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (uuid != null) 'uuid': uuid,
      if (entryId != null) 'entry_id': entryId,
      if (encryptedMeta != null) 'encrypted_meta': encryptedMeta,
      if (encryptedContent != null) 'encrypted_content': encryptedContent,
      if (isSynced != null) 'is_synced': isSynced,
    });
  }

  AttachmentsCompanion copyWith({
    Value<int>? id,
    Value<String>? uuid,
    Value<int>? entryId,
    Value<String>? encryptedMeta,
    Value<String>? encryptedContent,
    Value<bool>? isSynced,
  }) {
    return AttachmentsCompanion(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      entryId: entryId ?? this.entryId,
      encryptedMeta: encryptedMeta ?? this.encryptedMeta,
      encryptedContent: encryptedContent ?? this.encryptedContent,
      isSynced: isSynced ?? this.isSynced,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (uuid.present) {
      map['uuid'] = Variable<String>(uuid.value);
    }
    if (entryId.present) {
      map['entry_id'] = Variable<int>(entryId.value);
    }
    if (encryptedMeta.present) {
      map['encrypted_meta'] = Variable<String>(encryptedMeta.value);
    }
    if (encryptedContent.present) {
      map['encrypted_content'] = Variable<String>(encryptedContent.value);
    }
    if (isSynced.present) {
      map['is_synced'] = Variable<bool>(isSynced.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AttachmentsCompanion(')
          ..write('id: $id, ')
          ..write('uuid: $uuid, ')
          ..write('entryId: $entryId, ')
          ..write('encryptedMeta: $encryptedMeta, ')
          ..write('encryptedContent: $encryptedContent, ')
          ..write('isSynced: $isSynced')
          ..write(')'))
        .toString();
  }
}

class $TombstonesTable extends Tombstones
    with TableInfo<$TombstonesTable, TombstoneData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TombstonesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _entryUuidMeta = const VerificationMeta(
    'entryUuid',
  );
  @override
  late final GeneratedColumn<String> entryUuid = GeneratedColumn<String>(
    'entry_uuid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, entryUuid, deletedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tombstones';
  @override
  VerificationContext validateIntegrity(
    Insertable<TombstoneData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('entry_uuid')) {
      context.handle(
        _entryUuidMeta,
        entryUuid.isAcceptableOrUnknown(data['entry_uuid']!, _entryUuidMeta),
      );
    } else if (isInserting) {
      context.missing(_entryUuidMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_deletedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TombstoneData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TombstoneData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      entryUuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entry_uuid'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      )!,
    );
  }

  @override
  $TombstonesTable createAlias(String alias) {
    return $TombstonesTable(attachedDatabase, alias);
  }
}

class TombstoneData extends DataClass implements Insertable<TombstoneData> {
  final int id;
  final String entryUuid;
  final DateTime deletedAt;
  const TombstoneData({
    required this.id,
    required this.entryUuid,
    required this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['entry_uuid'] = Variable<String>(entryUuid);
    map['deleted_at'] = Variable<DateTime>(deletedAt);
    return map;
  }

  TombstonesCompanion toCompanion(bool nullToAbsent) {
    return TombstonesCompanion(
      id: Value(id),
      entryUuid: Value(entryUuid),
      deletedAt: Value(deletedAt),
    );
  }

  factory TombstoneData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TombstoneData(
      id: serializer.fromJson<int>(json['id']),
      entryUuid: serializer.fromJson<String>(json['entryUuid']),
      deletedAt: serializer.fromJson<DateTime>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'entryUuid': serializer.toJson<String>(entryUuid),
      'deletedAt': serializer.toJson<DateTime>(deletedAt),
    };
  }

  TombstoneData copyWith({int? id, String? entryUuid, DateTime? deletedAt}) =>
      TombstoneData(
        id: id ?? this.id,
        entryUuid: entryUuid ?? this.entryUuid,
        deletedAt: deletedAt ?? this.deletedAt,
      );
  TombstoneData copyWithCompanion(TombstonesCompanion data) {
    return TombstoneData(
      id: data.id.present ? data.id.value : this.id,
      entryUuid: data.entryUuid.present ? data.entryUuid.value : this.entryUuid,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TombstoneData(')
          ..write('id: $id, ')
          ..write('entryUuid: $entryUuid, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, entryUuid, deletedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TombstoneData &&
          other.id == this.id &&
          other.entryUuid == this.entryUuid &&
          other.deletedAt == this.deletedAt);
}

class TombstonesCompanion extends UpdateCompanion<TombstoneData> {
  final Value<int> id;
  final Value<String> entryUuid;
  final Value<DateTime> deletedAt;
  const TombstonesCompanion({
    this.id = const Value.absent(),
    this.entryUuid = const Value.absent(),
    this.deletedAt = const Value.absent(),
  });
  TombstonesCompanion.insert({
    this.id = const Value.absent(),
    required String entryUuid,
    required DateTime deletedAt,
  }) : entryUuid = Value(entryUuid),
       deletedAt = Value(deletedAt);
  static Insertable<TombstoneData> custom({
    Expression<int>? id,
    Expression<String>? entryUuid,
    Expression<DateTime>? deletedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (entryUuid != null) 'entry_uuid': entryUuid,
      if (deletedAt != null) 'deleted_at': deletedAt,
    });
  }

  TombstonesCompanion copyWith({
    Value<int>? id,
    Value<String>? entryUuid,
    Value<DateTime>? deletedAt,
  }) {
    return TombstonesCompanion(
      id: id ?? this.id,
      entryUuid: entryUuid ?? this.entryUuid,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (entryUuid.present) {
      map['entry_uuid'] = Variable<String>(entryUuid.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TombstonesCompanion(')
          ..write('id: $id, ')
          ..write('entryUuid: $entryUuid, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }
}

class $VersionsTable extends Versions
    with TableInfo<$VersionsTable, VersionData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $VersionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _majorMeta = const VerificationMeta('major');
  @override
  late final GeneratedColumn<int> major = GeneratedColumn<int>(
    'major',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _minorMeta = const VerificationMeta('minor');
  @override
  late final GeneratedColumn<int> minor = GeneratedColumn<int>(
    'minor',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _patchMeta = const VerificationMeta('patch');
  @override
  late final GeneratedColumn<int> patch = GeneratedColumn<int>(
    'patch',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, major, minor, patch, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'versions';
  @override
  VerificationContext validateIntegrity(
    Insertable<VersionData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('major')) {
      context.handle(
        _majorMeta,
        major.isAcceptableOrUnknown(data['major']!, _majorMeta),
      );
    } else if (isInserting) {
      context.missing(_majorMeta);
    }
    if (data.containsKey('minor')) {
      context.handle(
        _minorMeta,
        minor.isAcceptableOrUnknown(data['minor']!, _minorMeta),
      );
    } else if (isInserting) {
      context.missing(_minorMeta);
    }
    if (data.containsKey('patch')) {
      context.handle(
        _patchMeta,
        patch.isAcceptableOrUnknown(data['patch']!, _patchMeta),
      );
    } else if (isInserting) {
      context.missing(_patchMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  VersionData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return VersionData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      major: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}major'],
      )!,
      minor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}minor'],
      )!,
      patch: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}patch'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $VersionsTable createAlias(String alias) {
    return $VersionsTable(attachedDatabase, alias);
  }
}

class VersionData extends DataClass implements Insertable<VersionData> {
  final int id;
  final int major;
  final int minor;
  final int patch;
  final DateTime updatedAt;
  const VersionData({
    required this.id,
    required this.major,
    required this.minor,
    required this.patch,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['major'] = Variable<int>(major);
    map['minor'] = Variable<int>(minor);
    map['patch'] = Variable<int>(patch);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  VersionsCompanion toCompanion(bool nullToAbsent) {
    return VersionsCompanion(
      id: Value(id),
      major: Value(major),
      minor: Value(minor),
      patch: Value(patch),
      updatedAt: Value(updatedAt),
    );
  }

  factory VersionData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return VersionData(
      id: serializer.fromJson<int>(json['id']),
      major: serializer.fromJson<int>(json['major']),
      minor: serializer.fromJson<int>(json['minor']),
      patch: serializer.fromJson<int>(json['patch']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'major': serializer.toJson<int>(major),
      'minor': serializer.toJson<int>(minor),
      'patch': serializer.toJson<int>(patch),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  VersionData copyWith({
    int? id,
    int? major,
    int? minor,
    int? patch,
    DateTime? updatedAt,
  }) => VersionData(
    id: id ?? this.id,
    major: major ?? this.major,
    minor: minor ?? this.minor,
    patch: patch ?? this.patch,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  VersionData copyWithCompanion(VersionsCompanion data) {
    return VersionData(
      id: data.id.present ? data.id.value : this.id,
      major: data.major.present ? data.major.value : this.major,
      minor: data.minor.present ? data.minor.value : this.minor,
      patch: data.patch.present ? data.patch.value : this.patch,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('VersionData(')
          ..write('id: $id, ')
          ..write('major: $major, ')
          ..write('minor: $minor, ')
          ..write('patch: $patch, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, major, minor, patch, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is VersionData &&
          other.id == this.id &&
          other.major == this.major &&
          other.minor == this.minor &&
          other.patch == this.patch &&
          other.updatedAt == this.updatedAt);
}

class VersionsCompanion extends UpdateCompanion<VersionData> {
  final Value<int> id;
  final Value<int> major;
  final Value<int> minor;
  final Value<int> patch;
  final Value<DateTime> updatedAt;
  const VersionsCompanion({
    this.id = const Value.absent(),
    this.major = const Value.absent(),
    this.minor = const Value.absent(),
    this.patch = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  VersionsCompanion.insert({
    this.id = const Value.absent(),
    required int major,
    required int minor,
    required int patch,
    required DateTime updatedAt,
  }) : major = Value(major),
       minor = Value(minor),
       patch = Value(patch),
       updatedAt = Value(updatedAt);
  static Insertable<VersionData> custom({
    Expression<int>? id,
    Expression<int>? major,
    Expression<int>? minor,
    Expression<int>? patch,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (major != null) 'major': major,
      if (minor != null) 'minor': minor,
      if (patch != null) 'patch': patch,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  VersionsCompanion copyWith({
    Value<int>? id,
    Value<int>? major,
    Value<int>? minor,
    Value<int>? patch,
    Value<DateTime>? updatedAt,
  }) {
    return VersionsCompanion(
      id: id ?? this.id,
      major: major ?? this.major,
      minor: minor ?? this.minor,
      patch: patch ?? this.patch,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (major.present) {
      map['major'] = Variable<int>(major.value);
    }
    if (minor.present) {
      map['minor'] = Variable<int>(minor.value);
    }
    if (patch.present) {
      map['patch'] = Variable<int>(patch.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('VersionsCompanion(')
          ..write('id: $id, ')
          ..write('major: $major, ')
          ..write('minor: $minor, ')
          ..write('patch: $patch, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $SettingsTable extends Settings
    with TableInfo<$SettingsTable, SettingData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _saltMeta = const VerificationMeta('salt');
  @override
  late final GeneratedColumn<String> salt = GeneratedColumn<String>(
    'salt',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _encryptedPrivateKeyMeta =
      const VerificationMeta('encryptedPrivateKey');
  @override
  late final GeneratedColumn<String> encryptedPrivateKey =
      GeneratedColumn<String>(
        'encrypted_private_key',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _hostMeta = const VerificationMeta('host');
  @override
  late final GeneratedColumn<String> host = GeneratedColumn<String>(
    'host',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _apiTokenMeta = const VerificationMeta(
    'apiToken',
  );
  @override
  late final GeneratedColumn<String> apiToken = GeneratedColumn<String>(
    'api_token',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _useBiometricMeta = const VerificationMeta(
    'useBiometric',
  );
  @override
  late final GeneratedColumn<bool> useBiometric = GeneratedColumn<bool>(
    'use_biometric',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("use_biometric" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _pwLengthMeta = const VerificationMeta(
    'pwLength',
  );
  @override
  late final GeneratedColumn<int> pwLength = GeneratedColumn<int>(
    'pw_length',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(16),
  );
  static const VerificationMeta _pwSpecialCharsMeta = const VerificationMeta(
    'pwSpecialChars',
  );
  @override
  late final GeneratedColumn<String> pwSpecialChars = GeneratedColumn<String>(
    'pw_special_chars',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pwAvoidIlO0Meta = const VerificationMeta(
    'pwAvoidIlO0',
  );
  @override
  late final GeneratedColumn<bool> pwAvoidIlO0 = GeneratedColumn<bool>(
    'pw_avoid_il_o0',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("pw_avoid_il_o0" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _categoryPlaceholderMeta =
      const VerificationMeta('categoryPlaceholder');
  @override
  late final GeneratedColumn<String> categoryPlaceholder =
      GeneratedColumn<String>(
        'category_placeholder',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _lastSyncAtMeta = const VerificationMeta(
    'lastSyncAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastSyncAt = GeneratedColumn<DateTime>(
    'last_sync_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    salt,
    encryptedPrivateKey,
    host,
    apiToken,
    useBiometric,
    pwLength,
    pwSpecialChars,
    pwAvoidIlO0,
    categoryPlaceholder,
    lastSyncAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<SettingData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('salt')) {
      context.handle(
        _saltMeta,
        salt.isAcceptableOrUnknown(data['salt']!, _saltMeta),
      );
    } else if (isInserting) {
      context.missing(_saltMeta);
    }
    if (data.containsKey('encrypted_private_key')) {
      context.handle(
        _encryptedPrivateKeyMeta,
        encryptedPrivateKey.isAcceptableOrUnknown(
          data['encrypted_private_key']!,
          _encryptedPrivateKeyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_encryptedPrivateKeyMeta);
    }
    if (data.containsKey('host')) {
      context.handle(
        _hostMeta,
        host.isAcceptableOrUnknown(data['host']!, _hostMeta),
      );
    }
    if (data.containsKey('api_token')) {
      context.handle(
        _apiTokenMeta,
        apiToken.isAcceptableOrUnknown(data['api_token']!, _apiTokenMeta),
      );
    }
    if (data.containsKey('use_biometric')) {
      context.handle(
        _useBiometricMeta,
        useBiometric.isAcceptableOrUnknown(
          data['use_biometric']!,
          _useBiometricMeta,
        ),
      );
    }
    if (data.containsKey('pw_length')) {
      context.handle(
        _pwLengthMeta,
        pwLength.isAcceptableOrUnknown(data['pw_length']!, _pwLengthMeta),
      );
    }
    if (data.containsKey('pw_special_chars')) {
      context.handle(
        _pwSpecialCharsMeta,
        pwSpecialChars.isAcceptableOrUnknown(
          data['pw_special_chars']!,
          _pwSpecialCharsMeta,
        ),
      );
    }
    if (data.containsKey('pw_avoid_il_o0')) {
      context.handle(
        _pwAvoidIlO0Meta,
        pwAvoidIlO0.isAcceptableOrUnknown(
          data['pw_avoid_il_o0']!,
          _pwAvoidIlO0Meta,
        ),
      );
    }
    if (data.containsKey('category_placeholder')) {
      context.handle(
        _categoryPlaceholderMeta,
        categoryPlaceholder.isAcceptableOrUnknown(
          data['category_placeholder']!,
          _categoryPlaceholderMeta,
        ),
      );
    }
    if (data.containsKey('last_sync_at')) {
      context.handle(
        _lastSyncAtMeta,
        lastSyncAt.isAcceptableOrUnknown(
          data['last_sync_at']!,
          _lastSyncAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastSyncAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SettingData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SettingData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      salt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}salt'],
      )!,
      encryptedPrivateKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}encrypted_private_key'],
      )!,
      host: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}host'],
      ),
      apiToken: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}api_token'],
      ),
      useBiometric: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}use_biometric'],
      )!,
      pwLength: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}pw_length'],
      )!,
      pwSpecialChars: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pw_special_chars'],
      ),
      pwAvoidIlO0: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}pw_avoid_il_o0'],
      )!,
      categoryPlaceholder: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category_placeholder'],
      ),
      lastSyncAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_sync_at'],
      )!,
    );
  }

  @override
  $SettingsTable createAlias(String alias) {
    return $SettingsTable(attachedDatabase, alias);
  }
}

class SettingData extends DataClass implements Insertable<SettingData> {
  final int id;
  final String salt;
  final String encryptedPrivateKey;
  final String? host;
  final String? apiToken;
  final bool useBiometric;
  final int pwLength;
  final String? pwSpecialChars;
  final bool pwAvoidIlO0;
  final String? categoryPlaceholder;
  final DateTime lastSyncAt;
  const SettingData({
    required this.id,
    required this.salt,
    required this.encryptedPrivateKey,
    this.host,
    this.apiToken,
    required this.useBiometric,
    required this.pwLength,
    this.pwSpecialChars,
    required this.pwAvoidIlO0,
    this.categoryPlaceholder,
    required this.lastSyncAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['salt'] = Variable<String>(salt);
    map['encrypted_private_key'] = Variable<String>(encryptedPrivateKey);
    if (!nullToAbsent || host != null) {
      map['host'] = Variable<String>(host);
    }
    if (!nullToAbsent || apiToken != null) {
      map['api_token'] = Variable<String>(apiToken);
    }
    map['use_biometric'] = Variable<bool>(useBiometric);
    map['pw_length'] = Variable<int>(pwLength);
    if (!nullToAbsent || pwSpecialChars != null) {
      map['pw_special_chars'] = Variable<String>(pwSpecialChars);
    }
    map['pw_avoid_il_o0'] = Variable<bool>(pwAvoidIlO0);
    if (!nullToAbsent || categoryPlaceholder != null) {
      map['category_placeholder'] = Variable<String>(categoryPlaceholder);
    }
    map['last_sync_at'] = Variable<DateTime>(lastSyncAt);
    return map;
  }

  SettingsCompanion toCompanion(bool nullToAbsent) {
    return SettingsCompanion(
      id: Value(id),
      salt: Value(salt),
      encryptedPrivateKey: Value(encryptedPrivateKey),
      host: host == null && nullToAbsent ? const Value.absent() : Value(host),
      apiToken: apiToken == null && nullToAbsent
          ? const Value.absent()
          : Value(apiToken),
      useBiometric: Value(useBiometric),
      pwLength: Value(pwLength),
      pwSpecialChars: pwSpecialChars == null && nullToAbsent
          ? const Value.absent()
          : Value(pwSpecialChars),
      pwAvoidIlO0: Value(pwAvoidIlO0),
      categoryPlaceholder: categoryPlaceholder == null && nullToAbsent
          ? const Value.absent()
          : Value(categoryPlaceholder),
      lastSyncAt: Value(lastSyncAt),
    );
  }

  factory SettingData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SettingData(
      id: serializer.fromJson<int>(json['id']),
      salt: serializer.fromJson<String>(json['salt']),
      encryptedPrivateKey: serializer.fromJson<String>(
        json['encryptedPrivateKey'],
      ),
      host: serializer.fromJson<String?>(json['host']),
      apiToken: serializer.fromJson<String?>(json['apiToken']),
      useBiometric: serializer.fromJson<bool>(json['useBiometric']),
      pwLength: serializer.fromJson<int>(json['pwLength']),
      pwSpecialChars: serializer.fromJson<String?>(json['pwSpecialChars']),
      pwAvoidIlO0: serializer.fromJson<bool>(json['pwAvoidIlO0']),
      categoryPlaceholder: serializer.fromJson<String?>(
        json['categoryPlaceholder'],
      ),
      lastSyncAt: serializer.fromJson<DateTime>(json['lastSyncAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'salt': serializer.toJson<String>(salt),
      'encryptedPrivateKey': serializer.toJson<String>(encryptedPrivateKey),
      'host': serializer.toJson<String?>(host),
      'apiToken': serializer.toJson<String?>(apiToken),
      'useBiometric': serializer.toJson<bool>(useBiometric),
      'pwLength': serializer.toJson<int>(pwLength),
      'pwSpecialChars': serializer.toJson<String?>(pwSpecialChars),
      'pwAvoidIlO0': serializer.toJson<bool>(pwAvoidIlO0),
      'categoryPlaceholder': serializer.toJson<String?>(categoryPlaceholder),
      'lastSyncAt': serializer.toJson<DateTime>(lastSyncAt),
    };
  }

  SettingData copyWith({
    int? id,
    String? salt,
    String? encryptedPrivateKey,
    Value<String?> host = const Value.absent(),
    Value<String?> apiToken = const Value.absent(),
    bool? useBiometric,
    int? pwLength,
    Value<String?> pwSpecialChars = const Value.absent(),
    bool? pwAvoidIlO0,
    Value<String?> categoryPlaceholder = const Value.absent(),
    DateTime? lastSyncAt,
  }) => SettingData(
    id: id ?? this.id,
    salt: salt ?? this.salt,
    encryptedPrivateKey: encryptedPrivateKey ?? this.encryptedPrivateKey,
    host: host.present ? host.value : this.host,
    apiToken: apiToken.present ? apiToken.value : this.apiToken,
    useBiometric: useBiometric ?? this.useBiometric,
    pwLength: pwLength ?? this.pwLength,
    pwSpecialChars: pwSpecialChars.present
        ? pwSpecialChars.value
        : this.pwSpecialChars,
    pwAvoidIlO0: pwAvoidIlO0 ?? this.pwAvoidIlO0,
    categoryPlaceholder: categoryPlaceholder.present
        ? categoryPlaceholder.value
        : this.categoryPlaceholder,
    lastSyncAt: lastSyncAt ?? this.lastSyncAt,
  );
  SettingData copyWithCompanion(SettingsCompanion data) {
    return SettingData(
      id: data.id.present ? data.id.value : this.id,
      salt: data.salt.present ? data.salt.value : this.salt,
      encryptedPrivateKey: data.encryptedPrivateKey.present
          ? data.encryptedPrivateKey.value
          : this.encryptedPrivateKey,
      host: data.host.present ? data.host.value : this.host,
      apiToken: data.apiToken.present ? data.apiToken.value : this.apiToken,
      useBiometric: data.useBiometric.present
          ? data.useBiometric.value
          : this.useBiometric,
      pwLength: data.pwLength.present ? data.pwLength.value : this.pwLength,
      pwSpecialChars: data.pwSpecialChars.present
          ? data.pwSpecialChars.value
          : this.pwSpecialChars,
      pwAvoidIlO0: data.pwAvoidIlO0.present
          ? data.pwAvoidIlO0.value
          : this.pwAvoidIlO0,
      categoryPlaceholder: data.categoryPlaceholder.present
          ? data.categoryPlaceholder.value
          : this.categoryPlaceholder,
      lastSyncAt: data.lastSyncAt.present
          ? data.lastSyncAt.value
          : this.lastSyncAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SettingData(')
          ..write('id: $id, ')
          ..write('salt: $salt, ')
          ..write('encryptedPrivateKey: $encryptedPrivateKey, ')
          ..write('host: $host, ')
          ..write('apiToken: $apiToken, ')
          ..write('useBiometric: $useBiometric, ')
          ..write('pwLength: $pwLength, ')
          ..write('pwSpecialChars: $pwSpecialChars, ')
          ..write('pwAvoidIlO0: $pwAvoidIlO0, ')
          ..write('categoryPlaceholder: $categoryPlaceholder, ')
          ..write('lastSyncAt: $lastSyncAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    salt,
    encryptedPrivateKey,
    host,
    apiToken,
    useBiometric,
    pwLength,
    pwSpecialChars,
    pwAvoidIlO0,
    categoryPlaceholder,
    lastSyncAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SettingData &&
          other.id == this.id &&
          other.salt == this.salt &&
          other.encryptedPrivateKey == this.encryptedPrivateKey &&
          other.host == this.host &&
          other.apiToken == this.apiToken &&
          other.useBiometric == this.useBiometric &&
          other.pwLength == this.pwLength &&
          other.pwSpecialChars == this.pwSpecialChars &&
          other.pwAvoidIlO0 == this.pwAvoidIlO0 &&
          other.categoryPlaceholder == this.categoryPlaceholder &&
          other.lastSyncAt == this.lastSyncAt);
}

class SettingsCompanion extends UpdateCompanion<SettingData> {
  final Value<int> id;
  final Value<String> salt;
  final Value<String> encryptedPrivateKey;
  final Value<String?> host;
  final Value<String?> apiToken;
  final Value<bool> useBiometric;
  final Value<int> pwLength;
  final Value<String?> pwSpecialChars;
  final Value<bool> pwAvoidIlO0;
  final Value<String?> categoryPlaceholder;
  final Value<DateTime> lastSyncAt;
  const SettingsCompanion({
    this.id = const Value.absent(),
    this.salt = const Value.absent(),
    this.encryptedPrivateKey = const Value.absent(),
    this.host = const Value.absent(),
    this.apiToken = const Value.absent(),
    this.useBiometric = const Value.absent(),
    this.pwLength = const Value.absent(),
    this.pwSpecialChars = const Value.absent(),
    this.pwAvoidIlO0 = const Value.absent(),
    this.categoryPlaceholder = const Value.absent(),
    this.lastSyncAt = const Value.absent(),
  });
  SettingsCompanion.insert({
    this.id = const Value.absent(),
    required String salt,
    required String encryptedPrivateKey,
    this.host = const Value.absent(),
    this.apiToken = const Value.absent(),
    this.useBiometric = const Value.absent(),
    this.pwLength = const Value.absent(),
    this.pwSpecialChars = const Value.absent(),
    this.pwAvoidIlO0 = const Value.absent(),
    this.categoryPlaceholder = const Value.absent(),
    required DateTime lastSyncAt,
  }) : salt = Value(salt),
       encryptedPrivateKey = Value(encryptedPrivateKey),
       lastSyncAt = Value(lastSyncAt);
  static Insertable<SettingData> custom({
    Expression<int>? id,
    Expression<String>? salt,
    Expression<String>? encryptedPrivateKey,
    Expression<String>? host,
    Expression<String>? apiToken,
    Expression<bool>? useBiometric,
    Expression<int>? pwLength,
    Expression<String>? pwSpecialChars,
    Expression<bool>? pwAvoidIlO0,
    Expression<String>? categoryPlaceholder,
    Expression<DateTime>? lastSyncAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (salt != null) 'salt': salt,
      if (encryptedPrivateKey != null)
        'encrypted_private_key': encryptedPrivateKey,
      if (host != null) 'host': host,
      if (apiToken != null) 'api_token': apiToken,
      if (useBiometric != null) 'use_biometric': useBiometric,
      if (pwLength != null) 'pw_length': pwLength,
      if (pwSpecialChars != null) 'pw_special_chars': pwSpecialChars,
      if (pwAvoidIlO0 != null) 'pw_avoid_il_o0': pwAvoidIlO0,
      if (categoryPlaceholder != null)
        'category_placeholder': categoryPlaceholder,
      if (lastSyncAt != null) 'last_sync_at': lastSyncAt,
    });
  }

  SettingsCompanion copyWith({
    Value<int>? id,
    Value<String>? salt,
    Value<String>? encryptedPrivateKey,
    Value<String?>? host,
    Value<String?>? apiToken,
    Value<bool>? useBiometric,
    Value<int>? pwLength,
    Value<String?>? pwSpecialChars,
    Value<bool>? pwAvoidIlO0,
    Value<String?>? categoryPlaceholder,
    Value<DateTime>? lastSyncAt,
  }) {
    return SettingsCompanion(
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

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (salt.present) {
      map['salt'] = Variable<String>(salt.value);
    }
    if (encryptedPrivateKey.present) {
      map['encrypted_private_key'] = Variable<String>(
        encryptedPrivateKey.value,
      );
    }
    if (host.present) {
      map['host'] = Variable<String>(host.value);
    }
    if (apiToken.present) {
      map['api_token'] = Variable<String>(apiToken.value);
    }
    if (useBiometric.present) {
      map['use_biometric'] = Variable<bool>(useBiometric.value);
    }
    if (pwLength.present) {
      map['pw_length'] = Variable<int>(pwLength.value);
    }
    if (pwSpecialChars.present) {
      map['pw_special_chars'] = Variable<String>(pwSpecialChars.value);
    }
    if (pwAvoidIlO0.present) {
      map['pw_avoid_il_o0'] = Variable<bool>(pwAvoidIlO0.value);
    }
    if (categoryPlaceholder.present) {
      map['category_placeholder'] = Variable<String>(categoryPlaceholder.value);
    }
    if (lastSyncAt.present) {
      map['last_sync_at'] = Variable<DateTime>(lastSyncAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SettingsCompanion(')
          ..write('id: $id, ')
          ..write('salt: $salt, ')
          ..write('encryptedPrivateKey: $encryptedPrivateKey, ')
          ..write('host: $host, ')
          ..write('apiToken: $apiToken, ')
          ..write('useBiometric: $useBiometric, ')
          ..write('pwLength: $pwLength, ')
          ..write('pwSpecialChars: $pwSpecialChars, ')
          ..write('pwAvoidIlO0: $pwAvoidIlO0, ')
          ..write('categoryPlaceholder: $categoryPlaceholder, ')
          ..write('lastSyncAt: $lastSyncAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $UsersTable users = $UsersTable(this);
  late final $EntriesTable entries = $EntriesTable(this);
  late final $PermissionsTable permissions = $PermissionsTable(this);
  late final $AttachmentsTable attachments = $AttachmentsTable(this);
  late final $TombstonesTable tombstones = $TombstonesTable(this);
  late final $VersionsTable versions = $VersionsTable(this);
  late final $SettingsTable settings = $SettingsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    users,
    entries,
    permissions,
    attachments,
    tombstones,
    versions,
    settings,
  ];
}

typedef $$UsersTableCreateCompanionBuilder =
    UsersCompanion Function({
      Value<int> id,
      required String uuid,
      required String name,
      required String publicKey,
      Value<bool> isVerified,
      Value<bool> isHidden,
      required DateTime updatedAt,
    });
typedef $$UsersTableUpdateCompanionBuilder =
    UsersCompanion Function({
      Value<int> id,
      Value<String> uuid,
      Value<String> name,
      Value<String> publicKey,
      Value<bool> isVerified,
      Value<bool> isHidden,
      Value<DateTime> updatedAt,
    });

final class $$UsersTableReferences
    extends BaseReferences<_$AppDatabase, $UsersTable, UserData> {
  $$UsersTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$PermissionsTable, List<PermissionData>>
  _permissionsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.permissions,
    aliasName: $_aliasNameGenerator(db.users.id, db.permissions.userId),
  );

  $$PermissionsTableProcessedTableManager get permissionsRefs {
    final manager = $$PermissionsTableTableManager(
      $_db,
      $_db.permissions,
    ).filter((f) => f.userId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_permissionsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$UsersTableFilterComposer extends Composer<_$AppDatabase, $UsersTable> {
  $$UsersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get uuid => $composableBuilder(
    column: $table.uuid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get publicKey => $composableBuilder(
    column: $table.publicKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isVerified => $composableBuilder(
    column: $table.isVerified,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isHidden => $composableBuilder(
    column: $table.isHidden,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> permissionsRefs(
    Expression<bool> Function($$PermissionsTableFilterComposer f) f,
  ) {
    final $$PermissionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.permissions,
      getReferencedColumn: (t) => t.userId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PermissionsTableFilterComposer(
            $db: $db,
            $table: $db.permissions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$UsersTableOrderingComposer
    extends Composer<_$AppDatabase, $UsersTable> {
  $$UsersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get uuid => $composableBuilder(
    column: $table.uuid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get publicKey => $composableBuilder(
    column: $table.publicKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isVerified => $composableBuilder(
    column: $table.isVerified,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isHidden => $composableBuilder(
    column: $table.isHidden,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$UsersTableAnnotationComposer
    extends Composer<_$AppDatabase, $UsersTable> {
  $$UsersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get uuid =>
      $composableBuilder(column: $table.uuid, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get publicKey =>
      $composableBuilder(column: $table.publicKey, builder: (column) => column);

  GeneratedColumn<bool> get isVerified => $composableBuilder(
    column: $table.isVerified,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isHidden =>
      $composableBuilder(column: $table.isHidden, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> permissionsRefs<T extends Object>(
    Expression<T> Function($$PermissionsTableAnnotationComposer a) f,
  ) {
    final $$PermissionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.permissions,
      getReferencedColumn: (t) => t.userId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PermissionsTableAnnotationComposer(
            $db: $db,
            $table: $db.permissions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$UsersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $UsersTable,
          UserData,
          $$UsersTableFilterComposer,
          $$UsersTableOrderingComposer,
          $$UsersTableAnnotationComposer,
          $$UsersTableCreateCompanionBuilder,
          $$UsersTableUpdateCompanionBuilder,
          (UserData, $$UsersTableReferences),
          UserData,
          PrefetchHooks Function({bool permissionsRefs})
        > {
  $$UsersTableTableManager(_$AppDatabase db, $UsersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UsersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UsersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UsersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> uuid = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> publicKey = const Value.absent(),
                Value<bool> isVerified = const Value.absent(),
                Value<bool> isHidden = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => UsersCompanion(
                id: id,
                uuid: uuid,
                name: name,
                publicKey: publicKey,
                isVerified: isVerified,
                isHidden: isHidden,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String uuid,
                required String name,
                required String publicKey,
                Value<bool> isVerified = const Value.absent(),
                Value<bool> isHidden = const Value.absent(),
                required DateTime updatedAt,
              }) => UsersCompanion.insert(
                id: id,
                uuid: uuid,
                name: name,
                publicKey: publicKey,
                isVerified: isVerified,
                isHidden: isHidden,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$UsersTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback: ({permissionsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (permissionsRefs) db.permissions],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (permissionsRefs)
                    await $_getPrefetchedData<
                      UserData,
                      $UsersTable,
                      PermissionData
                    >(
                      currentTable: table,
                      referencedTable: $$UsersTableReferences
                          ._permissionsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$UsersTableReferences(db, table, p0).permissionsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.userId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$UsersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $UsersTable,
      UserData,
      $$UsersTableFilterComposer,
      $$UsersTableOrderingComposer,
      $$UsersTableAnnotationComposer,
      $$UsersTableCreateCompanionBuilder,
      $$UsersTableUpdateCompanionBuilder,
      (UserData, $$UsersTableReferences),
      UserData,
      PrefetchHooks Function({bool permissionsRefs})
    >;
typedef $$EntriesTableCreateCompanionBuilder =
    EntriesCompanion Function({
      Value<int> id,
      required String uuid,
      Value<String> category,
      Value<String> title,
      Value<String> url,
      Value<String> notes,
      Value<String> favicon,
      required String encryptedData,
      required int creatorId,
      required int updaterId,
      required DateTime updatedAt,
    });
typedef $$EntriesTableUpdateCompanionBuilder =
    EntriesCompanion Function({
      Value<int> id,
      Value<String> uuid,
      Value<String> category,
      Value<String> title,
      Value<String> url,
      Value<String> notes,
      Value<String> favicon,
      Value<String> encryptedData,
      Value<int> creatorId,
      Value<int> updaterId,
      Value<DateTime> updatedAt,
    });

final class $$EntriesTableReferences
    extends BaseReferences<_$AppDatabase, $EntriesTable, EntryData> {
  $$EntriesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$PermissionsTable, List<PermissionData>>
  _permissionsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.permissions,
    aliasName: $_aliasNameGenerator(db.entries.id, db.permissions.entryId),
  );

  $$PermissionsTableProcessedTableManager get permissionsRefs {
    final manager = $$PermissionsTableTableManager(
      $_db,
      $_db.permissions,
    ).filter((f) => f.entryId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_permissionsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$AttachmentsTable, List<AttachmentData>>
  _attachmentsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.attachments,
    aliasName: $_aliasNameGenerator(db.entries.id, db.attachments.entryId),
  );

  $$AttachmentsTableProcessedTableManager get attachmentsRefs {
    final manager = $$AttachmentsTableTableManager(
      $_db,
      $_db.attachments,
    ).filter((f) => f.entryId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_attachmentsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$EntriesTableFilterComposer
    extends Composer<_$AppDatabase, $EntriesTable> {
  $$EntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get uuid => $composableBuilder(
    column: $table.uuid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get favicon => $composableBuilder(
    column: $table.favicon,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get encryptedData => $composableBuilder(
    column: $table.encryptedData,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get creatorId => $composableBuilder(
    column: $table.creatorId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updaterId => $composableBuilder(
    column: $table.updaterId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> permissionsRefs(
    Expression<bool> Function($$PermissionsTableFilterComposer f) f,
  ) {
    final $$PermissionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.permissions,
      getReferencedColumn: (t) => t.entryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PermissionsTableFilterComposer(
            $db: $db,
            $table: $db.permissions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> attachmentsRefs(
    Expression<bool> Function($$AttachmentsTableFilterComposer f) f,
  ) {
    final $$AttachmentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.attachments,
      getReferencedColumn: (t) => t.entryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AttachmentsTableFilterComposer(
            $db: $db,
            $table: $db.attachments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$EntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $EntriesTable> {
  $$EntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get uuid => $composableBuilder(
    column: $table.uuid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get favicon => $composableBuilder(
    column: $table.favicon,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get encryptedData => $composableBuilder(
    column: $table.encryptedData,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get creatorId => $composableBuilder(
    column: $table.creatorId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updaterId => $composableBuilder(
    column: $table.updaterId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$EntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $EntriesTable> {
  $$EntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get uuid =>
      $composableBuilder(column: $table.uuid, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get url =>
      $composableBuilder(column: $table.url, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<String> get favicon =>
      $composableBuilder(column: $table.favicon, builder: (column) => column);

  GeneratedColumn<String> get encryptedData => $composableBuilder(
    column: $table.encryptedData,
    builder: (column) => column,
  );

  GeneratedColumn<int> get creatorId =>
      $composableBuilder(column: $table.creatorId, builder: (column) => column);

  GeneratedColumn<int> get updaterId =>
      $composableBuilder(column: $table.updaterId, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> permissionsRefs<T extends Object>(
    Expression<T> Function($$PermissionsTableAnnotationComposer a) f,
  ) {
    final $$PermissionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.permissions,
      getReferencedColumn: (t) => t.entryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PermissionsTableAnnotationComposer(
            $db: $db,
            $table: $db.permissions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> attachmentsRefs<T extends Object>(
    Expression<T> Function($$AttachmentsTableAnnotationComposer a) f,
  ) {
    final $$AttachmentsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.attachments,
      getReferencedColumn: (t) => t.entryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AttachmentsTableAnnotationComposer(
            $db: $db,
            $table: $db.attachments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$EntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $EntriesTable,
          EntryData,
          $$EntriesTableFilterComposer,
          $$EntriesTableOrderingComposer,
          $$EntriesTableAnnotationComposer,
          $$EntriesTableCreateCompanionBuilder,
          $$EntriesTableUpdateCompanionBuilder,
          (EntryData, $$EntriesTableReferences),
          EntryData,
          PrefetchHooks Function({bool permissionsRefs, bool attachmentsRefs})
        > {
  $$EntriesTableTableManager(_$AppDatabase db, $EntriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> uuid = const Value.absent(),
                Value<String> category = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> url = const Value.absent(),
                Value<String> notes = const Value.absent(),
                Value<String> favicon = const Value.absent(),
                Value<String> encryptedData = const Value.absent(),
                Value<int> creatorId = const Value.absent(),
                Value<int> updaterId = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => EntriesCompanion(
                id: id,
                uuid: uuid,
                category: category,
                title: title,
                url: url,
                notes: notes,
                favicon: favicon,
                encryptedData: encryptedData,
                creatorId: creatorId,
                updaterId: updaterId,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String uuid,
                Value<String> category = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> url = const Value.absent(),
                Value<String> notes = const Value.absent(),
                Value<String> favicon = const Value.absent(),
                required String encryptedData,
                required int creatorId,
                required int updaterId,
                required DateTime updatedAt,
              }) => EntriesCompanion.insert(
                id: id,
                uuid: uuid,
                category: category,
                title: title,
                url: url,
                notes: notes,
                favicon: favicon,
                encryptedData: encryptedData,
                creatorId: creatorId,
                updaterId: updaterId,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$EntriesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({permissionsRefs = false, attachmentsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (permissionsRefs) db.permissions,
                    if (attachmentsRefs) db.attachments,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (permissionsRefs)
                        await $_getPrefetchedData<
                          EntryData,
                          $EntriesTable,
                          PermissionData
                        >(
                          currentTable: table,
                          referencedTable: $$EntriesTableReferences
                              ._permissionsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$EntriesTableReferences(
                                db,
                                table,
                                p0,
                              ).permissionsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.entryId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (attachmentsRefs)
                        await $_getPrefetchedData<
                          EntryData,
                          $EntriesTable,
                          AttachmentData
                        >(
                          currentTable: table,
                          referencedTable: $$EntriesTableReferences
                              ._attachmentsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$EntriesTableReferences(
                                db,
                                table,
                                p0,
                              ).attachmentsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.entryId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$EntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $EntriesTable,
      EntryData,
      $$EntriesTableFilterComposer,
      $$EntriesTableOrderingComposer,
      $$EntriesTableAnnotationComposer,
      $$EntriesTableCreateCompanionBuilder,
      $$EntriesTableUpdateCompanionBuilder,
      (EntryData, $$EntriesTableReferences),
      EntryData,
      PrefetchHooks Function({bool permissionsRefs, bool attachmentsRefs})
    >;
typedef $$PermissionsTableCreateCompanionBuilder =
    PermissionsCompanion Function({
      Value<int> id,
      required int entryId,
      required int userId,
      required String encryptedKey,
      required int accessLevel,
    });
typedef $$PermissionsTableUpdateCompanionBuilder =
    PermissionsCompanion Function({
      Value<int> id,
      Value<int> entryId,
      Value<int> userId,
      Value<String> encryptedKey,
      Value<int> accessLevel,
    });

final class $$PermissionsTableReferences
    extends BaseReferences<_$AppDatabase, $PermissionsTable, PermissionData> {
  $$PermissionsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $EntriesTable _entryIdTable(_$AppDatabase db) => db.entries
      .createAlias($_aliasNameGenerator(db.permissions.entryId, db.entries.id));

  $$EntriesTableProcessedTableManager get entryId {
    final $_column = $_itemColumn<int>('entry_id')!;

    final manager = $$EntriesTableTableManager(
      $_db,
      $_db.entries,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_entryIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $UsersTable _userIdTable(_$AppDatabase db) => db.users.createAlias(
    $_aliasNameGenerator(db.permissions.userId, db.users.id),
  );

  $$UsersTableProcessedTableManager get userId {
    final $_column = $_itemColumn<int>('user_id')!;

    final manager = $$UsersTableTableManager(
      $_db,
      $_db.users,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_userIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$PermissionsTableFilterComposer
    extends Composer<_$AppDatabase, $PermissionsTable> {
  $$PermissionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get encryptedKey => $composableBuilder(
    column: $table.encryptedKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get accessLevel => $composableBuilder(
    column: $table.accessLevel,
    builder: (column) => ColumnFilters(column),
  );

  $$EntriesTableFilterComposer get entryId {
    final $$EntriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.entryId,
      referencedTable: $db.entries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EntriesTableFilterComposer(
            $db: $db,
            $table: $db.entries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$UsersTableFilterComposer get userId {
    final $$UsersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.userId,
      referencedTable: $db.users,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UsersTableFilterComposer(
            $db: $db,
            $table: $db.users,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PermissionsTableOrderingComposer
    extends Composer<_$AppDatabase, $PermissionsTable> {
  $$PermissionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get encryptedKey => $composableBuilder(
    column: $table.encryptedKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get accessLevel => $composableBuilder(
    column: $table.accessLevel,
    builder: (column) => ColumnOrderings(column),
  );

  $$EntriesTableOrderingComposer get entryId {
    final $$EntriesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.entryId,
      referencedTable: $db.entries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EntriesTableOrderingComposer(
            $db: $db,
            $table: $db.entries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$UsersTableOrderingComposer get userId {
    final $$UsersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.userId,
      referencedTable: $db.users,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UsersTableOrderingComposer(
            $db: $db,
            $table: $db.users,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PermissionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PermissionsTable> {
  $$PermissionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get encryptedKey => $composableBuilder(
    column: $table.encryptedKey,
    builder: (column) => column,
  );

  GeneratedColumn<int> get accessLevel => $composableBuilder(
    column: $table.accessLevel,
    builder: (column) => column,
  );

  $$EntriesTableAnnotationComposer get entryId {
    final $$EntriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.entryId,
      referencedTable: $db.entries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EntriesTableAnnotationComposer(
            $db: $db,
            $table: $db.entries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$UsersTableAnnotationComposer get userId {
    final $$UsersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.userId,
      referencedTable: $db.users,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UsersTableAnnotationComposer(
            $db: $db,
            $table: $db.users,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PermissionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PermissionsTable,
          PermissionData,
          $$PermissionsTableFilterComposer,
          $$PermissionsTableOrderingComposer,
          $$PermissionsTableAnnotationComposer,
          $$PermissionsTableCreateCompanionBuilder,
          $$PermissionsTableUpdateCompanionBuilder,
          (PermissionData, $$PermissionsTableReferences),
          PermissionData,
          PrefetchHooks Function({bool entryId, bool userId})
        > {
  $$PermissionsTableTableManager(_$AppDatabase db, $PermissionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PermissionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PermissionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PermissionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> entryId = const Value.absent(),
                Value<int> userId = const Value.absent(),
                Value<String> encryptedKey = const Value.absent(),
                Value<int> accessLevel = const Value.absent(),
              }) => PermissionsCompanion(
                id: id,
                entryId: entryId,
                userId: userId,
                encryptedKey: encryptedKey,
                accessLevel: accessLevel,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int entryId,
                required int userId,
                required String encryptedKey,
                required int accessLevel,
              }) => PermissionsCompanion.insert(
                id: id,
                entryId: entryId,
                userId: userId,
                encryptedKey: encryptedKey,
                accessLevel: accessLevel,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$PermissionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({entryId = false, userId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (entryId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.entryId,
                                referencedTable: $$PermissionsTableReferences
                                    ._entryIdTable(db),
                                referencedColumn: $$PermissionsTableReferences
                                    ._entryIdTable(db)
                                    .id,
                              )
                              as T;
                    }
                    if (userId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.userId,
                                referencedTable: $$PermissionsTableReferences
                                    ._userIdTable(db),
                                referencedColumn: $$PermissionsTableReferences
                                    ._userIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$PermissionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PermissionsTable,
      PermissionData,
      $$PermissionsTableFilterComposer,
      $$PermissionsTableOrderingComposer,
      $$PermissionsTableAnnotationComposer,
      $$PermissionsTableCreateCompanionBuilder,
      $$PermissionsTableUpdateCompanionBuilder,
      (PermissionData, $$PermissionsTableReferences),
      PermissionData,
      PrefetchHooks Function({bool entryId, bool userId})
    >;
typedef $$AttachmentsTableCreateCompanionBuilder =
    AttachmentsCompanion Function({
      Value<int> id,
      required String uuid,
      required int entryId,
      required String encryptedMeta,
      required String encryptedContent,
      Value<bool> isSynced,
    });
typedef $$AttachmentsTableUpdateCompanionBuilder =
    AttachmentsCompanion Function({
      Value<int> id,
      Value<String> uuid,
      Value<int> entryId,
      Value<String> encryptedMeta,
      Value<String> encryptedContent,
      Value<bool> isSynced,
    });

final class $$AttachmentsTableReferences
    extends BaseReferences<_$AppDatabase, $AttachmentsTable, AttachmentData> {
  $$AttachmentsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $EntriesTable _entryIdTable(_$AppDatabase db) => db.entries
      .createAlias($_aliasNameGenerator(db.attachments.entryId, db.entries.id));

  $$EntriesTableProcessedTableManager get entryId {
    final $_column = $_itemColumn<int>('entry_id')!;

    final manager = $$EntriesTableTableManager(
      $_db,
      $_db.entries,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_entryIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$AttachmentsTableFilterComposer
    extends Composer<_$AppDatabase, $AttachmentsTable> {
  $$AttachmentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get uuid => $composableBuilder(
    column: $table.uuid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get encryptedMeta => $composableBuilder(
    column: $table.encryptedMeta,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get encryptedContent => $composableBuilder(
    column: $table.encryptedContent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isSynced => $composableBuilder(
    column: $table.isSynced,
    builder: (column) => ColumnFilters(column),
  );

  $$EntriesTableFilterComposer get entryId {
    final $$EntriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.entryId,
      referencedTable: $db.entries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EntriesTableFilterComposer(
            $db: $db,
            $table: $db.entries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AttachmentsTableOrderingComposer
    extends Composer<_$AppDatabase, $AttachmentsTable> {
  $$AttachmentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get uuid => $composableBuilder(
    column: $table.uuid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get encryptedMeta => $composableBuilder(
    column: $table.encryptedMeta,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get encryptedContent => $composableBuilder(
    column: $table.encryptedContent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isSynced => $composableBuilder(
    column: $table.isSynced,
    builder: (column) => ColumnOrderings(column),
  );

  $$EntriesTableOrderingComposer get entryId {
    final $$EntriesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.entryId,
      referencedTable: $db.entries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EntriesTableOrderingComposer(
            $db: $db,
            $table: $db.entries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AttachmentsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AttachmentsTable> {
  $$AttachmentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get uuid =>
      $composableBuilder(column: $table.uuid, builder: (column) => column);

  GeneratedColumn<String> get encryptedMeta => $composableBuilder(
    column: $table.encryptedMeta,
    builder: (column) => column,
  );

  GeneratedColumn<String> get encryptedContent => $composableBuilder(
    column: $table.encryptedContent,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isSynced =>
      $composableBuilder(column: $table.isSynced, builder: (column) => column);

  $$EntriesTableAnnotationComposer get entryId {
    final $$EntriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.entryId,
      referencedTable: $db.entries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EntriesTableAnnotationComposer(
            $db: $db,
            $table: $db.entries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AttachmentsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AttachmentsTable,
          AttachmentData,
          $$AttachmentsTableFilterComposer,
          $$AttachmentsTableOrderingComposer,
          $$AttachmentsTableAnnotationComposer,
          $$AttachmentsTableCreateCompanionBuilder,
          $$AttachmentsTableUpdateCompanionBuilder,
          (AttachmentData, $$AttachmentsTableReferences),
          AttachmentData,
          PrefetchHooks Function({bool entryId})
        > {
  $$AttachmentsTableTableManager(_$AppDatabase db, $AttachmentsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AttachmentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AttachmentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AttachmentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> uuid = const Value.absent(),
                Value<int> entryId = const Value.absent(),
                Value<String> encryptedMeta = const Value.absent(),
                Value<String> encryptedContent = const Value.absent(),
                Value<bool> isSynced = const Value.absent(),
              }) => AttachmentsCompanion(
                id: id,
                uuid: uuid,
                entryId: entryId,
                encryptedMeta: encryptedMeta,
                encryptedContent: encryptedContent,
                isSynced: isSynced,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String uuid,
                required int entryId,
                required String encryptedMeta,
                required String encryptedContent,
                Value<bool> isSynced = const Value.absent(),
              }) => AttachmentsCompanion.insert(
                id: id,
                uuid: uuid,
                entryId: entryId,
                encryptedMeta: encryptedMeta,
                encryptedContent: encryptedContent,
                isSynced: isSynced,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$AttachmentsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({entryId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (entryId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.entryId,
                                referencedTable: $$AttachmentsTableReferences
                                    ._entryIdTable(db),
                                referencedColumn: $$AttachmentsTableReferences
                                    ._entryIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$AttachmentsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AttachmentsTable,
      AttachmentData,
      $$AttachmentsTableFilterComposer,
      $$AttachmentsTableOrderingComposer,
      $$AttachmentsTableAnnotationComposer,
      $$AttachmentsTableCreateCompanionBuilder,
      $$AttachmentsTableUpdateCompanionBuilder,
      (AttachmentData, $$AttachmentsTableReferences),
      AttachmentData,
      PrefetchHooks Function({bool entryId})
    >;
typedef $$TombstonesTableCreateCompanionBuilder =
    TombstonesCompanion Function({
      Value<int> id,
      required String entryUuid,
      required DateTime deletedAt,
    });
typedef $$TombstonesTableUpdateCompanionBuilder =
    TombstonesCompanion Function({
      Value<int> id,
      Value<String> entryUuid,
      Value<DateTime> deletedAt,
    });

class $$TombstonesTableFilterComposer
    extends Composer<_$AppDatabase, $TombstonesTable> {
  $$TombstonesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entryUuid => $composableBuilder(
    column: $table.entryUuid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TombstonesTableOrderingComposer
    extends Composer<_$AppDatabase, $TombstonesTable> {
  $$TombstonesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entryUuid => $composableBuilder(
    column: $table.entryUuid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TombstonesTableAnnotationComposer
    extends Composer<_$AppDatabase, $TombstonesTable> {
  $$TombstonesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get entryUuid =>
      $composableBuilder(column: $table.entryUuid, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$TombstonesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TombstonesTable,
          TombstoneData,
          $$TombstonesTableFilterComposer,
          $$TombstonesTableOrderingComposer,
          $$TombstonesTableAnnotationComposer,
          $$TombstonesTableCreateCompanionBuilder,
          $$TombstonesTableUpdateCompanionBuilder,
          (
            TombstoneData,
            BaseReferences<_$AppDatabase, $TombstonesTable, TombstoneData>,
          ),
          TombstoneData,
          PrefetchHooks Function()
        > {
  $$TombstonesTableTableManager(_$AppDatabase db, $TombstonesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TombstonesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TombstonesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TombstonesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> entryUuid = const Value.absent(),
                Value<DateTime> deletedAt = const Value.absent(),
              }) => TombstonesCompanion(
                id: id,
                entryUuid: entryUuid,
                deletedAt: deletedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String entryUuid,
                required DateTime deletedAt,
              }) => TombstonesCompanion.insert(
                id: id,
                entryUuid: entryUuid,
                deletedAt: deletedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TombstonesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TombstonesTable,
      TombstoneData,
      $$TombstonesTableFilterComposer,
      $$TombstonesTableOrderingComposer,
      $$TombstonesTableAnnotationComposer,
      $$TombstonesTableCreateCompanionBuilder,
      $$TombstonesTableUpdateCompanionBuilder,
      (
        TombstoneData,
        BaseReferences<_$AppDatabase, $TombstonesTable, TombstoneData>,
      ),
      TombstoneData,
      PrefetchHooks Function()
    >;
typedef $$VersionsTableCreateCompanionBuilder =
    VersionsCompanion Function({
      Value<int> id,
      required int major,
      required int minor,
      required int patch,
      required DateTime updatedAt,
    });
typedef $$VersionsTableUpdateCompanionBuilder =
    VersionsCompanion Function({
      Value<int> id,
      Value<int> major,
      Value<int> minor,
      Value<int> patch,
      Value<DateTime> updatedAt,
    });

class $$VersionsTableFilterComposer
    extends Composer<_$AppDatabase, $VersionsTable> {
  $$VersionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get major => $composableBuilder(
    column: $table.major,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get minor => $composableBuilder(
    column: $table.minor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get patch => $composableBuilder(
    column: $table.patch,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$VersionsTableOrderingComposer
    extends Composer<_$AppDatabase, $VersionsTable> {
  $$VersionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get major => $composableBuilder(
    column: $table.major,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get minor => $composableBuilder(
    column: $table.minor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get patch => $composableBuilder(
    column: $table.patch,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$VersionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $VersionsTable> {
  $$VersionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get major =>
      $composableBuilder(column: $table.major, builder: (column) => column);

  GeneratedColumn<int> get minor =>
      $composableBuilder(column: $table.minor, builder: (column) => column);

  GeneratedColumn<int> get patch =>
      $composableBuilder(column: $table.patch, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$VersionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $VersionsTable,
          VersionData,
          $$VersionsTableFilterComposer,
          $$VersionsTableOrderingComposer,
          $$VersionsTableAnnotationComposer,
          $$VersionsTableCreateCompanionBuilder,
          $$VersionsTableUpdateCompanionBuilder,
          (
            VersionData,
            BaseReferences<_$AppDatabase, $VersionsTable, VersionData>,
          ),
          VersionData,
          PrefetchHooks Function()
        > {
  $$VersionsTableTableManager(_$AppDatabase db, $VersionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$VersionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$VersionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$VersionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> major = const Value.absent(),
                Value<int> minor = const Value.absent(),
                Value<int> patch = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => VersionsCompanion(
                id: id,
                major: major,
                minor: minor,
                patch: patch,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int major,
                required int minor,
                required int patch,
                required DateTime updatedAt,
              }) => VersionsCompanion.insert(
                id: id,
                major: major,
                minor: minor,
                patch: patch,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$VersionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $VersionsTable,
      VersionData,
      $$VersionsTableFilterComposer,
      $$VersionsTableOrderingComposer,
      $$VersionsTableAnnotationComposer,
      $$VersionsTableCreateCompanionBuilder,
      $$VersionsTableUpdateCompanionBuilder,
      (VersionData, BaseReferences<_$AppDatabase, $VersionsTable, VersionData>),
      VersionData,
      PrefetchHooks Function()
    >;
typedef $$SettingsTableCreateCompanionBuilder =
    SettingsCompanion Function({
      Value<int> id,
      required String salt,
      required String encryptedPrivateKey,
      Value<String?> host,
      Value<String?> apiToken,
      Value<bool> useBiometric,
      Value<int> pwLength,
      Value<String?> pwSpecialChars,
      Value<bool> pwAvoidIlO0,
      Value<String?> categoryPlaceholder,
      required DateTime lastSyncAt,
    });
typedef $$SettingsTableUpdateCompanionBuilder =
    SettingsCompanion Function({
      Value<int> id,
      Value<String> salt,
      Value<String> encryptedPrivateKey,
      Value<String?> host,
      Value<String?> apiToken,
      Value<bool> useBiometric,
      Value<int> pwLength,
      Value<String?> pwSpecialChars,
      Value<bool> pwAvoidIlO0,
      Value<String?> categoryPlaceholder,
      Value<DateTime> lastSyncAt,
    });

class $$SettingsTableFilterComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get salt => $composableBuilder(
    column: $table.salt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get encryptedPrivateKey => $composableBuilder(
    column: $table.encryptedPrivateKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get host => $composableBuilder(
    column: $table.host,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get apiToken => $composableBuilder(
    column: $table.apiToken,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get useBiometric => $composableBuilder(
    column: $table.useBiometric,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pwLength => $composableBuilder(
    column: $table.pwLength,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pwSpecialChars => $composableBuilder(
    column: $table.pwSpecialChars,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get pwAvoidIlO0 => $composableBuilder(
    column: $table.pwAvoidIlO0,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get categoryPlaceholder => $composableBuilder(
    column: $table.categoryPlaceholder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastSyncAt => $composableBuilder(
    column: $table.lastSyncAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get salt => $composableBuilder(
    column: $table.salt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get encryptedPrivateKey => $composableBuilder(
    column: $table.encryptedPrivateKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get host => $composableBuilder(
    column: $table.host,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get apiToken => $composableBuilder(
    column: $table.apiToken,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get useBiometric => $composableBuilder(
    column: $table.useBiometric,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pwLength => $composableBuilder(
    column: $table.pwLength,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pwSpecialChars => $composableBuilder(
    column: $table.pwSpecialChars,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get pwAvoidIlO0 => $composableBuilder(
    column: $table.pwAvoidIlO0,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get categoryPlaceholder => $composableBuilder(
    column: $table.categoryPlaceholder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastSyncAt => $composableBuilder(
    column: $table.lastSyncAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get salt =>
      $composableBuilder(column: $table.salt, builder: (column) => column);

  GeneratedColumn<String> get encryptedPrivateKey => $composableBuilder(
    column: $table.encryptedPrivateKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get host =>
      $composableBuilder(column: $table.host, builder: (column) => column);

  GeneratedColumn<String> get apiToken =>
      $composableBuilder(column: $table.apiToken, builder: (column) => column);

  GeneratedColumn<bool> get useBiometric => $composableBuilder(
    column: $table.useBiometric,
    builder: (column) => column,
  );

  GeneratedColumn<int> get pwLength =>
      $composableBuilder(column: $table.pwLength, builder: (column) => column);

  GeneratedColumn<String> get pwSpecialChars => $composableBuilder(
    column: $table.pwSpecialChars,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get pwAvoidIlO0 => $composableBuilder(
    column: $table.pwAvoidIlO0,
    builder: (column) => column,
  );

  GeneratedColumn<String> get categoryPlaceholder => $composableBuilder(
    column: $table.categoryPlaceholder,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastSyncAt => $composableBuilder(
    column: $table.lastSyncAt,
    builder: (column) => column,
  );
}

class $$SettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SettingsTable,
          SettingData,
          $$SettingsTableFilterComposer,
          $$SettingsTableOrderingComposer,
          $$SettingsTableAnnotationComposer,
          $$SettingsTableCreateCompanionBuilder,
          $$SettingsTableUpdateCompanionBuilder,
          (
            SettingData,
            BaseReferences<_$AppDatabase, $SettingsTable, SettingData>,
          ),
          SettingData,
          PrefetchHooks Function()
        > {
  $$SettingsTableTableManager(_$AppDatabase db, $SettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> salt = const Value.absent(),
                Value<String> encryptedPrivateKey = const Value.absent(),
                Value<String?> host = const Value.absent(),
                Value<String?> apiToken = const Value.absent(),
                Value<bool> useBiometric = const Value.absent(),
                Value<int> pwLength = const Value.absent(),
                Value<String?> pwSpecialChars = const Value.absent(),
                Value<bool> pwAvoidIlO0 = const Value.absent(),
                Value<String?> categoryPlaceholder = const Value.absent(),
                Value<DateTime> lastSyncAt = const Value.absent(),
              }) => SettingsCompanion(
                id: id,
                salt: salt,
                encryptedPrivateKey: encryptedPrivateKey,
                host: host,
                apiToken: apiToken,
                useBiometric: useBiometric,
                pwLength: pwLength,
                pwSpecialChars: pwSpecialChars,
                pwAvoidIlO0: pwAvoidIlO0,
                categoryPlaceholder: categoryPlaceholder,
                lastSyncAt: lastSyncAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String salt,
                required String encryptedPrivateKey,
                Value<String?> host = const Value.absent(),
                Value<String?> apiToken = const Value.absent(),
                Value<bool> useBiometric = const Value.absent(),
                Value<int> pwLength = const Value.absent(),
                Value<String?> pwSpecialChars = const Value.absent(),
                Value<bool> pwAvoidIlO0 = const Value.absent(),
                Value<String?> categoryPlaceholder = const Value.absent(),
                required DateTime lastSyncAt,
              }) => SettingsCompanion.insert(
                id: id,
                salt: salt,
                encryptedPrivateKey: encryptedPrivateKey,
                host: host,
                apiToken: apiToken,
                useBiometric: useBiometric,
                pwLength: pwLength,
                pwSpecialChars: pwSpecialChars,
                pwAvoidIlO0: pwAvoidIlO0,
                categoryPlaceholder: categoryPlaceholder,
                lastSyncAt: lastSyncAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SettingsTable,
      SettingData,
      $$SettingsTableFilterComposer,
      $$SettingsTableOrderingComposer,
      $$SettingsTableAnnotationComposer,
      $$SettingsTableCreateCompanionBuilder,
      $$SettingsTableUpdateCompanionBuilder,
      (SettingData, BaseReferences<_$AppDatabase, $SettingsTable, SettingData>),
      SettingData,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$UsersTableTableManager get users =>
      $$UsersTableTableManager(_db, _db.users);
  $$EntriesTableTableManager get entries =>
      $$EntriesTableTableManager(_db, _db.entries);
  $$PermissionsTableTableManager get permissions =>
      $$PermissionsTableTableManager(_db, _db.permissions);
  $$AttachmentsTableTableManager get attachments =>
      $$AttachmentsTableTableManager(_db, _db.attachments);
  $$TombstonesTableTableManager get tombstones =>
      $$TombstonesTableTableManager(_db, _db.tombstones);
  $$VersionsTableTableManager get versions =>
      $$VersionsTableTableManager(_db, _db.versions);
  $$SettingsTableTableManager get settings =>
      $$SettingsTableTableManager(_db, _db.settings);
}
