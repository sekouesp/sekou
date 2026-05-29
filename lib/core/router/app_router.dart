import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/admin/admin_dashboard_screen.dart';
import '../../features/auth/auth_screen.dart';
import '../../features/auth/pending_approval_screen.dart';
import '../../features/chat/chat_detail_screen.dart';
import '../../features/chat/conversations_screen.dart';
import '../../features/culturel/culturel_screen.dart';
import '../../features/culturel/immersive_player_screen.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/landing/landing_screen.dart';
import '../../features/notifications/notifications_screen.dart';
import '../../features/oath/oath_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/public_profile/public_profile_screen.dart';
import '../../features/ranking/ranking_screen.dart';
import '../../features/shell/shell_screen.dart';
import '../../features/values/values_screen.dart';
import '../../providers/auth_provider.dart';
import '../../shared/widgets/loading_indicator.dart';
import '../../shared/widgets/locked_screen.dart';
import '../../main.dart';
import '../services/notification_service.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final notifier = _RouterNotifier(ref);
  return GoRouter(
    navigatorKey: NotificationService.navigatorKey,
    initialLocation: '/splash',
    refreshListenable: notifier,
    redirect: notifier.redirect,
    routes: [
      GoRoute(
        path: '/splash',
        builder: (_, __) => const _SplashScreen(),
      ),
      GoRoute(
        path: '/landing',
        pageBuilder: (_, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const LandingScreen(),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
        ),
      ),
      GoRoute(
        path: '/auth',
        pageBuilder: (_, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const AuthScreen(),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
        ),
      ),
      GoRoute(
        path: '/locked',
        builder: (_, __) => const LockedScreen(),
      ),
      GoRoute(
        path: '/pending_approval',
        builder: (_, __) => const PendingApprovalScreen(),
      ),
      GoRoute(
        path: '/profile/create',
        builder: (_, __) => const ProfileScreen(mode: ProfileMode.create),
      ),
      GoRoute(
        path: '/values',
        pageBuilder: (_, state) => _slideRoute(state, const ValuesScreen()),
      ),
      GoRoute(
        path: '/oath',
        pageBuilder: (_, state) => _slideRoute(state, const OathScreen()),
      ),
      GoRoute(
        path: '/culturel',
        pageBuilder: (_, state) => _slideRoute(state, const CulturelScreen()),
        routes: [
          GoRoute(
            path: 'player',
            builder: (_, state) {
              final extra = state.extra as Map<String, dynamic>?;
              return ImmersivePlayerScreen(soundData: extra ?? {});
            },
          ),
        ],
      ),
      GoRoute(
        path: '/admin',
        pageBuilder: (_, state) => _slideRoute(state, const AdminDashboardScreen()),
      ),
      GoRoute(
        path: '/user/:uid',
        pageBuilder: (_, state) => _slideRoute(
          state,
          PublicProfileScreen(uid: state.pathParameters['uid']!),
        ),
      ),
      GoRoute(
        path: '/notifications',
        pageBuilder: (_, state) => _slideRoute(state, const NotificationsScreen()),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            ShellScreen(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/home', builder: (_, __) => const DashboardScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/chat',
              builder: (_, __) => const ConversationsScreen(),
              routes: [
                GoRoute(
                  path: ':convId',
                  parentNavigatorKey: NotificationService.navigatorKey, // Fait passer le cht en plein ecran 
                  builder: (_, state) => ChatDetailScreen(
                    convId: state.pathParameters['convId']!,
                    extra: state.extra as Map<String, dynamic>? ?? {},
                  ),
                ),
              ],
            ),
          ]),

          StatefulShellBranch(routes: [
            GoRoute(path: '/ranking', builder: (_, __) => const RankingScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen(mode: ProfileMode.edit)),
          ]),
        ],
      ),
    ],
  );
});

CustomTransitionPage<void> _slideRoute(GoRouterState state, Widget child) {
  return CustomTransitionPage(
    key: state.pageKey,
    child: child,
    transitionsBuilder: (_, anim, __, c) => SlideTransition(
      position: Tween(begin: const Offset(1, 0), end: Offset.zero)
          .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
      child: c,
    ),
  );
}

class _RouterNotifier extends ChangeNotifier {
  final Ref _ref;
  _RouterNotifier(this._ref) {
    _ref.listen(authStateProvider, (_, __) => notifyListeners());
    _ref.listen(currentProfileProvider, (_, __) => notifyListeners());
  }

  String? redirect(BuildContext context, GoRouterState state) {
    final authAsync = _ref.read(authStateProvider);
    final profileAsync = _ref.read(currentProfileProvider);
    final path = state.uri.path;

    if (authAsync.isLoading || profileAsync.isLoading) return null;

    final user = authAsync.value;
    final profile = profileAsync.value;

    if (user == null) {
      if (path == '/landing' || path == '/auth' || path == '/splash') return null;
      return '/auth';
    }
    if (profile == null && path != '/profile/create' && path != '/splash' && path != '/landing') {
      return '/profile/create';
    }

    if (profile != null && !profile.isApproved && path != '/pending_approval' && path != '/landing') {
      return '/pending_approval';
    }

    if (profile != null && profile.isLocked && path != '/locked' && path != '/landing') {
      return '/locked';
    }

    if (profile != null && profile.isApproved && !profile.isLocked &&
        (path == '/auth' || path == '/splash' || path == '/' || path == '/pending_approval')) {
      return '/home';
    }

    return null;
  }
}

class _SplashScreen extends ConsumerWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.read(sharedPrefsProvider);
    final hasSeenLanding = prefs.getBool('has_seen_landing') ?? false;
    final auth = ref.watch(authStateProvider);

    // Le landing s'affiche UNE SEULE FOIS au tout premier lancement
    if (!hasSeenLanding) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        prefs.setBool('has_seen_landing', true);
        context.go('/landing');
      });
      return const _SplashView();
    }

    return auth.when(
      loading: () => const _SplashView(),
      error: (_, __) => const _SplashView(),
      data: (user) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (user == null) {
            context.go('/auth');
          } else {
            context.go('/home');
          }
        });
        return const _SplashView();
      },
    );
  }
}

class _SplashView extends StatelessWidget {
  const _SplashView();
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFFF5F7FF),
      body: Center(child: AppLoadingIndicator()),
    );
  }
}
