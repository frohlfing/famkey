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
  final FocusNode _passwordFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    final viewModel = context.read<LoginViewModel>();
    _vaultController.text = viewModel.vaultName;
    
    viewModel.addListener(_onViewModelChanged);

    if (viewModel.vaultName.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _passwordFocusNode.requestFocus();
      });
    }
  }

  void _onViewModelChanged() {
    final viewModel = context.read<LoginViewModel>();
    if (_vaultController.text != viewModel.vaultName) {
      setState(() {
        _vaultController.text = viewModel.vaultName;
      });
    }
  }

  @override
  void dispose() {
    context.read<LoginViewModel>().removeListener(_onViewModelChanged);
    _vaultController.dispose();
    _passwordController.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _handleLogin({bool forceCreate = false}) async {
    final viewModel = context.read<LoginViewModel>();
    var result = await viewModel.login(forceCreate: forceCreate);

    if (!mounted) return;

    if (result == LoginResult.vaultNotFound) {
      final create = await _showConfirmDialog(
        'Tresor anlegen',
        'Der Tresor "${viewModel.vaultName}" existiert auf diesem Gerät noch nicht.\nMöchtest du ihn anlegen?',
        'Ja, anlegen'
      );
      if (create == true) {
        // Kleine Verzögerung um AXTree-Fehler auf Windows zu vermeiden
        await Future.delayed(const Duration(milliseconds: 50));
        result = await viewModel.login(forceCreate: true);
      }
    }

    if (!mounted) return;

    switch (result) {
      case LoginResult.success:
        Navigator.pushReplacementNamed(context, '/main');
        break;
      
      case LoginResult.askToEnableBiometrics:
        final enable = await _showConfirmDialog(
          'Biometrie aktivieren',
          'Soll dein Schlüssel sicher auf diesem Gerät abgelegt werden, damit du dich beim nächsten Mal bequem per Fingerabdruck oder Gesichtserkennung anmelden kannst?',
          'Ja, Schlüssel speichern'
        );
        if (enable == true) {
          await viewModel.saveMasterKey(_passwordController.text);
        }
        if (mounted) Navigator.pushReplacementNamed(context, '/main');
        break;

      case LoginResult.corrupt:
        final delete = await _showConfirmDialog(
          'Tresor löschen',
          'Der Tresor ist korrupt. Soll er gelöscht werden?',
          'Ja, löschen'
        );
        if (delete == true) {
          await viewModel.cleanUp();
          setState(() {
            _vaultController.clear();
            _passwordController.clear();
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Der korrupte Tresor wurde gelöscht.'))
          );
        }
        break;

      default:
        break;
    }
  }

  Future<bool?> _showConfirmDialog(String title, String content, String confirmLabel) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Abbrechen')),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            child: Text(confirmLabel, style: TextStyle(color: confirmLabel.contains('löschen') ? Colors.red : null))
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<LoginViewModel>();
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
                  decoration: InputDecoration(
                    labelText: 'Tresor-Name',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.storage),
                    suffixIcon: viewModel.existingVaults.isNotEmpty 
                      ? PopupMenuButton<String>(
                          icon: const Icon(Icons.list),
                          tooltip: 'Vorhandene Tresore',
                          onSelected: (String value) {
                            viewModel.vaultName = value;
                            _vaultController.text = value;
                            _passwordFocusNode.requestFocus();
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
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
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
