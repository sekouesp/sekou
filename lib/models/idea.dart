import 'package:cloud_firestore/cloud_firestore.dart';

class Idea {
  final String id;
  final String title;
  final String description;
  final String authorId;
  final String authorName;
  final int votesCount;
  final List<String> votedBy;
  final String status; // 'pending', 'planned', 'implemented'
  final Timestamp createdAt;

  Idea({
    required this.id,
    required this.title,
    required this.description,
    required this.authorId,
    required this.authorName,
    required this.votesCount,
    required this.votedBy,
    required this.status,
    required this.createdAt,
  });

  factory Idea.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Idea(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      authorId: data['authorId'] ?? '',
      authorName: data['authorName'] ?? 'Anonyme',
      votesCount: data['votesCount'] ?? 0,
      votedBy: List<String>.from(data['votedBy'] ?? []),
      status: data['status'] ?? 'pending',
      createdAt: data['createdAt'] ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'authorId': authorId,
      'authorName': authorName,
      'votesCount': votesCount,
      'votedBy': votedBy,
      'status': status,
      'createdAt': createdAt,
    };
  }

  Idea copyWith({
    String? id,
    String? title,
    String? description,
    String? authorId,
    String? authorName,
    int? votesCount,
    List<String>? votedBy,
    String? status,
    Timestamp? createdAt,
  }) {
    return Idea(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      votesCount: votesCount ?? this.votesCount,
      votedBy: votedBy ?? this.votedBy,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
