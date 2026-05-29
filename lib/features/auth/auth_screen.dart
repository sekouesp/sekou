import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../core/constants.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _loading = false;
  String? _error;

  Future<void> _signInWithGoogle() async {
    setState(() { _loading = true; _error = null; });
    try {
      if (kIsWeb) {
        // Sur le Web, on utilise signInWithPopup natif à Firebase Auth
        final provider = GoogleAuthProvider();
        await FirebaseAuth.instance.signInWithPopup(provider);
      } else {
        // Sur Mobile, on passe par le package google_sign_in
        final googleUser = await GoogleSignIn().signIn();
        if (googleUser == null) {
          setState(() => _loading = false);
          return;
        }
        final googleAuth = await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        await FirebaseAuth.instance.signInWithCredential(credential);
      }
    } catch (e) {
      debugPrint('Erreur Google Sign-In: $e');
      setState(() {
        _error = 'Connexion impossible. Réessaie.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FF),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.06),
                        blurRadius: 24, offset: const Offset(0, 8)),
                  ],
                ),
                child: Image.network(AppConstants.logoUrl, width: 88, height: 88),
              ).animate().scale(begin: const Offset(0.7, 0.7),
                  duration: 700.ms, curve: Curves.elasticOut),

              const SizedBox(height: 32),

              const Text(
                'SEKOU',
                style: TextStyle(
                  fontSize: 30, fontWeight: FontWeight.w900,
                  letterSpacing: -0.5, fontStyle: FontStyle.italic,
                ),
              ).animate(delay: 200.ms).fadeIn().slideY(begin: 0.2),

              const SizedBox(height: 56),

              // Google Sign-In button
              FilledButton(
                onPressed: _loading ? null : _signInWithGoogle,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 58),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18)),
                ),
                child: _loading
                    ? const SizedBox(width: 22, height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.network(
                            'https://www.google.com/favicon.ico',
                            width: 20, height: 20,
                            errorBuilder: (_, __, ___) =>
                                const Icon(Icons.login_rounded, size: 20),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Connexion avec Google',
                            style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15, letterSpacing: 0.3),
                          ),
                        ],
                      ),
              ).animate(delay: 400.ms).fadeIn().slideY(begin: 0.2),

              if (_error != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF1F2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded,
                          color: Color(0xFFE11D48), size: 16),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_error!,
                          style: const TextStyle(
                              color: Color(0xFFE11D48),
                              fontWeight: FontWeight.w700, fontSize: 13))),
                    ],
                  ),
                ).animate().fadeIn().shakeX(),
              ],

            ],
          ),
        ),
      ),
    );
  }
}
