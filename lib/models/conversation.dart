import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_profile.dart';

class Conversation {
  final String id;
  final List<String> participantIds;
  final String type; // "direct" | "group"
  final Timestamp? lastMessageAt;
  final String? lastMessageText;
  final String? lastSenderId;
  final Map<String, int> unreadCounts;
  UserProfile? otherUser; // Populated in-app, not from Firestore

  Conversation({
    required this.id,
    required this.participantIds,
    required this.type,
    this.lastMessageAt,
    this.lastMessageText,
    this.lastSenderId,
    this.unreadCounts = const {},
    this.otherUser,
  });

  factory Conversation.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final unreadMap = data['unreadCounts'] as Map<String, dynamic>? ?? {};
    final mappedUnread = unreadMap.map((key, value) => MapEntry(key, (value as num).toInt()));

    return Conversation(
      id: doc.id,
      participantIds: List<String>.from(data['participantIds'] ?? []),
      type: data['type'] ?? 'direct',
      lastMessageAt: data['lastMessageAt'] as Timestamp?,
      lastMessageText: data['lastMessageText'],
      lastSenderId: data['lastSenderId'],
      unreadCounts: mappedUnread,
    );
  }
}
