import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../models/user_profile.dart';
import '../../core/services/notification_service.dart';
import '../../providers/auth_provider.dart';
import '../../models/idea.dart';
import '../../features/ideas/ideas_provider.dart';
import '../../main.dart';

final realtimeBusProvider = Provider<RealtimeBusService>((ref) {
  final service = RealtimeBusService(ref);
  service.initialize();
  ref.onDispose(() => service.dispose());
  return service;
});

/// UIDs actuellement en ligne (présence Supabase).
final onlineUidsProvider = StateProvider<Set<String>>((_) => {});

/// Clés `'$convId|$uid'` des utilisateurs en train d'écrire.
final typingProvider = StateProvider<Set<String>>((_) => {});

class RealtimeBusService {
  final Ref _ref;
  RealtimeChannel? _channel;

  /// Timers d'expiration des indicateurs « en train d'écrire ».
  final Map<String, Timer> _typingTimers = {};

  RealtimeBusService(this._ref);

  void initialize() {
    if (_channel != null) return;
    // On se connecte au canal 'sekou_events' de Supabase
    _channel = Supabase.instance.client.channel('sekou_events');

    _channel!
      .onBroadcast(event: 'user_updated', callback: _onUserUpdated)
      .onBroadcast(event: 'idea_updated', callback: _onIdeaUpdated)
      .onBroadcast(event: 'new_message', callback: _onNewMessage)
      .onBroadcast(event: 'typing', callback: _onTyping)
      .onPresenceSync((_) => _recomputeOnline())
      .onPresenceJoin((_) => _recomputeOnline())
      .onPresenceLeave((_) => _recomputeOnline())
      .subscribe((status, [error]) {
        if (status == RealtimeSubscribeStatus.subscribed) {
          print('✅ [RealtimeBus] Connecté avec succès à Supabase !');
          _trackPresence();
        }
      });
  }

  // ── Présence ────────────────────────────────────────────────
  /// S'annonce comme « en ligne » sur le canal de présence.
  Future<void> _trackPresence() async {
    final uid = _ref.read(currentUidProvider);
    if (uid == null || _channel == null) return;
    try {
      await _channel!.track({'uid': uid});
    } catch (_) {}
  }

  /// Recalcule l'ensemble des UIDs en ligne depuis l'état de présence.
  void _recomputeOnline() {
    if (_channel == null) return;
    final uids = <String>{};
    for (final state in _channel!.presenceState()) {
      for (final presence in state.presences) {
        final uid = presence.payload['uid'];
        if (uid is String) uids.add(uid);
      }
    }
    _ref.read(onlineUidsProvider.notifier).state = uids;
  }

  /// À appeler quand l'app revient au premier plan.
  Future<void> setOnline() => _trackPresence();

  /// À appeler quand l'app passe en arrière-plan.
  Future<void> setOffline() async {
    if (_channel == null) return;
    try {
      await _channel!.untrack();
    } catch (_) {}
  }

  // ── Typing ──────────────────────────────────────────────────
  Future<void> broadcastTyping(String convId, String fromUid, bool isTyping) async {
    if (_channel == null) return;
    try {
      await _channel!.sendBroadcastMessage(
        event: 'typing',
        payload: {'convId': convId, 'uid': fromUid, 'typing': isTyping},
      );
    } catch (_) {}
  }

  void _onTyping(Map<String, dynamic> payload) {
    final convId = payload['convId'] as String?;
    final uid = payload['uid'] as String?;
    final isTyping = payload['typing'] as bool? ?? false;
    if (convId == null || uid == null) return;
    if (uid == _ref.read(currentUidProvider)) return; // ignore mon propre typing

    final key = '$convId|$uid';
    _typingTimers[key]?.cancel();
    final current = {..._ref.read(typingProvider)};
    if (isTyping) {
      current.add(key);
      // Filet de sécurité : si le « stop » se perd, on expire après 4 s.
      _typingTimers[key] = Timer(const Duration(seconds: 4), () {
        final s = {..._ref.read(typingProvider)}..remove(key);
        _ref.read(typingProvider.notifier).state = s;
        _typingTimers.remove(key);
      });
    } else {
      current.remove(key);
      _typingTimers.remove(key);
    }
    _ref.read(typingProvider.notifier).state = current;
  }

