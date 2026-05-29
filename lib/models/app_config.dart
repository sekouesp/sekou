import 'package:cloud_firestore/cloud_firestore.dart';

class AppConfig {
  final bool showValues;
  final bool showOath;
  final bool disableChat;
  final bool rankingEnabled;
  final int rankingLimit;
  final bool culturelEnabled;
  final bool annoncesEnabled; // NOUVEAU
  final Map<String, String> departmentLogos;
  final String? communalLogo;
  final Map<String, String> commissionLinks; // NOUVEAU — liens WhatsApp

  const AppConfig({
    this.showValues = true,
    this.showOath = true,
    this.disableChat = false,
    this.rankingEnabled = true,
    this.rankingLimit = 100,
    this.culturelEnabled = true,
    this.annoncesEnabled = true,
    this.departmentLogos = const {},
    this.communalLogo,
    this.commissionLinks = const {},
  });

  factory AppConfig.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return AppConfig(
      showValues: data['showValues'] ?? true,
      showOath: data['showOath'] ?? true,
      disableChat: data['disableChat'] ?? false,
      rankingEnabled: data['rankingEnabled'] ?? true,
      rankingLimit: (data['rankingLimit'] as num?)?.toInt() ?? 100,
      culturelEnabled: data['culturelEnabled'] ?? true,
      annoncesEnabled: data['annoncesEnabled'] ?? true,
      departmentLogos: Map<String, String>.from(data['departmentLogos'] ?? {}),
      communalLogo: data['communalLogo'],
      commissionLinks: Map<String, String>.from(data['commissionLinks'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() => {
    'showValues': showValues,
    'showOath': showOath,
    'disableChat': disableChat,
    'rankingEnabled': rankingEnabled,
    'rankingLimit': rankingLimit,
    'culturelEnabled': culturelEnabled,
    'annoncesEnabled': annoncesEnabled,
    'departmentLogos': departmentLogos,
    if (communalLogo != null) 'communalLogo': communalLogo,
    'commissionLinks': commissionLinks,
  };
}
