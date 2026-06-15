import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'core/router/app_router.dart';
import 'core/services/notification_service.dart';
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

  // OneSignal init
  await NotificationService.initialize();

  final prefs = await SharedPreferences.getInstance();

  runApp(ProviderScope(
    overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
    child: const EspSekouApp(),
  ));
}

final sharedPrefsProvider =
    Provider<SharedPreferences>((_) => throw UnimplementedError());

class EspSekouApp extends ConsumerWidget {
  const EspSekouApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark, // For Android
        statusBarBrightness: Brightness.light, // For iOS
      ),
      child: MaterialApp.router(
        title: 'SEKOU',
        debugShowCheckedModeBanner: false,
        routerConfig: router,
        theme: ThemeData(
          useMaterial3: true,
          fontFamily: 'Inter',
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4F46E5)),
          visualDensity: VisualDensity.adaptivePlatformDensity,
          appBarTheme: const AppBarTheme(
            systemOverlayStyle: SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: Brightness.dark,
              statusBarBrightness: Brightness.light,
            ),
          ),
          pageTransitionsTheme: kIsWeb
              ? null
              : PageTransitionsTheme(
                  builders: <TargetPlatform, PageTransitionsBuilder>{
                    TargetPlatform.android:
                        const PredictiveBackPageTransitionsBuilder(),
                    TargetPlatform.iOS: const CupertinoPageTransitionsBuilder(),
                  },
                ),

        ),
      ),
    );
  }
}
