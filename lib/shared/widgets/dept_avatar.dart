import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../core/theme/dept_theme.dart';
import '../../models/user_profile.dart';

class DeptAvatar extends StatelessWidget {
  final UserProfile user;
  final double size;
  final double borderRadius;

  const DeptAvatar({
    super.key,
    required this.user,
    this.size = 48,
    this.borderRadius = 14,
  });

  @override
  Widget build(BuildContext context) {
    final theme = DeptTheme.of(user.department);
    return Container(
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
