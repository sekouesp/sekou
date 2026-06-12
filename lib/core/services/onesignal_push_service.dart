import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

/// Service pour envoyer des push via l'API REST OneSignal
/// Remplace complètement les Cloud Functions Firebase
class OneSignalPushService {
  static String get _appId => dotenv.env['ONESIGNAL_APP_ID'] ?? '';
  static String get _restApiKey => dotenv.env['ONESIGNAL_REST_API_KEY'] ?? '';
  static const _apiUrl   = 'https://onesignal.com/api/v1/notifications';

  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Authorization': 'Key $_restApiKey',
  };

  // PUSH À TOUS LES USERS (broadcast)
  // Appelé depuis admin_dashboard quand il publie une annonce
  static Future<void> sendBroadcastPush({
    required String title,
    required String body,
    String type = 'general',
  }) async {
    final typeEmoji = {
      'urgent': '🚨',
      'event':  '📅',
      'info':   'ℹ️',
      'general': '📢',
    };
    final emoji = typeEmoji[type] ?? '📢';

    final payload = {
      'app_id': _appId,
      'included_segments': ['All'], // Tous les abonnés
      'headings': {'fr': '$emoji $title', 'en': '$emoji $title'},
      'contents': {'fr': body, 'en': body},
      'data': {'route': '/notifications', 'type': type},
      'priority': type == 'urgent' ? 10 : 7,
      'android_accent_color': 'FF4F46E5',
      'small_icon': 'ic_stat_onesignal_default',
    };

    final response = await http.post(
      Uri.parse(_apiUrl),
      headers: _headers,
      body: jsonEncode(payload),
    );

    if (response.statusCode != 200) {
      throw Exception('OneSignal push failed: ${response.body}');
    }
  }

  // PUSH À UN SEUL USER (message privé)
  // Appelé depuis chat_detail quand un message est envoyé
  static Future<void> sendMessagePush({
    required String recipientUid,
    required String senderName,
    required String messageText,
    required String convId,
  }) async {
    final body = messageText.length > 80
        ? '${messageText.substring(0, 80)}…'
        : messageText;

    final payload = {
      'app_id': _appId,
      'target_channel': 'push',
      'filters': [
        {'field': 'tag', 'key': 'uid', 'relation': '=', 'value': recipientUid}
      ],
      'headings': {'fr': '💬 $senderName', 'en': '💬 $senderName'},
      'contents': {'fr': body, 'en': body},
      'data': {'route': '/chat/$convId', 'senderId': recipientUid},
      'web_url': 'https://sekouesp.github.io/sekou/#/chat/$convId',
      'priority': 9,
      'android_accent_color': 'FF4F46E5',
    };

    final response = await http.post(
      Uri.parse(_apiUrl),
      headers: _headers,
      body: jsonEncode(payload),
    );

    if (response.statusCode != 200) {
      throw Exception('OneSignal message push failed: ${response.body}');
    }
  }

  // PUSH LOCK/UNLOCK (compte suspendu)
  // Appelé depuis admin quand il lock/unlock un user
  static Future<void> sendLockPush({
    required String targetUid,
    required bool isLocked,
  }) async {
    final title   = isLocked ? '🔒 Compte verrouillé' : '🔓 Compte réactivé';
    final body    = isLocked
        ? 'Ton compte SEKOU a été suspendu. Contacte le bureau.'
        : 'Ton compte SEKOU a été réactivé. Bienvenue de retour !';
    final route   = isLocked ? '/locked' : '/home';

    final payload = {
      'app_id': _appId,
      'target_channel': 'push',
      'filters': [
        {'field': 'tag', 'key': 'uid', 'relation': '=', 'value': targetUid}
      ],
      'headings': {'fr': title, 'en': title},
      'contents': {'fr': body, 'en': body},
      'data': {'route': route},
      'web_url': 'https://sekouesp.github.io/sekou/#$route',
      'priority': 10,
      'android_accent_color': isLocked ? 'FFE11D48' : 'FF059669',
    };

    await http.post(
      Uri.parse(_apiUrl),
      headers: _headers,
      body: jsonEncode(payload),
    );
  }

  // PUSH SEGMENTÉ PAR DÉPARTEMENT
  // Bonus OneSignal impossible avec Firebase Functions gratuit
  static Future<void> sendDepartmentPush({
    required String department,
    required String title,
    required String body,
  }) async {
    final payload = {
      'app_id': _appId,
      // Filtre par tag département
      'filters': [
        {'field': 'tag', 'key': 'department', 'relation': '=', 'value': department},
      ],
      'headings': {'fr': title, 'en': title},
      'contents': {'fr': body, 'en': body},
      'data': {'route': '/home/notifications'},
      'web_url': 'https://sekouesp.github.io/sekou/#/home/notifications',
      'priority': 7,
      'android_accent_color': 'FF4F46E5',
    };

    await http.post(
      Uri.parse(_apiUrl),
      headers: _headers,
      body: jsonEncode(payload),
    );
  }
}
