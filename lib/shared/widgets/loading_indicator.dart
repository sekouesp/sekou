import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/constants.dart';

class AppLoadingIndicator extends StatelessWidget {
  const AppLoadingIndicator({super.key});
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.network(AppConstants.logoUrl, width: 80, height: 80)
            .animate(onPlay: (c) => c.repeat())
            .scale(begin: const Offset(0.95, 0.95), end: const Offset(1.05, 1.05),
                duration: 900.ms, curve: Curves.easeInOut)
            .then()
            .scale(begin: const Offset(1.05, 1.05), end: const Offset(0.95, 0.95),
                duration: 900.ms, curve: Curves.easeInOut),
        const SizedBox(height: 24),
        const CircularProgressIndicator(strokeWidth: 2),
      ],
    );
  }
}
