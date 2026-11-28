import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../games/neon_dash/dash_screen.dart';
import 'arcade_screen.dart';

class NufatGamesHubScreen extends StatefulWidget {
  const NufatGamesHubScreen({super.key});

  @override
  State<NufatGamesHubScreen> createState() => _NufatGamesHubScreenState();
}

class _NufatGamesHubScreenState extends State<NufatGamesHubScreen> {
  int _strikerBest = 0;
  int _dashBest = 0;

  @override
  void initState() {
    super.initState();
    _loadScores();
  }

  Future<void> _loadScores() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        _strikerBest = prefs.getInt('ns_best_score') ?? 0;
        _dashBest = prefs.getInt('nufat_dash_best_v1') ?? 0;
      });
    } catch (_) {}
  }

  Future<void> _openGame(Widget screen) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => screen),
    );
    _loadScores();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050714),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          children: [
            // Compact Hub Header
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF00E5FF), Color(0xFF3B82F6)],
                    ),
                  ),
                  child: const Icon(Icons.sports_esports_rounded, color: Color(0xFF050714), size: 26),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'NUFAT GAMES',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Arcade Hub · Offline-Ready 60 FPS',
                        style: TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0x1A00E5FF),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0x5500E5FF)),
                  ),
                  child: const Text(
                    '2 GAMES',
                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900, color: Color(0xFF00E5FF)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            const Text(
              'KOLEKSI UTAMA',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
                color: Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(height: 10),

            // 1. NEON STRIKER
            _GameCard(
              title: 'NEON STRIKER',
              genre: 'Cyberpunk Arcade Shooter',
              description: 'Tembak gelombang musuh & Boss, kumpulkan koin, buka 3 pesawat di Hangar, dan picu EMP Shockwave!',
              accent: const Color(0xFF00E5FF),
              icon: Icons.rocket_launch_rounded,
              bestScore: _strikerBest,
              tags: const ['60 FPS', 'Hangar & Upgrade', 'Boss Wave'],
              onPlay: () => _openGame(const ArcadeScreen()),
            ),
            const SizedBox(height: 12),

            // 2. NEON DASH
            _GameCard(
              title: 'NEON DASH',
              genre: 'Cyberpunk Endless Runner',
              description: 'Lari tanpa batas! Double Jump & Slide hindari laser, kumpulkan koin, serta aktifkan Shield, Magnet & Turbo 2X.',
              accent: const Color(0xFFFACC15),
              icon: Icons.bolt_rounded,
              bestScore: _dashBest,
              tags: const ['60 FPS', 'Double Jump', 'Power-Ups'],
              onPlay: () => _openGame(const DashScreen()),
            ),

            const SizedBox(height: 22),
            const Text(
              'SEGERA HADIR',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
                color: Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF0B1124),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.auto_awesome_rounded, color: Color(0xFFC084FC), size: 22),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Koleksi game baru (Stack Tower, Puzzle 5S, & API Cloud Games) siap ditambahkan langsung di update berikutnya.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8), height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GameCard extends StatelessWidget {
  const _GameCard({
    required this.title,
    required this.genre,
    required this.description,
    required this.accent,
    required this.icon,
    required this.bestScore,
    required this.tags,
    required this.onPlay,
  });

  final String title;
  final String genre;
  final String description;
  final Color accent;
  final IconData icon;
  final int bestScore;
  final List<String> tags;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPlay,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF0E1730),
              accent.withValues(alpha: 0.12),
            ],
          ),
          border: Border.all(color: accent.withValues(alpha: 0.45), width: 1.3),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: accent.withValues(alpha: 0.5)),
                  ),
                  child: Icon(icon, color: accent, size: 26),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        genre,
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: accent),
                      ),
                    ],
                  ),
                ),
                if (bestScore > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF060B18),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: const Color(0x5534D399)),
                    ),
                    child: Text(
                      'BEST $bestScore',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF34D399)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              description,
              style: const TextStyle(fontSize: 12.5, color: Color(0xFFCBD5E1), height: 1.45),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: tags
                        .map(
                          (t) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              t,
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF94A3B8)),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: const Color(0xFF050714),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: onPlay,
                  icon: const Icon(Icons.play_arrow_rounded, size: 18),
                  label: const Text('MAIN', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12.5)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
