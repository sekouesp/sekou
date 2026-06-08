import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/notification_item.dart';
import 'auth_provider.dart';

bool get _firebaseSupported =>
    kIsWeb || Platform.isAndroid || Platform.isIOS || Platform.isMacOS;

class NotificationsNotifier extends StateNotifier<List<NotificationItem>> {
  NotificationsNotifier() : super([]);

  void addNotification(NotificationItem item) {
    if (state.any((n) => n.id == item.id)) return;
    state = [item, ...state];
  }

  void markRead(String id) {
    state = state.map((n) => n.id == id ? (n..read = true) : n).toList();
  }

  void markAllRead() {
    state = state.map((n) => n..read = true).toList();
  }

  void remove(String id) {
    state = state.where((n) => n.id != id).toList();
  }

  void markTypeRead(NotificationType type) {
    state = state.map((n) => n.type == type ? (n..read = true) : n).toList();
  }

  int get unreadCount => state.where((n) => !n.read).length;
}

final notificationsProvider =
    StateNotifierProvider<NotificationsNotifier, List<NotificationItem>>(
        (_) => NotificationsNotifier());

// Stream provider pour compter les annonces non lues
final unreadBroadcastsCountProvider = StreamProvider.autoDispose<int>((ref) {
  if (!_firebaseSupported) return Stream.value(0);
  
  final profileAsync = ref.watch(currentProfileProvider);
  final profile = profileAsync.value;
  if (profile == null) return Stream.value(0);

  Query query = FirebaseFirestore.instance.collection('broadcasts');

  // Si on a une date de dernière lecture, on compte les plus récents
  if (profile.lastReadAnnouncementsAt != null) {
    query = query.where('createdAt', isGreaterThan: profile.lastReadAnnouncementsAt);
  } else {
    // Si jamais lu, on compte tout (limité aux 10 derniers jours ou juste un max)
    final tenDaysAgo = Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 10)));
    query = query.where('createdAt', isGreaterThan: tenDaysAgo);
  }

  return query.snapshots().map((snapshot) {
    // Filtrage par département
    final dept = profile.department;
    final validDocs = snapshot.docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final filterDept = data['filterDept'] as String?;
      return filterDept == null || filterDept.isEmpty || filterDept == dept;
    });
    return validDocs.length;
  });
});

// Stream provider pour compter les messages non lus
final unreadMessagesCountProvider = StreamProvider.autoDispose<int>((ref) {
  if (!_firebaseSupported) return Stream.value(0);

  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(0);

  return FirebaseFirestore.instance
      .collection('conversations')
      .where('participantIds', arrayContains: uid)
      .snapshots()
      .map((snapshot) {
    int totalUnread = 0;
    for (var doc in snapshot.docs) {
      final data = doc.data();
      final unreadMap = data['unreadCounts'] as Map<String, dynamic>? ?? {};
      final unreadForMe = (unreadMap[uid] as num?)?.toInt() ?? 0;
      totalUnread += unreadForMe;
    }
    return totalUnread;
  });
});
