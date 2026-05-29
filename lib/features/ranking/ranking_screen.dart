import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/dept_theme.dart';
import '../../models/app_config.dart';
import '../../models/user_profile.dart';
import '../../providers/auth_provider.dart';
import '../../providers/config_provider.dart';
import '../../shared/widgets/dept_avatar.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/loading_indicator.dart';

class RankingScreen extends ConsumerWidget {
  const RankingScreen({super.key});

  List<_RankedUser> _buildRanking(List<UserProfile> users, AppConfig? config) {
    var sorted = users
        .where((u) => !u.isSuperAdmin &&
            (u.interactionStats?.points ?? 0) > 0)
        .toList()
      ..sort((a, b) => (b.interactionStats?.points ?? 0)
          .compareTo(a.interactionStats?.points ?? 0));

    final limit = config?.rankingLimit ?? 100;
    if (sorted.length > limit) sorted = sorted.take(limit).toList();

    return sorted.asMap().entries.map((entry) {
      final i = entry.key;
      final u = entry.value;
      final stats = u.interactionStats;
      final badges = <_Badge>[];

      if (i == 0) badges.add(const _Badge('👑', 'Major', Color(0xFFF59E0B)));
      if ((stats?.crossDeptInteractions.length ?? 0) >= 3) {
        badges.add(const _Badge('🛡️', 'Ambassadeur', Color(0xFFE11D48)));
      }
      if ((stats?.startedConversations ?? 0) >= 50) {
        badges.add(const _Badge('⚡', 'Ultra Connecté', Color(0xFF4F46E5)));
      } else if ((stats?.startedConversations ?? 0) >= 20) {
        badges.add(const _Badge('🔥', 'Très Actif', Color(0xFF0891B2)));
      }

      return _RankedUser(user: u, rank: i + 1, badges: badges);
    }).toList();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider).value;
    final usersAsync = ref.watch(allUsersProvider);
    final me = ref.watch(currentProfileProvider).value;

