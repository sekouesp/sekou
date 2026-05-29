import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});
  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  int _step = 0;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 2000), () {
      if (mounted) setState(() => _step = 1);
    });
    Future.delayed(const Duration(milliseconds: 6000), () {
      if (mounted) setState(() => _step = 2);
    });
    Future.delayed(const Duration(milliseconds: 11000), () {
      if (mounted) context.go('/auth');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // slate-50 exact
      body: Stack(
        children: [
          // Contenu  AnimatedSwitcher = AnimatePresence mode="wait"
          Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, anim) {
                // Exit: opacity + scale 1.1 ; Enter: opacity + y 20
                return FadeTransition(
                  opacity: anim,
                  child: child,
                );
              },
              child: _buildStep(),
            ),
          ),

          // Barre progression  exactement 11s, bg-slate-200, fill blue-600
          Positioned(
            bottom: 48, left: 0, right: 0,
            child: Center(
              child: SizedBox(
                width: 192, // w-48
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: Stack(
                    children: [
                      Container(height: 4, color: const Color(0xFFE2E8F0)),
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: 1.0),
                        duration: const Duration(milliseconds: 11000),
                        curve: Curves.linear,
                        builder: (_, value, __) => FractionallySizedBox(
                          widthFactor: value,
                          alignment: Alignment.centerLeft,
                          child: Container(
                              height: 4,
                              color: const Color(0xFF2563EB)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Skip
          Positioned(
            bottom: 36, right: 20,
            child: TextButton(
              onPressed: () => context.go('/auth'),
              child: Text('Passer →',
                  style: TextStyle(
                      color: Colors.grey.shade400,
                      fontWeight: FontWeight.w700, fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case 0: return const _StepLogo(key: ValueKey('logo'));
      case 1: return const _StepIntro(key: ValueKey('intro'));
      case 2: return const _StepWolof(key: ValueKey('wolof'));
      default: return const SizedBox.shrink(key: ValueKey('empty'));
    }
  }
}

//  Step 0 : Logo + titre
class _StepLogo extends StatelessWidget {
  const _StepLogo({super.key});
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.network(
          AppConstants.logoUrl,
          width: 192, height: 192, // w-48 h-48
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const SizedBox(width: 192, height: 192),
        ).animate()
         .scale(begin: const Offset(0.8, 0.8), duration: 600.ms,
             curve: Curves.easeOut)
         .fadeIn(duration: 500.ms),
        const SizedBox(height: 32),
        const Text('SEKOU',
            style: TextStyle(
              fontSize: 22, fontWeight: FontWeight.w900,
              letterSpacing: 8, color: Color(0xFF1E293B),
            )).animate(delay: 150.ms).fadeIn(),
      ],
    );
  }
}

//  Step 1 : Promotion ESP 2026
class _StepIntro extends StatelessWidget {
  const _StepIntro({super.key});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // "Promotion ESP 2026"
          const Text(
            'Promotion ESP 2026',
            style: TextStyle(
              fontSize: 38, fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A), letterSpacing: -1, height: 1.1,
            ),
            textAlign: TextAlign.center,
          ).animate()
           .fadeIn(duration: 500.ms)
           .slideY(begin: 0.15, curve: Curves.easeOut),

          const SizedBox(height: 24),

          Text.rich(
            const TextSpan(
              style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700,
                color: Color(0xFF64748B),
                letterSpacing: 3,
              ),
              children: [
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: Text('E',
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900,
                          color: Color(0xFF2563EB), letterSpacing: 0)),
                ),
                TextSpan(text: 'xcellence dans la '),
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: Text('S',
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900,
                          color: Color(0xFF2563EB), letterSpacing: 0)),
                ),
                TextSpan(text: 'olidarité et le '),
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: Text('P',
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900,
                          color: Color(0xFF2563EB), letterSpacing: 0)),
                ),
                TextSpan(text: 'artage'),
              ],
            ),
            textAlign: TextAlign.center,
          ).animate(delay: 200.ms).fadeIn(),
        ],
      ),
    );
  }
}

//  Step 2 : Citation Wolof
class _StepWolof extends StatelessWidget {
  const _StepWolof({super.key});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text.rich(
            TextSpan(
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w300,
                color: Color(0xFF1E293B),
                fontStyle: FontStyle.italic,
                height: 1.6,
              ),
              children: [
                const TextSpan(text: '"DUT 1 est ce que '),
                const TextSpan(
                  text: 'khamante ngen',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF2563EB),
                  ),
                ),
                const TextSpan(text: ' sen birr ?"'),
              ],
            ),
            textAlign: TextAlign.center,
          ).animate()
           .scale(begin: const Offset(0.9, 0.9), duration: 1500.ms,
               curve: Curves.easeOut)
           .fadeIn(duration: 800.ms),

          const SizedBox(height: 32),

          const Text('UN & INDIVISIBLE',
              style: TextStyle(
                fontSize: 8, fontWeight: FontWeight.w900,
                letterSpacing: 5, color: Color(0xFF94A3B8),
              )).animate(delay: 400.ms).fadeIn(),
        ],
      ),
    );
  }
}
