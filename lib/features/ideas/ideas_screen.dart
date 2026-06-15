import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../providers/auth_provider.dart';
import '../../shared/widgets/loading_indicator.dart';
import '../../core/services/realtime_bus_service.dart';
import 'ideas_provider.dart';

class IdeasScreen extends ConsumerWidget {
  const IdeasScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ideasAsync = ref.watch(ideasProvider);
    final myProfile = ref.watch(currentProfileProvider).value;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('💡 Boîte à Idées', style: TextStyle(fontWeight: FontWeight.w900)),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        centerTitle: true,
      ),
      body: ideasAsync.when(
        loading: () => const Center(child: AppLoadingIndicator()),
        error: (e, _) => Center(child: Text('Erreur: $e')),
        data: (ideas) {
          if (ideas.isEmpty) {
            return _buildEmptyState(context);
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(ideasProvider);
              await ref.read(ideasProvider.future);
            },
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: ideas.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final idea = ideas[index];
                final hasVoted = myProfile != null && idea.votedBy.contains(myProfile.uid);

                return _IdeaCard(
                  idea: idea,
                  hasVoted: hasVoted,
                  onVote: () async {
                    HapticFeedback.lightImpact();
                    if (myProfile != null) {
                      await ref.read(ideasProvider.notifier).toggleVote(idea, myProfile.uid);
                      ref.read(realtimeBusProvider).broadcastIdeaUpdate(idea.id);
                    }
                  },
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddIdeaModal(context, ref, myProfile?.uid ?? '', myProfile?.fullName ?? 'Anonyme'),
        backgroundColor: const Color(0xFF4F46E5),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Proposer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('💡', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          const Text('Aucune idée pour le moment',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 8),
          Text('Sois le premier à proposer une\namélioration pour l\'application SEKOU !',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600)),
        ],
      ),
    );
  }

  void _showAddIdeaModal(BuildContext context, WidgetRef ref, String uid, String name) {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20, right: 20, top: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('💡 Nouvelle Idée', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
              const SizedBox(height: 20),
              TextField(
                controller: titleCtrl,
                decoration: InputDecoration(
                  labelText: 'Titre (court et clair)',
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: 'Détails de ton idée...',
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  onPressed: () async {
                    if (titleCtrl.text.trim().isEmpty) return;
                    HapticFeedback.mediumImpact();
                    context.pop();
                    final newIdeaId = await ref.read(ideasProvider.notifier).addIdea(
                      titleCtrl.text.trim(),
                      descCtrl.text.trim(),
                      uid,
                      name,
                    );
                    ref.read(realtimeBusProvider).broadcastIdeaUpdate(newIdeaId);
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Soumettre', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }
}

class _IdeaCard extends StatelessWidget {
  final dynamic idea; // Using dynamic because of import issues in this snippet context
  final bool hasVoted;
  final VoidCallback onVote;

  const _IdeaCard({required this.idea, required this.hasVoted, required this.onVote});

  @override
  Widget build(BuildContext context) {
    Color statusColor = Colors.grey;
    String statusText = 'Nouveau';
    if (idea.status == 'planned') {
      statusColor = Colors.orange;
      statusText = 'Prévu';
    } else if (idea.status == 'implemented') {
      statusColor = Colors.green;
      statusText = 'Réalisé !';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Tooltip(
            message: hasVoted ? 'Retirer mon vote' : 'Voter pour cette idée',
            child: Material(
              color: hasVoted ? const Color(0xFF4F46E5).withOpacity(0.1) : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: onVote,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: hasVoted ? const Color(0xFF4F46E5).withOpacity(0.3) : Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        hasVoted ? Icons.favorite_rounded : Icons.favorite_outline_rounded,
                        color: hasVoted ? const Color(0xFF4F46E5) : Colors.grey.shade400,
                        size: 24,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${idea.votesCount}',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          color: hasVoted ? const Color(0xFF4F46E5) : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Contenu
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(idea.title,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, height: 1.2)),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        statusText,
                        style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  idea.description,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14, height: 1.4),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.person_rounded, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      idea.authorName,
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    Text(
                      timeago.format(idea.createdAt.toDate(), locale: 'fr'),
                      style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
