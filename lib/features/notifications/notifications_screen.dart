import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/dept_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/config_provider.dart';
import '../../providers/notifications_provider.dart';

final _broadcastsProvider =
    StreamProvider.autoDispose.family<List<QueryDocumentSnapshot>, String>((ref, dept) {
  return FirebaseFirestore.instance
      .collection('broadcasts')
      .orderBy('createdAt', descending: true)
      .limit(20)
      .snapshots()
      .map((s) => s.docs.where((doc) {
            final data = doc.data();
            final filterDept = data['filterDept'] as String?;
            return filterDept == null || filterDept.isEmpty || filterDept == dept;
          }).toList());
});

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final profile = ref.read(currentProfileProvider).value;
      if (profile != null) {
        FirebaseFirestore.instance.collection('users').doc(profile.uid).update({
          'lastReadAnnouncementsAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentProfileProvider).value;
    final dept    = profile?.department ?? '';
    final theme   = DeptTheme.of(dept);
    final config  = ref.watch(appConfigProvider).value;
    final notifier = ref.read(notificationsProvider.notifier);
    final broadcastsAsync = ref.watch(_broadcastsProvider(dept));

    // Annonces désactivées
    if (config?.annoncesEnabled == false) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.tinted,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(Icons.campaign_outlined, color: theme.primary, size: 44),
              ),
              const SizedBox(height: 16),
              const Text('Annonces suspendues',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
              const SizedBox(height: 8),
              Text('Temporairement suspendues par le bureau.',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: broadcastsAsync.when(
        loading: () => _buildSkeletons(theme),
        error: (e, _) => Center(child: Text('Erreur: $e')),
        data: (docs) {
          return CustomScrollView(
            slivers: [
              // Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: theme.tinted,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.notifications_rounded,
                              color: theme.primary, size: 18),
                        ),
                        const SizedBox(width: 8),
                        Text("FLUX D'ANNONCES BUREAU",
                            style: TextStyle(
                                fontSize: 9, fontWeight: FontWeight.w900,
                                letterSpacing: 2, color: Colors.grey.shade400)),
                      ]),
                      const SizedBox(height: 8),
                      const Text('Espace Notifications',
                          style: TextStyle(fontWeight: FontWeight.w900,
                              fontSize: 24, letterSpacing: -0.5)),
                    ],
                  ),
                ).animate().fadeIn().slideY(begin: -0.05),
              ),

              // Liste vide
              if (docs.isEmpty)
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 32),
                    decoration: BoxDecoration(
                      color: theme.tinted,
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(
                          color: theme.primary.withOpacity(0.1)),
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 16)],
                          ),
                          child: Icon(Icons.campaign_outlined,
                              color: Colors.grey.shade200, size: 36),
                        ),
                        const SizedBox(height: 16),
                        const Text('Aucune annonce',
                            style: TextStyle(
                                fontWeight: FontWeight.w900, fontSize: 16)),
                        const SizedBox(height: 6),
                        Text("Les messages du bureau s'afficheront ici.",
                            style: TextStyle(color: Colors.grey.shade400,
                                fontSize: 12, fontWeight: FontWeight.w600),
                            textAlign: TextAlign.center),
                      ],
                    ),
                  ).animate().fadeIn().scale(begin: const Offset(0.95, 0.95)),
                ),

              // Broadcasts
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      final doc  = docs[i];
                      final data = doc.data() as Map<String, dynamic>;
                      final ts   = data['createdAt'] as Timestamp?;
                      final filterDept = data['filterDept'] as String?;
                      return _BroadcastCard(
                        text: data['text'] as String? ?? '',
                        timestamp: ts,
                        filterDept: filterDept,
                        theme: theme,
                        index: i,
                      );
                    },
                    childCount: docs.length,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSkeletons(DeptTheme theme) {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: 3,
      itemBuilder: (_, i) => Container(
        margin: const EdgeInsets.only(bottom: 16),
        height: 140,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(32),
        ),
      ).animate(onPlay: (c) => c.repeat(reverse: true))
       .shimmer(duration: 1200.ms, color: Colors.grey.shade100),
    );
  }
}

class _BroadcastCard extends StatefulWidget {
  final String text;
  final String? filterDept;
  final Timestamp? timestamp;
  final DeptTheme theme;
  final int index;

  const _BroadcastCard({
    required this.text, required this.timestamp,
    required this.filterDept, required this.theme, required this.index,
  });

  @override
  State<_BroadcastCard> createState() => _BroadcastCardState();
}

class _BroadcastCardState extends State<_BroadcastCard> {
  bool _acknowledged = false;

  String _formatDate(Timestamp? ts) {
    if (ts == null) return 'Maintenant';
    final d = ts.toDate();
    try {
      return DateFormat("d MMMM yyyy 'à' HH:mm", 'fr_FR').format(d);
    } catch (_) {
      return DateFormat("dd/MM/yyyy HH:mm").format(d);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16, offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Watermark icon en fond
          Positioned(
            bottom: -16, right: -16,
            child: Icon(Icons.campaign_rounded,
                size: 120,
                color: theme.primary.withOpacity(0.03)),
          ),

          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icône + date
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Icône annonce
                    Container(
                      width: 52, height: 52,
                      decoration: BoxDecoration(
                        color: theme.tinted,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Icon(Icons.campaign_rounded,
                          color: theme.primary, size: 26),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Date
                          Row(children: [
                            Icon(Icons.calendar_today_rounded,
                                size: 11, color: theme.primary),
                            const SizedBox(width: 4),
                            Text(
                              _formatDate(widget.timestamp),
                              style: TextStyle(
                                fontSize: 10, fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
                                color: Colors.grey.shade400,
                              ),
                            ),
                          ]),
                          // Badge département ciblé
                          if (widget.filterDept != null &&
                              widget.filterDept!.isNotEmpty)
                            Container(
                              margin: const EdgeInsets.only(top: 6),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: theme.primary,
                                borderRadius: BorderRadius.circular(7),
                              ),
                              child: Text(
                                widget.filterDept!.replaceAll('Génie ', 'G. '),
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9, fontWeight: FontWeight.w900),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                // Texte principal — italic entre guillemets
                Text(
                  '"${widget.text}"',
                  style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w700,
                    height: 1.55, fontStyle: FontStyle.italic,
                    color: Color(0xFF1E293B), letterSpacing: -0.3,
                  ),
                ),

                // Footer
                Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: Row(
                    children: [
                      Image.network(
                        'https://res.cloudinary.com/dkpqkwjgo/image/upload/v1779016358/esp_sekou_logo_nobg_yh1xt7.png',
                        width: 18, height: 18,
                        color: Colors.grey.shade300,
                        colorBlendMode: BlendMode.modulate,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          "Adminstrateur",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 8, fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
                              color: Colors.grey.shade300,
                              fontStyle: FontStyle.italic),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Bouton "C'est compris"
                      GestureDetector(
                        onTap: () => setState(() => _acknowledged = true),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _acknowledged ? 'Lu ✓' : "C'est compris",
                              style: TextStyle(
                                fontSize: 10, fontWeight: FontWeight.w900,
                                letterSpacing: 1,
                                color: _acknowledged
                                    ? Colors.grey.shade300 : theme.primary,
                              ),
                            ),
                            if (!_acknowledged) ...[
                              const SizedBox(width: 3),
                              Icon(Icons.chevron_right_rounded,
                                  size: 14, color: theme.primary),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate(delay: Duration(milliseconds: 60 * widget.index))
     .fadeIn(duration: 400.ms)
     .scale(begin: const Offset(0.97, 0.97), curve: Curves.easeOut);
  }
}
