/// Alle Daten im Dialog, die der Benutzer ändern kann.
class SyncServerFormData {

  /// Die URL des Servers für die Synchronisation.
  final String host;

  /// Das API-Token für die Authentifizierung gegenüber dem Server.
  final String apiToken;

  /// Konstruktor
  const SyncServerFormData({
    this.host = '',
    this.apiToken = '',
  });

  /// Daten aktualisieren (immutable)
  SyncServerFormData copyWith({
    String? host,
    String? apiToken,
  }) {
    return SyncServerFormData(
      host: host ?? this.host,
      apiToken: apiToken ?? this.apiToken,
    );
  }

  // @formatter:off
  /// Operator `==` für das Objekt anpassen
  @override
  bool operator == (Object other) =>
    identical(this, other) ||
      other is SyncServerFormData && (
        runtimeType == other.runtimeType &&
          host == other.host &&
          apiToken == other.apiToken
      );

  /// Liefert den HashCode für das Objekt
  /// (erforderlich, wenn ein Operators überschrieben wird)
  @override
  int get hashCode =>
    host.hashCode ^
    apiToken.hashCode;
// @formatter:on
}