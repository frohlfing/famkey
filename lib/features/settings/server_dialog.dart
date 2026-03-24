import 'package:flutter/material.dart';
import 'package:privault/widgets/password_field.dart';

// Test-Status des Dialogs
enum TestStatus { success, failure }

/// Einstellungen des Passwort-Generators.
class ServerDialogData {
  /// Die URL des Servers für die Synchronisation.
  final String host;

  /// Das API-Token für die Authentifizierung gegenüber dem Server.
  final String apiToken;

  /// Konstruktor
  const ServerDialogData({
    this.host = '',
    this.apiToken = '',
  });

  /// Daten aktualisieren (immutable)
  ServerDialogData copyWith({
    String? host,
    String? apiToken,
  }) {
    return ServerDialogData(
      host: host ?? this.host,
      apiToken: apiToken ?? this.apiToken,
    );
  }

  // @formatter:off
  /// Operator `==` für das Objekt anpassen
  @override
  bool operator == (Object other) =>
    identical(this, other) ||
      other is ServerDialogData && (
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
class ServerDialog {

  /// Öffnet den Dialog und gibt bei Bestätigung die Einstellungen zurück.
  static Future<ServerDialogData?> show(
    BuildContext context, {
    String? host,
    String? apiToken,
    String? hostErrorText,
    String? apiTokenErrorText,
    required void Function(ServerDialogData) onTestConnectionPressed,
    TestStatus? testStatus,
    String? testResult,
  }) {
    final hostController = TextEditingController(text: host);
    final apiTokenController = TextEditingController(text: apiToken);

    return showDialog<ServerDialogData>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
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
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: 'Serveradresse',
                      errorText: hostErrorText,
                      prefixIcon: Icon(Icons.cloud_outlined),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) {
                      // Sobald getippt wird, Fehlermeldung löschen
                      if (hostErrorText != null || testStatus != null) {
                        setDialogState(() {
                          hostErrorText = null;
                          testStatus = null;
                          testResult = null;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),

                  // --- API-Token ---
                  PasswordField(
                    controller: apiTokenController,
                    textInputAction: TextInputAction.next,
                    label: 'API-Token',
                    prefixIcon: Icons.vpn_key_outlined,
                    errorText: apiTokenErrorText,
                    onChanged: (_) {
                      // Sobald getippt wird, Fehlermeldung löschen
                      if (apiTokenErrorText != null || testStatus != null) {
                        setDialogState(() {
                          apiTokenErrorText = null;
                          testStatus = null;
                          testResult = null;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 8),

                  // --- Button für Verbindungtest ---
                  ElevatedButton.icon(
                    onPressed: () {
                      final formData = ServerDialogData(
                        host: hostController.text,
                        apiToken: apiTokenController.text,
                      );
                      Navigator.of(ctx).pop(null);
                      onTestConnectionPressed(formData);
                    },
                    icon: const Icon(Icons.swap_calls_outlined),
                    label: const Text('Verbindung testen'),
                  ),

                  // --- Testergebnisses ---
                  const SizedBox(height: 12), // Abstand unter dem Button
                  if (testStatus == TestStatus.success)
                    Row(
                      children: const [
                        Icon(Icons.check_circle, color: Colors.green),
                        SizedBox(width: 8),
                        Text('Verbindung erfolgreich', style: TextStyle(color: Colors.green)),
                      ]
                    )
                  else if (testStatus == TestStatus.failure && testResult != null)
                      Row(
                      children: [
                        Icon(Icons.error, color: Theme.of(context).colorScheme.error),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            testResult!,
                            softWrap: true,
                            style: TextStyle(color: Theme.of(context).colorScheme.error),
                          ),
                        ),
                      ]
                    )
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
                  //if (hostController.text.isNotEmpty) {
                    final formData = ServerDialogData(
                      host: hostController.text,
                      apiToken: apiTokenController.text,
                    );
                    Navigator.of(ctx).pop(formData);
                  //}
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      },
    );
  }
}
