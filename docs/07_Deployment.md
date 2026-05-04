# 07 Deployment (Build & Auslieferung)

## Grundlagen: Der Release-Modus (`--release`)
Der Release-Modus optimiert die App für die Veröffentlichung. Im Gegensatz zum Debug-Modus (Entwicklung) bewirkt dieser:
- **AOT-Kompilierung:** Der Code wird in schnellen Maschinencode übersetzt (höhere Performance).
- **Tree Shaking:** Nicht verwendeter Code wird entfernt (kleinere Dateigröße).
- **Bereinigung:** Das "DEBUG"-Banner und Debug-Tools werden entfernt. `kDebugMode` ist in diesem Modus `false`.

**In Android Studio (GUI) finden:**
- **Build erstellen:** Menü `Build` -> `Flutter` -> `Build APK / Web / Windows`.
- **Release-Lauf:** In den `Run Configurations` (neben dem Play-Button) den `Build mode` auf `release` umstellen.

## Wichtig: App-Versionierung
In der `pubspec.yaml` wird die Version definiert (z. B. `version: 1.0.0+1`):
- **1.0.0 (Version Name):** Die sichtbare Versionsnummer für den Nutzer.
- **+1 (Build Number):** Eine interne Nummer, die bei jedem Release im Store (Play Store/App Store) erhöht werden MUSS.

---

## 1. Deployment der Windows-App
1. Öffne das Terminal in Android Studio.
2. Führe den Build-Befehl aus:
   ```powershell
   flutter build windows --release
   ```
3. Die fertigen Dateien befinden sich im Ordner:
   `build\windows\x64\runner\Release\`
4. Zur Weitergabe muss der gesamte Inhalt dieses Ordners (die `.exe` sowie alle benötigten `.dll`-Dateien) in ein ZIP-Archiv gepackt werden.

## 2. Deployment der Android-App
1. Stelle sicher, dass die App-Signierung (`key.jks`) korrekt konfiguriert ist.
2. **Für die direkte Installation (APK):**
   ```powershell
   flutter build apk --release
   ```
   Pfad: `build\app\outputs\flutter-apk\app-release.apk`
3. **Für den Google Play Store (App Bundle):**
   ```powershell
   flutter build appbundle --release
   ```
   Pfad: `build\app\outputs\bundle\release\app-release.aab`

## 3. Deployment der Web-App
1. Führe den Build-Befehl aus:
   ```powershell
   flutter build web --release
   ```
2. Falls die App auf dem Server in einem Unterverzeichnis (z. B. `/app/`) liegt, gib dies beim Build an:
   ```powershell
   flutter build web --release --base-href "/app/"
   ```
3. Kopiere den gesamten Inhalt aus `build/web/` auf deinen Webserver.

## 4. Serverseitige Migration (PHP/Backend)
1. Führe das Build-Skript aus, um das Paket zu schnüren:
   ```powershell
   .\bin\build_server_setup.ps1
   ```
2. Lade die erzeugte `famkey_server_setup.zip` hoch und entpacke sie auf dem Server.
3. Einspielen der SQL-Skripte aus dem Ordner `migrations/` per `phpMyAdmin` oder CLI.

## 5. Release auf GitHub erstellen

Best Practice: 
- MAJOR = eigener Branch 
- MINOR = eigener Tag 
 
### 5.1 Release-Tag für eine neue MINOR-Version erstellen
- Schritt 1: Tag lokal erstellen und pushen
  ```bash
  git tag -a v0.3.0 -m "Version 0.3.0 Release"
  git push origin v0.3.0
  ```
- Schritt 2: Auf GitHub unter "Releases" -> "Draft a new release" den Tag wählen und Artefakte hochladen.

### 5.2 Branch für alte MAJOR-Version erstellen (Maintenance)
1. Branch "1.x" erstellen: `git checkout -b 1.x` && `git push -u origin 1.x`.
2. Auf `main` die Version in der `pubspec.yaml` erhöhen.
3. Committen und Pushen.
