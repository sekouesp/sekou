import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Wraps a child with a staggered fade+slide animation.
/// Use inside ListView.builder for automatic entry animations.
class AnimatedListItem extends StatelessWidget {
  final Widget child;
  final int index;
  final Duration delay;
  final Duration duration;

  const AnimatedListItem({
    super.key,
    required this.child,
    required this.index,
    this.delay = const Duration(milliseconds: 40),
    this.duration = const Duration(milliseconds: 350),
  });

  @override
  Widget build(BuildContext context) {
    return child
        .animate(delay: delay * index)
        .fadeIn(duration: duration, curve: Curves.easeOut)
        .slideX(begin: -0.04, curve: Curves.easeOut);
  }
}

/// Standard bottom sheet drag handle.
class SheetDragHandle extends StatelessWidget {
  const SheetDragHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: 12, bottom: 8),
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: Theme.of(context).dividerColor,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

/// Hero wrapper for profile photos.
class HeroPhoto extends StatelessWidget {
  final String tag;
  final Widget child;

  const HeroPhoto({super.key, required this.tag, required this.child});

  @override
  Widget build(BuildContext context) {
    return Hero(tag: tag, child: child);
  }
}
