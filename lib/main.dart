import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'core/router/app_router.dart';
import 'core/services/notification_service.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'core/utils/timeago_fr_short.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Firebase init
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  // Activer le cache hors-ligne (Offline Persistence) pour TOUTES les plateformes y compris le WEB
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  // OneSignal init
  await NotificationService.initialize();

  // Register custom French locale for timeago (short format: "1 h", "5 mn")
  registerTimeagoFrShort();

  final prefs = await SharedPreferences.getInstance();

  runApp(ProviderScope(
    overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
    child: const EspSekouApp(),
  ));
}

final sharedPrefsProvider =
    Provider<SharedPreferences>((_) => throw UnimplementedError());

final rootScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

class EspSekouApp extends ConsumerWidget {
  const EspSekouApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeProvider);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: themeMode == ThemeMode.dark
          ? const SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: Brightness.light,
              statusBarBrightness: Brightness.dark,
            )
          : const SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: Brightness.dark,
              statusBarBrightness: Brightness.light,
            ),
      child: MaterialApp.router(
        title: 'SEKOU',
        debugShowCheckedModeBanner: false,
        scaffoldMessengerKey: rootScaffoldMessengerKey,
        routerConfig: router,
        themeMode: themeMode,
        theme: lightTheme,
        darkTheme: darkTheme,
        builder: (context, child) => MediaQuery.withClampedTextScaling(
          minScaleFactor: 1.0,
          maxScaleFactor: 1.3,
          child: child!,
        ),
      ),
    );
  }
}
