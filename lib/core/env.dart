import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Globale Zugriffsvariable (Kurzform für Env())
final env = Env();

class Env {
  /// Singleton-Instanz
  static final Env _instance = Env._internal();
  factory Env() => _instance;
  Env._internal(); /// privater benannter Konstruktor

  // ------------------------------------------------------------------------
  // --- Interne Zustandsvariablen ---
  // ------------------------------------------------------------------------

  /// Speicherpfad der App
  late String _storagePath;

  // ------------------------------------------------------------------------
  // --- Initialisierung ---
  // ------------------------------------------------------------------------

  /// Initialisierung
  /// Wird einmalig in `main()` aufgerufen.
  Future<void> init() async {
    _storagePath = kIsWeb ? '' : (await getApplicationSupportDirectory()).path;
  }

  // ------------------------------------------------------------------------
  // --- Getter ---
  // ------------------------------------------------------------------------

  // --- Plattform-Flags ---

  /// Gibt an, ob die App im Browser läuft.
  bool get isWeb => kIsWeb;

  /// Gibt an, ob die App auf Windows läuft.
  bool get isWindows => !kIsWeb && Platform.isWindows;

  /// Gibt an, ob die App auf Linux läuft.
  bool get isLinux => !kIsWeb && Platform.isLinux;

  /// Gibt an, ob die App auf Android läuft.
  bool get isAndroid => !kIsWeb && Platform.isAndroid;

  /// Gibt an, ob die App auf iOS läuft.
  bool get isIOS => !kIsWeb && Platform.isIOS;

  /// Gibt an, ob die App auf macOS läuft.
  bool get isMacOS => !kIsWeb && Platform.isMacOS;

  /// Gibt an, ob die App auf iOS oder macOS läuft.
  bool get isApple => !kIsWeb && (Platform.isIOS || Platform.isMacOS);

  /// Gibt an, ob die App auf Android oder iOS läuft.
  bool get isMobile  => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  /// Gibt an, ob die App auf Windows, Linux oder macOS läuft.
  bool get isDesktop  => !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

  // --- Umgebungsvariablen ---

  /// Der aktuelle Benutzername laut Betriebssystem.
  String get username => kIsWeb ? 'User' : (Platform.environment['USERNAME'] ?? 'User');

  /// Gibt an, ob gerade ein Unit-Test ausgeführt wird.
  bool get isTest => kIsWeb ? false : Platform.environment.containsKey('FLUTTER_TEST');

  // --- Dateisystem ---

  /// Speicherpfad der App.
  /// Unter Windows: `C:\Users\<user>\AppData\Roaming\de.frohlfing.famkey\FamKey`
  /// Unter Android: `/data/data/<package>/files`
  /// Unter Linux: `/home/<user>/.local/share/de.frohlfing.famkey/FamKey`
  /// Im Webbrowser: kein Dateisystem (Leerstring)
  String get storagePath => _storagePath;

  /// Speicherpfad für die Tresore
  String get vaultStoragePath => isWeb ? 'drift_db' : p.join(_storagePath, 'vaults');
}