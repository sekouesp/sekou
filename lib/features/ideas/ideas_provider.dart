import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/idea.dart';

final ideasProvider = AsyncNotifierProvider<IdeasNotifier, List<Idea>>(IdeasNotifier.new);

class IdeasNotifier extends AsyncNotifier<List<Idea>> {
  @override
  Future<List<Idea>> build() async {
    final snap = await FirebaseFirestore.instance
        .collection('ideas')
        .orderBy('votesCount', descending: true)
        .orderBy('createdAt', descending: true)
        .get();
    return snap.docs.map(Idea.fromFirestore).toList();
  }

  /// Met à jour localement une idée (appelé par le Bus Supabase)
  void updateIdeaLocal(Idea updatedIdea) {
    if (state.value == null) return;
    
    final currentList = state.value!;
    final index = currentList.indexWhere((i) => i.id == updatedIdea.id);
    
    if (index != -1) {
      final newList = [...currentList];
      newList[index] = updatedIdea;
      // Re-trier la liste par votes
      newList.sort((a, b) {
        final cmp = b.votesCount.compareTo(a.votesCount);
        if (cmp != 0) return cmp;
        return b.createdAt.compareTo(a.createdAt);
      });
      state = AsyncValue.data(newList);
    } else {
      // Nouvelle idée
      final newList = [...currentList, updatedIdea];
      newList.sort((a, b) {
        final cmp = b.votesCount.compareTo(a.votesCount);
        if (cmp != 0) return cmp;
        return b.createdAt.compareTo(a.createdAt);
      });
      state = AsyncValue.data(newList);
    }
  }

  Future<void> addIdea(String title, String description, String authorId, String authorName) async {
    final newIdea = Idea(
      id: '',
      title: title,
      description: description,
      authorId: authorId,
      authorName: authorName,
      votesCount: 1,
      votedBy: [authorId], // L'auteur vote automatiquement pour son idée
      status: 'pending',
      createdAt: Timestamp.now(),
    );

    final docRef = await FirebaseFirestore.instance.collection('ideas').add(newIdea.toMap());
    
    // On met à jour localement pour que ce soit instantané pour l'auteur
    final ideaWithId = newIdea.copyWith(id: docRef.id);
    updateIdeaLocal(ideaWithId);
  }

  Future<void> toggleVote(Idea idea, String uid) async {
    final hasVoted = idea.votedBy.contains(uid);
    final docRef = FirebaseFirestore.instance.collection('ideas').doc(idea.id);

    if (hasVoted) {
      // Retirer le vote
      await docRef.update({
        'votedBy': FieldValue.arrayRemove([uid]),
        'votesCount': FieldValue.increment(-1),
      });
    } else {
      // Ajouter le vote
      await docRef.update({
        'votedBy': FieldValue.arrayUnion([uid]),
        'votesCount': FieldValue.increment(1),
      });
    }
  }
}
