import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqlite3/open.dart';
import 'package:path/path.dart' as p;
import 'dart:ffi';

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

  if (!kIsWeb && Platform.isWindows) {
    final dllPath = p.join(Directory.current.path, 'sqlite3mc_x64.dll');
    if (File(dllPath).existsSync()) {
      open.overrideFor(OperatingSystem.windows, () => DynamicLibrary.open(dllPath));
      debugPrint('✅ SQLiteMC DLL registriert');
    }
  }

  await setupServiceLocator();
  
  final configService = getIt<ConfigService>();
  await configService.ensureDefaultPath(); 

  runApp(const PriVaultApp());
}

class PriVaultApp extends StatelessWidget {
  const PriVaultApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LoginViewModel(getIt(), getIt(), getIt(), getIt(), getIt())),
        ChangeNotifierProvider(create: (_) => MainViewModel(getIt(), getIt(), getIt())),
        ChangeNotifierProvider(create: (_) => EditViewModel(getIt(), getIt(), getIt(), getIt())),
        ChangeNotifierProvider(create: (_) => DetailViewModel(getIt(), getIt(), getIt(), getIt())),
        ChangeNotifierProvider(create: (_) => SettingsViewModel(getIt(), getIt(), getIt(), getIt(), getIt(), getIt())),
      ],
      child: MaterialApp(
        title: 'PriVault',
        debugShowCheckedModeBanner: false, 
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey), 
          useMaterial3: true,
          appBarTheme: const AppBarTheme(centerTitle: true),
        ),
        builder: (context, child) {
          return Stack(
            children: [
              child!,
              if (kDebugMode) 
                Align(
                  alignment: Alignment.bottomLeft,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.white, width: 1),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.warning_amber_rounded, color: Colors.white, size: 14),
                          SizedBox(width: 4),
                          Text('DEBUG MODE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
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
        routes: {
          '/': (context) => const LoginScreen(),
          '/main': (context) => const MainScreen(),
          '/settings': (context) => const SettingsScreen(),
        },
      ),
    );
  }
}
