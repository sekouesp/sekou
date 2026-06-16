import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { user, admin, superAdmin }

class InteractionStats {
  final int points;
  final int startedConversations;
  final int totalMessages;
  final List<String> crossDeptInteractions; // inter-département (remplace bureauInteractions)

  const InteractionStats({
    this.points = 0,
    this.startedConversations = 0,
    this.totalMessages = 0,
    this.crossDeptInteractions = const [],
  });

  factory InteractionStats.fromMap(Map<String, dynamic> map) => InteractionStats(
    points: (map['points'] as num?)?.toInt() ?? 0,
    startedConversations: (map['startedConversations'] as num?)?.toInt() ?? 0,
    totalMessages: (map['totalMessages'] as num?)?.toInt() ?? 0,
    crossDeptInteractions: List<String>.from(
      map['crossDeptInteractions'] ?? map['bureauInteractions'] ?? []),
  );

  Map<String, dynamic> toMap() => {
    'points': points,
    'startedConversations': startedConversations,
    'totalMessages': totalMessages,
    'crossDeptInteractions': crossDeptInteractions,
  };
}

class UserProfile {
  final String uid;
  final String firstName;
  final String lastName;
  final String alias;
  final String photoUrl;
  final String department;
  final String bio;
  final String hobbies;
  final UserRole role;
  final bool isBureauMember;
  final String? bureauRole;
  final bool isLocked;
  final bool isApproved;
  final List<String> commissions;
  final InteractionStats? interactionStats;
  final List<String> badges;
  final Timestamp? lastReadAnnouncementsAt;
  final Timestamp? createdAt;
  final Timestamp? approvedAt;

  const UserProfile({
    required this.uid,
    required this.firstName,
    required this.lastName,
    this.alias = '',
    this.photoUrl = '',
    required this.department,
    this.bio = '',
    this.hobbies = '',
    this.role = UserRole.user,
    this.isBureauMember = false,
    this.bureauRole,
    this.isLocked = false,
    this.isApproved = false,
    this.commissions = const [],
    this.interactionStats,
    this.badges = const [],
    this.lastReadAnnouncementsAt,
    this.createdAt,
    this.approvedAt,
  });

  factory UserProfile.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserProfile(
      uid: doc.id,
      firstName: data['firstName'] ?? '',
      lastName: data['lastName'] ?? '',
      alias: data['alias'] ?? '',
      photoUrl: data['photoUrl'] ?? '',
      department: data['department'] ?? '',
      bio: data['bio'] ?? '',
      hobbies: data['hobbies'] ?? '',
      role: _parseRole(data['role']),
      isBureauMember: data['isBureauMember'] ?? false,
      bureauRole: data['bureauRole'],
      isLocked: data['isLocked'] ?? false,
      isApproved: data['isApproved'] ?? true, // Pour rétrocompatibilité, les anciens users sont validés par défaut
      commissions: List<String>.from(data['commissions'] ?? []),
      interactionStats: data['interactionStats'] != null
          ? InteractionStats.fromMap(data['interactionStats'] as Map<String, dynamic>)
          : null,
      badges: List<String>.from(data['badges'] ?? []),
      lastReadAnnouncementsAt: data['lastReadAnnouncementsAt'] as Timestamp?,
      createdAt: data['createdAt'] as Timestamp?,
      approvedAt: data['approvedAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() => {
    'firstName': firstName,
    'lastName': lastName,
    'alias': alias,
    'photoUrl': photoUrl,
    'department': department,
    'bio': bio,
    'hobbies': hobbies,
    'role': role == UserRole.superAdmin ? 'super-admin' : role.name,
    'isBureauMember': isBureauMember,
    if (bureauRole != null) 'bureauRole': bureauRole,
    'isLocked': isLocked,
    'isApproved': isApproved,
    'commissions': commissions,
    if (interactionStats != null) 'interactionStats': interactionStats!.toMap(),
    'badges': badges,
    if (lastReadAnnouncementsAt != null) 'lastReadAnnouncementsAt': lastReadAnnouncementsAt,
    if (createdAt != null) 'createdAt': createdAt,
    if (approvedAt != null) 'approvedAt': approvedAt,
  };

  static UserRole _parseRole(dynamic role) {
    if (role == 'admin') return UserRole.admin;
    if (role == 'super-admin') return UserRole.superAdmin;
    return UserRole.user;
  }

  String get fullName => '$firstName $lastName';
  String get initials =>
      '${firstName.isNotEmpty ? firstName[0].toUpperCase() : ''}'
      '${lastName.isNotEmpty ? lastName[0].toUpperCase() : ''}';
  bool get isAdmin => role == UserRole.admin || role == UserRole.superAdmin;
  bool get isSuperAdmin => role == UserRole.superAdmin;

  /// Nombre de jours pendant lesquels un membre est considéré « nouveau ».
  static const newcomerDays = 14;

  /// Vrai si le membre a été approuvé (ou créé) récemment → tag « Nouveau ».
  bool get isNewcomer {
    final ts = approvedAt ?? createdAt;
    if (ts == null) return false;
    return DateTime.now().difference(ts.toDate()).inDays <= newcomerDays;
  }

  UserProfile copyWith({
    String? firstName, String? lastName, String? alias, String? photoUrl,
    String? department, String? bio, String? hobbies,
    UserRole? role, bool? isBureauMember, String? bureauRole,
    bool? isLocked, bool? isApproved, List<String>? commissions,
    InteractionStats? interactionStats, List<String>? badges,
    Timestamp? lastReadAnnouncementsAt, Timestamp? createdAt, Timestamp? approvedAt,
  }) => UserProfile(
    uid: uid,
    firstName: firstName ?? this.firstName,
    lastName: lastName ?? this.lastName,
    alias: alias ?? this.alias,
    photoUrl: photoUrl ?? this.photoUrl,
    department: department ?? this.department,
    bio: bio ?? this.bio,
    hobbies: hobbies ?? this.hobbies,
    role: role ?? this.role,
    isBureauMember: isBureauMember ?? this.isBureauMember,
    bureauRole: bureauRole ?? this.bureauRole,
    isLocked: isLocked ?? this.isLocked,
    isApproved: isApproved ?? this.isApproved,
    commissions: commissions ?? this.commissions,
    interactionStats: interactionStats ?? this.interactionStats,
    badges: badges ?? this.badges,
    lastReadAnnouncementsAt: lastReadAnnouncementsAt ?? this.lastReadAnnouncementsAt,
    createdAt: createdAt ?? this.createdAt,
    approvedAt: approvedAt ?? this.approvedAt,
  );
}
