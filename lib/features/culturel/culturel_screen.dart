import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/dept_theme.dart';
import '../../models/sound.dart';
import '../../providers/auth_provider.dart';
import '../../providers/config_provider.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/loading_indicator.dart';

final _soundsProvider = StreamProvider.autoDispose<List<Sound>>((ref) {
  return FirebaseFirestore.instance
      .collection('culturel_sounds')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(Sound.fromFirestore).toList());
});

class CulturelScreen extends ConsumerWidget {
  const CulturelScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final soundsAsync = ref.watch(_soundsProvider);
    final profile = ref.watch(currentProfileProvider).value;
    final configAsync = ref.watch(appConfigProvider);
    final theme = DeptTheme.of(profile?.department);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('CULTUREL', style: TextStyle(color: Colors.white,
                fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1)),
            Text('Sons & Hymnes', style: TextStyle(
                color: Colors.white.withOpacity(0.4), fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
        actions: [
          if (profile?.isAdmin == true)
            IconButton(
              icon: const Icon(Icons.add_circle_rounded, color: Colors.white),
              onPressed: () => _showAddSoundDialog(context, ref),
            ),
        ],
      ),
      body: soundsAsync.when(
        loading: () => const Center(child: AppLoadingIndicator()),
        error: (e, _) => Center(child: Text('Erreur: $e', style: const TextStyle(color: Colors.white))),
        data: (sounds) {
          if (sounds.isEmpty) {
            return const EmptyState(
              icon: Icons.music_off_rounded,
              title: 'Aucun son disponible',
              subtitle: 'Papadji n\'a pas encore uploadé de sons.',
            );
          }

          final communal = sounds.where((s) => s.type == 'communal').toList();
          final departmental = sounds.where((s) => s.type == 'department').toList();

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (communal.isNotEmpty) ...[
                  _SectionTitle(label: '🎵 COMMUNAL', icon: Icons.public_rounded),
                  const SizedBox(height: 12),
                  ...communal.asMap().entries.map((e) =>
                    _SoundCard(sound: e.value, index: e.key, theme: theme,
                        deptLogoUrl: configAsync.value?.communalLogo)),
                ],
                if (departmental.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _SectionTitle(label: '🏛️ DÉPARTEMENTAL', icon: Icons.school_rounded),
                  const SizedBox(height: 12),
                  ...departmental.asMap().entries.map((e) {
                    final deptLogo = configAsync.value?.departmentLogos[e.value.department ?? ''];
                    return _SoundCard(sound: e.value, index: e.key, theme: theme,
                        deptLogoUrl: deptLogo);
                  }),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  void _showAddSoundDialog(BuildContext context, WidgetRef ref) {
    final nameCtrl = TextEditingController();
    final urlCtrl = TextEditingController();
    String type = 'communal';
    String? dept;
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            left: 24, right: 24, top: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Ajouter un son', style: TextStyle(color: Colors.white,
                  fontWeight: FontWeight.w900, fontSize: 18)),
              const SizedBox(height: 20),
              _DarkTextField(ctrl: nameCtrl, label: 'Nom du son'),
              const SizedBox(height: 12),
              _DarkTextField(ctrl: urlCtrl, label: 'URL audio'),
              const SizedBox(height: 12),
              SegmentedButton<String>(
                style: SegmentedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                ),
                segments: const [
                  ButtonSegment(value: 'communal', label: Text('Communal')),
                  ButtonSegment(value: 'department', label: Text('Département')),
                ],
                selected: {type},
                onSelectionChanged: (v) => setState(() {
                  type = v.first;
                  if (type == 'department' && dept == null) {
                    dept = 'Génie Informatique';
                  }
                }),
              ),
              if (type == 'department') ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: dept ?? 'Génie Informatique',
                      isExpanded: true,
                      dropdownColor: const Color(0xFF1E293B),
                      style: const TextStyle(color: Colors.white,
                          fontWeight: FontWeight.w600, fontSize: 13),
                      items: ['Génie Informatique','Génie Civil','Génie Électrique',
                          'Génie Mécanique','Génie Chimique et Biologie Appliquée','Gestion']
                        .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                        .toList(),
                      onChanged: (v) => setState(() => dept = v),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () async {
                    if (nameCtrl.text.isEmpty || urlCtrl.text.isEmpty) return;
                    await FirebaseFirestore.instance.collection('culturel_sounds').add({
                      'name': nameCtrl.text.trim(),
                      'url': urlCtrl.text.trim(),
                      'type': type,
                      if (dept != null) 'department': dept,
                      'createdAt': FieldValue.serverTimestamp(),
                      'lyrics': [],
                    });
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: const Text('AJOUTER', style: TextStyle(
                      fontWeight: FontWeight.w900, letterSpacing: 1)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String label;
  final IconData icon;
  const _SectionTitle({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.white.withOpacity(0.3), size: 14),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(
            color: Colors.white.withOpacity(0.4),
            fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 2)),
      ],
    );
  }
}

class _SoundCard extends StatelessWidget {
  final Sound sound;
  final int index;
  final DeptTheme theme;
  final String? deptLogoUrl;
  const _SoundCard({required this.sound, required this.index,
      required this.theme, this.deptLogoUrl});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/culturel/player', extra: {
        'id': sound.id,
        'name': sound.name,
        'url': sound.url,
        'lyrics': sound.lyrics,
        'type': sound.type,
        'department': sound.department ?? '',
      }),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Row(
          children: [
            _SoundThumbnail(sound: sound, theme: theme, deptLogoUrl: deptLogoUrl),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(sound.name,
                      style: const TextStyle(color: Colors.white,
                          fontWeight: FontWeight.w800, fontSize: 14)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: (sound.type == 'communal'
                              ? const Color(0xFF4F46E5) : theme.primary).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          sound.type == 'communal' ? 'Communal' : sound.department ?? '',
                          style: TextStyle(
                            color: sound.type == 'communal'
                                ? const Color(0xFF818CF8) : theme.primaryContainer,
                            fontSize: 10, fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (sound.lyrics.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Icon(Icons.lyrics_rounded,
                            color: Colors.white.withOpacity(0.3), size: 12),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 22),
            ),
          ],
        ),
      ).animate(delay: Duration(milliseconds: 60 * index)).fadeIn().slideY(begin: 0.1),
    );
  }
}

class _DarkTextField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  const _DarkTextField({required this.ctrl, required this.label});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
        filled: true,
        fillColor: Colors.white.withOpacity(0.06),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 2),
        ),
      ),
    );
  }
}


class _SoundThumbnail extends StatelessWidget {
  final Sound sound;
  final DeptTheme theme;
  final String? deptLogoUrl;

  const _SoundThumbnail({
    required this.sound,
    required this.theme,
    this.deptLogoUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52, height: 52,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [theme.primary, theme.primary.withOpacity(0.6)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: deptLogoUrl != null && deptLogoUrl!.isNotEmpty
          ? Image.network(
              deptLogoUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Icon(
                  Icons.music_note_rounded, color: Colors.white, size: 24),
            )
          : const Icon(Icons.music_note_rounded, color: Colors.white, size: 24),
    ).animate(onPlay: (c) => c.repeat(reverse: true))
     .scale(begin: const Offset(0.95, 0.95), end: const Offset(1.05, 1.05),
         duration: 2000.ms, curve: Curves.easeInOut);
  }
}
