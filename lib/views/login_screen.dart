import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:privault/viewmodels/login_view_model.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _vaultController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _vaultFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();
  
  late LoginViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = context.read<LoginViewModel>();
    _vaultController.text = _viewModel.vaultName;
    
    // WICHTIG: Fehler beheben (setState während build) und Passwort leeren
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _viewModel.resetState();
        _passwordController.clear();
        _applyFocus();
      }
    });

    _viewModel.addListener(_onViewModelChanged);
  }

  void _onViewModelChanged() {
    if (!mounted) return;
    if (_vaultController.text != _viewModel.vaultName) {
      setState(() {
        _vaultController.text = _viewModel.vaultName;
      });
    } else {
      setState(() {});
    }
  }

  void _applyFocus() {
    // Punkt 3: Fokus auf Tresorname, wenn dieser leer ist, sonst auf Passwortfeld
    if (_vaultController.text.isEmpty) {
      _vaultFocusNode.requestFocus();
    } else {
      _passwordFocusNode.requestFocus();
    }
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onViewModelChanged);
    _vaultController.dispose();
    _passwordController.dispose();
    _vaultFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

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
        final delete = await _showConfirmDialog(
          'Tresor löschen',
          'Der Tresor ist korrupt. Soll er gelöscht werden?',
          'Ja, löschen',
        );
        if (delete == true && mounted) {
          await _viewModel.cleanUp();
          setState(() {
            _vaultController.clear();
            _passwordController.clear();
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Der korrupte Tresor wurde gelöscht.')),
            );
          }
        }
        break;

      default:
        break;
    }
  }

  Future<bool?> _showConfirmDialog(String title, String content, String confirmLabel) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Abbrechen')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmLabel, style: TextStyle(color: confirmLabel.contains('löschen') ? Colors.red : null)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<LoginViewModel>();

    // Punkt 1: Login möglich, wenn Passwort da ODER Biometrie für existierenden Tresor verfügbar
    final bool canLogin = viewModel.password.isNotEmpty || (viewModel.isExists && viewModel.hasBiometricKey);

    return Scaffold(
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
                          tooltip: 'Vorhandene Tresore',
                          onOpened: () => viewModel.refreshVaultList(), // NEU: Live-Update beim Öffnen
                          onSelected: (String value) {
                            if (mounted) {
                              viewModel.vaultName = value;
                              _passwordFocusNode.requestFocus();
                            }
                          },
                          itemBuilder: (BuildContext context) {
                            return viewModel.existingVaults.map((String vault) {
                              return PopupMenuItem<String>(value: vault, child: Text(vault));
                            }).toList();
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
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    labelText: 'Master-Passwort',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.key),
                    suffixIcon: viewModel.hasBiometricKey
                      ? const Icon(Icons.fingerprint, color: Colors.blue)
                      : null,
                  ),
                  onChanged: (value) => viewModel.password = value,
                  onSubmitted: canLogin ? (_) => _handleLogin() : null,
                ),
                const SizedBox(height: 24),

                if (viewModel.errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      viewModel.errorMessage!,
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  ),

                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  ),
                  onPressed: (viewModel.isBusy || !canLogin) ? null : () => _handleLogin(),
                  child: viewModel.isBusy
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(viewModel.isExists ? 'Tresor öffnen' : 'Tresor neu anlegen'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
