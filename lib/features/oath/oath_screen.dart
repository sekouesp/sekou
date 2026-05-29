import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants.dart';

const _oathLines = [
  "Je jure d'obéir à mes anciens",
  "En tout ce qui concerne le travail auquel je suis appelé",
  "Et dans l'exercice de mes devoirs.",
  "Je jure egalement de ne faire usage de mes connaissances",
  "Que pour la réussite de tout polytechnicien.",
  "Il faut être conscient que dans la compétition",
  "L'ambition individuelle sert le bien commun.",
  "Mais le meilleur résultat arrive",
  "Lorsque chacun fait ce qui est bon pour lui et pour le groupe",
  ".",
];

class OathScreen extends StatelessWidget {
  const OathScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Color(0xFF1E293B)),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 60),
        child: Column(
          children: [
            // Header
            Column(
              children: [
                Transform.rotate(
                  angle: 0.05, // rotate-3
                  child: Container(
                    width: 56, height: 56,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [
                        BoxShadow(color: Color(0x20000000),
                            blurRadius: 20, offset: Offset(0, 8)),
                      ],
                    ),
                    child: const Icon(Icons.menu_book_rounded,
                        color: Colors.white, size: 26),
                  ),
                ).animate().fadeIn().slideY(begin: -0.3),
                const SizedBox(height: 20),
                const Text('LE SERMENT',
                    style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 28, letterSpacing: -0.5,
                        color: Color(0xFF1E293B))),
                const SizedBox(height: 4),
                const Text('POLYTECHNICIEN',
                    style: TextStyle(
                        fontSize: 9, fontWeight: FontWeight.w900,
                        letterSpacing: 5, color: Color(0xFF94A3B8))),
              ],
            ).animate().fadeIn(duration: 500.ms),

            const SizedBox(height: 32),

            // Card sombre
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(40),
                border: Border.all(color: const Color(0xFF1E293B), width: 4),
                boxShadow: const [
                  BoxShadow(color: Color(0x60000000),
                      blurRadius: 40, offset: Offset(0, 16)),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  // Quote icon watermark
                  const Positioned(
                    top: -8, left: -8,
                    child: Icon(Icons.format_quote_rounded,
                        size: 80, color: Color(0x0CFFFFFF)),
                  ),
                  // Logo watermark bas droite
                  Positioned(
                    bottom: -32, right: -32,
                    child: Opacity(
                      opacity: 0.05,
                      child: Image.network(
                        AppConstants.logoUrl,
                        width: 160, height: 160,
                        color: Colors.white,
                        colorBlendMode: BlendMode.srcIn,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ),
                  ),
                  // Lignes du serment
                  Padding(
                    padding: const EdgeInsets.fromLTRB(28, 36, 28, 36),
                    child: Column(
                      children: _oathLines.asMap().entries.map((entry) {
                        final i = entry.key;
                        final line = entry.value;
                        final isDot = line == ".";
                        return Padding(
                          padding: EdgeInsets.symmetric(
                              vertical: isDot ? 12 : 6),
                          child: isDot
                              ? Text('•',
                                  style: const TextStyle(
                                    fontSize: 36, fontWeight: FontWeight.w900,
                                    color: Color(0xFFF59E0B),
                                  ))
                              : Text(
                                  line,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Color(0xFFCBD5E1),
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    fontStyle: FontStyle.italic,
                                    height: 1.6,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                        ).animate(delay: Duration(milliseconds: 80 * i))
                         .fadeIn(duration: 400.ms)
                         .slideY(begin: 0.1);
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ).animate(delay: 200.ms).fadeIn().slideY(begin: 0.1),

            const SizedBox(height: 20),

            // Caption
            Text(
              "À prononcer lors des rituels d'intégration.",
              style: TextStyle(
                  color: Colors.grey.shade400, fontSize: 9,
                  fontWeight: FontWeight.w800,
                  fontStyle: FontStyle.italic,
                  letterSpacing: 2),
              textAlign: TextAlign.center,
            ).animate(delay: 500.ms).fadeIn(),
          ],
        ),
      ),
    );
  }
}
