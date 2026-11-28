import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../games/neon_dash/dash_screen.dart';
import '../services/remote_games_service.dart';
import 'arcade_screen.dart';
import 'web_game_player_screen.dart';

class NufatGamesHubScreen extends StatefulWidget {
  const NufatGamesHubScreen({super.key});

  @override
  State<NufatGamesHubScreen> createState() => _NufatGamesHubScreenState();
}

class _NufatGamesHubScreenState extends State<NufatGamesHubScreen> {
  int _strikerBest = 0;
  int _dashBest = 0;
  List<RemoteWebGame> _remoteGames = RemoteGamesService.fallbackGames;
  Map<String, int> _webBests = const {};
  bool _remoteFromServer = false;
  bool _loadingRemote = false;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    await _loadScores();
    await _loadRemoteCatalog();
  }

  Future<void> _loadScores() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final webBests = await RemoteGamesService.instance.loadWebBestScores(_remoteGames);
      if (!mounted) return;
      setState(() {
        _strikerBest = prefs.getInt('ns_best_score') ?? 0;
        _dashBest = prefs.getInt('nufat_dash_best_v1') ?? 0;
        _webBests = webBests;
      });
    } catch (_) {}
  }

  Future<void> _loadRemoteCatalog() async {
    if (mounted) setState(() => _loadingRemote = true);
    final res = await RemoteGamesService.instance.fetchCatalog();
    final webBests = await RemoteGamesService.instance.loadWebBestScores(res.games);
    if (!mounted) return;
    setState(() {
      _remoteGames = res.games;
      _remoteFromServer = res.fromServer;
      _webBests = webBests;
      _loadingRemote = false;
    });
  }

  Future<void> _openGame(Widget screen) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => screen),
    );
    await _loadScores();
  }

  @override
  Widget build(BuildContext context) {
    final totalGames = 2 + _remoteGames.length;
    return Scaffold(
      backgroundColor: const Color(0xFF050714),
      body: SafeArea(
        child: RefreshIndicator(
          color: const Color(0xFF00E5FF),
          backgroundColor: const Color(0xFF0B1124),
          onRefresh: _loadAll,
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
                          'Hybrid Native 60 FPS & Cloud WebView',
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
                    child: Text(
                      '$totalGames GAMES',
                      style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900, color: Color(0xFF00E5FF)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Section 1: Ori Native Games
              const _SectionHeader(
                title: 'ORI NATIVE · OFFLINE 60 FPS',
                badge: 'NATIVE',
                badgeColor: Color(0xFF34D399),
              ),
              const SizedBox(height: 10),

              _GameCard(
                title: 'NEON STRIKER',
                genre: 'Cyberpunk Arcade Shooter',
                description:
                    'Tembak gelombang musuh & Boss, kumpulkan koin, buka 3 pesawat di Hangar, dan picu EMP Shockwave!',
                accent: const Color(0xFF00E5FF),
                icon: Icons.rocket_launch_rounded,
                modeBadge: 'ORI NATIVE',
                bestScore: _strikerBest,
                tags: const ['Offline', 'Hangar & Upgrade', 'Boss Wave'],
                onPlay: () => _openGame(const ArcadeScreen()),
              ),
              const SizedBox(height: 12),

              _GameCard(
                title: 'NEON DASH',
                genre: 'Cyberpunk Endless Runner',
                description:
                    'Lari tanpa batas! Double Jump & Slide hindari laser, kumpulkan koin, serta aktifkan Shield, Magnet & Turbo 2X.',
                accent: const Color(0xFFFACC15),
                icon: Icons.bolt_rounded,
                modeBadge: 'ORI NATIVE',
                bestScore: _dashBest,
                tags: const ['Offline', 'Double Jump', 'Power-Ups'],
                onPlay: () => _openGame(const DashScreen()),
              ),

              const SizedBox(height: 24),

              // Section 2: Cloud WebView Games (Dynamic via API)
              Row(
                children: [
                  Expanded(
                    child: _SectionHeader(
                      title: 'CLOUD ARCADE · UPDATE VIA API',
                      badge: _remoteFromServer ? 'LIVE API' : 'WEBVIEW',
                      badgeColor: const Color(0xFFC084FC),
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: _loadingRemote ? null : _loadRemoteCatalog,
                    icon: _loadingRemote
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFC084FC)),
                          )
                        : const Icon(Icons.sync_rounded, size: 18, color: Color(0xFFC084FC)),
                    tooltip: 'Muat ulang katalog API',
                  ),
                ],
              ),
              const SizedBox(height: 8),

              for (final g in _remoteGames) ...[
                _GameCard(
                  title: g.title,
                  genre: g.genre,
                  description: g.description,
                  accent: g.accentColor,
                  icon: Icons.public_rounded,
                  modeBadge: 'WEBVIEW',
                  bestScore: _webBests[g.id] ?? 0,
                  tags: g.tags,
                  onPlay: () => _openGame(WebGamePlayerScreen(game: g)),
                ),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.badge,
    required this.badgeColor,
  });

  final String title;
  final String badge;
  final Color badgeColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.1,
            color: Color(0xFF94A3B8),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: badgeColor.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: badgeColor.withValues(alpha: 0.45)),
          ),
          child: Text(
            badge,
            style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, color: badgeColor),
          ),
        ),
      ],
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
    required this.modeBadge,
    required this.bestScore,
    required this.tags,
    required this.onPlay,
  });

  final String title;
  final String genre;
  final String description;
  final Color accent;
  final IconData icon;
  final String modeBadge;
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF060B18),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: accent.withValues(alpha: 0.45)),
                      ),
                      child: Text(
                        modeBadge,
                        style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, color: accent),
                      ),
                    ),
                    if (bestScore > 0) ...[
                      const SizedBox(height: 4),
                      Text(
                        'BEST $bestScore',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF34D399)),
                      ),
                    ],
                  ],
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
