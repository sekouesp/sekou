import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../models/conversation.dart';
import '../../models/user_profile.dart';
import '../../providers/auth_provider.dart';
import '../../providers/config_provider.dart';
import '../../shared/widgets/dept_avatar.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/loading_indicator.dart';

final _convProvider = StreamProvider.autoDispose<List<Conversation>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value([]);
  return FirebaseFirestore.instance
      .collection('conversations')
      .where('participantIds', arrayContains: uid)
      .orderBy('lastMessageAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(Conversation.fromFirestore).toList());
});

class ConversationsScreen extends ConsumerStatefulWidget {
  const ConversationsScreen({super.key});

  @override
  ConsumerState<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends ConsumerState<ConversationsScreen> {
  String _search = '';
  bool _filterUnread = false;

  void _showBroadcastSheet(BuildContext context, WidgetRef ref) {
    final titleCtrl = TextEditingController();
    final textCtrl = TextEditingController();
    String type = 'general';
    String dept = '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            left: 20, right: 20, top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.campaign_rounded, color: Color(0xFF1E293B), size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Text('Broadcast rapide',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                controller: titleCtrl,
                style: const TextStyle(fontWeight: FontWeight.w700),
                decoration: _inputDecor('Titre'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: textCtrl,
                maxLines: 3,
                style: const TextStyle(fontWeight: FontWeight.w600),
                decoration: _inputDecor('Message'),
              ),
              const SizedBox(height: 12),
              // Type chips
              Wrap(
                spacing: 6,
                children: ['general', 'urgent', 'event', 'info'].map((t) =>
                  ChoiceChip(
                    label: Text(t.toUpperCase(),
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900)),
                    selected: type == t,
                    onSelected: (_) => setState(() => type = t),
                    selectedColor: _typeColor(t).withOpacity(0.15),
                    labelStyle: TextStyle(color: type == t ? _typeColor(t) : Colors.grey),
                  )).toList(),
              ),
              const SizedBox(height: 10),
              // Dept filter
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade200),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: dept,
                    isExpanded: true,
                    style: const TextStyle(color: Colors.black87,
                        fontWeight: FontWeight.w600, fontSize: 13, fontFamily: 'Inter'),
                    items: [
                      const DropdownMenuItem(value: '', child: Text('📢 Tous les départements')),
                      ...['Génie Informatique','Génie Civil','Génie Électrique',
                          'Génie Mécanique','Génie Chimique et Biologie Appliquée','Gestion']
                        .map((d) => DropdownMenuItem(value: d, child: Text(d))),
                    ],
                    onChanged: (v) => setState(() => dept = v ?? ''),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF1E293B),
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () async {
                    if (titleCtrl.text.isEmpty || textCtrl.text.isEmpty) return;
                    await FirebaseFirestore.instance.collection('broadcasts').add({
                      'title': titleCtrl.text.trim(),
                      'text': textCtrl.text.trim(),
                      'type': type,
                      if (dept.isNotEmpty) 'filterDept': dept,
                      'createdAt': FieldValue.serverTimestamp(),
                    });
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  icon: const Icon(Icons.send_rounded),
                  label: const Text('ENVOYER',
                      style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecor(String label) => InputDecoration(
    labelText: label,
    filled: true,
    fillColor: const Color(0xFFF5F7FF),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade200)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade200)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF1E293B), width: 2)),
  );

  Color _typeColor(String t) {
    switch (t) {
      case 'urgent': return const Color(0xFFE11D48);
      case 'event': return const Color(0xFF4F46E5);
      case 'info': return const Color(0xFF0891B2);
      default: return const Color(0xFF059669);
    }
  }

  @override
  Widget build(BuildContext context) {
    final convsAsync = ref.watch(_convProvider);
    final usersAsync = ref.watch(allUsersProvider);
    final profileAsync = ref.watch(currentProfileProvider);
    final config = ref.watch(appConfigProvider).value;

    if (config?.disableChat == true) {
      return const Scaffold(
        body: EmptyState(
          icon: Icons.chat_bubble_outline_rounded,
          title: 'Chat désactivé',
          subtitle: 'Le bureau a temporairement désactivé la messagerie.',
        ),
      );
    }

    final isAdmin = ref.watch(currentProfileProvider).value?.isAdmin ?? false;

    return Scaffold(
      backgroundColor: Colors.transparent, // pageBg appliqué via Shell
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: () => _showBroadcastSheet(context, ref),
              icon: const Icon(Icons.campaign_rounded),
              label: const Text('Broadcast',
                  style: TextStyle(fontWeight: FontWeight.w800)),
              backgroundColor: const Color(0xFF1E293B),
              foregroundColor: Colors.white,
            )
          : null,
      body: convsAsync.when(
        loading: () => const Center(child: AppLoadingIndicator()),
        error: (e, _) => Center(child: Text('Erreur: $e')),
        data: (convs) {
          final allUsers = usersAsync.value ?? [];
          final me = profileAsync.value;
          if (me == null) return const SizedBox.shrink();

          // Enrich conversations with other user profile
          for (final conv in convs) {
            final otherId = conv.participantIds.firstWhere(
              (id) => id != me.uid, orElse: () => '');
            conv.otherUser = allUsers.cast<UserProfile?>()
                .firstWhere((u) => u?.uid == otherId, orElse: () => null);
          }

          final validConvs = convs.where((c) => c.otherUser != null).toList();

          if (validConvs.isEmpty) {
            return const EmptyState(
              icon: Icons.chat_bubble_outline_rounded,
              title: 'Aucune conversation',
              subtitle: 'Contacte un étudiant depuis l\'annuaire pour commencer.',
            );
          }

          // Filtres : recherche par nom de l'interlocuteur + non-lus
          final q = _search.trim().toLowerCase();
          final filtered = validConvs.where((c) {
            final matchSearch = q.isEmpty ||
                (c.otherUser?.fullName.toLowerCase().contains(q) ?? false);
            final matchUnread =
                !_filterUnread || ((c.unreadCounts[me.uid] ?? 0) > 0);
            return matchSearch && matchUnread;
          }).toList();

          return Column(
            children: [
              _buildSearchFilterBar(),
              Expanded(
                child: filtered.isEmpty
                    ? EmptyState(
                        icon: _filterUnread
                            ? Icons.mark_chat_read_outlined
                            : Icons.search_off_rounded,
                        title: _filterUnread
                            ? 'Aucun message non lu'
                            : 'Aucun résultat',
                        subtitle: _filterUnread
                            ? 'Toutes tes conversations sont à jour.'
                            : 'Aucune conversation ne correspond à ta recherche.',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(
                            vertical: 16, horizontal: 16),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, i) {
                          final conv = filtered[i];
              final other = conv.otherUser;
              final isMe = conv.lastSenderId == me.uid;
              final ts = conv.lastMessageAt?.toDate();
              final timeStr = ts != null ? timeago.format(ts, locale: 'fr') : '';
              final unreadCount = conv.unreadCounts[me.uid] ?? 0;
              // « Vu » : mon dernier message a été lu par l'autre (son compteur = 0)
              final otherUid = conv.participantIds.firstWhere(
                  (id) => id != me.uid, orElse: () => '');
              final otherHasRead = isMe &&
                  conv.lastMessageText != null &&
                  (conv.unreadCounts[otherUid] ?? 0) == 0;

              return Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.6), // web: bg-white/80
                  borderRadius: BorderRadius.circular(16), // rounded-2xl
                  border: Border.all(color: const Color(0xFFF1F5F9)), // border-slate-100
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
                  ],
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: other != null
                      ? Stack(
                          clipBehavior: Clip.none,
                          children: [
                            DeptAvatar(user: other, size: 54),
                            if (other.isBureauMember)
                              Positioned(
                                bottom: -2, right: -2,
                                child: Container(
                                  width: 16, height: 16,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1E293B),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 1.5),
                                  ),
                                  child: const Icon(Icons.verified_rounded, color: Colors.white, size: 8),
                                ),
                              ),
                          ],
                        )
                      : const CircleAvatar(child: Icon(Icons.person_rounded)),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          other?.fullName ?? 'Utilisateur supprimé',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(timeStr, style: TextStyle(color: Colors.grey.shade400, fontSize: 11,
                          fontWeight: FontWeight.w600)),
                    ],
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        if (isMe) ...[
                          Icon(
                            otherHasRead ? Icons.done_all_rounded : Icons.done_rounded,
                            size: 15,
                            color: otherHasRead
                                ? const Color(0xFF38BDF8)
                                : Colors.grey.shade500,
                          ),
                          const SizedBox(width: 3),
                        ],
                        Expanded(
                          child: Text(
                            conv.lastMessageText ?? '',
                            style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 13,
                                fontWeight: FontWeight.w500),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  trailing: unreadCount > 0
                      ? Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Color(0xFFEF4444), // Badge rouge clair
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            unreadCount > 9 ? '9+' : '$unreadCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        )
                      : null,
                  onTap: () => context.push('/chat/${conv.id}', extra: {
                    'otherName': other?.fullName ?? '',
                    'otherDept': other?.department ?? '',
                    'otherUid': other?.uid ?? '',
                    'isBureau': other?.isBureauMember ?? false,
                  }),
                ),
              ).animate(delay: Duration(milliseconds: 40 * i)).fadeIn(duration: 300.ms).slideX(begin: -0.05);
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Barre de recherche + filtre « non lus » en haut de la liste.
  Widget _buildSearchFilterBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              onChanged: (v) => setState(() => _search = v),
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Rechercher une conversation...',
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                filled: true,
                fillColor: Colors.white.withOpacity(0.7),
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
                  borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 2),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Bascule « non lus »
          Material(
            color: _filterUnread ? const Color(0xFF4F46E5) : Colors.white.withOpacity(0.7),
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => setState(() => _filterUnread = !_filterUnread),
              child: Container(
                height: 46,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _filterUnread ? const Color(0xFF4F46E5) : Colors.grey.shade200,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.mark_chat_unread_rounded,
                      size: 18,
                      color: _filterUnread ? Colors.white : Colors.grey.shade600,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Non lus',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: _filterUnread ? Colors.white : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
