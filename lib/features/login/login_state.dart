import 'package:famkey/core/app_error.dart';

/// Ein Enum für den Status von Aktionen
enum LoginActionStatus {
  initial, // Der Ausgangszustand
  progress, // Daten werden geladen
  success, // Login wurde erfolgreich beendet
  failure, // Aktion mit Fehler beendet
  askToCreateVault, // Frage, ob ein neuer Tresor erstellt werden soll
  askToCleanUp, // Frage, ob die Datenbank gelöscht werden soll (weil sie korrupt ist)
  askToEnableBiometrics, // Frage, ob die Biometrie aktiviert werden soll
}

class LoginState {

  /// Der Name des Tresors, der geöffnet oder neu erstellt werden soll.
  final String vaultName;

  /// Eine Liste aller auf diesem Gerät gefundenen Tresore.
  final List<String> existingVaults;

  /// Gibt an, ob der gewählte Tresor bereits lokal existiert.
  final bool isExists;

  /// Das eingegebene Master-Passwort.
  final String password;

  /// Die berechnete Passwortstärke
  final int passwordStrength;

  /// Gibt an, ob für den aktuell gewählten Tresor der Master-Key im Secure-Store liegt.
  final bool hasBiometricKey;

  /// Der Status der letzten Aktion.
  final LoginActionStatus status;

  /// Der Fehler der letzten Operation.
  final AppError error;

  // --- Getter ---

  /// Gibt an, ob gerade eine Hintergrundaktion läuft.
  bool get isBusy => status == LoginActionStatus.progress;

  /// Gibt an, ob der Login-Button aktiv sein sollte.
  bool get canLogin => password.isNotEmpty || (isExists && hasBiometricKey);

  /// Konstruktor
  const LoginState({
    this.vaultName = '',
    this.existingVaults = const [],
    this.isExists = false,
    this.password = '',
    this.passwordStrength = 0,
    this.hasBiometricKey = false,
    this.status = LoginActionStatus.initial,
    this.error = const AppError.none(),
  });

  /// Status aktualisieren (immutable)
  LoginState copyWith({
    String? vaultName,
    List<String>? existingVaults,
    bool? isExists,
    String? password,
    int? passwordStrength,
    bool? hasBiometricKey,
    LoginActionStatus? status,
    AppError? error,
  }) {
    return LoginState(
      vaultName: vaultName ?? this.vaultName,
      existingVaults: existingVaults ?? this.existingVaults,
      isExists: isExists ?? this.isExists,
      password: password ?? this.password,
      passwordStrength: passwordStrength ?? this.passwordStrength,
      hasBiometricKey: hasBiometricKey ?? this.hasBiometricKey,
      status: status ?? this.status,
      error: error ?? this.error,
    );
  }
}
