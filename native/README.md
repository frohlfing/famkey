# Ordner: native/

Der Ordner `native/` enthält alle nativen Artefakte, die nicht direkt Teil des Flutter-Codes sind.

## Inhalt
- `sqlcipher/windows/sqlite-jdbc-3.51.2.0.jar` – SQLCipher‑fähiger JDBC‑Treiber (für Database Navigator in der IDE)

## Zweck
- Native Bibliotheken zentral verwalten
- Plattformabhängige Dateien logisch gruppieren
- Vermeiden, dass DLLs oder JARs in App-Ordnern liegen

## Besonderheiten
- Dateien sind **plattformabhängig**
- Werden von Flutter nicht automatisch eingebunden
- Müssen ggf. im Windows Runner kopiert werden

## Wichtig
Dieser Ordner ist **kein Flutter-Code**.
Er dient nur als Quelle für native Abhängigkeiten.
