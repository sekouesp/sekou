import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/notification_service.dart';
import '../../core/theme/dept_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/config_provider.dart';
import '../../providers/notifications_provider.dart';
import '../../shared/widgets/dept_avatar.dart';
import '../../shared/widgets/mesh_gradient_background.dart';

class ShellScreen extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;
  const ShellScreen({super.key, required this.navigationShell});

  @override
  ConsumerState<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends ConsumerState<ShellScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final uid = ref.read(currentUidProvider);
      if (uid != null) {
        NotificationService.savePlayerId(uid);
      }
    });
  }

  void _navigate(int index) {
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentProfileProvider);
    final configAsync = ref.watch(appConfigProvider);
    final notifications = ref.watch(notificationsProvider);
    final unread = notifications.where((n) => !n.read).length;

    final profile = profileAsync.value;
    final theme = DeptTheme.of(profile?.department);
    final cs = ColorScheme.fromSeed(seedColor: theme.seed);

    return MeshGradientBackground(
      primaryColor: theme.primary,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            Image.network(
              'https://res.cloudinary.com/dkpqkwjgo/image/upload/v1779016358/esp_sekou_logo_nobg_yh1xt7.png',
              width: 34, height: 34,
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'SEKOU',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14,
                      letterSpacing: 0.5, fontStyle: FontStyle.italic),
                ),
                Text(
                  'POLYTECH DAKAR',
                  style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900,
                      letterSpacing: 2, color: theme.primary),
                ),
              ],
            ),
          ],
        ),
        actions: [
          // Notification bell
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () => context.push('/notifications'),
              ),
              if (unread > 0)
                Positioned(
                  right: 8, top: 8,
                  child: Container(
                    width: 16, height: 16,
                    decoration: BoxDecoration(
                      color: cs.error,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        unread > 9 ? '9+' : '$unread',
                        style: const TextStyle(color: Colors.white, fontSize: 9,
                            fontWeight: FontWeight.w900),
                      ),
                    ),
                  ).animate(onPlay: (c) => c.repeat(reverse: true))
                   .scale(begin: const Offset(0.9, 0.9), end: const Offset(1.1, 1.1),
                       duration: 800.ms),
                ),
            ],
          ),
          // More menu (drawer)
          Builder(
            builder: (ctx) => IconButton(
              icon: const Icon(Icons.menu_rounded),
              onPressed: () => Scaffold.of(ctx).openEndDrawer(),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      endDrawer: _buildDrawer(context, profile, configAsync.value, theme),
      body: widget.navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: widget.navigationShell.currentIndex,
        onDestinationSelected: _navigate,
        backgroundColor: Colors.white.withOpacity(0.8), // Glass effect
        surfaceTintColor: Colors.transparent,
        indicatorColor: Colors.transparent, // We use pill-style selectedIcon instead
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        animationDuration: const Duration(milliseconds: 400),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: _buildGlowIcon(Icons.home_rounded, theme.primary),
            label: 'Accueil',
          ),
          NavigationDestination(
            icon: const Icon(Icons.chat_bubble_outline_rounded),
            selectedIcon: _buildGlowIcon(Icons.chat_bubble_rounded, theme.primary),
            label: 'Messages',
          ),

          NavigationDestination(
            icon: const Icon(Icons.emoji_events_outlined),
            selectedIcon: _buildGlowIcon(Icons.emoji_events_rounded, theme.primary),
            label: 'Classement',
          ),
          NavigationDestination(
            icon: profile != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: DeptAvatar(user: profile, size: 26, borderRadius: 8),
                  )
                : const Icon(Icons.person_outline_rounded),
            selectedIcon: profile != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: DeptAvatar(user: profile, size: 26, borderRadius: 8),
                  )
                : const Icon(Icons.person_rounded),
            label: 'Profil',
          ),
        ],
      ).animate().slideY(begin: 1, duration: 600.ms, curve: Curves.easeOutExpo),
      ),
    );
  }

  Widget _buildGlowIcon(IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12), // rounded-xl like web
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.35),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: 20),
    );
  }

  Widget _buildDrawer(BuildContext context, dynamic profile, dynamic config, DeptTheme theme) {
    return Drawer(
      width: 300,
      child: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Image.network(
                    'https://res.cloudinary.com/dkpqkwjgo/image/upload/v1779016358/esp_sekou_logo_nobg_yh1xt7.png',
                    width: 44, height: 44,
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('SEKOU', style: TextStyle(fontWeight: FontWeight.w900,
                          fontSize: 16, fontStyle: FontStyle.italic)),
                      Text('Menu', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            const SizedBox(height: 8),
            if (config?.culturelEnabled == true || (profile?.isAdmin ?? false))
              _drawerItem(
                context, icon: Icons.music_note_rounded, label: 'Culturel',
                onTap: () { Navigator.pop(context); context.push('/culturel'); },
              ),
            if (config?.showValues == true)
              _drawerItem(
                context, icon: Icons.favorite_rounded, label: 'Valeurs',
                onTap: () { Navigator.pop(context); context.push('/values'); },
              ),
            if (config?.showOath == true)
              _drawerItem(
                context, icon: Icons.menu_book_rounded, label: 'Serment',
                onTap: () { Navigator.pop(context); context.push('/oath'); },
              ),
            if (profile?.isAdmin == true)
              _drawerItem(
                context, icon: Icons.admin_panel_settings_rounded,
                label: 'Gestion Bureau', color: theme.primary,
                onTap: () { Navigator.pop(context); context.push('/admin'); },
              ),
            const Spacer(),
            const Divider(height: 1),
            _drawerItem(
              context, icon: Icons.logout_rounded, label: 'Déconnexion',
              color: const Color(0xFFE11D48),
              onTap: () async {
                Navigator.pop(context);
                await ref.read(authNotifierProvider.notifier).signOut();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _drawerItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    final c = color ?? Colors.black87;
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: c.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: c, size: 20),
      ),
      title: Text(label, style: TextStyle(color: c, fontWeight: FontWeight.w700, fontSize: 14)),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      horizontalTitleGap: 12,
    );
  }
}
