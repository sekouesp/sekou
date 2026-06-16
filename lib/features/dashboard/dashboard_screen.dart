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

import '../../core/services/realtime_bus_service.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});
  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  String _search = '';
  String _filterDept = '';

  @override
  void initState() {
    super.initState();
    // On initialise le bus temps réel silencieusement
    Future.microtask(() {
      ref.read(realtimeBusProvider).initialize();
    });
  }

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
          if (!u.isApproved) return false;
          final name = '${u.firstName} ${u.lastName}'.toLowerCase();
          final matchSearch = _search.isEmpty || name.contains(_search.toLowerCase());
          final matchDept = _filterDept.isEmpty || u.department == _filterDept;
          return matchSearch && matchDept;
        }).toList();

        final sorted = [...allUsers.where((u) => u.isApproved)]..sort((a, b) =>
            (b.interactionStats?.points ?? 0).compareTo(a.interactionStats?.points ?? 0));
        final myRank = sorted.indexWhere((u) => u.uid == profile.uid) + 1;

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1280),
            child: RefreshIndicator(
              color: theme.primary,
              onRefresh: () async {
                ref.invalidate(allUsersProvider);
                await ref.read(allUsersProvider.future);
              },
              child: CustomScrollView(
              slivers: [
                // Welcome + Impact Cards
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              sliver: SliverToBoxAdapter(
                child: Column(
                  children: [
                    Builder(
                      builder: (context) {
                        final isDesktop = MediaQuery.of(context).size.width >= 1024;
                        
                        final welcomeContent = Stack(
                          clipBehavior: Clip.none,
                          children: [
                            if (isDesktop)
                              Positioned(
                                right: -40,
                                bottom: -40,
                                child: Transform.rotate(
                                  angle: 0.2,
                                  child: Opacity(
                                    opacity: 0.08,
                                    child: Image.network(
                                      'https://res.cloudinary.com/dkpqkwjgo/image/upload/v1779016358/esp_sekou_logo_nobg_yh1xt7.png',
                                      width: 256,
                                      height: 256,
                                      color: theme.primary,
                                    ),
                                  ),
                                ),
                              ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                  Text(
                                    '"DUT 1 EST-CE QUE KHAMANTE NAGN SUNU BIRR ?"',
                                    style: TextStyle(
                                      fontSize: isDesktop ? 36 : 20,
                                      fontWeight: FontWeight.w900,
                                      fontFamily: 'serif', // font-serif
                                      letterSpacing: -1, // tracking-tighter
                                      height: 1.1,
                                      color: const Color(0xFF0F172A), // slate-900
                                    ),
                                ),
                                const SizedBox(height: 16),
                                  Text(
                                    'Bienvenue, ${profile.firstName}.',
                                    style: TextStyle(color: const Color(0xFF475569), fontSize: isDesktop ? 16 : 14, fontWeight: FontWeight.w500), // text-slate-600
                                  ),
                                if (profile.commissions.isNotEmpty && config != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 24),
                                    child: Wrap(
                                      spacing: 12,
                                      runSpacing: 12,
                                      children: profile.commissions.map((comm) {
                                        final rawLink = config.commissionLinks[comm] ?? '';
                                        final urlMatch = RegExp(r'https://chat\.whatsapp\.com/[A-Za-z0-9]+').firstMatch(rawLink);
                                        final href = urlMatch?.group(0) ?? rawLink;
                                        final hasLink = href.isNotEmpty;

                                        return Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            onTap: hasLink ? () => launchUrl(Uri.parse(href), mode: LaunchMode.externalApplication) : null,
                                            borderRadius: BorderRadius.circular(14),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius: BorderRadius.circular(14),
                                                border: Border.all(color: Colors.grey.shade100),
                                                boxShadow: [
                                                  BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
                                                ],
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(Icons.chat_rounded, size: 18, color: Color(0xFF25D366)),
                                                  const SizedBox(width: 8),
                                                  Text('Rejoindre $comm', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF334155))),
                                                ],
                                              ),
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        );

                        final welcomeBlock = Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(isDesktop ? 40 : 20),
                          clipBehavior: Clip.hardEdge,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [theme.tinted, Colors.white], // bg-gradient-to-br
                            ),
                            borderRadius: BorderRadius.circular(24), // rounded-3xl
                            border: Border.all(color: theme.primary.withOpacity(0.5), width: 1),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 1)), // shadow-sm
                            ],
                          ),
                          child: welcomeContent,
                        ).animate().fadeIn(duration: 500.ms).slideY(begin: -0.1);

                        final impactBlock = Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(isDesktop ? 32 : 20),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A), // slate-900
                            borderRadius: BorderRadius.circular(40), // rounded-[2.5rem]
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 32, offset: const Offset(0, 12)),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween, // Distributes space if height is forced
                            children: [
                              // Top part
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text('TON IMPACT', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 3)),
                                      const Spacer(),
                                      const Icon(Icons.auto_awesome_rounded, color: Color(0xFFFBBF24), size: 16),
                                    ],
                                  ),
                                  const SizedBox(height: 24),
                                  // Points and rank
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('POINTS ACCUMULÉS', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 8, fontWeight: FontWeight.w700)),
                                          Text('${profile.interactionStats?.points ?? 0}', style: TextStyle(color: Colors.white, fontSize: isDesktop ? 32 : 24, fontWeight: FontWeight.w900, letterSpacing: -1)), // tracking-tighter
                                        ],
                                      ),
                                      const Spacer(),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text('CLASSEMENT', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 8, fontWeight: FontWeight.w700)),
                                          Text(myRank > 0 ? '#$myRank' : '—', style: TextStyle(color: const Color(0xFF818CF8), fontSize: isDesktop ? 20 : 16, fontWeight: FontWeight.w900)), // indigo-400
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      _statChip(label: 'MESSAGES', value: '${profile.interactionStats?.totalMessages ?? 0}'),
                                      const SizedBox(width: 12),
                                      _statChip(label: 'CONTACTS', value: '${profile.interactionStats?.startedConversations ?? 0}'),
                                    ],
                                  ),
                                ],
                              ),
                              if (!isDesktop) const SizedBox(height: 24), // Add spacing on mobile where space isn't distributed
                              Padding(
                                padding: EdgeInsets.only(top: isDesktop ? 24 : 0),
                                child: InkWell(
                                  onTap: () => context.go('/ranking'),
                                  borderRadius: BorderRadius.circular(16), // rounded-2xl
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                                    child: const Text('VOIR LE CLASSEMENT', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1.5)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ).animate(delay: 100.ms).fadeIn(duration: 500.ms).slideY(begin: 0.1);

                        if (isDesktop) {
                          return IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(flex: 2, child: welcomeBlock),
                                const SizedBox(width: 24),
                                Expanded(child: impactBlock),
                              ],
                            ),
                          );
                        }
                        
                        return SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          clipBehavior: Clip.none,
                          physics: const BouncingScrollPhysics(),
                          child: IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                SizedBox(
                                  width: MediaQuery.of(context).size.width * 0.85,
                                  child: welcomeBlock,
                                ),
                                const SizedBox(width: 16),
                                SizedBox(
                                  width: MediaQuery.of(context).size.width * 0.85,
                                  child: impactBlock,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),

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
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: MediaQuery.of(context).size.width >= 1200 ? 4 
                            : MediaQuery.of(context).size.width >= 800 ? 3 
                            : 2,
                        childAspectRatio: 0.82,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                    ),
            ),
              ],
            ),
            ), // RefreshIndicator
          ),
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
    final cs = ColorScheme.fromSeed(seedColor: theme.seed);
    final isDesktop = MediaQuery.of(context).size.width >= 800;

    return InkWell(
      onTap: () {
        if (user.isBureauMember) {
          showUserDetailModal(context, user);
        } else {
          context.push('/user/${user.uid}');
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: EdgeInsets.all(isDesktop ? 24 : 16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.8),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF1F5F9)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                DeptAvatar(user: user, size: isDesktop ? 80 : 64, borderRadius: 100), // fully rounded in web
                if (user.isBureauMember)
                  Positioned(
                    bottom: 0, right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: Icon(Icons.verified_rounded,
                          color: Colors.white, size: isDesktop ? 12 : 10),
                    ),
                  ),
                if (user.isNewcomer)
                  const Positioned(
                    top: -6, right: -10,
                    child: NewBadge(),
                  ),
              ],
            ),
            SizedBox(height: isDesktop ? 16 : 12),
            Text(
              user.firstName, // React uses firstName prominently
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: isDesktop ? 18 : 14,
                color: const Color(0xFF1E293B),
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              user.department, // React uses full department name
              style: const TextStyle(
                color: Color(0xFF94A3B8), // slate-400
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5, // tracking-widest
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Text(
                user.bio.isNotEmpty ? user.bio : "ESPRIT ESP.",
                style: TextStyle(
                  color: const Color(0xFF64748B), // slate-500
                  fontSize: isDesktop ? 12 : 10,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w500,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
                maxLines: isDesktop ? 3 : 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(top: 12),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFFF8FAFC))), // slate-50
              ),
              child: Column(
                children: [
                  if (config.rankingEnabled == true || profile.isAdmin)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: theme.tinted, // theme.light
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${user.interactionStats?.points ?? 0} PTS',
                        style: TextStyle(
                          color: theme.primary, // theme.text
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: theme.tinted,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'POLYTECHNICIEN',
                        style: TextStyle(
                          color: theme.primary,
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  if (user.commissions.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      '+${user.commissions.length} COMMISSION${user.commissions.length > 1 ? 'S' : ''}',
                      style: const TextStyle(
                        fontSize: 7,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF94A3B8),
                        letterSpacing: -0.5, // tracking-tighter
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate(delay: Duration(milliseconds: 50 * (index % 6))).fadeIn(duration: 400.ms).scale(
          begin: const Offset(0.95, 0.95),
          curve: Curves.easeOutCubic,
        );
  }
}
