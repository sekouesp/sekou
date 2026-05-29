import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/dept_theme.dart';
import '../../models/user_profile.dart';
import '../../providers/auth_provider.dart';
import '../../providers/config_provider.dart';
import '../../shared/widgets/dept_avatar.dart';
import '../../shared/widgets/empty_state.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../shared/widgets/user_detail_modal.dart';
import '../../shared/widgets/loading_indicator.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});
  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  String _search = '';
  String _filterDept = '';

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentProfileProvider);
    final usersAsync = ref.watch(allUsersProvider);
    final configAsync = ref.watch(appConfigProvider);

    return profileAsync.when(
      loading: () => const Center(child: AppLoadingIndicator()),
      error: (e, _) => Center(child: Text('Erreur: $e')),
      data: (profile) {
        if (profile == null) return const SizedBox.shrink();
        final theme = DeptTheme.of(profile.department);
        final cs = ColorScheme.fromSeed(seedColor: theme.seed);
        final config = configAsync.value;
        final allUsers = usersAsync.value ?? [];

        final filtered = allUsers.where((u) {
          final name = '${u.firstName} ${u.lastName}'.toLowerCase();
          final matchSearch = _search.isEmpty || name.contains(_search.toLowerCase());
          final matchDept = _filterDept.isEmpty || u.department == _filterDept;
          return matchSearch && matchDept;
        }).toList();

        final sorted = [...allUsers]..sort((a, b) =>
            (b.interactionStats?.points ?? 0).compareTo(a.interactionStats?.points ?? 0));
        final myRank = sorted.indexWhere((u) => u.uid == profile.uid) + 1;

        return CustomScrollView(
          slivers: [
            // Welcome + Impact Cards
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              sliver: SliverToBoxAdapter(
                child: Column(
                  children: [
                    // Welcome card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      clipBehavior: Clip.hardEdge,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.6), // Glassmorphism base
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: Colors.white.withOpacity(0.8), width: 1.5),
                        boxShadow: [
                          BoxShadow(color: theme.primary.withOpacity(0.15), blurRadius: 20, offset: const Offset(0, 8)),
                        ],
                      ),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned(
                            right: -30,
                            bottom: -30,
                            child: Transform.rotate(
                              angle: 0.2, // ~12 degrees
                              child: Opacity(
                                opacity: 0.08,
                                child: Image.network(
                                  'https://res.cloudinary.com/dkpqkwjgo/image/upload/v1779016358/esp_sekou_logo_nobg_yh1xt7.png',
                                  width: 160,
                                  height: 160,
                                  color: theme.primary,
                                ),
                              ),
                            ),
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'UN & INDIVISIBLE',
                                      style: TextStyle(
                                        color: theme.primary,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 3,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      '"DUT 1 est-ce que khamante nagn sunu birr ?"',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        fontStyle: FontStyle.italic,
                                        height: 1.4,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Bienvenue, ${profile.firstName}.',
                                      style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              DeptAvatar(user: profile, size: 64, borderRadius: 20),
                            ],
                          ),
                        ],
                      ),
                    ).animate().fadeIn(duration: 500.ms).slideY(begin: -0.1),

                    // WhatsApp Commission Links
                    if (profile.commissions.isNotEmpty && config != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: profile.commissions.map((comm) {
                            final rawLink = config.commissionLinks[comm] ?? '';
                            // Extraire l'URL WhatsApp du texte
                            final urlMatch = RegExp(r'https://chat\.whatsapp\.com/[A-Za-z0-9]+')
                                .firstMatch(rawLink);
                            final href = urlMatch?.group(0) ?? rawLink;
                            final hasLink = href.isNotEmpty;

                            return Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: hasLink
                                    ? () => launchUrl(Uri.parse(href),
                                        mode: LaunchMode.externalApplication)
                                    : null,
                                borderRadius: BorderRadius.circular(14),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: Colors.grey.shade100),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.04),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.chat_rounded,
                                        size: 18,
                                        color: Color(0xFF25D366),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Rejoindre $comm',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12,
                                          color: Color(0xFF334155),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ).animate(delay: 80.ms).fadeIn().slideY(begin: 0.1),

                    const SizedBox(height: 12),

                    // Impact card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A).withOpacity(0.85), // Dark glass
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.5),
                        boxShadow: [
                          BoxShadow(color: const Color(0xFF0F172A).withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 8)),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'TON IMPACT',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.4),
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 3,
                                ),
                              ),
                              const Spacer(),
                              const Icon(Icons.auto_awesome_rounded, color: Color(0xFFFBBF24), size: 16),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Points',
                                    style: TextStyle(color: Colors.white.withOpacity(0.4),
                                        fontSize: 10, fontWeight: FontWeight.w700),
                                  ),
                                  Text(
                                    '${profile.interactionStats?.points ?? 0}',
                                    style: const TextStyle(color: Colors.white,
                                        fontSize: 36, fontWeight: FontWeight.w900),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text('Rang', style: TextStyle(color: Colors.white.withOpacity(0.4),
                                      fontSize: 10, fontWeight: FontWeight.w700)),
                                  Text(
                                    myRank > 0 ? '#$myRank' : '—',
                                    style: TextStyle(color: cs.primaryContainer,
                                        fontSize: 24, fontWeight: FontWeight.w900),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              _statChip(
                                label: 'Messages',
                                value: '${profile.interactionStats?.totalMessages ?? 0}',
                              ),
                              const SizedBox(width: 8),
                              _statChip(
                                label: 'Contacts',
                                value: '${profile.interactionStats?.startedConversations ?? 0}',
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          InkWell(
                            onTap: () => context.go('/ranking'),
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Text(
                                'VOIR LE CLASSEMENT',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Color(0xFF0F172A),
                                  fontWeight: FontWeight.w900,
                                  fontSize: 11,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ).animate(delay: 100.ms).fadeIn(duration: 500.ms).slideY(begin: 0.1),

                    const SizedBox(height: 24),

                    // Search + Filter
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            onChanged: (v) => setState(() => _search = v),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                            decoration: InputDecoration(
                              hintText: 'Chercher un étudiant...',
                              prefixIcon: const Icon(Icons.search_rounded, size: 20),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(vertical: 12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(color: Colors.grey.shade200),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(color: Colors.grey.shade200),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(color: theme.primary, width: 2),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        PopupMenuButton<String>(
                          initialValue: _filterDept,
                          onSelected: (v) => setState(() => _filterDept = v == _filterDept ? '' : v),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          icon: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _filterDept.isEmpty ? Colors.white : theme.primaryContainer,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Icon(Icons.filter_list_rounded,
                                color: _filterDept.isEmpty ? Colors.grey : theme.primary, size: 20),
                          ),
                          itemBuilder: (_) => [
                            const PopupMenuItem(value: '', child: Text('Tous')),
                            ...['Génie Informatique', 'Génie Civil', 'Génie Électrique',
                              'Génie Mécanique', 'Génie Chimique et Biologie Appliquée', 'Gestion']
                              .map((d) => PopupMenuItem(value: d, child: Text(d))),
                          ],
                        ),
                      ],
                    ).animate(delay: 200.ms).fadeIn(),

                    const SizedBox(height: 8),

                    Row(
                      children: [
                        Text(
                          'ANNUAIRE',
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12,
                              letterSpacing: 2, color: Colors.grey.shade500),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: theme.primaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${filtered.length}',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900,
                                color: theme.onPrimaryContainer),
                          ),
                        ),
                      ],
                    ).animate(delay: 250.ms).fadeIn(),
                  ],
                ),
              ),
            ),

            // Users Grid
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
              sliver: filtered.isEmpty
                  ? const SliverToBoxAdapter(
                      child: EmptyState(
                        icon: Icons.person_search_rounded,
                        title: 'Aucun étudiant trouvé',
                        subtitle: 'Modifie ta recherche ou le filtre',
                      ),
                    )
                  : SliverGrid(
                      delegate: SliverChildBuilderDelegate(
                        (context, i) => _UserCard(
                          user: filtered[i],
                          profile: profile,
                          config: config,
                          index: i,
                        ),
                        childCount: filtered.length,
                      ),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.82,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _statChip({required String label, required String value}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Column(
          children: [
            Text(label, style: TextStyle(color: Colors.white.withOpacity(0.4),
                fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1)),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(color: Colors.white,
                fontSize: 16, fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  final UserProfile user;
  final UserProfile profile;
  final dynamic config;
  final int index;

  const _UserCard({
    required this.user,
    required this.profile,
    required this.config,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final theme = DeptTheme.of(user.department);

    return InkWell(
      onTap: () {
        if (user.isBureauMember) {
          showUserDetailModal(context, user);
        } else {
          context.push('/user/${user.uid}');
        }
      },
      borderRadius: BorderRadius.circular(22),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.55), // Glass
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withOpacity(0.8), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: theme.primary.withOpacity(0.06),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                DeptAvatar(user: user, size: 68, borderRadius: 20),
                if (user.isBureauMember)
                  Positioned(
                    bottom: -4, right: -4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(Icons.verified_rounded,
                          color: Colors.white, size: 10),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                user.fullName,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                user.department.replaceAll('Génie ', 'G. '),
                style: TextStyle(
                  color: theme.primary,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (user.isBureauMember && user.bureauRole != null) ...[
              const SizedBox(height: 6),
              const SmallBureauBadge(),
            ],
          ],
        ),
      ),
    ).animate(delay: Duration(milliseconds: 50 * (index % 6))).fadeIn(duration: 400.ms).scale(
          begin: const Offset(0.95, 0.95),
          curve: Curves.easeOutCubic,
        );
  }
}
