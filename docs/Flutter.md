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

## Unterschied zwischen watch und read (und listen)

| Methode                     | Wann benutzen?                                         | Was passiert?                                                                                                                   |
|-----------------------------|--------------------------------------------------------|---------------------------------------------------------------------------------------------------------------------------------|  
| `ref.watch(provider)`       | In der build-Methode.                                  | Registriert das Widget als "Zuhörer". Sobald der State sich ändert, wird die ganze `build`-Methode neu ausgeführt.              |
| `ref.read(provider)`        | In Callbacks (`onPressed`) oder einmalig im `listen`.  | Holt den aktuellen Schnappschuss des States, ohne eine dauerhafte Verbindung aufzubauen. Es löst keinen Re-Build aus.           |
| `ref.listen(provider, ...)` | In der `build`-Methode (für Seiteneffekte).            | Führt eine Funktion aus, wenn sich der State ändert (wenn `next` ungleich `previous` ist), aber ohne das Widget neu zu rendern. |

## WebAppliance (WASM)

### WasmDatabase

Für die WasmDatabase müssen diese beiden Dateien in den `web`-Ordner kopiert werden:

- `drift_worker.js` - Quelle: https://github.com/simolus3/drift/releases/tag/drift-2.31.0
- `sqlite3.wasm` - Quelle: https://github.com/simolus3/sqlite3.dart/releases/tag/sqlite3-2.9.4

Die Versionsnummern müssen exakt mit den Flutter-Paketen übereinstimmen!
Versionen aus `pubspec.lock` lesen:
```shell
Select-String -Path pubspec.lock -Pattern "^\s+(sqlite3|drift):" -A 2
````
Oder einfach `pubspec.lock` in Android Studio öffnen und nach dem Paketnamen suchen.

Bei einem Update der Flutter-Pakete dürfen diese beiden Dateien nicht vergessen werden.

### Origin-Private File System (OPFS)

OPFS ist ein persistentes, origin-gebundenes Dateisystem im Browser. 
Dateipfade werden als Verzeichnisstruktur im OPFS abgebildet.

Voraussetzung: Die App muss mit den COOP/COEP-Headern ausgeliefert werden,
damit SharedArrayBuffer und Atomics verfügbar sind (für den Drift-Worker).

Konfiguration in Android Studio:
- `Run` → `Edit Configurations` → `Add New Configuration` → `Flutter`
- In das Feld `Additional run args` dies einfügen:
```
-d chrome
  --web-header=Cross-Origin-Opener-Policy=same-origin
  --web-header=Cross-Origin-Embedder-Policy=require-corp
```
Das OPFS selbst funktioniert auch ohne diese Header.

Per Terminal starten:
```shell
flutter run -d edge --web-header="Cross-Origin-Opener-Policy=same-origin" --web-header="Cross-Origin-Embedder-Policy=require-corp"
```

Verfügbare Browser anzeigen:
```shell
flutter devices
```

Dateien im OPFS anzeigen (in der Entwicklungskonsole des Browsers (F12)):
```javascript
const root = await navigator.storage.getDirectory();
const driftDir = await root.getDirectoryHandle('drift_db');
for await (const [name, handle] of driftDir.entries()) {
  console.log(name, handle.kind);
}
```

```javascript
const root = await navigator.storage.getDirectory();
const driftDir = await root.getDirectoryHandle('drift_db');
await driftDir.removeEntry('test', { recursive: true });
console.log('Tresor "test" gelöscht');
try {
  await driftDir.removeEntry('test.db3.salt');
  console.log('Salt gelöscht');
} catch (_) {
}
```

### Bedingten Import / Platform-Weiche

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
