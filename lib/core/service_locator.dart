import 'package:get_it/get_it.dart';
import 'package:privault/services/auto_lock_service.dart';
import 'package:privault/services/autofill_service.dart';
import 'package:privault/services/biometric_service.dart';
import 'package:privault/services/clipboard_service.dart';
import 'package:privault/services/config_service.dart';
import 'package:privault/services/crypto_service.dart';
import 'package:privault/services/database_service.dart';
import 'package:privault/services/system_settings_service.dart';
import 'package:privault/services/password_service.dart';
import 'package:privault/services/session_service.dart';
import 'package:privault/services/web_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

final getIt = GetIt.instance;

Future<void> setupServiceLocator() async {
  final prefs = await SharedPreferences.getInstance();
  getIt.registerLazySingleton<AutofillService>(() => AutofillService.create());
  getIt.registerLazySingleton<BiometricService>(() => BiometricService());
  getIt.registerLazySingleton<ConfigService>(() => ConfigService(prefs));
  getIt.registerLazySingleton<CryptoService>(() => CryptoService());
  getIt.registerLazySingleton<DatabaseService>(() => DatabaseService());
  getIt.registerLazySingleton<SystemSettingsService>(() => SystemSettingsServiceFactory.create());
  getIt.registerLazySingleton<PasswordService>(() => PasswordService());
  getIt.registerLazySingleton<SessionService>(() => SessionService(getIt<CryptoService>()));
  getIt.registerLazySingleton<WebService>(() => WebService(getIt<CryptoService>()));
  getIt.registerLazySingleton<ClipboardService>(() => ClipboardService(getIt<ConfigService>()));
  getIt.registerLazySingleton<AutoLockService>(() => AutoLockService(getIt<SessionService>(), getIt<DatabaseService>(), getIt<ClipboardService>()));
}
