# Unit-Tests

## Code-Generierung für Mocks 

```shell
flutter pub run build_runner build --delete-conflicting-outputs
```
- `build`: Erstellt die fehlenden Dateien einmalig.
- `delete-conflicting-outputs` (Optional, aber empfohlen): Löscht alte oder fehlerhafte generierte Dateien, bevor die neuen erstellt werden.

## Voraussetzungen in der pubspec.yaml

```yaml
dev_dependencies:
flutter_test:
  sdk: flutter
mockito: ^5.4.4  # Oder eine aktuellere Version
build_runner: ^2.4.8 # Wichtig für die Generierung
```