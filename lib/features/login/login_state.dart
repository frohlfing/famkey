import 'package:privault/core/app_error.dart';

/// ------------------------------------------------------------------------
/// STATE-KLASSE
/// - Enthält alle Werte, die vorher im ViewModel als Felder existierten.
/// - Immutable: Änderungen passieren über copyWith().
/// ------------------------------------------------------------------------
class LoginState {
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

  /// Gibt an, ob ein Ladesymbol angezeigt wird
  final bool isBusy;

  /// Gibt an, ob gefragt werden soll, ob Biometrie aktiviert werden soll.
  final bool askToEnableBiometrics;

  /// Fehler der letzten Operation
  final FormError? error;

  /// Konstruktor
  const LoginState({
    this.vaultName = '',
    this.password = '',
    this.isExists = false,
    this.hasBiometricKey = false,
    this.existingVaults = const [],
    this.isBusy = false,
    this.askToEnableBiometrics = false,
    this.error,
  });

  /// Status aktualisieren (immutable)
  LoginState copyWith({
    String? vaultName,
    String? password,
    bool? isExists,
    bool? hasBiometricKey,
    List<String>? existingVaults,
    bool? isBusy,
    bool? askToEnableBiometrics,
    FormError? error,
  }) {
    return LoginState(
      vaultName: vaultName ?? this.vaultName,
      password: password ?? this.password,
      isExists: isExists ?? this.isExists,
      hasBiometricKey: hasBiometricKey ?? this.hasBiometricKey,
      existingVaults: existingVaults ?? this.existingVaults,
      isBusy: isBusy ?? this.isBusy,
      askToEnableBiometrics: askToEnableBiometrics ?? false, // wird zurückgesetzt, wenn nicht angegeben
      error: error, // wird zurückgesetzt, wenn nicht angegeben
    );
  }
}