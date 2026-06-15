import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

import 'package:flutter/foundation.dart';

import '../models/user_profile.dart';
import '../core/services/notification_service.dart';
import '../core/services/web_interop.dart';

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

final allUsersProvider = AsyncNotifierProvider<AllUsersNotifier, List<UserProfile>>(AllUsersNotifier.new);

class AllUsersNotifier extends AsyncNotifier<List<UserProfile>> {
  @override
  Future<List<UserProfile>> build() async {
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .orderBy('firstName')
        .get();
    return snap.docs.map(UserProfile.fromFirestore).toList();
  }

  /// Met à jour localement un utilisateur (appelé par le Bus Supabase)
  void updateUserLocal(UserProfile updatedUser) {
    if (state.value == null) return;
    
    final currentList = state.value!;
    final index = currentList.indexWhere((u) => u.uid == updatedUser.uid);
    
    if (index != -1) {
      final newList = [...currentList];
      newList[index] = updatedUser;
      state = AsyncValue.data(newList);
    } else {
      // S'il n'était pas dans la liste (ex: nouveau profil validé), on l'ajoute
      final newList = [...currentList, updatedUser];
      state = AsyncValue.data(newList);
    }
  }
}

class AuthNotifier extends StateNotifier<AsyncValue<void>> {
  AuthNotifier() : super(const AsyncValue.data(null));

  Future<void> signOut() async {
    try {
      if (!kIsWeb) {
        await GoogleSignIn().signOut();
      }
      await FirebaseAuth.instance.signOut();
      NotificationService.clearPlayerId();
    } catch (e) {
      debugPrint('Logout error: $e');
    }
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
    if (dept != null) {
      if (kIsWeb) {
        loginOneSignalWeb(uid, dept);
      } else {
        OneSignal.User.addTagWithKey('department', dept);
      }
    }
  }
}

final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AsyncValue<void>>(
        (_) => AuthNotifier());