  void _onUserUpdated(Map<String, dynamic> payload) async {
    print(' [RealtimeBus] Signal reçu : $payload');
    final uid = payload['uid'] as String?;
    if (uid == null) return;

    try {
      // Le signal nous dit "Ce user a changé". 
      // On va faire UNE SEULE lecture très ciblée sur Firebase pour le récupérer à jour.
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists) {
        final updatedUser = UserProfile.fromFirestore(doc);
        // On l'injecte silencieusement dans le Dashboard local !
        _ref.read(allUsersProvider.notifier).updateUserLocal(updatedUser);
        print(' [RealtimeBus] Dashboard mis à jour localement pour $uid');
      } else {
        // Le document n'existe plus (ex: utilisateur refusé/supprimé)
        _ref.read(allUsersProvider.notifier).removeUserLocal(uid);
        print(' [RealtimeBus] Utilisateur retiré localement : $uid');
      }
    } catch (e) {
      print(' [RealtimeBus] Erreur de maj locale : $e');
    }
  }

  void _onIdeaUpdated(Map<String, dynamic> payload) async {
    print(' [RealtimeBus] Signal reçu (Idée) : $payload');
    final ideaId = payload['ideaId'] as String?;
    if (ideaId == null) return;

    try {
      final doc = await FirebaseFirestore.instance.collection('ideas').doc(ideaId).get();
      if (doc.exists) {
        final updatedIdea = Idea.fromFirestore(doc);
        _ref.read(ideasProvider.notifier).updateIdeaLocal(updatedIdea);
      }
    } catch (e) {
      print(' [RealtimeBus] Erreur de maj locale idée : $e');
    }
  }

  void _onNewMessage(Map<String, dynamic> payload) {
    final recipientUid = payload['recipientUid'] as String?;
    final senderName = payload['senderName'] as String?;
    final text = payload['text'] as String?;
    final convId = payload['convId'] as String?;
    
    final myUid = _ref.read(currentUidProvider);
    if (myUid != null && recipientUid == myUid && senderName != null) {
      // Vérifier si on n'est pas DÉJÀ dans la conversation
      final context = NotificationService.navigatorKey.currentContext;
      if (context != null) {
        final uri = GoRouterState.of(context).uri.toString();
        if (convId != null && uri.contains('/chat/$convId')) {
          // L'utilisateur est déjà dans le chat, ne pas afficher le toast.
          return;
        }
      }
      _showToast(senderName, text);
    }
  }

  void _showToast(String senderName, String? text) {
    rootScaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.mark_chat_unread_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    senderName,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  Text(
                    text ?? 'Nouveau message',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF1E293B), // Dark blue/slate
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  /// Appeler cette fonction pour prévenir les autres téléphones qu'un user a changé
  Future<void> broadcastUserUpdate(String uid) async {
    if (_channel == null) return;
    try {
      await _channel!.sendBroadcastMessage(
        event: 'user_updated',
        payload: {'uid': uid},
      );
      print(' [RealtimeBus] Signal envoyé pour le user : $uid');
    } catch (e) {
      print(' [RealtimeBus] Impossible d\'envoyer le signal : $e');
    }
  }

  Future<void> broadcastIdeaUpdate(String ideaId) async {
    if (_channel == null) return;
    try {
      await _channel!.sendBroadcastMessage(
        event: 'idea_updated',
        payload: {'ideaId': ideaId},
      );
    } catch (e) {
      print('❌ [RealtimeBus] Impossible d\'envoyer le signal idée : $e');
    }
  }

  Future<void> broadcastNewMessage(String recipientUid, String senderName, String text, String convId) async {
    if (_channel == null) return;
    try {
      await _channel!.sendBroadcastMessage(
        event: 'new_message',
        payload: {
          'recipientUid': recipientUid,
          'senderName': senderName,
          'text': text,
          'convId': convId,
        },
      );
    } catch (e) {
      print('❌ [RealtimeBus] Impossible d\'envoyer le signal nouveau message : $e');
    }
  }

  void dispose() {
    for (final t in _typingTimers.values) {
      t.cancel();
    }
    _typingTimers.clear();
    _channel?.unsubscribe();
  }
}
