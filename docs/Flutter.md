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

### Bedingten Import / Platform-Weiche

Diese Pakete werden nicht bei einer WebAssembly unterstützt.
```dart
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
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
