import 'package:cloud_firestore/cloud_firestore.dart';

enum MessageType { text, image, audio, sticker }

class Message {
  final String id;
  final String senderId;
  final String text;
  final Timestamp createdAt;
  
  final MessageType type;
  final String? mediaUrl;

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
    this.type = MessageType.text,
    this.mediaUrl,
    this.replyToId,
    this.replyToText,
    this.replyToSenderId,
    this.editedAt,
  });

  factory Message.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    // Rétrocompatibilité : si 'type' n'existe pas, on considère que c'est du texte.
    MessageType msgType = MessageType.text;
    final typeStr = data['type'] as String?;
    if (typeStr == 'image') msgType = MessageType.image;
    if (typeStr == 'audio') msgType = MessageType.audio;
    if (typeStr == 'sticker') msgType = MessageType.sticker;

    return Message(
      id: doc.id,
      senderId: data['senderId'] ?? '',
      text: data['text'] ?? '',
      createdAt: data['createdAt'] as Timestamp? ?? Timestamp.now(),
      type: msgType,
      mediaUrl: data['mediaUrl'] as String?,
      replyToId: data['replyToId'] as String?,
      replyToText: data['replyToText'] as String?,
      replyToSenderId: data['replyToSenderId'] as String?,
      editedAt: data['editedAt'] as Timestamp?,
    );
  }
}
