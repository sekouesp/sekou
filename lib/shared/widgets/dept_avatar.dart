import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../core/theme/dept_theme.dart';
import '../../models/user_profile.dart';

class DeptAvatar extends StatelessWidget {
  final UserProfile user;
  final double size;
  final double borderRadius;
  /// Affiche une pastille verte « en ligne » en bas-droite si vrai.
  final bool online;

  const DeptAvatar({
    super.key,
    required this.user,
    this.size = 48,
    this.borderRadius = 14,
    this.online = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = DeptTheme.of(user.department);
    final avatar = Container(
      width: size, height: size,
      decoration: BoxDecoration(
        color: theme.primary,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      clipBehavior: Clip.antiAlias,
      child: user.photoUrl.isNotEmpty
          ? CachedNetworkImage(
              imageUrl: user.photoUrl,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => _initials(theme),
            )
          : _initials(theme),
    );
    if (!online) return avatar;
    final dot = (size * 0.28).clamp(10.0, 16.0);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        avatar,
        Positioned(
          right: -1, bottom: -1,
          child: Container(
            width: dot, height: dot,
            decoration: BoxDecoration(
              color: const Color(0xFF22C55E),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _initials(DeptTheme theme) => Center(
    child: Text(
      user.initials,
      style: TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w900,
        fontSize: size * 0.35,
      ),
    ),
  );
}

/// Petite pastille « NOUVEAU » pour signaler un membre récemment arrivé.
class NewBadge extends StatelessWidget {
  const NewBadge({super.key});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF059669),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Text(
        'NOUVEAU',
        style: TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.w900, letterSpacing: 1),
      ),
    );
  }
}

class SmallBureauBadge extends StatelessWidget {
  const SmallBureauBadge({super.key});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Text(
        'BUREAU',
        style: TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.w900, letterSpacing: 1),
      ),
    );
  }
}
