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
  final Map<String, Timestamp> lastReadAt; // uid → dernier instant de lecture
  final List<String> hiddenFor; // uids ayant fermé/masqué la conversation
  final List<String> pinnedBy; // uids ayant épinglé la conversation
  UserProfile? otherUser; // Populated in-app, not from Firestore

  Conversation({
    required this.id,
    required this.participantIds,
    required this.type,
    this.lastMessageAt,
    this.lastMessageText,
    this.lastSenderId,
    this.unreadCounts = const {},
    this.lastReadAt = const {},
    this.hiddenFor = const [],
    this.pinnedBy = const [],
    this.otherUser,
  });

  factory Conversation.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final unreadMap = data['unreadCounts'] as Map<String, dynamic>? ?? {};
    final mappedUnread = unreadMap.map((key, value) => MapEntry(key, (value as num).toInt()));

    final readMap = data['lastReadAt'] as Map<String, dynamic>? ?? {};
    final mappedRead = <String, Timestamp>{};
    readMap.forEach((key, value) {
      if (value is Timestamp) mappedRead[key] = value;
    });

    return Conversation(
      id: doc.id,
      participantIds: List<String>.from(data['participantIds'] ?? []),
      type: data['type'] ?? 'direct',
      lastMessageAt: data['lastMessageAt'] as Timestamp?,
      lastMessageText: data['lastMessageText'],
      lastSenderId: data['lastSenderId'],
      unreadCounts: mappedUnread,
      lastReadAt: mappedRead,
      hiddenFor: List<String>.from(data['hiddenFor'] ?? []),
      pinnedBy: List<String>.from(data['pinnedBy'] ?? []),
    );
  }
}
