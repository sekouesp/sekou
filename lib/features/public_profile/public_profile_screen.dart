import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/dept_theme.dart';
import '../chat/conversations_screen.dart';
import '../../models/user_profile.dart';
import '../../providers/auth_provider.dart';
import '../../providers/config_provider.dart';
import '../../shared/widgets/dept_avatar.dart';
import '../../shared/widgets/loading_indicator.dart';
import '../../shared/widgets/photo_viewer.dart';

class PublicProfileScreen extends HookConsumerWidget {
  final String uid;
  const PublicProfileScreen({super.key, required this.uid});

  Future<void> _startConversation(BuildContext context, WidgetRef ref, String otherUid, UserProfile other) async {
    final me = ref.read(currentUidProvider)!;
    final fs = FirebaseFirestore.instance;

    // Check if conversation already exists
    final existing = await fs.collection('conversations')
        .where('participantIds', arrayContains: me)
        .where('type', isEqualTo: 'direct')
        .get();

    String? convId;
    for (final doc in existing.docs) {
      final ids = List<String>.from(doc.data()['participantIds'] ?? []);
      if (ids.contains(otherUid)) {
        convId = doc.id;
        break;
      }
    }

    if (convId == null) {
      final ref2 = await fs.collection('conversations').add({
        'participantIds': [me, otherUid],
        'type': 'direct',
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastMessageText': null,
        'lastSenderId': null,
      });
      convId = ref2.id;
      // Update stats
      await fs.collection('users').doc(me).update({
        'interactionStats.startedConversations': FieldValue.increment(1),
      });
    }

    if (context.mounted) {
      openConversation(context, ref, convId, {
        'otherName': other.fullName,
        'otherDept': other.department,
        'otherUid': other.uid,
        'isBureau': other.isBureauMember,
      });
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider).value;
    final me = ref.watch(currentProfileProvider).value;
    final isLoading = useState(false);

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const Scaffold(body: Center(child: AppLoadingIndicator()));
        if (!snap.data!.exists) {
          return Scaffold(
            appBar: AppBar(leading: BackButton()),
            body: const Center(child: Text('Profil introuvable')),
          );
        }
        final user = UserProfile.fromFirestore(snap.data!);
        final theme = DeptTheme.of(user.department);
        final isMe = user.uid == me?.uid;

        return Scaffold(
          backgroundColor: const Color(0xFFF5F7FF),
          body: CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 220,
                pinned: true,
                backgroundColor: theme.primary,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                  onPressed: () => context.pop(),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft, end: Alignment.bottomRight,
                            colors: [theme.primary, theme.primary.withOpacity(0.7)],
                          ),
                        ),
                      ),
                      // Background circles
                      Positioned(top: -30, right: -30,
                          child: Container(width: 160, height: 160,
                              decoration: BoxDecoration(shape: BoxShape.circle,
                                  color: Colors.white.withOpacity(0.06)))),
                      Positioned(bottom: -20, left: -20,
                          child: Container(width: 120, height: 120,
                              decoration: BoxDecoration(shape: BoxShape.circle,
                                  color: Colors.white.withOpacity(0.04)))),
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(height: 40),
                            GestureDetector(
                              onTap: user.photoUrl.isEmpty
                                  ? null
                                  : () => showFullScreenPhoto(context, user.photoUrl),
                              child: Hero(
                                tag: 'avatar_${user.uid}',
                                child: DeptAvatar(user: user, size: 88, borderRadius: 28),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(user.fullName,
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(color: Colors.white,
                                          fontWeight: FontWeight.w900, fontSize: 20)),
                                ),
                                if (user.isBureauMember) ...[
                                  const SizedBox(width: 6),
                                  const Icon(Icons.verified_rounded, color: Colors.white, size: 18),
                                ],
                              ],
                            ),
                            if (user.alias.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text('@${user.alias}',
                                  style: TextStyle(color: Colors.white.withOpacity(0.9),
                                      fontSize: 14, fontWeight: FontWeight.bold, fontStyle: FontStyle.italic)),
                            ],
                            const SizedBox(height: 4),
                            Text(user.department,
                                style: TextStyle(color: Colors.white.withOpacity(0.7),
                                    fontSize: 12, fontWeight: FontWeight.w600)),
                            if (user.isNewcomer) ...[
                              const SizedBox(height: 8),
                              const NewBadge(),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // Bureau badge
                    if (user.isBureauMember)
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.verified_rounded,
                                  color: Colors.white, size: 18),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Membre du Bureau',
                                      style: TextStyle(color: Colors.white,
                                          fontWeight: FontWeight.w800, fontSize: 13)),
                                  if (user.bureauRole != null)
                                    Text(user.bureauRole!,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(color: Colors.white.withOpacity(0.5),
                                            fontSize: 12)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1),

                    // Stats row
                    Row(
                      children: [
                        _StatCard(value: '${user.interactionStats?.points ?? 0}',
                            label: 'Points', icon: Icons.auto_awesome_rounded,
                            color: theme.primary, flex: 1),
                        const SizedBox(width: 8),
                        _StatCard(value: '${user.interactionStats?.totalMessages ?? 0}',
                            label: 'Messages', icon: Icons.chat_bubble_rounded,
                            color: const Color(0xFF059669), flex: 1),
                        const SizedBox(width: 8),
                        _StatCard(value: '${user.interactionStats?.startedConversations ?? 0}',
                            label: 'Contacts', icon: Icons.people_rounded,
                            color: const Color(0xFF0891B2), flex: 1),
                      ],
                    ).animate(delay: 150.ms).fadeIn().slideY(begin: 0.1),

                    const SizedBox(height: 16),

                    // Bio
                    if (user.bio.isNotEmpty)
                      _InfoCard(
                        icon: Icons.info_outline_rounded,
                        label: 'BIO',
                        content: user.bio,
                      ).animate(delay: 200.ms).fadeIn(),

                    if (user.hobbies.isNotEmpty)
                      _InfoCard(
                        icon: Icons.favorite_outline_rounded,
                        label: 'PASSIONS',
                        content: user.hobbies,
                      ).animate(delay: 250.ms).fadeIn(),


                    // Badges
                    if (user.badges.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      _InfoCard(
                        icon: Icons.emoji_events_outlined,
                        label: 'BADGES',
                        content: user.badges.join(' '),
                        large: true,
                      ).animate(delay: 300.ms).fadeIn(),
                    ],

                    // Commissions (simple affichage, sans lien WhatsApp)
                    if (user.commissions.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: Colors.grey.shade100),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Icon(Icons.groups_rounded,
                                  size: 14, color: Colors.grey.shade400),
                              const SizedBox(width: 6),
                              Text('COMMISSIONS',
                                  style: TextStyle(fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.5,
                                      color: Colors.grey.shade400)),
                            ]),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 6, runSpacing: 6,
                              children: user.commissions.map((comm) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF4F46E5).withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                        color: const Color(0xFF4F46E5).withOpacity(0.15)),
                                  ),
                                  child: Text(comm, style: const TextStyle(
                                      color: Color(0xFF4F46E5),
                                      fontWeight: FontWeight.w800, fontSize: 12)),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ).animate(delay: 350.ms).fadeIn(),
                    ],

                    // Badge cross-dept
                    if ((user.interactionStats?.crossDeptInteractions.length ?? 0) >= 3) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF7ED),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFFDE68A)),
                        ),
                        child: Row(children: [
                          const Text('🛡️', style: TextStyle(fontSize: 22)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              const Text('Ambassadeur',
                                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                              Text(
                                'A connecté ${user.interactionStats!.crossDeptInteractions.length} départements',
                                style: TextStyle(color: Colors.grey.shade500,
                                    fontSize: 11, fontWeight: FontWeight.w600)),
                            ]),
                          ),
                        ]),
                      ).animate(delay: 400.ms).fadeIn(),
                    ],

                    const SizedBox(height: 24),

                    // CTA
                    if (!isMe && !(config?.disableChat ?? false))
                      FilledButton.icon(
                        onPressed: isLoading.value ? null : () async {
                          isLoading.value = true;
                          HapticFeedback.mediumImpact();
                          await _startConversation(context, ref, user.uid, user);
                          if (context.mounted) isLoading.value = false;
                        },
                        icon: isLoading.value
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.chat_bubble_rounded),
                        label: Text(isLoading.value ? 'Ouverture...' : 'Envoyer un message'),
                        style: FilledButton.styleFrom(
                          backgroundColor: theme.primary,
                          minimumSize: const Size(double.infinity, 54),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18)),
                          textStyle: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 14),
                        ),
                      ).animate(delay: 400.ms).fadeIn().slideY(begin: 0.2),
                  ]),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value, label;
  final IconData icon;
  final Color color;
  final int flex;
  const _StatCard({required this.value, required this.label,
      required this.icon, required this.color, required this.flex});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.15)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 6),
            Text(value, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: color)),
            Text(label, style: TextStyle(color: Colors.grey.shade500,
                fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String label, content;
  final bool large;
  const _InfoCard({required this.icon, required this.label,
      required this.content, this.large = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: Colors.grey.shade400),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900,
                  letterSpacing: 1.5, color: Colors.grey.shade400)),
            ],
          ),
          const SizedBox(height: 10),
          Text(content, style: TextStyle(
            fontWeight: FontWeight.w600, fontSize: large ? 22 : 14,
            height: 1.6, color: Colors.black87,
          )),
        ],
      ),
    );
  }
}
