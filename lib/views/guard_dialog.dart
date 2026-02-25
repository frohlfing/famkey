import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:privault/services/crypto_service.dart';
import 'package:privault/services/session_service.dart';
import 'package:privault/services/database_service.dart';

/// Ein sicherheitskritischer Dialog, der den `GuardService` der MAUI-App ablöst.
/// 
/// **Wann wird dieser Dialog verwendet?**
/// Immer dann, wenn die App eine tiefgreifende, unwiderrufliche oder sicherheitskritische 
/// Aktion auf der Datenbank ausführen muss. Typische Szenarien sind:
/// 1. **Master-Passwort ändern:** Die gesamte Datenbank muss neu verschlüsselt werden.
/// 2. **Notfall-Reset (Adoption):** Wenn das Passwort auf einem anderen Gerät (z. B. PC) 
///    geändert wurde und dieses Handy nun gezwungen wird, die neue Identität 
///    (neuer Master-Key, neues RSA-Paar) vom Server zu übernehmen.
///
/// **Warum ist dieser Dialog so komplex (Backup-Logik)?**
/// Normale Datenbankoperationen (wie das Löschen eines Eintrags) können in einer 
/// SQL-Transaktion gekapselt werden. Wenn etwas schiefgeht, wird ein `Rollback` gemacht.
/// Die Operation `PRAGMA rekey` (welche die Verschlüsselung der SQLite-Datei ändert) 
/// ist jedoch **nicht transaktionssicher**. 
/// Bricht die App während eines `rekey` ab (Stromausfall, Crash), ist die Datenbank-Datei 
/// physisch zerstört und unwiderruflich korrupt. 
/// Daher erstellt dieser Dialog *vor* der Operation ein physisches File-Backup (`.bak`) 
/// der Datenbank und stellt dieses bei einem Fehler automatisch wieder her.
class GuardDialog extends StatefulWidget {
  
  /// Der Titel des Dialogs (z. B. "Identität bestätigen").
  final String title;
  
  /// Eine kurze Beschreibung, warum das Passwort benötigt wird.
  final String message;
  
  /// Die kritische Aktion, die bei korrektem Passwort ausgeführt wird. 
  /// Bekommt den abgeleiteten (neuen) Master-Key als Parameter übergeben, 
  /// um damit z. B. `rekey()` auszuführen.
  final Future<void> Function(Uint8List masterKey) operation;
  
  /// Wenn `true`, wird die Session nach erfolgreicher Operation zwingend beendet 
  /// und der Nutzer muss sich am Startbildschirm neu anmelden.
  final bool forceLogout;
  
  /// (Optional) Wenn angegeben, wird dieses Salt zur Ableitung des Keys genutzt, 
  /// statt des lokal in der DB gespeicherten. 
  /// Wird bei der "Adoption" benötigt, da das neue Salt vom Server kommt.
  final String? overrideSalt;
  
  /// (Optional) Wenn angegeben, wird dieser verschlüsselte Private-Key zur Validierung genutzt.
  /// Wird ebenfalls bei der "Adoption" vom Server bereitgestellt.
  final String? overrideValidationKey;

  // Injizierte Services
  final CryptoService cryptoService;
  final SessionService sessionService;
  final DatabaseService databaseService;

  const GuardDialog({
    super.key,
    required this.title,
    required this.message,
    required this.operation,
    required this.cryptoService,
    required this.sessionService,
    required this.databaseService,
    this.forceLogout = false,
    this.overrideSalt,
    this.overrideValidationKey,
  });

  /// Statische Hilfsmethode, um den Dialog aufzurufen und das Ergebnis abzuwarten.
  static Future<bool> execute(
    BuildContext context, {
    required String title,
    required String message,
    required Future<void> Function(Uint8List masterKey) operation,
    required CryptoService cryptoService,
    required SessionService sessionService,
    required DatabaseService databaseService,
    bool forceLogout = false,
    String? overrideSalt,
    String? overrideValidationKey,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false, // Darf aus Sicherheitsgründen nicht durch Klick daneben geschlossen werden
      builder: (dialogContext) => GuardDialog(
        title: title,
        message: message,
        operation: operation,
        forceLogout: forceLogout,
        overrideSalt: overrideSalt,
        overrideValidationKey: overrideValidationKey,
        cryptoService: cryptoService,
        sessionService: sessionService,
        databaseService: databaseService,
      ),
    );
    return result ?? false;
  }

