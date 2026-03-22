/// Alle Daten in den Einstellungen, die für den Dirty-Check relevant sind.
class SettingsFormData {

  // --- Tresor ---

  /// Der Name des Tresors.
  final String vaultName;

  // --- Login ---

  /// Gibt an, ob Fingerabdruck bzw. Gesichtserkennung als Anmeldeoption zur Verfügung steht.
  final bool useBiometric;

  // --- Sync-Server ---

  /// Der Name des angemeldeten Benutzers innerhalb des Tresors.
  final String userName;

  /// Die URL des Servers für die Synchronisation.
  final String host;

  /// Das API-Token für die Authentifizierung gegenüber dem Server.
  final String apiToken;

  // --- Passwort-Generator ---

  /// Eingestellte Länge für den Passwortgenerator.
  final int pwLength;

  /// Der aktuell gewählte Satz an Sonderzeichen für generierte Passwörter.
  final String pwSpecialChars;

  /// Gibt an, ob optisch ähnliche Zeichen ('I', 'l', 'O', '0') ausgelassen werden.
  final bool pwAvoidIlO0;

  // --- Design ---

  /// Anzeigename für eine leere Kategorie.
  final String categoryPlaceholder;

  /// Konstruktor
  const SettingsFormData({
    this.vaultName = '',
    this.useBiometric = false,
    this.userName = '',
    this.host = '',
    this.apiToken = '',
    this.pwLength = 16,
    this.pwSpecialChars = '',
    this.pwAvoidIlO0 = false,
    this.categoryPlaceholder = '',
  });

  /// Daten aktualisieren (immutable)
  SettingsFormData copyWith({
    String? vaultName,
    bool? useBiometric,
    String? userName,
    String? host,
    String? apiToken,
    int? pwLength,
    String? pwSpecialChars,
    bool? pwAvoidIlO0,
    String? categoryPlaceholder,
  }) {
    return SettingsFormData(
      vaultName: vaultName ?? this.vaultName,
      useBiometric: useBiometric ?? this.useBiometric,
      userName: userName ?? this.userName,
      host: host ?? this.host,
      apiToken: apiToken ?? this.apiToken,
      pwLength: pwLength ?? this.pwLength,
      pwSpecialChars: pwSpecialChars ?? this.pwSpecialChars,
      pwAvoidIlO0: pwAvoidIlO0 ?? this.pwAvoidIlO0,
      categoryPlaceholder: categoryPlaceholder ?? this.categoryPlaceholder,
    );
  }

  // @formatter:off
  /// Operator `==` für das Objekt anpassen
  @override
  bool operator == (Object other) =>
    identical(this, other) ||
    other is SettingsFormData && (
      runtimeType == other.runtimeType &&
      vaultName == other.vaultName &&
      useBiometric == other.useBiometric &&
      userName == other.userName &&
      host == other.host &&
      apiToken == other.apiToken &&
      pwLength == other.pwLength &&
      pwSpecialChars == other.pwSpecialChars &&
      pwAvoidIlO0 == other.pwAvoidIlO0 &&
      categoryPlaceholder == other.categoryPlaceholder
    );

  /// Liefert den HashCode für das Objekt
  /// (erforderlich, wenn ein Operators überschrieben wird)
  @override
  int get hashCode =>
    vaultName.hashCode ^
    useBiometric.hashCode ^
    userName.hashCode ^
    host.hashCode ^
    apiToken.hashCode ^
    pwLength.hashCode ^
    pwSpecialChars.hashCode ^
    pwAvoidIlO0.hashCode ^
    categoryPlaceholder.hashCode;
  // @formatter:on
}