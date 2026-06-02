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

const double _kDesktopBreakpoint = 800;

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
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= _kDesktopBreakpoint;

    return MeshGradientBackground(
      primaryColor: theme.primary,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: isDesktop ? null : _buildMobileAppBar(context, profile, theme, cs, unread),
        endDrawer: isDesktop ? null : _buildMobileDrawer(context, profile, configAsync.value, theme),
        bottomNavigationBar: isDesktop ? null : _buildMobileBottomNav(theme, profile),
        body: Row(
          children: [
            if (isDesktop)
              _buildDesktopSidebar(context, profile, configAsync.value, theme, unread),
            Expanded(
              child: Column(
                children: [
                  if (isDesktop)
                    _buildDesktopHeader(context, profile, theme, unread),
                  Expanded(
                    child: widget.navigationShell,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // DESKTOP LAYOUT (Sidebar + Header)
  // ---------------------------------------------------------------------------
  Widget _buildDesktopSidebar(BuildContext context, dynamic profile, dynamic config, DeptTheme theme, int unread) {
    final int currentIndex = widget.navigationShell.currentIndex;
    
    return Container(
      width: 260,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.85),
        border: Border(right: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Column(
        children: [
          // Header / Logo
          Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10)),
                    ],
                  ),
                  child: Image.network(
                    'https://res.cloudinary.com/dkpqkwjgo/image/upload/v1779016358/esp_sekou_logo_nobg_yh1xt7.png',
                    width: 60, height: 60,
                  ),
                ).animate(onPlay: (c) => c.repeat(reverse: true)).scaleXY(begin: 0.98, end: 1.02, duration: 3.seconds),
                const SizedBox(height: 16),
                const Text('SEKOU', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic, letterSpacing: -0.5)),
              ],
            ),
          ),
          
          // Navigation Items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _desktopNavItem(icon: Icons.home_rounded, label: 'Accueil', isActive: currentIndex == 0, onTap: () => _navigate(0), theme: theme),
                if (config?.disableChat != true)
                  _desktopNavItem(icon: Icons.chat_bubble_rounded, label: 'Conversations', isActive: currentIndex == 1, onTap: () => _navigate(1), theme: theme),
                if (config?.rankingEnabled != false)
                  _desktopNavItem(icon: Icons.emoji_events_rounded, label: 'Classement', isActive: currentIndex == 2, onTap: () => _navigate(2), theme: theme),
                if (config?.culturelEnabled == true || (profile?.isAdmin ?? false))
                  _desktopNavItem(icon: Icons.music_note_rounded, label: 'Culturel', isActive: false, onTap: () => context.push('/culturel'), theme: theme),
                if (config?.showValues == true)
                  _desktopNavItem(icon: Icons.favorite_rounded, label: 'Valeurs', isActive: false, onTap: () => context.push('/values'), theme: theme),
                if (config?.showOath == true)
                  _desktopNavItem(icon: Icons.menu_book_rounded, label: 'Serment', isActive: false, onTap: () => context.push('/oath'), theme: theme),
                if (profile?.isAdmin == true)
                  _desktopNavItem(icon: Icons.admin_panel_settings_rounded, label: 'Gestion Bureau', isActive: false, onTap: () => context.push('/admin'), theme: theme),
                _desktopNavItem(icon: Icons.person_rounded, label: 'Mon Profil', isActive: currentIndex == 3, onTap: () => _navigate(3), theme: theme),
              ],
            ),
          ),
          
          // User Profile Card & Logout
          if (profile != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
                color: Colors.grey.shade50,
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      DeptAvatar(user: profile, size: 40, borderRadius: 12),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${profile.firstName} ${profile.lastName}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                            Text(profile.department.isNotEmpty ? profile.department : 'Étudiant', style: TextStyle(color: Colors.grey.shade500, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1), maxLines: 1, overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () async {
                      await ref.read(authNotifierProvider.notifier).signOut();
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF1F2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.logout_rounded, size: 16, color: Color(0xFFE11D48)),
                          SizedBox(width: 8),
                          Text('Déconnexion', style: TextStyle(color: Color(0xFFE11D48), fontWeight: FontWeight.w700, fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _desktopNavItem({required IconData icon, required String label, required bool isActive, required VoidCallback onTap, required DeptTheme theme, int badge = 0}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? theme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isActive ? [BoxShadow(color: theme.primary.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))] : null,
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: isActive ? Colors.white : Colors.grey.shade400),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: isActive ? Colors.white : Colors.grey.shade600,
                  fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
            if (badge > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: const Color(0xFFE11D48), borderRadius: BorderRadius.circular(10)),
                child: Text(badge > 9 ? '9+' : '$badge', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopHeader(BuildContext context, dynamic profile, DeptTheme theme, int unread) {
    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.4),
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.5))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          IconButton(
            onPressed: () => context.push('/home/notifications'),
            icon: Stack(
              children: [
                Icon(Icons.notifications_outlined, color: Colors.grey.shade700),
                if (unread > 0)
                  Positioned(
                    right: 0, top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(color: Color(0xFFE11D48), shape: BoxShape.circle),
                      constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                      child: Text(unread > 9 ? '9+' : '$unread', style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900), textAlign: TextAlign.center),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          if (profile != null) ...[
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${profile.firstName} ${profile.lastName}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, fontStyle: FontStyle.italic)),
                Text('POLYTECHNICIEN', style: TextStyle(color: theme.primary, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 2)),
              ],
            ),
            const SizedBox(width: 12),
            DeptAvatar(user: profile, size: 40, borderRadius: 12),
          ]
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // MOBILE LAYOUT
  // ---------------------------------------------------------------------------
  PreferredSizeWidget _buildMobileAppBar(BuildContext context, dynamic profile, DeptTheme theme, ColorScheme cs, int unread) {
    return AppBar(
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
        Stack(
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_outlined),
              onPressed: () => context.push('/home/notifications'),
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
        Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu_rounded),
            onPressed: () => Scaffold.of(ctx).openEndDrawer(),
          ),
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _buildMobileDrawer(BuildContext context, dynamic profile, dynamic config, DeptTheme theme) {
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
              _drawerItem(context, icon: Icons.music_note_rounded, label: 'Culturel', onTap: () { Navigator.pop(context); context.push('/culturel'); }),
            if (config?.showValues == true)
              _drawerItem(context, icon: Icons.favorite_rounded, label: 'Valeurs', onTap: () { Navigator.pop(context); context.push('/values'); }),
            if (config?.showOath == true)
              _drawerItem(context, icon: Icons.menu_book_rounded, label: 'Serment', onTap: () { Navigator.pop(context); context.push('/oath'); }),
            if (profile?.isAdmin == true)
              _drawerItem(context, icon: Icons.admin_panel_settings_rounded, label: 'Gestion Bureau', color: theme.primary, onTap: () { Navigator.pop(context); context.push('/admin'); }),
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

  Widget _drawerItem(BuildContext context, {required IconData icon, required String label, required VoidCallback onTap, Color? color}) {
    final c = color ?? Colors.black87;
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: c.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: c, size: 20),
      ),
      title: Text(label, style: TextStyle(color: c, fontWeight: FontWeight.w700, fontSize: 14)),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      horizontalTitleGap: 12,
    );
  }

  Widget _buildMobileBottomNav(DeptTheme theme, dynamic profile) {
    return NavigationBar(
      selectedIndex: widget.navigationShell.currentIndex,
      onDestinationSelected: _navigate,
      backgroundColor: Colors.white.withOpacity(0.8),
      surfaceTintColor: Colors.transparent,
      indicatorColor: Colors.transparent,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      animationDuration: const Duration(milliseconds: 400),
      destinations: [
        NavigationDestination(icon: const Icon(Icons.home_outlined), selectedIcon: _buildGlowIcon(Icons.home_rounded, theme.primary), label: 'Accueil'),
        NavigationDestination(icon: const Icon(Icons.chat_bubble_outline_rounded), selectedIcon: _buildGlowIcon(Icons.chat_bubble_rounded, theme.primary), label: 'Messages'),
        NavigationDestination(icon: const Icon(Icons.emoji_events_outlined), selectedIcon: _buildGlowIcon(Icons.emoji_events_rounded, theme.primary), label: 'Classement'),
        NavigationDestination(
          icon: profile != null ? ClipRRect(borderRadius: BorderRadius.circular(20), child: DeptAvatar(user: profile, size: 26, borderRadius: 8)) : const Icon(Icons.person_outline_rounded),
          selectedIcon: profile != null ? ClipRRect(borderRadius: BorderRadius.circular(20), child: DeptAvatar(user: profile, size: 26, borderRadius: 8)) : const Icon(Icons.person_rounded),
          label: 'Profil',
        ),
      ],
    ).animate().slideY(begin: 1, duration: 600.ms, curve: Curves.easeOutExpo);
  }

  Widget _buildGlowIcon(IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: color.withOpacity(0.35), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Icon(icon, color: Colors.white, size: 20),
    );
  }
}
