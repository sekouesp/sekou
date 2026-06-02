import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'dart:ui';

import '../../core/constants.dart';

/// Parrot images from Cloudinary — exact same set as the web version
const _parrotImages = [
  'assets/images/parrots/parrot_nice_blue-yellow-green_gipcj0.jpg',
  'assets/images/parrots/parrot_gray-green_tqo3nj.jpg',
  'assets/images/parrots/parrot_blue-yellow_jwcuzv.jpg',
  'assets/images/parrots/parrot_gray_eoaitb.jpg',
  'assets/images/parrots/parrot_red_its2ro.jpg',
  'assets/images/parrots/parrot_head-from-right_zgokyo.jpg',
  'assets/images/parrots/parrot_green-red_um6eh0.jpg',
  'assets/images/parrots/10_Amazing_Facts_About_Parrots___Sarai_Chinwag_zggof4.jpg',
  'assets/images/parrots/Fotos_De_Vera_Saldanha_Araujo_Em_Art___Parrot_i2j7jy.jpg',
  'assets/images/parrots/parrot_head_from_right_msgyfd.jpg',
  'assets/images/parrots/parrot_blue-red_tlydhg.jpg',
  'assets/images/parrots/parrot_small-green_ipuboa.jpg',
  'assets/images/parrots/parrot_pretty_sqki52.jpg',
  'assets/images/parrots/parrot_head_from_right-nice_thqktn.jpg',
  'assets/images/parrots/parrot_fighting_v2om7f.jpg',
  'assets/images/parrots/parrot_blue_bg_xuuqal.jpg',
  'assets/images/parrots/parrot_the_original_uww57x.jpg',
  'assets/images/parrots/parrot_duo_loafp7.jpg',
  'assets/images/parrots/parrot_red-white_syup5w.jpg',
  'assets/images/parrots/parrot_small_green_s79fje.jpg',
  'assets/images/parrots/parrot_white_nyifm3.jpg',
];

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  bool _loading = false;
  String? _error;
  late AnimationController _scrollController;

  @override
  void initState() {
    super.initState();
    // Slow infinite scroll animation (60s loop like the web)
    _scrollController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 60),
    )..repeat();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

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
      backgroundColor: const Color(0xFFF1F5F9), // slate-100
      body: Stack(
        children: [
          //  Infinite Scrolling Parrot Grid Background 
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            bottom: -MediaQuery.of(context).size.height, // Forces height to 2 * screenHeight
            child: AnimatedBuilder(
              animation: _scrollController,
              builder: (context, child) {
                // Scroll offset: translate Y from 0 to -screenHeight (repeat)
                final offset = _scrollController.value * -MediaQuery.of(context).size.height;
                return Transform.translate(
                  offset: Offset(0, offset),
                  child: child,
                );
              },
              child: Opacity(
                opacity: 0.5, // Web: opacity-50
                child: _ParrotMasonryGrid(), // No need for SizedBox anymore
              ),
            ),
          ),

          //  Gradient overlay (web: bg-gradient-to-t from-slate-100/70) 
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    const Color(0xFFF1F5F9).withOpacity(0.7),
                    const Color(0xFFF1F5F9).withOpacity(0.2),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          //  Central Login Card (Glassmorphism, exactly like web) 
          Center(
            child: Container(
              width: 320,
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.4), // bg-white/40
                borderRadius: BorderRadius.circular(40), // rounded-[2.5rem]
                border: Border.all(
                  color: Colors.white.withOpacity(0.4), // border-white/40
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 32,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(40),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20), // backdrop-blur-xl
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      //  Logo in glass container 
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.6), // bg-white/60
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.5),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: Image.network(
                          AppConstants.logoUrl,
                          width: 64, height: 64,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) =>
                              const Icon(Icons.school_rounded, size: 64,
                                  color: Color(0xFF1E293B)),
                        ),
                      ).animate()
                       .rotate(begin: -0.5, duration: 800.ms,
                           curve: Curves.elasticOut)
                       .scale(begin: const Offset(0, 0), duration: 800.ms,
                           curve: Curves.elasticOut)
                       .fadeIn(delay: 400.ms),

                      const SizedBox(height: 24),

                      //  Title: SEKOU 
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.only(bottom: 16),
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: Color(0x3394A3B8), // border-slate-400/20
                            ),
                          ),
                        ),
                        child: const Text(
                          'SEKOU',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF1E293B),
                            letterSpacing: 6, // tracking-[0.25em]
                          ),
                        ),
                      ).animate(delay: 600.ms)
                       .fadeIn()
                       .slideY(begin: 0.15),

                      const SizedBox(height: 32),

                      //  Google Sign-In Button (web style exact) 
                      GestureDetector(
                        onTap: _loading ? null : _signInWithGoogle,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A).withOpacity(0.9),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFF1E293B),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF0F172A).withOpacity(0.1),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: _loading
                              ? const Center(
                                  child: SizedBox(
                                    width: 22, height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.login_rounded,
                                        size: 18,
                                        color: Color(0xCCFFFFFF)), // text-white/80
                                    const SizedBox(width: 12),
                                    const Text(
                                      'CONNEXION',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 14,
                                        letterSpacing: 3.5, // tracking-[0.15em]
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ).animate(delay: 800.ms)
                       .fadeIn()
                       .slideY(begin: 0.15),

                      //  Error 
                      if (_error != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF1F2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline_rounded,
                                  color: Color(0xFFE11D48), size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(_error!,
                                    style: const TextStyle(
                                        color: Color(0xFFE11D48),
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13)),
                              ),
                            ],
                          ),
                        ).animate().fadeIn().shakeX(),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ).animate()
           .scale(begin: const Offset(0.9, 0.9), duration: 600.ms,
               curve: Curves.easeOutExpo)
           .fadeIn(delay: 200.ms),
        ],
      ),
    );
  }
}

/// Masonry-style grid of parrot images that tiles vertically
class _ParrotMasonryGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final columns = screenWidth > 600 ? 4 : 3;
    final itemWidth = screenWidth / columns;

    // Split images into columns
    final columnLists = List.generate(columns, (_) => <String>[]);
    // Fill many copies for a very long seamless scrolling
    final allImages = <String>[];
    for (var i = 0; i < 30; i++) {
      allImages.addAll(_parrotImages);
    }
    for (var i = 0; i < allImages.length; i++) {
      columnLists[i % columns].add(allImages[i]);
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: columnLists.map((images) {
        return SizedBox(
          width: itemWidth,
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            child: Column(
              children: images.map((url) {
                return Padding(
                padding: const EdgeInsets.all(4),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16), // rounded-2xl
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Image.asset(
                      url,
                      width: itemWidth - 8,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        height: 120,
                        color: const Color(0xFFE2E8F0).withOpacity(0.3),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      );
    }).toList(),
  );
  }
}