    if (config?.rankingEnabled == false && !(me?.isAdmin ?? false)) {
      return const Scaffold(
        body: EmptyState(
          icon: Icons.emoji_events_outlined,
          title: 'Classement désactivé',
          subtitle: 'Le bureau a temporairement désactivé le classement.',
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent, // Let Shell's MeshGradient bleed through
      body: usersAsync.when(
        loading: () => const Center(child: AppLoadingIndicator()),
        error: (e, _) => Center(child: Text('Erreur: $e')),
        data: (users) {
          final ranked = _buildRanking(users, config);
          final theme = DeptTheme.of(me?.department);
          final cs = ColorScheme.fromSeed(seedColor: theme.seed);
          final myRank = me != null
              ? ranked.indexWhere((r) => r.user.uid == me.uid) + 1 : 0;

          return CustomScrollView(
            slivers: [
              // Hero banner
              SliverToBoxAdapter(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(24, 36, 24, 48),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                      colors: [theme.primary, theme.seed.withOpacity(0.7)],
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 64, height: 64,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Icon(Icons.emoji_events_rounded,
                                color: Colors.white, size: 36),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('CLASSEMENT ÉLITE',
                                    style: TextStyle(color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 20, fontStyle: FontStyle.italic)),
                                Text(
                                  'Top ${config?.rankingLimit ?? 100} étudiants',
                                  style: TextStyle(
                                      color: Colors.white.withOpacity(0.7),
                                      fontWeight: FontWeight.w700, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          _HeroStat(
                            label: 'TES POINTS',
                            value: '${me?.interactionStats?.points ?? 0}',
                          ),
                          const SizedBox(width: 12),
                          _HeroStat(
                            label: 'TON RANG',
                            value: myRank > 0 ? '#$myRank' : '—',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Info card
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_rounded,
                          color: Color(0xFFD97706), size: 18),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Commence des conversations (+10 pts) et reste actif (+1 pt). '
                          'Bonus ×2 pour les échanges inter-départements ! '
                          'Débloque des badges en connectant toute la promo.',
                          style: TextStyle(
                            color: Color(0xFF92400E),
                            fontWeight: FontWeight.w600, fontSize: 12, height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ).animate(delay: 100.ms).fadeIn(),
              ),

              // Top 3 podium
              if (ranked.length >= 3)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                    child: _Podium(
                      first: ranked[0],
                      second: ranked[1],
                      third: ranked[2],
                    ),
                  ),
                ),

              // Liste complète
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      final r = ranked[i];
                      final isMe = r.user.uid == me?.uid;
                      final theme2 = DeptTheme.of(r.user.department);
                      return _RankRow(
                          ranked: r, isMe: isMe, theme: theme2, index: i);
                    },
                    childCount: ranked.length,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _RankedUser {
  final UserProfile user;
  final int rank;
  final List<_Badge> badges;
  const _RankedUser({required this.user, required this.rank, required this.badges});
}

class _Badge {
  final String emoji, label;
  final Color color;
  const _Badge(this.emoji, this.label, this.color);
}

class _HeroStat extends StatelessWidget {
  final String label, value;
  const _HeroStat({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Text(label, style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(
                color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }
}

class _Podium extends StatelessWidget {
  final _RankedUser first, second, third;
  const _Podium({required this.first, required this.second, required this.third});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.6), // Glass Podium
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.8), width: 1.5),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 5)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _PodiumSlot(ranked: second, height: 70),
          _PodiumSlot(ranked: first, height: 100, isFirst: true),
          _PodiumSlot(ranked: third, height: 50),
        ],
      ),
    );
  }
}

class _PodiumSlot extends StatelessWidget {
  final _RankedUser ranked;
  final double height;
  final bool isFirst;
  const _PodiumSlot({required this.ranked, required this.height, this.isFirst = false});
  @override
  Widget build(BuildContext context) {
    final theme = DeptTheme.of(ranked.user.department);
    return Column(
      children: [
        if (isFirst)
          const Text('👑', style: TextStyle(fontSize: 22))
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .moveY(begin: 0, end: -5, duration: 1500.ms),
        DeptAvatar(user: ranked.user, size: isFirst ? 68 : 52, borderRadius: 18)
            .animate(delay: Duration(milliseconds: ranked.rank * 100))
            .scale(begin: const Offset(0.5, 0.5), curve: Curves.elasticOut),
        const SizedBox(height: 6),
        Text(ranked.user.firstName,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11),
            maxLines: 1, overflow: TextOverflow.ellipsis),
        Text('${ranked.user.interactionStats?.points ?? 0} pts',
            style: TextStyle(color: theme.primary,
                fontSize: 10, fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        Container(
          width: 70, height: height,
          decoration: BoxDecoration(
            color: isFirst
                ? theme.primary.withOpacity(0.15) : Colors.grey.shade100,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
          ),
          child: Center(
            child: Text('#${ranked.rank}',
                style: TextStyle(
                    fontWeight: FontWeight.w900, fontSize: 18,
                    color: isFirst ? theme.primary : Colors.grey.shade400)),
          ),
        ).animate(delay: Duration(milliseconds: ranked.rank * 80))
         .slideY(begin: 1, duration: 500.ms, curve: Curves.easeOutCubic),
      ],
    );
  }
}

class _RankRow extends StatelessWidget {
  final _RankedUser ranked;
  final bool isMe;
  final DeptTheme theme;
  final int index;
  const _RankRow({required this.ranked, required this.isMe,
      required this.theme, required this.index});

  static const _medals = {1: '👑', 2: '🥈', 3: '🥉'};

  @override
  Widget build(BuildContext context) {
    final medal = _medals[ranked.rank];
    return GestureDetector(
      onTap: () => context.push('/user/${ranked.user.uid}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isMe ? theme.tinted.withOpacity(0.8) : Colors.white.withOpacity(0.6), // Glass Row
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: isMe ? theme.primary.withOpacity(0.5) : Colors.white.withOpacity(0.8),
              width: 1.5),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            SizedBox(
              width: 38,
              child: medal != null
                  ? Text(medal,
                      style: const TextStyle(fontSize: 22),
                      textAlign: TextAlign.center)
                  : Text('#${ranked.rank}',
                      style: TextStyle(fontWeight: FontWeight.w900,
                          fontSize: 13, color: Colors.grey.shade400),
                      textAlign: TextAlign.center),
            ),
            const SizedBox(width: 10),
            DeptAvatar(user: ranked.user, size: 44),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(ranked.user.fullName,
                            style: const TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 14),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                      if (isMe)
                        Container(
                          margin: const EdgeInsets.only(left: 6),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: theme.primary,
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: const Text('Toi',
                              style: TextStyle(color: Colors.white,
                                  fontSize: 8, fontWeight: FontWeight.w900)),
                        ),
                    ],
                  ),
                  Text(ranked.user.department.replaceAll('Génie ', 'G. '),
                      style: TextStyle(color: theme.primary,
                          fontSize: 11, fontWeight: FontWeight.w700)),
                  if (ranked.badges.isNotEmpty)
                    Wrap(
                      spacing: 4,
                      children: ranked.badges.map((b) => Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: b.color.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text('${b.emoji} ${b.label}',
                            style: TextStyle(color: b.color,
                                fontSize: 9, fontWeight: FontWeight.w900)),
                      )).toList(),
                    ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${ranked.user.interactionStats?.points ?? 0}',
                    style: TextStyle(fontWeight: FontWeight.w900,
                        fontSize: 18, color: theme.primary)),
                Text('pts', style: TextStyle(color: Colors.grey.shade400,
                    fontSize: 10, fontWeight: FontWeight.w700)),
                Text(
                  '${ranked.user.interactionStats?.crossDeptInteractions.length ?? 0} depts',
                  style: TextStyle(color: Colors.grey.shade400,
                      fontSize: 9, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ],
        ),
      ),
    ).animate(delay: Duration(milliseconds: 30 * (index % 10)))
     .fadeIn(duration: 350.ms)
     .slideX(begin: 0.05, curve: Curves.easeOutCubic);
  }
}
