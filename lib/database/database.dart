import 'dart:ffi';
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/open.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:privault/core/service_locator.dart';
import 'package:privault/services/config_service.dart';
import 'package:flutter/foundation.dart';

part 'database.g.dart';

@DataClassName('UserData')
class Users extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get uuid => text().unique()();

  TextColumn get name => text().unique()();

  TextColumn get publicKey => text()();

  BoolColumn get isVerified => boolean().withDefault(const Constant(false))();

  BoolColumn get isHidden => boolean().withDefault(const Constant(false))();

  DateTimeColumn get updatedAt => dateTime()();
}

@DataClassName('EntryData')
class Entries extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get uuid => text().unique()();

  TextColumn get category => text().withDefault(const Constant(''))();

  TextColumn get title => text().withDefault(const Constant(''))();

  TextColumn get url => text().withDefault(const Constant(''))();

  TextColumn get notes => text().withDefault(const Constant(''))();

  TextColumn get favicon => text().withDefault(const Constant(''))();

  TextColumn get encryptedData => text()();

  IntColumn get creatorId => integer()();

  IntColumn get updaterId => integer()();

  DateTimeColumn get updatedAt => dateTime()();
}

@DataClassName('PermissionData')
class Permissions extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get entryId => integer().references(Entries, #id)();

  IntColumn get userId => integer().references(Users, #id)();

  TextColumn get encryptedKey => text()();

  IntColumn get accessLevel => integer()();

  @override
  List<Set<Column>> get uniqueKeys => [
    {entryId, userId},
  ];
}

@DataClassName('AttachmentData')
class Attachments extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get uuid => text().unique()();

  IntColumn get entryId => integer().references(Entries, #id)();

  TextColumn get encryptedMeta => text()();

  TextColumn get encryptedContent => text()(); // Base64 verschlüsselter Inhalt
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
}

@DataClassName('TombstoneData')
class Tombstones extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get entryUuid => text().unique()();

  DateTimeColumn get deletedAt => dateTime()();
}

@DataClassName('VersionData')
class Versions extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();

  IntColumn get major => integer()();

  IntColumn get minor => integer()();

  IntColumn get patch => integer()();

  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('SettingData')
class Settings extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();

  TextColumn get salt => text()();

  TextColumn get encryptedPrivateKey => text()();

  TextColumn get host => text().nullable()();

  TextColumn get apiToken => text().nullable()();

  BoolColumn get useBiometric => boolean().withDefault(const Constant(true))();

  IntColumn get pwLength => integer().withDefault(const Constant(16))();

  TextColumn get pwSpecialChars => text().nullable()();

  BoolColumn get pwAvoidIlO0 => boolean().withDefault(const Constant(true))();

  TextColumn get categoryPlaceholder => text().nullable()();

  DateTimeColumn get lastSyncAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [Users, Entries, Permissions, Attachments, Tombstones, Versions, Settings])
class AppDatabase extends _$AppDatabase {
  final String password;
  final String dbName;

  AppDatabase(this.dbName, this.password) : super(_openConnection(dbName, password));

  @override
  int get schemaVersion => 1;

  static QueryExecutor _openConnection(String name, String password) {
    return LazyDatabase(() async {
      // WICHTIG: Nutze den zentralen Speicherpfad aus dem ConfigService
      final config = getIt<ConfigService>();
      final storagePath = config.vaultStoragePath;
      final file = File(p.join(storagePath, '$name.db3'));

      // DLL-Bindung für SQLCipher
      if (!kIsWeb && Platform.isWindows) {
        final dllPath = p.join(Directory.current.path, 'sqlite3mc_x64.dll');
        if (File(dllPath).existsSync()) {
          open.overrideFor(OperatingSystem.windows, () => DynamicLibrary.open(dllPath));
          debugPrint('✅ SQLiteMC DLL registriert');
        }
      }

      if (kDebugMode) {
        // Brauchen wir, um die DB per Database Navigator öffnen zu können
        debugPrint("🔑 DB-Passwort: $password");
      }

      final rawDb = sqlite3.open(file.path);
      rawDb.execute("PRAGMA cipher = 'sqlcipher';");
      rawDb.execute("PRAGMA hexkey = '$password';");

      return NativeDatabase.opened(rawDb);
    });
  }
}
