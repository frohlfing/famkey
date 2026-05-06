import 'package:get_it/get_it.dart';
import 'package:famkey/services/autolock_service.dart';
import 'package:famkey/services/autofill_service.dart';
import 'package:famkey/services/autotype_service.dart';
import 'package:famkey/services/biometric_service.dart';
import 'package:famkey/services/clipboard_service.dart';
import 'package:famkey/services/config_service.dart';
import 'package:famkey/services/crypto_service.dart';
import 'package:famkey/services/database_service.dart';
import 'package:famkey/services/info_service.dart';
import 'package:famkey/services/password_service.dart';
import 'package:famkey/services/session_service.dart';
import 'package:famkey/services/web_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

final getIt = GetIt.instance;

Future<void> setupServiceLocator() async {
  final prefs = await SharedPreferences.getInstance();
  getIt.registerLazySingleton<AutofillService>(() => AutofillService());
  getIt.registerLazySingleton<AutotypeService>(() => AutotypeService());
  getIt.registerLazySingleton<BiometricService>(() => BiometricService());
  getIt.registerLazySingleton<ConfigService>(() => ConfigService(prefs));
  getIt.registerLazySingleton<CryptoService>(() => CryptoService());
  getIt.registerLazySingleton<DatabaseService>(() => DatabaseService());
  getIt.registerLazySingleton<InfoService>(() => InfoService());
  getIt.registerLazySingleton<PasswordService>(() => PasswordService());
  getIt.registerLazySingleton<SessionService>(() => SessionService(getIt<CryptoService>()));
  getIt.registerLazySingleton<WebService>(() => WebService(getIt<CryptoService>()));
  getIt.registerLazySingleton<ClipboardService>(() => ClipboardService(getIt<ConfigService>()));
  getIt.registerLazySingleton<AutolockService>(() => AutolockService(getIt<SessionService>(), getIt<DatabaseService>(), getIt<ClipboardService>()));
}
