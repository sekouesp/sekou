import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

import '../models/user_profile.dart';
import '../core/services/notification_service.dart';

final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

final currentUidProvider = Provider<String?>((ref) {
  return ref.watch(authStateProvider).value?.uid;
});

final currentProfileProvider = StreamProvider<UserProfile?>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(null);
  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .snapshots()
      .map((snap) => snap.exists ? UserProfile.fromFirestore(snap) : null);
});

final allUsersProvider = StreamProvider<List<UserProfile>>((ref) {
  return FirebaseFirestore.instance
      .collection('users')
      .orderBy('firstName')
      .snapshots()
      .map((snap) => snap.docs.map(UserProfile.fromFirestore).toList());
});

class AuthNotifier extends StateNotifier<AsyncValue<void>> {
  AuthNotifier() : super(const AsyncValue.data(null));

  Future<void> signOut() async {
    await GoogleSignIn().signOut();
    await FirebaseAuth.instance.signOut();
    NotificationService.clearPlayerId();
    state = const AsyncValue.data(null);
  }

  void savePlayerIdAfterLogin(String uid) {
    NotificationService.savePlayerId(uid);
    _tagDepartment(uid);
  }

  Future<void> _tagDepartment(String uid) async {
    final snap = await FirebaseFirestore.instance
        .collection('users').doc(uid).get();
    if (!snap.exists) return;
    final dept = snap.data()?['department'] as String?;
    if (dept != null) OneSignal.User.addTagWithKey('department', dept);
  }
}

final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AsyncValue<void>>(
        (_) => AuthNotifier());
