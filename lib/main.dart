import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:privault/core/logger.dart';
import 'package:privault/core/service_locator.dart';
import 'package:privault/services/config_service.dart';
import 'package:privault/features/detail/detail_page.dart';
import 'package:privault/features/edit/edit_page.dart';
import 'package:privault/features/login/login_page.dart';
import 'package:privault/features/main/main_page.dart';
import 'package:privault/features/settings/settings_notifier.dart';
import 'package:privault/features/settings/settings_page.dart';

// @formatter:off
void main() async {

  runZonedGuarded(() async { // fängt unbehandelte async‑Fehler ab

    WidgetsFlutterBinding.ensureInitialized();

    // Unbehandelte UI-Fehler abfangen
    FlutterError.onError = (FlutterErrorDetails details) async {
      await Logger().fatal('Flutter Error: ${details.exception}', stack: details.stack);
    };

    // Unbehandelte native Fehler abfangen
    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      Logger().fatal('Platform Error: $error', stack: stack);
      return true; // handled (verhindert Absturz)
    };

    // Dienste registrieren
    await setupServiceLocator();

    // Config-Service initialisieren
    final configService = getIt<ConfigService>();
    await configService.init();

    // Logger initialisieren
    await Logger().init(minLevel: configService.logMinLevel, maxDays: configService.logMaxDays);

    // ProviderScope hinzufügen (Riverpod Einstiegspunkt)
    runApp(
      const ProviderScope(
        child: PriVaultApp(),
      ),
    );

  }, (error, stack) async {
    await Logger().fatal('Zone Error: $error', stack: stack);
  });
}
// @formatter:on

class PriVaultApp extends ConsumerWidget {
  const PriVaultApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {

    // SettingsNotifier beobachten
    final settings = ref.watch(settingsProvider);

    return MaterialApp(
      title: 'PriVault',
      debugShowCheckedModeBanner: false,

      // ThemeMode über SettingsNotifier-State holen
      themeMode: settings.themeMode,

      // Helles Design
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blueGrey
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(centerTitle: true),
      ),

      // Dunkles Design
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blueGrey,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(centerTitle: true),
      ),

      builder: (context, child) {
        return Stack(
          children: [
            child!,
            if (kDebugMode)
              Align(
                alignment: Alignment.bottomRight,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.white, width: 1),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Colors.white, size: 14),
                        SizedBox(width: 4),
                        Text(
                          'DEBUG MODE',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },

      initialRoute: '/',

      onGenerateRoute: (settings) {
        if (settings.name == '/detail') {
          final entryId = settings.arguments as int;
          return MaterialPageRoute(builder: (context) => DetailPage(entryId: entryId));
        }
        if (settings.name == '/edit') {
          final entryId = settings.arguments as int?;
          return MaterialPageRoute(builder: (context) => EditPage(entryId: entryId));
        }
        return null;
      },

      routes: {
        '/': (context) => const LoginPage(),
        '/main': (context) => const MainPage(),
        '/settings': (context) => const SettingsPage(),
      },
    );
  }
}
