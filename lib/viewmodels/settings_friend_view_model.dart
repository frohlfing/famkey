import 'package:flutter/foundation.dart';
import 'package:privault/models/entities/user_entity.dart';
import 'package:privault/services/crypto_service.dart';
import 'package:privault/services/database_service.dart';

class SettingsFriendViewModel extends ChangeNotifier {
  final CryptoService _cryptoService;
  final DatabaseService _databaseService;
  
  final UserEntity user;
  bool _needsRekeying = false;

  SettingsFriendViewModel(this._cryptoService, this._databaseService, this.user);

  String get name => user.name;
  
  bool get isVerified => user.isVerified;
  set isVerified(bool value) {
    // Note: Verification state is usually updated via SettingsViewModel to ensure DB sync
    notifyListeners();
  }

  bool get needsRekeying => _needsRekeying;

  String get fingerprint {
    // Logic from C#: _cryptoService.Fingerprint(User.PublicKey).Replace(":", ":\u200B");
    // We'll implement a basic version here, assuming CryptoService.fingerprint exists
    final raw = _cryptoService.computeHash(user.publicKey).toUpperCase();
    // Add colons for readability like in C#
    return raw.replaceAllMapped(RegExp(r".{2}"), (match) => "${match.group(0)}:").replaceAll(RegExp(r":$"), "");
  }

  Future<void> refreshStatus() async {
    // Similar to C# logic: await _databaseService.HasAccessWithoutKeyAsync(User.Id);
    // For now we simulate or use a placeholder
    _needsRekeying = false; 
    notifyListeners();
  }
}
