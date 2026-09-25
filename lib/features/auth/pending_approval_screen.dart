import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_provider.dart';

class PendingApprovalScreen extends ConsumerWidget {
  const PendingApprovalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FF),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.hourglass_top_rounded,
                    size: 64,
                    color: Color(0xFF4F46E5),
                  ),
                ).animate().scale(delay: 200.ms, curve: Curves.easeOutBack),
                const SizedBox(height: 32),
                const Text(
                  'En attente de validation',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                  textAlign: TextAlign.center,
                ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.2),
                const SizedBox(height: 16),
                Text(
                  'Ton inscription a bien été reçue ! Un administrateur doit maintenant valider ton compte avant que tu puisses accéder à l\'application.',
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.2),
                const SizedBox(height: 48),
                OutlinedButton.icon(
                  onPressed: () {
                    ref.read(authNotifierProvider.notifier).signOut();
                  },
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Se déconnecter'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFE11D48),
                    side: const BorderSide(color: Color(0xFFE11D48)),
                    minimumSize: const Size(double.infinity, 54),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ).animate().fadeIn(delay: 600.ms),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
