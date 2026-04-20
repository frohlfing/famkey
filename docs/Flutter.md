# Flutter

## Pakete aktualisieren

- Aktualisiert alle Pakete so wie in `pubspec.yaml` angegeben:
```shell
flutter pub upgrade
```
 
- Aktualisiert AUCH Major-Versionen (ändert `pubspec.yaml`):
```shell
flutter pub upgrade --major-versions
```

- Zeigt, was veraltet ist:
```shell
flutter pub outdated
```

## ORM (Object-Relational Mapping) mit Drift 

Drift ist eine leistungsstarke Datenbankbibliothek für Dart- und Flutter-Anwendungen.

### Schritte, um eine neue Entität (z.B. `UserEntity`) zu erstellen:

1. Tabelle definieren: Erstelle in der `database.dart` (in `lib/database`) eine neue Klasse:
```Dart
class UserEntities extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
}
```

2. Tabelle registrieren: Füge die Klasse in der `@DriftDatabase`-Annotation hinzu:
```Dart
@DriftDatabase(tables: [Users, ..., UserEntities]) // <-- Hier ergänzen
class AppDatabase extends _$AppDatabase { 
... 
```

3. `database.g.dart` generieren bzw. aktualisieren (die zugrundeliegende _$AppDatabase-Klasse mit dem SQL-Code und der Mapping-Logik):
```shell
flutter pub run build_runner build --delete-conflicting-outputs 
```

4. Schema-Version erhöhen (Wichtig bei Updates!):
   Wenn die App ausgerollt ist und du eine Tabelle hinzufügst, musst du `schemaVersion` von 1 auf 2 erhöhen
   und dann doch eine MigrationStrategy definieren, damit Drift weiß, dass es die neue Tabelle nachinstallieren muss.


## Unterschied zwischen watch und read (und listen)

| Methode                     | Wann benutzen?                                         | Was passiert?                                                                                                                   |
|-----------------------------|--------------------------------------------------------|---------------------------------------------------------------------------------------------------------------------------------|  
| `ref.watch(provider)`       | In der build-Methode.                                  | Registriert das Widget als "Zuhörer". Sobald der State sich ändert, wird die ganze `build`-Methode neu ausgeführt.              |
| `ref.read(provider)`        | In Callbacks (`onPressed`) oder einmalig im `listen`.  | Holt den aktuellen Schnappschuss des States, ohne eine dauerhafte Verbindung aufzubauen. Es löst keinen Re-Build aus.           |
| `ref.listen(provider, ...)` | In der `build`-Methode (für Seiteneffekte).            | Führt eine Funktion aus, wenn sich der State ändert (wenn `next` ungleich `previous` ist), aber ohne das Widget neu zu rendern. |


## Bedingten Import / Platform-Weiche

Diese Pakete werden nicht bei einer WebAssembly unterstützt.
```dart
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import `package:open_filex/src/platform/`;
```

Wenn Teile daraus verwendet werden müssen, muss mit `kIsWeb` sichergestellt werden, dass im Web der Code nicht ausgeführt wird.
```dart
bool get isWindows => !kIsWeb && Platform.isWindows;
```

Oder man abstrahiert den Code und verwendet einen bedingten Import:
```dart
export 'app_file/app_file_stub.dart'
  if (dart.library.ffi) 'app_file/app_file_native.dart'
  if (dart.library.js_interop) 'app_file/app_file_web.dart';  
```
