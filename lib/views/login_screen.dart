import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:privault/viewmodels/login_view_model.dart';

/// Der [LoginScreen] dient als Einstiegspunkt und Sicherheitsschleuse der App.
///
/// Er ermöglicht den Zugriff auf bestehende Tresore oder das Initialisieren eines neuen Tresors.
/// Kernfunktionen sind:
/// * Auswahl eines lokal vorhandenen Tresors oder Eingabe eines neuen Namens.
/// * Sicherer Login mittels Master-Passwort.
/// * Optionale Entsperrung per Biometrie (Fingerabdruck/Gesichtserkennung), falls zuvor aktiviert.
/// * Handhabung von Erst-Einrichtungen und Wiederherstellungsszenarien.
class LoginScreen extends StatefulWidget {

    /// Konstruktor
    const LoginScreen({super.key});

    @override
    State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {

    // ------------------------------------------------------------------------
    // --- Interne Variablen ---
    // ------------------------------------------------------------------------

    late LoginViewModel _viewModel;

    final TextEditingController _vaultController = TextEditingController();
    final TextEditingController _passwordController = TextEditingController();
    final FocusNode _vaultFocusNode = FocusNode();
    final FocusNode _passwordFocusNode = FocusNode();

    /// Gibt an, ob das Passwort ausgeblendet ist
    bool _obscurePassword = true;

    // ------------------------------------------------------------------------
    // --- Initialisierung & Lifecycle ---
    // ------------------------------------------------------------------------

    /// Initialisiert den Screen und stellt die Verbindung zum [LoginViewModel] her.
    /// 
    /// Beim Start wird geprüft, ob bereits ein Tresorname bekannt ist. Zudem wird 
    /// ein Callback registriert, um nach dem ersten Frame den Fokus korrekt zu setzen 
    /// und das Passwortfeld zu leeren.
    @override
    void initState() {
        super.initState();

        _viewModel = context.read<LoginViewModel>();
        _viewModel.addListener(_onViewModelChanged);

        _vaultController.text = _viewModel.vaultName;

        WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                    _viewModel.resetState();
                    _passwordController.clear();
                    _applyFocus();
                }
            }
        );
    }

    /// Bereinigt die Ressourcen beim Verlassen des Screens.
    /// 
    /// Entfernt den Listener vom ViewModel, löscht das Passwort aus dem Speicher 
    /// und gibt die Text-Controller sowie Focus-Nodes frei.
    @override
    void dispose() {
        _viewModel.removeListener(_onViewModelChanged);
        _viewModel.clearPassword(notify: false);
        _vaultController.dispose();
        _passwordController.dispose();
        _vaultFocusNode.dispose();
        _passwordFocusNode.dispose();
        super.dispose();
    }

    // ------------------------------------------------------------------------
    // --- Benutzeroberfläche ---
    // ------------------------------------------------------------------------

    /// Baut die Anmeldemaske der App auf.
    /// 
    /// Das Layout ist zentriert und für mobile Geräte sowie Desktop-Ansichten optimiert.
    @override
    Widget build(BuildContext context) {
        final viewModel = context.watch<LoginViewModel>();
        final bool canLogin = viewModel.password.isNotEmpty || (viewModel.isExists && viewModel.hasBiometricKey);

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
                                                border: const OutlineInputBorder(),
                                                prefixIcon: const Icon(Icons.storage),
                                                suffixIcon: viewModel.existingVaults.isNotEmpty
                                                    ? PopupMenuButton<String>(
                                                        icon: const Icon(Icons.list),
                                                        tooltip: 'Tresor auswählen',
                                                        onOpened: () => viewModel.resetState(),
                                                        onSelected: (String value) {
                                                            if (mounted) {
                                                                viewModel.vaultName = value;
                                                                _passwordFocusNode.requestFocus();
                                                            }
                                                        },
                                                        itemBuilder: (BuildContext context) {
                                                            return viewModel.existingVaults.map((String vault) {
                                                                    return PopupMenuItem<String>(value: vault, child: Text(vault));
                                                                }
                                                            ).toList();
                                                        },
                                                    )
                                                    : null,
                                            ),
                                            onChanged: (value) => viewModel.vaultName = value,
                                        ),
                                        const SizedBox(height: 16),

                                        TextField(
                                            controller: _passwordController,
                                            focusNode: _passwordFocusNode,
                                            obscureText: _obscurePassword,
                                            textInputAction: TextInputAction.done,
                                            decoration: InputDecoration(
                                                labelText: 'Master-Passwort',
                                                border: const OutlineInputBorder(),
                                                prefixIcon: const Icon(Icons.key),
                                                errorText: viewModel.errorMessage,
                                                suffixIcon: SizedBox(
                                                    width: 80, // Platz für beide Icons
                                                    child: Row(
                                                        mainAxisAlignment: MainAxisAlignment.end,
                                                        children: [
                                                            IconButton(
                                                                tooltip: _obscurePassword ? 'Passwort anzeigen' : 'Passwort verbergen',
                                                                icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                                                                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                                            ),
                                                            if (viewModel.hasBiometricKey)
                                                            Tooltip(
                                                                message: 'Anmeldung per Biometrie möglich',
                                                                child: const Padding(
                                                                    padding: EdgeInsets.only(right: 8.0),
                                                                    child: Icon(Icons.fingerprint, color: Colors.blue),
                                                                ),
                                                            ),
                                                        ],
                                                    ),
                                                ),
                                            ),
                                            onChanged: (value) => viewModel.password = value,
                                            onSubmitted: canLogin ? (_) => _handleLogin() : null,
                                        ),
                                        const SizedBox(height: 24),

                                        // if (viewModel.errorMessage != null)
                                        //   Padding(
                                        //     padding: const EdgeInsets.only(bottom: 16),
                                        //     child: Text(
                                        //       viewModel.errorMessage!,
                                        //       style: const TextStyle(color: Colors.red),
                                        //       textAlign: TextAlign.center,
                                        //     ),
                                        //   ),
                                        ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                                padding: const EdgeInsets.symmetric(vertical: 18),
                                                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                                            ),
                                            onPressed: (viewModel.isBusy || !canLogin) ? null : () => _handleLogin(),
                                            child: const Text('Anmelden'),
                                        ),
                                    ],
                                ),
                            ),
                        ),
                    ),
                ),

                if (viewModel.isBusy) Container(
                    color: Colors.black.withValues(alpha: 0.05),
                    child: const Center(child: CircularProgressIndicator()),
                ),
            ],
        );
    }

    // ------------------------------------------------------------------------
    // --- Interne Methoden ---
    // ------------------------------------------------------------------------

    /// Steuert den gesamten Anmeldevorgang und verarbeitet die verschiedenen Ergebnisse.
    /// 
    /// Je nach Rückmeldung des ViewModels führt diese Funktion folgende Aktionen aus:
    /// * **Erfolg:** Navigiert zum Hauptbildschirm.
    /// * **Biometrie:** Fragt den Nutzer, ob der Schlüssel für künftige Logins im Secure Storage abgelegt werden soll.
    /// * **Nicht gefunden:** Bietet die Erstellung eines neuen Tresors an.
    /// * **Korrupt:** Ermöglicht das Löschen eines beschädigten lokalen Tresors.
    Future<void> _handleLogin({bool forceCreate = false}) async {
        if (!mounted) return;
        final result = await _viewModel.login(forceCreate: forceCreate);
        if (!mounted) return;

        switch (result) {
            case LoginResult.success:
                Navigator.pushReplacementNamed(context, '/main');
                break;

            case LoginResult.askToEnableBiometrics:
                final enable = await _showConfirmDialog(
                    'Biometrie aktivieren',
                    'Soll dein Schlüssel sicher auf diesem Gerät abgelegt werden, damit du dich beim nächsten Mal bequem per Fingerabdruck oder Gesichtserkennung anmelden kannst?',
                    'Ja, Schlüssel speichern',
                );
                if (enable == true && mounted) {
                    await _viewModel.saveMasterKey(_passwordController.text);
                }
                if (mounted) Navigator.pushReplacementNamed(context, '/main');
                break;

            case LoginResult.vaultNotFound:
                final create = await _showConfirmDialog(
                    'Tresor anlegen',
                    'Der Tresor "${_viewModel.vaultName}" existiert im gewählten Ordner noch nicht.\nMöchtest du ihn anlegen?',
                    'Ja, anlegen',
                );
                if (create == true && mounted) {
                    _handleLogin(forceCreate: true);
                }
                break;

            case LoginResult.corrupt:
                final delete = await _showConfirmDialog('Tresor löschen', 'Der Tresor ist korrupt. Soll er gelöscht werden?', 'Ja, löschen');
                if (delete == true && mounted) {
                    await _viewModel.cleanUp();
                    setState(() {
                            _vaultController.clear();
                            _passwordController.clear();
                        }
                    );
                }
                break;
            default:
            break;
        }
    }

    /// Zeigt einen Bestätigungsdialog für kritische Entscheidungen an.
    /// 
    /// Wird genutzt für die Aktivierung von Biometrie, die Neuanlage eines Tresors 
    /// oder das Löschen korrupter Daten.
    Future<bool?> _showConfirmDialog(String title, String content, String confirmLabel) {
        return showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
                title: Text(title),
                content: Text(content),
                actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Abbrechen')),
                    ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        autofocus: true,
                        child: Text(confirmLabel, style: TextStyle(color: confirmLabel.contains('löschen') ? Colors.red : null)),
                    ),
                ],
            ),
        );
    }

    /// Reagiert auf Änderungen im ViewModel.
    /// 
    /// Synchronisiert die Textfelder, falls sich der Tresorname (z. B. durch Auswahl 
    /// aus der Liste) geändert hat oder der Login-Status zurückgesetzt wurde.
    void _onViewModelChanged() {
        if (!mounted) return;
        if (_vaultController.text != _viewModel.vaultName) {
            setState(() {
                    _vaultController.text = _viewModel.vaultName;
                }
            );
        }
        if (_viewModel.password.isEmpty && _passwordController.text.isNotEmpty) {
            _passwordController.clear();
        }
        setState(() {
            }
        );
    }

    /// Setzt den Fokus intelligent beim Öffnen des Screens.
    /// 
    /// Ist noch kein Tresorname vorhanden, wird das Namensfeld fokussiert. 
    /// Ansonsten springt der Cursor direkt in das Passwortfeld, um den Login zu beschleunigen.
    void _applyFocus() {
        if (_vaultController.text.isEmpty) {
            _vaultFocusNode.requestFocus();
        }
        else {
            _passwordFocusNode.requestFocus();
        }
    }
}
