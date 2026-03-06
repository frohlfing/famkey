import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:privault/services/biometric_service.dart';
import 'package:privault/services/crypto_service.dart';
import 'package:privault/services/database_service.dart';
import 'package:privault/services/session_service.dart';
import 'package:privault/services/web_service.dart';
import 'package:privault/services/password_service.dart';
import 'package:privault/services/config_service.dart';

final getIt = GetIt.instance;

Future<void> setupServiceLocator() async {
  final prefs = await SharedPreferences.getInstance();
  getIt.registerLazySingleton<ConfigService>(() => ConfigService(prefs));
  getIt.registerLazySingleton<CryptoService>(() => CryptoService());
  getIt.registerLazySingleton<DatabaseService>(() => DatabaseService(getIt<ConfigService>()));
  getIt.registerLazySingleton<SessionService>(() => SessionService(getIt<CryptoService>()));
  getIt.registerLazySingleton<BiometricService>(() => BiometricService());
  getIt.registerLazySingleton<PasswordService>(() => PasswordService());
  getIt.registerLazySingleton<WebService>(
    () => WebService(
      getIt<CryptoService>(),
      baseUrl: 'https://privault.test/api',
      apiToken: '',
    ),
  );
}
