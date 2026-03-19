import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:privault/features/login/login_notifier.dart';
import 'package:privault/features/login/login_state.dart';
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
  // --- TextEditingController & FocusNode ---
  // ------------------------------------------------------------------------

  final _vaultController = TextEditingController();
  final _passwordController = TextEditingController();

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
      //_passwordController.clear();

      // Focus auf das erste leere Textfeld setzen
      _applyFocus();
    });
  }

  /// Gibt Ressourcen frei.
  @override
  void dispose() {
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

  /// Rendert die Seite (getriggert durch Änderungen im State)
  @override
  Widget build(BuildContext context) {

    // Listener für Side-Effects (Navigation, SnackBars)
    // Er wird nur einmal ausgelöst, wenn sich der Status ändert, und verursacht keine Rebuilds.
    ref.listen(loginProvider.select((s) => s.status), (previous, next) async {
      final notifier = ref.read(loginProvider.notifier);
      final state = ref.read(loginProvider);

      switch (next) {
        case LoginActionStatus.success:
          _passwordController.clear();
          Navigator.of(context).pushReplacementNamed('/main');
          break;

        case LoginActionStatus.askToCreateVault:
          final create = await ConfirmDialog.show(
            context,
            title: 'Tresor anlegen',
            text: 'Der Tresor "${state.vaultName}" existiert im gewählten Ordner noch nicht.\nMöchtest du ihn anlegen?',
            ok: 'Ja, anlegen',
          );
          if (mounted && create == true) {
            notifier.login(forceCreate: true);
          }
          break;

        case LoginActionStatus.askToEnableBiometrics:
          final enable = await ConfirmDialog.show(
            context,
            title: 'Biometrie aktivieren',
            text: 'Soll dein Schlüssel sicher auf diesem Gerät abgelegt werden, damit du dich beim nächsten Mal bequem per Fingerabdruck oder Gesichtserkennung anmelden kannst?',
            ok: 'Ja, Schlüssel speichern',
          );
          if (mounted) {
            if (enable == true) {
              notifier.saveMasterKeyAndCompleteLogin(_passwordController.text);
            } else {
              notifier.completeLogin();
            }
          }
          break;

        case LoginActionStatus.askToCleanUp:
          final delete = await ConfirmDialog.show(
            context,
            title: 'Tresor löschen',
            text: 'Der Tresor ist korrupt. Soll er gelöscht werden?',
            ok: 'Ja, löschen',
            autofocus: false,
          );
          if (mounted && delete == true) {
            notifier.cleanUp();
          }
          break;

        case LoginActionStatus.failure:
          if (state.error.field == null) { // Nur allgemeine Fehler anzeigen
            Snack.show(context, state.error.text);
          }
          break;

        default:
          break;
      }
    });

    // Gezielte Watches für maximale Performance
    final isBusy = ref.watch(loginProvider.select((s) => s.isBusy));
    final canLogin = ref.watch(loginProvider.select((s) => s.canLogin));

    // Notifier holen
    final notifier = ref.read(loginProvider.notifier);

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

                    // --- Logo ---
                    const Icon(Icons.lock_person_outlined, size: 80, color: Colors.blueGrey),
                    const SizedBox(height: 16),

                    // --- Überschrift ---
                    Text(
                      'PriVault',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 48),

                    // --- Tresor ---

                    Consumer(builder: (context, ref, _) {
                      final existingVaults = ref.watch(loginProvider.select((s) => s.existingVaults));
                      final errorText = ref.watch(loginProvider.select((s) => s.error.field == 'vaultName' ? s.error.text : null));
                      return TextField(
                        controller: _vaultController,
                        focusNode: _vaultFocusNode,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: 'Tresorname',
                          prefixIcon: const Icon(Icons.shield_outlined),
                          errorText: errorText,
                          border: const OutlineInputBorder(),
                          suffixIcon: existingVaults.isNotEmpty ? PopupMenuButton<String>(
                            icon: const Icon(Icons.list),
                            tooltip: 'Tresor auswählen',
                            onSelected: (val) {
                              notifier.setVaultName(val);
                              _passwordFocusNode.requestFocus();
                            },
                            itemBuilder: (BuildContext context) {
                              return existingVaults.map((String vault) => PopupMenuItem<String>(value: vault, child: Text(vault))).toList();
                            },
                          ) : null,
                        ),
                        onChanged: (value) => notifier.setVaultName(value),
                      );
                    }),
                    const SizedBox(height: 16),

                    // --- Passwort ---
                    Consumer(builder: (context, ref, _) {
                      final isExists = ref.watch(loginProvider.select((s) => s.isExists));
                      final password = ref.watch(loginProvider.select((s) => s.password));
                      final passwordStrength = ref.watch(loginProvider.select((s) => s.passwordStrength));
                      final hasBiometricKey = ref.watch(loginProvider.select((s) => s.hasBiometricKey));
                      final errorText = ref.watch(loginProvider.select((s) => s.error.field == 'password' ? s.error.text : null));
                      return Column(
                        children: [
                          PasswordField(
                            controller: _passwordController,
                            focusNode: _passwordFocusNode,
                            label: 'Master-Passwort',
                            prefixIcon: Icons.key_outlined,
                            errorText: errorText,
                            suffixActions: [
                              if (hasBiometricKey)
                                const Tooltip(
                                  message: 'Anmeldung per Biometrie möglich',
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 8),
                                    child: Icon(Icons.fingerprint, color: Colors.blue),
                                  ),
                                ),
                            ],
                            onChanged: (val) => notifier.setPassword(val),
                            onSubmitted: (_) => notifier.login(),
                          ),
                          //const SizedBox(height: 6),
                          // --- Passwortstärke ---
                          if (!isExists && password.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: PasswordStrengthBar(score: passwordStrength),
                            ),
                        ],
                      );
                    }),
                    const SizedBox(height: 24),

                    // --- Login-Button ---
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                      ),
                      onPressed: (isBusy || !canLogin) ? null : () => notifier.login(),
                      icon: const Icon(Icons.login_outlined),
                      label: const Text('Anmelden'),
                    ),

                  ],
                ),
              ),
            ),
          ),
        ),

        if (isBusy)
          Container(
            color: Colors.black.withValues(alpha: 0.1),
            child: const Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }
}
