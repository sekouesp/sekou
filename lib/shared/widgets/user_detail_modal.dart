import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/dept_theme.dart';
import '../../models/user_profile.dart';
import '../../providers/auth_provider.dart';
import '../../providers/config_provider.dart';
import '../widgets/dept_avatar.dart';

/// Affiche un bottom sheet avec l'aperçu rapide d'un profil
/// Utilisé depuis Dashboard en tap sur une carte étudiant
void showUserDetailModal(BuildContext context, UserProfile user) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _UserDetailModal(user: user),
  );
}

class _UserDetailModal extends ConsumerStatefulWidget {
  final UserProfile user;
  const _UserDetailModal({required this.user});

  @override
  ConsumerState<_UserDetailModal> createState() => _UserDetailModalState();
}

class _UserDetailModalState extends ConsumerState<_UserDetailModal> {
  bool _isLoading = false;

  Future<void> _startConversation(BuildContext context, WidgetRef ref, String otherUid, UserProfile other) async {
    setState(() => _isLoading = true);
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
        'interactionStats.points': FieldValue.increment(other.isBureauMember ? 20 : 10),
        'interactionStats.bureauInteractions': other.isBureauMember
            ? FieldValue.arrayUnion([otherUid]) : FieldValue.arrayUnion([]),
      });
    }

    if (context.mounted) {
      final goRouter = GoRouter.of(context);
      Navigator.pop(context); // Close the modal
      goRouter.push('/chat/$convId', extra: {
        'otherName': other.fullName,
        'otherDept': other.department,
        'otherUid': other.uid,
        'isBureau': other.isBureauMember,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = DeptTheme.of(widget.user.department);
    final config = ref.watch(appConfigProvider).value;
    final me = ref.watch(currentProfileProvider).value;
    final isMe = me?.uid == widget.user.uid;
    final user = widget.user;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
            child: Column(
              children: [
                // Avatar + infos
                Row(
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        DeptAvatar(user: user, size: 72, borderRadius: 22),
                        if (user.isBureauMember)
                          Positioned(
                            bottom: -4, right: -4,
                            child: Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E293B),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              child: const Icon(Icons.verified_rounded,
                                  color: Colors.white, size: 11),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(user.fullName,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w900, fontSize: 18)),
                              ),
                              // Badge Joker
                              if (user.bureauRole == 'Joker')
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF3C7),
                                    borderRadius: BorderRadius.circular(7),
                                  ),
                                  child: const Text('⭐ JOKER', style: TextStyle(
                                      fontSize: 9, fontWeight: FontWeight.w900,
                                      color: Color(0xFFD97706))),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(user.department,
                              style: TextStyle(color: theme.primary,
                                  fontWeight: FontWeight.w700, fontSize: 12)),
                          if (user.isBureauMember && user.bureauRole != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E293B),
                                  borderRadius: BorderRadius.circular(7),
                                ),
                                child: Text(user.bureauRole!,
                                    style: const TextStyle(color: Colors.white,
                                        fontSize: 9, fontWeight: FontWeight.w900)),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1),

                const SizedBox(height: 20),

                // Stats rapides
                Row(
                  children: [
                    _QuickStat(
                      value: '${user.interactionStats?.points ?? 0}',
                      label: 'Points',
                      icon: Icons.auto_awesome_rounded,
                      color: theme.primary,
                    ),
                    const SizedBox(width: 8),
                    _QuickStat(
                      value: '${user.interactionStats?.totalMessages ?? 0}',
                      label: 'Messages',
                      icon: Icons.chat_bubble_rounded,
                      color: const Color(0xFF059669),
                    ),
                    const SizedBox(width: 8),
                    _QuickStat(
                      value: user.badges.isNotEmpty ? user.badges.join(' ') : '—',
                      label: 'Badges',
                      icon: Icons.emoji_events_rounded,
                      color: const Color(0xFFD97706),
                      isEmoji: user.badges.isNotEmpty,
                    ),
                  ],
                ).animate(delay: 100.ms).fadeIn(),

                if (user.bio.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: theme.tinted,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      user.bio,
                      style: TextStyle(color: Colors.grey.shade700,
                          fontSize: 13, height: 1.6, fontWeight: FontWeight.w500),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ).animate(delay: 150.ms).fadeIn(),
                ],

                const SizedBox(height: 24),

                // Boutons action
                Row(
                  children: [
                    // Voir profil complet
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          context.push('/user/${user.uid}');
                        },
                        icon: const Icon(Icons.person_rounded, size: 18),
                        label: const Text('Voir profil',
                            style: TextStyle(fontWeight: FontWeight.w800)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.black87,
                          side: BorderSide(color: Colors.grey.shade200),
                          minimumSize: const Size(0, 50),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ),

                    if (!isMe && !(config?.disableChat ?? false)) ...[
                      const SizedBox(width: 10),
                      // Message direct
                      Expanded(
                        flex: 2,
                        child: FilledButton.icon(
                            onPressed: _isLoading ? null : () => _startConversation(context, ref, user.uid, user),
                            icon: _isLoading 
                                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Icon(Icons.chat_bubble_rounded, size: 18),
                            label: Text(_isLoading ? 'Chargement...' : 'Message',
                              style: TextStyle(fontWeight: FontWeight.w800)),
                          style: FilledButton.styleFrom(
                            backgroundColor: theme.primary,
                            minimumSize: const Size(0, 50),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                          ),
                        ),
                      ),
                    ],
                  ],
                ).animate(delay: 200.ms).fadeIn().slideY(begin: 0.2),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickStat extends StatelessWidget {
  final String value, label;
  final IconData icon;
  final Color color;
  final bool isEmoji;

  const _QuickStat({
    required this.value, required this.label,
    required this.icon, required this.color,
    this.isEmoji = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.12)),
        ),
        child: Column(
          children: [
            isEmoji
                ? Text(value, style: const TextStyle(fontSize: 18))
                : Text(value, style: TextStyle(
                    fontWeight: FontWeight.w900, fontSize: 17, color: color)),
            const SizedBox(height: 3),
            Text(label, style: TextStyle(color: Colors.grey.shade500,
                fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
          ],
        ),
      ),
    );
  }
}
