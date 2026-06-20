import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'web_interop.dart';

class NotificationService {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  static String get _oneSignalAppId => dotenv.env['ONESIGNAL_APP_ID'] ?? '';

  static Future<void> initialize() async {
    if (kIsWeb) {
      debugPrint('Initialisation de OneSignal Web via JS Interop');
      initOneSignalWeb(_oneSignalAppId);
      return;
    }

    // Init OneSignal
    OneSignal.initialize(_oneSignalAppId);

    // Demande la permission push (iOS + Android
    await OneSignal.Notifications.requestPermission(true);

    // Handler quand notification reçue en foreground
    OneSignal.Notifications.addForegroundWillDisplayListener((event) {
      // Affiche la notification en foreground
      event.notification.display();
    });

    // Handler quand user tape sur la notification
    OneSignal.Notifications.addClickListener((event) {
      final route = event.notification.additionalData?['route'] as String?;
      if (route != null) {
        _handleRoute(route);
      }
    });
  }

  /// Sauvegarde le OneSignal Player ID dans Firestore
  /// À appeler après connexion de l'utilisateur
  static Future<void> savePlayerId(String uid) async {
    if (kIsWeb) {
      // Sur le Web, la méthode login() est appelée via JS. 
      // Le department sera taggué juste après via auth_provider.dart
      loginOneSignalWeb(uid, null);
      return;
    }

    // Associe l'External ID OneSignal avec l'UID Firebase
    OneSignal.login(uid);
    // Tague l'utilisateur pour le routage de messages
    OneSignal.User.addTagWithKey('uid', uid);

    try {
      final deviceState = await OneSignal.User.getOnesignalId();
      if (deviceState != null) {
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'oneSignalPlayerId': deviceState,
          'oneSignalUpdatedAt': DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {
      debugPrint('Erreur sauvegarde OneSignal ID: $e');
    }
  }

  /// Supprime le tag quand déconnexion
  static Future<void> clearPlayerId() async {
    if (kIsWeb) {
      logoutOneSignalWeb();
      return;
    }
    OneSignal.logout();
    OneSignal.User.removeTag('uid');
  }

  // Navigation interne après tap sur notif
  static void _handleRoute(String route) {
    if (navigatorKey.currentContext != null) {
      GoRouter.of(navigatorKey.currentContext!).push(route);
    }
  }
}
