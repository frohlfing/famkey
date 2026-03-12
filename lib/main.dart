import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart' as prov;
import 'package:privault/core/service_locator.dart';
import 'package:privault/services/config_service.dart';
import 'package:privault/viewmodels/login_view_model.dart';
import 'package:privault/viewmodels/main_view_model.dart';
import 'package:privault/viewmodels/edit_view_model.dart';
import 'package:privault/viewmodels/detail_view_model.dart';
import 'package:privault/viewmodels/settings_view_model.dart';
import 'package:privault/views/login_screen.dart';
import 'package:privault/views/main_screen.dart';
import 'package:privault/views/edit_screen.dart';
import 'package:privault/views/detail_screen.dart';
import 'package:privault/views/settings_screen.dart';

void main() async {
    WidgetsFlutterBinding.ensureInitialized();

    // ------------------------------------------------------------------------
    // Error Handling
    // ------------------------------------------------------------------------

    // unhandled Flutter framework errors
    FlutterError.onError = (FlutterErrorDetails details) {
        debugPrint('❌ [UNHANDLED-FLUTTER] ${details.exceptionAsString()}');
        if (details.stack != null) {
            debugPrintStack(stackTrace: details.stack);
        }
    };

    // Unhandled async errors (z.B. Futures, Isolates, PlatformDispatcher)
    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
        debugPrint('❌ [UNHANDLED-ASYNC] $error');
        debugPrintStack(stackTrace: stack);
        return true; // handled
    };

    // ------------------------------------------------------------------------

    await setupServiceLocator();

    final configService = getIt<ConfigService>();
    await configService.ensureDefaultPath();

    //runApp(const PriVaultApp());

    runApp(
      ProviderScope(
        child: PriVaultApp(),
      ),
    );

}

class PriVaultApp extends StatelessWidget {
    const PriVaultApp({super.key});

    @override
    Widget build(BuildContext context) {
        return prov.MultiProvider(
            providers: [
              prov.ChangeNotifierProvider(create: (_) => LoginViewModel(getIt(), getIt(), getIt(), getIt(), getIt(), getIt())),
              prov.ChangeNotifierProvider(create: (_) => MainViewModel(getIt(), getIt(), getIt(), getIt(), getIt())),
              prov.ChangeNotifierProvider(create: (_) => EditViewModel(getIt(), getIt(), getIt(), getIt())),
              prov.ChangeNotifierProvider(create: (_) => DetailViewModel(getIt(), getIt(), getIt(), getIt())),
              prov.ChangeNotifierProvider(create: (_) => SettingsViewModel(getIt(), getIt(), getIt(), getIt(), getIt(), getIt())),
            ],
            child: prov.Consumer<SettingsViewModel>(
                builder: (context, viewModel, _) {
                    return MaterialApp(
                        title: 'PriVault',
                        debugShowCheckedModeBanner: false,
                        themeMode: viewModel.themeMode,

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
                                return MaterialPageRoute(builder: (context) => DetailScreen(entryId: entryId));
                            }
                            if (settings.name == '/edit') {
                                final entryId = settings.arguments as int?;
                                return MaterialPageRoute(builder: (context) => EditScreen(entryId: entryId));
                            }
                            return null;
                        },
                        routes: {'/':(context) => const LoginScreen(), '/main':(context) => const MainScreen(), '/settings':(context) => const SettingsScreen()},
                    );
                },
            ),
        );
    }
}
