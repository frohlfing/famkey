import 'package:flutter/material.dart';
import 'package:privault/widgets/password_field.dart';

/// Einstellungen des Passwort-Generators.
class ServerSettingsDialogData {
  /// Die URL des Servers für die Synchronisation.
  final String host;

  /// Das API-Token für die Authentifizierung gegenüber dem Server.
  final String apiToken;

  /// Konstruktor
  const ServerSettingsDialogData({
    this.host = '',
    this.apiToken = '',
  });

  /// Daten aktualisieren (immutable)
  ServerSettingsDialogData copyWith({
    String? host,
    String? apiToken,
  }) {
    return ServerSettingsDialogData(
      host: host ?? this.host,
      apiToken: apiToken ?? this.apiToken,
    );
  }

  // @formatter:off
  /// Operator `==` für das Objekt anpassen
  @override
  bool operator == (Object other) =>
    identical(this, other) ||
      other is ServerSettingsDialogData && (
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

/// Ein modaler Dialog zum Konfigurieren des Passwort-Generators.
class ServerSettingsDialog {

  /// Öffnet den Dialog und gibt bei Bestätigung die Einstellungen zurück.
  static Future<ServerSettingsDialogData?> show(BuildContext context, {
        String? host,
        String? apiToken,
        String? hostErrorText,
        String? apiTokenErrorText,
        void Function(ServerSettingsDialogData)? onTestConnectionPressed,
      }) {
    final hostController = TextEditingController(text: host);
    final apiTokenController = TextEditingController(text: apiToken);

    return showDialog<ServerSettingsDialogData>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Sync-Server'),
          content: SizedBox(
            width: 450,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

              // --- Host ---
              TextField(
                controller: hostController,
                decoration: InputDecoration(
                  labelText: 'Serveradresse',
                  errorText: hostErrorText,
                  prefixIcon: Icon(Icons.cloud_outlined),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // --- API-Token ---
              PasswordField(
                controller: apiTokenController,
                label: 'API-Token',
                prefixIcon: Icons.vpn_key_outlined,
                errorText: apiTokenErrorText,
              ),
              const SizedBox(height: 8),

              // --- Button für Verbindungtest ---
              if (onTestConnectionPressed != null)
                ElevatedButton.icon(
                  onPressed: () {
                    final formData = ServerSettingsDialogData(
                      host: hostController.text,
                      apiToken: apiTokenController.text,
                    );
                    onTestConnectionPressed(formData);
                  },
                  icon: const Icon(Icons.swap_calls_outlined),
                  label: const Text('Verbindung testen'),
                ),
              if (onTestConnectionPressed != null)
                const SizedBox(height: 32),

            ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(null),
              child: const Text('Abbrechen'),
            ),
            ElevatedButton(
              onPressed: () {
                if (hostController.text.isNotEmpty) {
                  final formData = ServerSettingsDialogData(
                    host: hostController.text,
                    apiToken: apiTokenController.text,
                  );
                  Navigator.of(ctx).pop(formData);
                }
              },
              child: const Text('OK'),
            ),
          ],
        ),
      ),
    );
  }
}
