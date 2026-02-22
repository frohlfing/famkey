# 07 Deployment (Build & Auslieferung)

## 1. Deployment der Windows-App
1. Sicherstellen, dass in `Privault.Core.csproj` die `Version` und `RequiredServerMinor` korrekt angehoben sind.
2. TODO

## 2. Deployment der Android-App
1. Sicherstellen, dass in `Privault.Core.csproj` die `Version` und `RequiredServerMinor` korrekt angehoben sind.
2. TODO
Erstellung von Release-APKs/AABs via CLI:
```powershell
dotnet publish -f net8.0-android -c Release
```

## 3. Deployment der Web-App
1. Sicherstellen, dass in `Privault.Core.csproj` die `Version` und `RequiredServerMinor` korrekt angehoben sind.
2. TODO

## 4. Serverseitige Migration
1. Sicherstellen, dass in `config.php` die `VERSION` und `REQUIRED_CLIENT_MINOR` korrekt angehoben sind.
2. Kopieren des `Host`-Ordners auf den Webserver.
3. Einspielen der SQL-Skripte aus dem Ordner `Host/migrations/` per `phpMyAdmin` oder CLI.

## 5. Release auf Github erstellen

Best Practice: 
- MAJOR = eigener Branch 
- MINOR = eigener Tag 
 
### 5.1 Release-Tag für eine neue MINOR-Version erstellen

Für jede MINOR-App-Version sollte ein Release-Tag auf GitHub erstellt werden.

- Schritt 1: Tag erstellen (falls noch nicht geschehen)
  ```bash
  git tag -a v0.3.0 -m "Version 0.3.0 Release"
  git push origin v0.3.0
  git push --tags
  ```
- Schritt 2: Offizielles Release auf GitHub anlegen
  - Gehe zu GitHub und öffne dein Repository.
  - Klicke oben auf "Releases" / "Draft a new release" / v0.3.0
  - Beschreibung für das Release eingeben (Änderungen, Features, Bugfixes etc.)
  - Auf "Publish release" klicken.

### 5.2 Branch für alte MAJOR-Version erstellen

Wenn du von MAJOR 1 auf 2 gehst, machst du aus dem bisherigen Stand einen Maintenance-Branch:

- Schritt 1: Branch "1.x" erstellen
  ```bash
  git checkout main
  git pull
  git checkout -b 1.x
  git push -u origin 1.x
  ```

- "1.x" bleibt für Bugfixes/Hotfixes auf MAJOR 1.
- "main" ist ab jetzt die Entwicklungslinie für MAJOR 2.

- Schritt 2:
  Auf "main" erhöhst du die Version (in `Privault.Core.csproj` und in `config.php`).

- Schritt 3: Committen:
  ```bash
  git checkout main
  git pull
  git add -A
  git commit -m "Bump version to 2.0.0 (major release)"
  git push
  ```
