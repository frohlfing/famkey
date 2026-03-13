import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:privault/core/app_error.dart';
import 'package:privault/features/login/login_notifier.dart';
import 'package:privault/widgets/confirm_dialog.dart';
import 'package:privault/widgets/password_field.dart';
import 'package:privault/widgets/password_strength_bar.dart';
import 'package:privault/widgets/snack.dart';

/// Der [LoginPage] dient als Einstiegspunkt und Sicherheitsschleuse der App.
///
/// Er ermöglicht den Zugriff auf bestehende Tresore oder das Initialisieren eines neuen Tresors.
/// Kernfunktionen sind:
/// * Auswahl eines lokal vorhandenen Tresors oder Eingabe eines neuen Namens.
/// * Sicherer Login mittels Master-Passwort.
/// * Optionale Entsperrung per Biometrie (Fingerabdruck/Gesichtserkennung), falls zuvor aktiviert.
/// * Handhabung von Erst-Einrichtungen und Wiederherstellungsszenarien.
class LoginPage extends ConsumerStatefulWidget {
  /// Konstruktor
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {

  // ------------------------------------------------------------------------
  // --- Interne Variablen ---
  // ------------------------------------------------------------------------

  final TextEditingController _vaultController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _vaultFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();

  // ------------------------------------------------------------------------
  // --- Initialisierung & Lifecycle ---
  // ------------------------------------------------------------------------

  /// Initialisiert die Seite und lädt die Daten, sobald der erste Frame gerendert wurde.
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Daten laden
      final notifier = ref.read(loginProvider.notifier);
      await notifier.load();

      // Textfelder synchronisieren
      final state = ref.read(loginProvider);
      _vaultController.text = state.vaultName;
      _passwordController.clear();

      // Focus auf das erste leere Textfeld setzen
      _applyFocus();
    });
  }

  /// Gibt Ressourcen frei.
  @override
  void dispose() {
    // Controller & FocusNodes freigeben
    _vaultController.dispose();
    _passwordController.dispose();
    _vaultFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  /// Setzt den Fokus intelligent beim Öffnen des Screens.
  ///
  /// Ist noch kein Tresorname vorhanden, wird das Namensfeld fokussiert.
  /// Ansonsten springt der Cursor direkt in das Passwortfeld, um den Login zu beschleunigen.
  void _applyFocus() {
    if (_vaultController.text.isEmpty) {
      _vaultFocusNode.requestFocus();
    } else {
      _passwordFocusNode.requestFocus();
    }
  }

  // ------------------------------------------------------------------------
  // --- Benutzeroberfläche ---
  // ------------------------------------------------------------------------

  /// Baut die Anmeldemaske der App auf.
  ///
  /// Das Layout ist zentriert und für mobile Geräte sowie Desktop-Ansichten optimiert.
  @override
  Widget build(BuildContext context) {
    // Notifier und State holen
    final notifier = ref.read(loginProvider.notifier);
    final state = ref.watch(loginProvider);

    // Button-Status berechnen
    final bool canLogin = state.password.isNotEmpty || (state.isExists && state.hasBiometricKey);

    return Stack(
      children: [
        Scaffold(
          body: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32.0),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.lock_person_outlined, size: 80, color: Colors.blueGrey),
                    const SizedBox(height: 16),
                    Text(
                      'PriVault',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 48),

                    TextField(
                      controller: _vaultController,
                      focusNode: _vaultFocusNode,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: 'Tresor-Name',
                        prefixIcon: const Icon(Icons.shield_outlined),
                        errorText: notifier.getFieldErrorText('vaultName'),
                        border: const OutlineInputBorder(),
                        suffixIcon: state.existingVaults.isNotEmpty
                            ? PopupMenuButton<String>(
                                icon: const Icon(Icons.list),
                                tooltip: 'Tresor auswählen',
                                onSelected: (String value) {
                                  if (mounted) {
                                    notifier.setVaultName(value);
                                    _passwordFocusNode.requestFocus();
                                  }
                                },
                                itemBuilder: (BuildContext context) {
                                  return state.existingVaults.map((String vault) {
                                    return PopupMenuItem<String>(value: vault, child: Text(vault));
                                  }).toList();
                                },
                              )
                            : null,
                      ),
                      onChanged: (value) => notifier.setVaultName(value),
                    ),
                    const SizedBox(height: 16),

                    PasswordField(
                      controller: _passwordController,
                      focusNode: _passwordFocusNode,
                      label: 'Master-Passwort',
                      prefixIcon: Icons.key_outlined,
                      errorText: notifier.getFieldErrorText('password'),
                      suffixActions: [
                        if (state.hasBiometricKey)
                          const Tooltip(
                            message: 'Anmeldung per Biometrie möglich',
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8),
                              child: Icon(Icons.fingerprint, color: Colors.blue),
                            ),
                          ),
                      ],
                      onChanged: (val) => notifier.setPassword(val),
                      onSubmitted: (_) => _handleLogin(),
                    ),

                    const SizedBox(height: 6),
                    if (!state.isExists && state.password.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: PasswordStrengthBar(score: notifier.getPasswordStrength()),
                      ),

                    const SizedBox(height: 24),

                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                      ),
                      onPressed: (state.isBusy || !canLogin) ? null : () => _handleLogin(),
                      icon: const Icon(Icons.login_outlined),
                      label: const Text('Anmelden'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        if (state.isBusy)
          Container(
            color: Colors.black.withValues(alpha: 0.05),
            child: const Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }

  // ------------------------------------------------------------------------
  // --- Handler ---
  // ------------------------------------------------------------------------

  /// Steuert den gesamten Anmeldevorgang und verarbeitet die verschiedenen Ergebnisse.
  Future<void> _handleLogin({bool forceCreate = false}) async {
    // Busy-Check
    if (ref.read(loginProvider).isBusy) return;

    // Login durchführen
    final notifier = ref.read(loginProvider.notifier);
    final success = await notifier.login(forceCreate: forceCreate);
    if (!mounted) return;

    // Aktuellen State holen
    final state = ref.read(loginProvider);

    // Fehlerfall
    if (!success) {
      switch (state.error?.code) {
        case ErrorCode.vaultNotFound:
          final create = await ConfirmDialog.show(
            context,
            title: 'Tresor anlegen',
            text: 'Der Tresor "${state.vaultName}" existiert im gewählten Ordner noch nicht.\nMöchtest du ihn anlegen?',
            ok: 'Ja, anlegen',
          );
          if (create == true && mounted) {
            _handleLogin(forceCreate: true);
          }
          break;

        case ErrorCode.vaultCorrupt:
          final delete = await ConfirmDialog.show(
            context,
            title: 'Tresor löschen',
            text: 'Der Tresor ist korrupt. Soll er gelöscht werden?',
            ok: 'Ja, löschen',
            autofocus: false,
          );
          if (delete == true && mounted) {
            await notifier.cleanUp();
            setState(() {
              _vaultController.clear();
              _passwordController.clear();
            });
          }
          break;

        default:
          if (state.error?.field == null) {
            Snack.show(context, state.error?.text ?? ErrorCode.unknown.defaultText);
          }
      }
      return;
    }

    // Erfolgsfall

    // Falls Biometrie aktiviert werden kann: Nachfragen
    if (state.askToEnableBiometrics) {
      final enable = await ConfirmDialog.show(
        context,
        title: 'Biometrie aktivieren',
        text: 'Soll dein Schlüssel sicher auf diesem Gerät abgelegt werden, damit du dich beim nächsten Mal bequem per Fingerabdruck oder Gesichtserkennung anmelden kannst?',
        ok: 'Ja, Schlüssel speichern',
      );
      if (enable == true && mounted) {
        await notifier.saveMasterKey(_passwordController.text);
      }
    }

    // Passwort im State zurücksetzen
    notifier.clearPassword();

    // Hauptseite öffnen
    if (mounted) Navigator.of(context).pushReplacementNamed('/main');
  }
}
