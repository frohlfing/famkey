import 'package:get_it/get_it.dart';
import 'package:privault/services/biometric_service.dart';
import 'package:privault/services/crypto_service.dart';
import 'package:privault/services/database_service.dart';
import 'package:privault/services/session_service.dart';
import 'package:privault/services/web_service.dart';
import 'package:privault/services/sync_service.dart';
import 'package:privault/services/password_service.dart';

final getIt = GetIt.instance;

void setupServiceLocator() {
  getIt.registerLazySingleton<CryptoService>(() => CryptoService());
  getIt.registerLazySingleton<DatabaseService>(() => DatabaseService());
  getIt.registerLazySingleton<SessionService>(() => SessionService(getIt<CryptoService>()));
  getIt.registerLazySingleton<BiometricService>(() => BiometricService());
  getIt.registerLazySingleton<PasswordService>(() => PasswordService());
  
  getIt.registerLazySingleton<WebService>(() => WebService(
    getIt<CryptoService>(),
    baseUrl: 'https://privault.test/api',
    apiToken: '',
  ));

  getIt.registerLazySingleton<SyncService>(() => SyncService(
    getIt<CryptoService>(),
    getIt<DatabaseService>(),
    getIt<SessionService>(),
    getIt<WebService>(),
  ));
}