  @override
  State<GuardDialog> createState() => _GuardDialogState();
}

class _GuardDialogState extends State<GuardDialog> {
  final TextEditingController _passwordController = TextEditingController();
  bool _isBusy = false;
  String? _errorMessage;
  bool _obscureText = true;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final pw = _passwordController.text;
    if (pw.isEmpty) return;

    setState(() {
      _isBusy = true;
      _errorMessage = null;
    });

    Uint8List? masterKey;

    try {
      // 1. Key ableiten
      // Zugriff auf die Map via String-Keys, da SettingsEntity im SessionService aktuell eine Map ist.
      final saltString = widget.overrideSalt ?? widget.sessionService.settings?['salt'];
      if (saltString == null || saltString.isEmpty) {
        throw Exception("Kein Salt vorhanden.");
      }
      final salt = base64Decode(saltString);

      // Zeitintensive Operation (Argon2id)
      masterKey = await widget.cryptoService.deriveKey(pw, salt);

      // 2. Passwort validieren
      // Wir testen, ob sich der RSA Private-Key mit dem abgeleiteten Master-Key entschlüsseln lässt.
      final validationKey = widget.overrideValidationKey ?? widget.sessionService.settings?['encrypted_private_key'];
      if (validationKey == null || validationKey.isEmpty) {
        throw Exception("Kein privater RSA-Schlüssel zur Validierung vorhanden.");
      }

      try {
        await widget.cryptoService.decrypt(validationKey, masterKey);
      } catch (_) {
        throw Exception("Falsches Master-Passwort.");
      }

      // 3. Physisches Datenbank-Backup erstellen (Schutz vor PRAGMA rekey Korruption)
      widget.databaseService.createBackup();

      try {
        // 4. Die eigentliche, kritische Logik ausführen (z.B. Rekey der Datenbank)
        await widget.operation(masterKey);

        // 5. Erfolg: Das Backup wird nicht mehr benötigt und gelöscht.
        widget.databaseService.removeBackup();

        if (widget.forceLogout) {
          // Alle Keys aus dem RAM löschen und zum Login zurückkehren
          widget.sessionService.clearSession();
          if (!mounted) return;
          if (!context.mounted) return;
          Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
        } else {
          // Dialog erfolgreich schließen
          if (!mounted) return;
          if (!context.mounted) return;
          Navigator.of(context).pop(true);
        }

      } catch (operationException) {
        // 6. Fehler während der kritischen Operation (z.B. App-Absturz simuliert oder I/O Error)
        // -> Rollback auf Dateisystem-Ebene!
        widget.databaseService.restoreBackup();
        throw Exception("Kritischer Fehler. Änderungen wurden verworfen: ${operationException.toString()}");
      }
  
    } catch (ex) {
      // Fehlerbehandlung für UI anzeigen
      setState(() {
        _errorMessage = ex.toString().replaceAll("Exception: ", "");
      });
    } finally {
      // 7. Hygiene: Unabhängig von Erfolg oder Fehler muss der in Schritt 1 
      // abgeleitete Master-Key sofort aus dem Arbeitsspeicher (RAM) gewischt werden.
      if (masterKey != null) {
        widget.cryptoService.wipeKey(masterKey);
      }
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.message),
          const SizedBox(height: 16),
          TextField(
            controller: _passwordController,
            obscureText: _obscureText,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Master-Passwort',
              border: const OutlineInputBorder(),
              errorText: _errorMessage,
              suffixIcon: IconButton(
                icon: Icon(_obscureText ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _obscureText = !_obscureText),
              ),
            ),
            onSubmitted: (_) => _submit(),
          ),
          if (_isBusy)
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: LinearProgressIndicator(),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isBusy ? null : () => Navigator.of(context).pop(false),
          child: const Text('Abbrechen'),
        ),
        ElevatedButton(
          onPressed: _isBusy ? null : _submit,
          child: const Text('Bestätigen'),
        ),
      ],
    );
  }
}
