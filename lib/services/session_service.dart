import 'package:flutter/foundation.dart';
import 'package:privault/models/entities/user_entity.dart';
import 'package:privault/services/crypto_service.dart';

class SessionService extends ChangeNotifier {
  final CryptoService _cryptoService;

  UserEntity? _user;
  Uint8List? _privateKey;
  String _vaultName = '';
  Map<String, dynamic>? _settings; // Simplified settings for now

  SessionService(this._cryptoService);

  bool get isLoggedIn => _user != null && _privateKey != null;

  UserEntity? get user => _user;
  Uint8List? get privateKey => _privateKey;
  String get vaultName => _vaultName;
  Map<String, dynamic>? get settings => _settings;

  void setSession({
    required UserEntity user,
    required Uint8List privateKey,
    required String vaultName,
    Map<String, dynamic>? settings,
  }) {
    _user = user;
    _privateKey = privateKey;
    _vaultName = vaultName;
    _settings = settings;
    notifyListeners();
  }

  void clearSession() {
    _user = null;
    _vaultName = '';
    _settings = null;
    if (_privateKey != null) {
      // "Wipe" the key in memory if possible
      _privateKey!.fillRange(0, _privateKey!.length, 0);
      _privateKey = null;
    }
    notifyListeners();
  }
}
