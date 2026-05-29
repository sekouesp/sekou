import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants.dart';

const _values = [
  ["L'excellence",   "l'humilité"],
  ["L'amour",        "la bienveillance"],
  ["La solidarité",  "la tolérance"],
  ["Le respect",     "la considération"],
  ["Le courage",     "la patience"],
  ["La paix",        "la tranquillité"],
  ["La joie",        "l'espérance"],
  ["La volonté",     "la rigueur"],
  ["La justice",     "la vérité"],
  ["L'unité",        "la communion fraternelle"],
];

class ValuesScreen extends StatelessWidget {
  const ValuesScreen({super.key});

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
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Center(
              child: Column(
                children: [
                  Container(
                    width: 56, height: 56,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF1F2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.favorite_rounded,
                        color: Color(0xFFF43F5E), size: 28),
                  ).animate()
                   .scale(begin: const Offset(0, 0), duration: 500.ms,
                       curve: Curves.elasticOut),
                  const SizedBox(height: 16),
                  const Text('VALEURS FONDAMENTALES',
                      style: TextStyle(fontWeight: FontWeight.w900,
                          fontSize: 18, letterSpacing: 1,
                          color: Color(0xFF1E293B))),
                  const SizedBox(height: 6),
                  Text('Le socle de notre identité polytechnicienne.',
                      style: TextStyle(color: Colors.grey.shade400,
                          fontSize: 10, fontWeight: FontWeight.w800,
                          letterSpacing: 2),
                      textAlign: TextAlign.center),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // Grille 2 colonnes — 10 valeurs
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 32,
                childAspectRatio: 1.4,
              ),
              itemCount: _values.length,
              itemBuilder: (context, i) {
                final v1 = _values[i][0];
                final v2 = _values[i][1];
                final num = (i + 1).toString().padLeft(2, '0');
                return _ValueCard(
                    v1: v1, v2: v2, num: num, index: i);
              },
            ),

            const SizedBox(height: 48),

            // Footer dark — fidèle au web
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(36),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  // Gradient top bar
                  Positioned(
                    top: 0, left: 0, right: 0,
                    child: Container(
                      height: 3,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Color(0xFF3B82F6),
                            Color(0xFFF43F5E),
                            Color(0xFFF59E0B),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Watermark logo rotate 12
                  Positioned(
                    right: -20, bottom: -20,
                    child: Opacity(
                      opacity: 0.1,
                      child: Transform.rotate(
                        angle: 0.21,
                        child: Image.network(
                          AppConstants.logoUrl,
                          width: 160, height: 160,
                          color: Colors.white,
                          colorBlendMode: BlendMode.srcIn,
                          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                        ),
                      ),
                    ),
                  ),
                  // Text E S P
                  Padding(
                    padding: const EdgeInsets.fromLTRB(28, 32, 28, 32),
                    child: Text.rich(
                      const TextSpan(
                        style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700,
                          fontStyle: FontStyle.italic,
                          color: Color(0xFF94A3B8),
                          height: 1.8, letterSpacing: 0.5,
                        ),
                        children: [
                          TextSpan(text: '"'),
                          TextSpan(
                            text: 'E',
                            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900,
                                color: Color(0xFF60A5FA), fontStyle: FontStyle.italic),
                          ),
                          TextSpan(text: 'xcellence dans la '),
                          TextSpan(
                            text: 'S',
                            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900,
                                color: Color(0xFF60A5FA), fontStyle: FontStyle.italic),
                          ),
                          TextSpan(text: 'olidarité et le '),
                          TextSpan(
                            text: 'P',
                            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900,
                                color: Color(0xFF60A5FA), fontStyle: FontStyle.italic),
                          ),
                          TextSpan(text: 'artage"'),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ).animate(delay: 200.ms).fadeIn().slideY(begin: 0.1),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _ValueCard extends StatelessWidget {
  final String v1, v2, num;
  final int index;
  const _ValueCard({
      required this.v1, required this.v2,
      required this.num, required this.index});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Numéro watermark
        Positioned(
          top: -16, left: -8,
          child: Text(num,
              style: const TextStyle(
                  fontSize: 64, fontWeight: FontWeight.w900,
                  color: Color(0xFFF1F5F9), height: 1)),
        ),
        // Contenu
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.only(left: 16, top: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 4, height: 40,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(left: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text.rich(
                        TextSpan(children: [
                          TextSpan(
                            text: '$v1 ',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          const TextSpan(
                            text: 'et ',
                            style: TextStyle(
                              fontWeight: FontWeight.w300,
                              fontSize: 11,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                          TextSpan(
                            text: v2,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                        ]),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Axe $num',
                        style: const TextStyle(
                          fontSize: 8, fontWeight: FontWeight.w900,
                          letterSpacing: 2, color: Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ).animate(delay: Duration(milliseconds: 50 * index))
     .fadeIn(duration: 400.ms)
     .slideX(begin: -0.05, curve: Curves.easeOut);
  }
}
