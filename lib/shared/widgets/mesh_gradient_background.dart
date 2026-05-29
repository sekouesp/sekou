import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';

class MeshGradientBackground extends StatefulWidget {
  final Color primaryColor;
  final Widget child;

  const MeshGradientBackground({
    super.key,
    required this.primaryColor,
    required this.child,
  });

  @override
  State<MeshGradientBackground> createState() => _MeshGradientBackgroundState();
}

class _MeshGradientBackgroundState extends State<MeshGradientBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Variations based on the primary color
    final color1 = widget.primaryColor.withOpacity(0.15);
    final color2 = _lighten(widget.primaryColor, 0.2).withOpacity(0.12);
    final color3 = _darken(widget.primaryColor, 0.1).withOpacity(0.10);

    return Stack(
      children: [
        // Base light background
        Container(color: const Color(0xFFF5F7FF)),

        // Animated Orb 1
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Positioned(
              top: MediaQuery.of(context).size.height * 0.1 +
                  sin(_controller.value * 2 * pi) * 50,
              left: MediaQuery.of(context).size.width * 0.1 +
                  cos(_controller.value * 2 * pi) * 30,
              child: _buildOrb(color1, 300),
            );
          },
        ),

        // Animated Orb 2
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Positioned(
              bottom: MediaQuery.of(context).size.height * 0.2 +
                  cos(_controller.value * 2 * pi) * 40,
              right: MediaQuery.of(context).size.width * 0.1 +
                  sin(_controller.value * 2 * pi) * 50,
              child: _buildOrb(color2, 250),
            );
          },
        ),

        // Animated Orb 3
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Positioned(
              top: MediaQuery.of(context).size.height * 0.4 +
                  sin(_controller.value * pi) * 60,
              right: MediaQuery.of(context).size.width * 0.3 +
                  cos(_controller.value * pi) * 40,
              child: _buildOrb(color3, 350),
            );
          },
        ),

        // The blur layer that mixes the orbs
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
            child: Container(color: Colors.transparent),
          ),
        ),

        // The actual content (transparent pages)
        widget.child,
      ],
    );
  }

  Widget _buildOrb(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }

  Color _lighten(Color color, [double amount = .1]) {
    assert(amount >= 0 && amount <= 1);
    final hsl = HSLColor.fromColor(color);
    final hslLight =
        hsl.withLightness((hsl.lightness + amount).clamp(0.0, 1.0));
    return hslLight.toColor();
  }

  Color _darken(Color color, [double amount = .1]) {
    assert(amount >= 0 && amount <= 1);
    final hsl = HSLColor.fromColor(color);
    final hslDark = hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));
    return hslDark.toColor();
  }
}
