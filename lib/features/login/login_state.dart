import 'package:privault/core/app_error.dart';

class LoginState {
  /// Gibt an, ob ein Ladesymbol angezeigt wird.
  final bool isBusy;

  /// Der Name des Tresors, der geöffnet oder neu erstellt werden soll.
  final String vaultName;

  /// Das eingegebene Master-Passwort.
  final String password;

  /// Gibt an, ob der gewählte Tresor bereits lokal existiert.
  final bool isExists;

  /// Gibt an, ob für den aktuell gewählten Tresor der Master-Key im Secure-Store liegt.
  final bool hasBiometricKey;

  /// Eine Liste aller auf diesem Gerät gefundenen Tresore.
  final List<String> existingVaults;

  /// Gibt an, ob gefragt werden soll, ob Biometrie aktiviert werden soll.
  final bool askToEnableBiometrics;

  /// Der Fehler der letzten Operation.
  final FormError error;

  /// Konstruktor
  const LoginState({
    this.isBusy = false,
    this.vaultName = '',
    this.password = '',
    this.isExists = false,
    this.hasBiometricKey = false,
    this.existingVaults = const [],
    this.askToEnableBiometrics = false,
    this.error = const FormError.none(),
  });

  /// Status aktualisieren (immutable)
  LoginState copyWith({
    bool? isBusy,
    String? vaultName,
    String? password,
    bool? isExists,
    bool? hasBiometricKey,
    List<String>? existingVaults,
    bool? askToEnableBiometrics,
    FormError? error,
  }) {
    return LoginState(
      isBusy: isBusy ?? this.isBusy,
      vaultName: vaultName ?? this.vaultName,
      password: password ?? this.password,
      isExists: isExists ?? this.isExists,
      hasBiometricKey: hasBiometricKey ?? this.hasBiometricKey,
      existingVaults: existingVaults ?? this.existingVaults,
      askToEnableBiometrics: askToEnableBiometrics ?? this.askToEnableBiometrics,
      error: error ?? this.error,
    );
  }
}