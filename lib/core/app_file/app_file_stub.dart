import 'package:famkey/core/app_file.dart';

// Fallback, falls keine plattformspezifische Implementierung verfügbar ist.

/// Erzeugt eine [AppFile]-Instanz für den angegebenen Pfad.
AppFile createAppFile(String path)
  => throw UnsupportedError('Plattform nicht unterstützt');

/// Erzeugt eine [AppDirectory]-Instanz für den angegebenen Pfad.
AppDirectory createAppDirectory(String path)
  => throw UnsupportedError('Plattform nicht unterstützt');

/// Liefert ein temporäres Verzeichnis.
Future<AppDirectory> createTempAppDirectory()
  => throw UnsupportedError('Plattform nicht unterstützt');

/// Liefert eine temporäre Datei in einem temporären Verzeichnis.
/// Wenn filename nicht angegeben ist, wird eine UUID als Dateiname verwendet.
Future<AppFile> createTempAppFile([String? filename])
  => throw UnsupportedError('Plattform nicht unterstützt');

/// Erzeugt eine [AppFilePicker]-Instanz.
AppFilePicker createAppFilePicker()
  => throw UnsupportedError('Plattform nicht unterstützt');

/// Öffnet den Systemdialog zum Speichern der Datei (nativ) oder löst einen Browser-Download aus (Web/OPFS).
Future<void> downloadAppFile(AppFile file)
  => throw UnsupportedError('Plattform nicht unterstützt');