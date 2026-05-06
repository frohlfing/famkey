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

Selbst wenn man in einer Factory `if (kIsWeb) return WebService()` schreibt, würde der Compiler versuchen, `WebService`
auf allen Plattformen aufzulösen.

**Lösung:** Nur der bedingte Import verhindert, dass inkompatibler Code "gesehen" wird:
```dart
export 'app_file/app_file_stub.dart'
  if (dart.library.ffi) 'app_file/app_file_native.dart'
  if (dart.library.js_interop) 'app_file/app_file_web.dart';  
```

### Delegation-Pattern

Dieses Pattern wird im offiziellen Flutter-Code und in modernen Paketen (wie `package:http`) verwendet, um die Vorteile 
des `factory`-Konstruktors (einfache API für den Nutzer) mit der notwendigen Isolation plattformspezifischer 
Bibliotheken zu kombinieren. 

Das Muster produziert zwar ein **Zirkelbezug**, aber Darts Compiler ist so konzipiert, dass er 
zirkuläre Imports zwischen Bibliotheken problemlos auflöst, solange keine „Initialisierungs-Zyklen“ (z. B. zwei 
statische Variablen, die sich gegenseitig zur Erzeugung benötigen) vorliegen.

Hier ist die Umsetzung für einen `DummyService`:

1. Die Schnittstelle/Interface: `dummy_service.dart`

    Diese Datei ist der einzige öffentliche Einstiegspunkt. Sie definiert die API und nutzt bedingte Importe, um die 
    korrekte Erzeugungs-Logik zu laden.
    
    ```dart
    // Bedingte Importe der Implementierungs-Logik
    import 'dummy_service/dummy_service_stub.dart'
      if (dart.library.io) 'dummy_service/dummy_service_io.dart'
      if (dart.library.js_interop) 'dummy_service/dummy_service_web.dart';
    
    abstract class DummyService {
      // Der Factory-Konstruktor delegiert an eine Top-Level-Funktion, die in allen importierten Dateien existiert.
      factory DummyService() => createDummyService();
    
      void doSomething();
    }
    ```

2. Der Stub: `dummy_service/dummy_service_stub.dart`

    Diese Datei dient als Sicherheitsnetz für Plattformen, die nicht explizit abgedeckt sind, und verhindert Analyse-Fehler 
    in der IDE.
    
    ```dart
    import '../dummy_service.dart';
    
    // Die Funktion wirft standardmäßig einen Fehler
    DummyService createDummyService() => throw UnsupportedError(
      'DummyService ist auf dieser Plattform nicht verfügbar.',
    );
    ```

3. Die Native-Implementierung: `dummy_service/dummy_service_native.dart`

    Hier können Bibliotheken wie `dart:io` sicher importiert werden, da diese Datei nur für Mobile- oder Desktop-Builds
    herangezogen wird.
    
    ```dart
    import 'dart:io';
    import '../dummy_service.dart';
    
    class DummyServiceNative implements DummyService {
      @override
      void doSomething() => print('Native Logik auf ${Platform.operatingSystem}');
    }
    
    // Die plattformspezifische Erzeugungs-Funktion
    DummyService createDummyService() => DummyServiceNative();
    ```

4. Die Web-Implementierung: `dummy_service/dummy_service_web.dart`

    Für die Wasm-Kompatibilität wird hier auf `dart.library.js_interop` geprüft und modernes `package:web` verwendet.
    
    ```dart
    import 'package:web/web.dart' as web;
    import 'dart:js_interop';
    import '../dummy_service.dart';
    
    class DummyServiceWeb implements DummyService {
      @override
      void doSomething() {
        web.console.log('Web-Logik ausgeführt'.toJS);
      }
    }
    
    // Die Web-spezifische Erzeugungs-Funktion
    DummyService createDummyService() => DummyServiceWeb();
    ```
