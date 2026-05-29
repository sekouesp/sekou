import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/notification_item.dart';

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

// Broadcasts stream for real-time listening
final broadcastsStreamProvider = StreamProvider.autoDispose((ref) {
  if (!_firebaseSupported) return const Stream.empty();
  final now = Timestamp.now();
  return FirebaseFirestore.instance
      .collection('broadcasts')
      .where('createdAt', isGreaterThan: now)
      .orderBy('createdAt', descending: true)
      .snapshots();
});
