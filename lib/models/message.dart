import 'package:cloud_firestore/cloud_firestore.dart';

class Message {
  final String id;
  final String senderId;
  final String text;
  final Timestamp createdAt;

  /// Message cité (réponse). `null` si ce message n'est pas une réponse.
  final String? replyToId;
  final String? replyToText;
  final String? replyToSenderId;

  /// Non nul si le message a été modifié après envoi.
  final Timestamp? editedAt;

  const Message({
    required this.id,
    required this.senderId,
    required this.text,
    required this.createdAt,
    this.replyToId,
    this.replyToText,
    this.replyToSenderId,
    this.editedAt,
  });

  factory Message.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Message(
      id: doc.id,
      senderId: data['senderId'] ?? '',
      text: data['text'] ?? '',
      createdAt: data['createdAt'] as Timestamp? ?? Timestamp.now(),
      replyToId: data['replyToId'] as String?,
      replyToText: data['replyToText'] as String?,
      replyToSenderId: data['replyToSenderId'] as String?,
      editedAt: data['editedAt'] as Timestamp?,
    );
  }
}
