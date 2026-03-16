/// Snapshot über die veränderlichen Eigenschaften.
class SettingsSnapshot {
  final String vaultName;
  final bool useBiometric;
  final String userName;
  final String host;
  final String apiToken;
  final int pwLength;
  final String pwSpecialChars;
  final bool pwAvoidIlO0;
  final String categoryPlaceholder;

  /// Konstruktor
  SettingsSnapshot({
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
}