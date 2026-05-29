import 'package:cloud_firestore/cloud_firestore.dart';

class Sound {
  final String id;
  final String name;
  final String url;
  final String type; // "communal" | "department"
  final String? department;
  final Timestamp createdAt;
  final List<String> lyrics;

  const Sound({
    required this.id,
    required this.name,
    required this.url,
    required this.type,
    this.department,
    required this.createdAt,
    this.lyrics = const [],
  });

  factory Sound.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Sound(
      id: doc.id,
      name: data['name'] ?? '',
      url: data['url'] ?? '',
      type: data['type'] ?? 'communal',
      department: data['department'],
      createdAt: data['createdAt'] as Timestamp? ?? Timestamp.now(),
      lyrics: List<String>.from(data['lyrics'] ?? []),
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'url': url,
    'type': type,
    if (department != null) 'department': department,
    'createdAt': createdAt,
    'lyrics': lyrics,
  };
}
