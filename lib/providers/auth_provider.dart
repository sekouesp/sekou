import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

import 'package:flutter/foundation.dart';

import '../models/user_profile.dart';
import '../core/services/notification_service.dart';
import '../core/services/web_interop.dart';
import '../main.dart';

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
  static const _lastRefreshKey = 'allUsers_lastServerRefresh';
  static const _refreshIntervalHours = 6;

  @override
  Future<List<UserProfile>> build() async {
    // Stratégie "Cache-First" :
    // 1. On essaie d'abord de lire depuis le cache local (0 lectures Firebase)
    // 2. Si le cache est vide (premier lancement), on va chercher sur le serveur
    // 3. Entre les lancements, le Bus Supabase met à jour les profils individuellement
    // 4. Le cache serveur est rafraîchi silencieusement toutes les 6h max
    try {
      final cachedSnap = await FirebaseFirestore.instance
          .collection('users')
          .orderBy('firstName')
          .get(const GetOptions(source: Source.cache));
      if (cachedSnap.docs.isNotEmpty) {
        // Cache trouvé ! 0 lecture Firebase 🎉
        // Rafraîchir en arrière-plan seulement si ça fait plus de 6h
        _refreshIfStale();
        return cachedSnap.docs.map(UserProfile.fromFirestore).toList();
      }
    } catch (_) {
      // Pas de cache disponible (premier lancement), on continue vers le serveur
    }

    // Premier lancement ou cache vide : on va chercher sur Firebase (154 lectures)
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .orderBy('firstName')
        .get(const GetOptions(source: Source.server));
    _saveRefreshTimestamp();
    return snap.docs.map(UserProfile.fromFirestore).toList();
  }

  /// Ne rafraîchit le cache serveur que si le dernier refresh date de plus de 6h
  Future<void> _refreshIfStale() async {
    try {
      final prefs = ref.read(sharedPrefsProvider);
      final lastRefresh = prefs.getInt(_lastRefreshKey) ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      final hoursSinceRefresh = (now - lastRefresh) / (1000 * 60 * 60);

      if (hoursSinceRefresh < _refreshIntervalHours) return; // Pas encore le moment

      await FirebaseFirestore.instance
          .collection('users')
          .orderBy('firstName')
          .get(const GetOptions(source: Source.server));
      _saveRefreshTimestamp();
    } catch (_) {
      // Pas grave si ça échoue, on a le cache et le Bus Supabase
    }
  }

  void _saveRefreshTimestamp() {
    try {
      final prefs = ref.read(sharedPrefsProvider);
      prefs.setInt(_lastRefreshKey, DateTime.now().millisecondsSinceEpoch);
    } catch (_) {}
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

  /// Retire localement un utilisateur (ex: rejeté/supprimé)
  void removeUserLocal(String uid) {
    if (state.value == null) return;
    final newList = state.value!.where((u) => u.uid != uid).toList();
    state = AsyncValue.data(newList);
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
