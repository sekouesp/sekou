import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';

import '../../core/theme/dept_theme.dart';
import '../../providers/auth_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ImmersivePlayerScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> soundData;
  const ImmersivePlayerScreen({super.key, required this.soundData});

  @override
  ConsumerState<ImmersivePlayerScreen> createState() => _ImmersivePlayerScreenState();
}

class _ImmersivePlayerScreenState extends ConsumerState<ImmersivePlayerScreen>
    with TickerProviderStateMixin {
  late final AudioPlayer _player;
  late final AnimationController _rotateCtrl;
  late final AnimationController _pulseCtrl;
  late final ScrollController _lyricsCtrl;

  bool _loading = true;
  bool _playing = false;
  Duration _pos = Duration.zero;
  Duration _dur = Duration.zero;
  int _currentLyricIdx = 0;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _lyricsCtrl = ScrollController();
    _rotateCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 8))..repeat();
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800))..repeat(reverse: true);
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    try {
      final url = widget.soundData['url'] as String? ?? '';
      if (url.isEmpty) throw Exception('URL vide');
      await _player.setUrl(url);
      setState(() => _loading = false);

      _player.positionStream.listen((pos) {
        if (mounted) setState(() { _pos = pos; _updateLyric(); });
      });
      _player.durationStream.listen((d) {
        if (mounted && d != null) setState(() => _dur = d);
      });
      _player.playingStream.listen((p) {
        if (mounted) {
          setState(() => _playing = p);
          if (p) {
            _rotateCtrl.repeat();
          } else {
            _rotateCtrl.stop();
          }
        }
      });

      await _player.play();
    } catch (e) {
      if (mounted) setState(() { _loading = false; });
    }
  }

  void _updateLyric() {
    final lyrics = widget.soundData['lyrics'] as List? ?? [];
    if (lyrics.isEmpty) return;
    final secs = _pos.inSeconds;
    // Simple line-per-5-sec heuristic
    final idx = (secs ~/ 5).clamp(0, lyrics.length - 1);
    if (idx != _currentLyricIdx) {
      setState(() => _currentLyricIdx = idx);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_lyricsCtrl.hasClients) {
          _lyricsCtrl.animateTo(
            idx * 48.0,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  String _fmt(Duration d) =>
      '${d.inMinutes.toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  void dispose() {
    _player.dispose();
    _rotateCtrl.dispose();
    _pulseCtrl.dispose();
    _lyricsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentProfileProvider).value;
    final dept = (widget.soundData['type'] == 'department'
        ? widget.soundData['department'] : profile?.department) as String? ?? '';
    final theme = DeptTheme.of(dept);
    final lyrics = widget.soundData['lyrics'] as List? ?? [];
    final name = widget.soundData['name'] as String? ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1E),
      body: Stack(
        children: [
          // Background gradient
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _pulseCtrl,
              builder: (_, __) => Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -0.4),
                    radius: 1.2 + (_pulseCtrl.value * 0.2),
                    colors: [
                      theme.primary.withOpacity(0.3),
                      const Color(0xFF0A0F1E),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Floating circles
          ...List.generate(5, (i) => Positioned(
            left: (i * 80.0) % MediaQuery.of(context).size.width,
            top: (i * 120.0) % MediaQuery.of(context).size.height,
            child: AnimatedBuilder(
              animation: _rotateCtrl,
              builder: (_, __) => Transform.rotate(
                angle: _rotateCtrl.value * 2 * pi * (i.isEven ? 1 : -1),
                child: Container(
                  width: 60 + i * 20.0,
                  height: 60 + i * 20.0,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: theme.primary.withOpacity(0.04 + i * 0.01), width: 1),
                  ),
                ),
              ),
            ),
          )),

          SafeArea(
            child: Column(
              children: [
                // Top bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.keyboard_arrow_down_rounded,
                            color: Colors.white, size: 28),
                        onPressed: () => context.pop(),
                      ),
                      const Spacer(),
                      Text(
                        'EN LECTURE',
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.4),
                            fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2),
                      ),
                      const Spacer(),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Vinyl disc
                AnimatedBuilder(
                  animation: _rotateCtrl,
                  builder: (_, child) => Transform.rotate(
                    angle: _playing ? _rotateCtrl.value * 2 * pi : 0,
                    child: child,
                  ),
                  child: Container(
                    width: 220, height: 220,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: SweepGradient(
                        colors: [
                          const Color(0xFF1E293B),
                          const Color(0xFF0F172A),
                          theme.primary.withOpacity(0.8),
                          const Color(0xFF1E293B),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: theme.primary.withOpacity(0.4),
                          blurRadius: _playing ? 60 : 20,
                          spreadRadius: _playing ? 10 : 2,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Container(
                        width: 80, height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF0F172A),
                          border: Border.all(color: Colors.white.withOpacity(0.1)),
                        ),
                        child: Center(
                          child: Icon(Icons.music_note_rounded,
                              color: theme.primaryContainer, size: 28),
                        ),
                      ),
                    ),
                  ),
                ).animate().scale(begin: const Offset(0.5, 0.5),
                    duration: 700.ms, curve: Curves.elasticOut),

                const SizedBox(height: 32),

                // Song name
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    name,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 22,
                        fontWeight: FontWeight.w900, fontStyle: FontStyle.italic),
                    textAlign: TextAlign.center,
                  ),
                ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2),

                const SizedBox(height: 6),

                Text(
                  widget.soundData['type'] == 'communal' ? 'Hymne Communal' :
                      widget.soundData['department'] ?? '',
                  style: TextStyle(
                      color: theme.primaryContainer,
                      fontSize: 13, fontWeight: FontWeight.w700),
                ).animate().fadeIn(delay: 300.ms),

                const Spacer(),

                // Lyrics
                if (lyrics.isNotEmpty)
                  SizedBox(
                    height: 100,
                    child: ListView.builder(
                      controller: _lyricsCtrl,
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      itemCount: lyrics.length,
                      itemBuilder: (_, i) {
                        final isActive = i == _currentLyricIdx;
                        return AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 300),
                          style: TextStyle(
                            color: isActive ? Colors.white : Colors.white.withOpacity(0.25),
                            fontSize: isActive ? 16 : 13,
                            fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
                            fontStyle: FontStyle.italic,
                            height: 1.8,
                          ),
                          child: Text(
                            lyrics[i].toString(),
                            textAlign: TextAlign.center,
                          ),
                        );
                      },
                    ),
                  ),

                const Spacer(),

                // Progress
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 4,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                          activeTrackColor: Colors.white,
                          inactiveTrackColor: Colors.white.withOpacity(0.15),
                          thumbColor: Colors.white,
                          overlayColor: Colors.white.withOpacity(0.1),
                        ),
                        child: Slider(
                          value: _dur.inMilliseconds > 0
                              ? (_pos.inMilliseconds / _dur.inMilliseconds).clamp(0.0, 1.0)
                              : 0.0,
                          onChanged: (v) => _player.seek(
                              Duration(milliseconds: (v * _dur.inMilliseconds).round())),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(_fmt(_pos), style: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                                fontSize: 11, fontWeight: FontWeight.w700)),
                            Text(_fmt(_dur), style: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                                fontSize: 11, fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Controls
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: Icon(Icons.replay_10_rounded,
                            color: Colors.white.withOpacity(0.6), size: 28),
                        onPressed: () => _player.seek(_pos - const Duration(seconds: 10)),
                      ),
                      GestureDetector(
                        onTap: () => _playing ? _player.pause() : _player.play(),
                        child: AnimatedBuilder(
                          animation: _pulseCtrl,
                          builder: (_, __) => Container(
                            width: 72, height: 72,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                              boxShadow: _playing ? [
                                BoxShadow(
                                  color: Colors.white.withOpacity(0.3 + _pulseCtrl.value * 0.2),
                                  blurRadius: 20 + _pulseCtrl.value * 10,
                                  spreadRadius: 4,
                                ),
                              ] : [],
                            ),
                            child: Icon(
                              _loading ? Icons.hourglass_empty_rounded :
                              _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                              color: const Color(0xFF0A0F1E),
                              size: 36,
                            ),
                          ),
                        ),
                      ).animate().scale(begin: const Offset(0.5, 0.5),
                          delay: 400.ms, duration: 600.ms, curve: Curves.elasticOut),
                      IconButton(
                        icon: Icon(Icons.forward_10_rounded,
                            color: Colors.white.withOpacity(0.6), size: 28),
                        onPressed: () => _player.seek(_pos + const Duration(seconds: 10)),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
