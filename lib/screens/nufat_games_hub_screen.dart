import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../games/chess/chess_screen.dart';
import '../games/congklak/congklak_screen.dart';
import '../games/dam/dam_screen.dart';
import '../games/fruit_merge/fruit_merge_screen.dart';
import '../games/karambol/karambol_screen.dart';
import '../games/ludo/ludo_screen.dart';
import '../games/ular_tangga/ular_tangga_screen.dart';
import '../games/water_sort/water_sort_screen.dart';
import '../games/gaple/gaple_screen.dart';
import '../games/neon_block/block_screen.dart';
import '../games/neon_dash/dash_screen.dart';
import '../services/remote_games_service.dart';
import '../widgets/game_tile_artwork.dart';
import 'arcade_screen.dart';
import 'web_game_player_screen.dart';

class _HubGameItem {
  const _HubGameItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.isNative,
    required this.category,
    required this.colors,
    required this.icon,
    this.emoji,
    required this.bestScore,
    required this.onTap,
  });

  final String id;
  final String title;
  final String subtitle;
  final bool isNative;
  final String category; // Native | Arcade | Kuis | Puzzle | Kata | Refleks | Memory
  final List<Color> colors;
  final IconData icon;
  final String? emoji;
  final int bestScore;
  final VoidCallback onTap;
}

class NufatGamesHubScreen extends StatefulWidget {
  const NufatGamesHubScreen({super.key});

  @override
  State<NufatGamesHubScreen> createState() => _NufatGamesHubScreenState();
}

class _NufatGamesHubScreenState extends State<NufatGamesHubScreen> {
  static const List<String> _categories = [
    'Semua',
    'Native',
    'Arcade',
    'Kuis',
    'Puzzle',
    'Kata',
    'Refleks',
    'Memory',
  ];

  int _topTab = 1; // 0: Semua, 1: Game, 2: Native, 3: Cloud
  int _bottomTab = 0; // 0: Main, 1: Cloud, 3: Skor, 4: Aku
  String _selectedCategory = 'Semua';
  bool _searching = false;
  final TextEditingController _searchCtrl = TextEditingController();

  int _strikerBest = 0;
  int _dashBest = 0;
  int _chessBest = 0;
  int _blockBest = 0;
  int _gapleBest = 0;
  int _congklakBest = 0;
  int _ludoBest = 0;
  int _ularBest = 0;
  int _damBest = 0;
  int _waterBest = 1;
  int _fruitBest = 0;
  int _karambolBest = 0;
  List<RemoteWebGame> _remoteGames = RemoteGamesService.fallbackGames;
  Map<String, int> _webBests = const {};
  bool _remoteFromServer = false;
  bool _loadingRemote = false;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
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
        _chessBest = prefs.getInt('nufat_chess_best_v1') ?? 0;
        _blockBest = prefs.getInt('nufat_block_best_v1') ?? 0;
        _gapleBest = prefs.getInt('nufat_gaple_best_v1') ?? 0;
        _congklakBest = prefs.getInt('nufat_congklak_best_v1') ?? 0;
        _ludoBest = prefs.getInt('nufat_ludo_best_v1') ?? 0;
        _ularBest = prefs.getInt('nufat_ulartangga_best_v1') ?? 0;
        _damBest = prefs.getInt('nufat_dam_best_v1') ?? 0;
        _waterBest = prefs.getInt('nufat_watersort_best_v1') ?? 1;
        _fruitBest = prefs.getInt('nufat_fruitmerge_best_v1') ?? 0;
        _karambolBest = prefs.getInt('nufat_karambol_best_v1') ?? 0;
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

  String _resolveCategory(RemoteWebGame g) {
    final hay = '${g.genre} ${g.tags.join(' ')} ${g.id}'.toLowerCase();
    if (hay.contains('kuis') || hay.contains('quiz')) return 'Kuis';
    if (hay.contains('memory') || hay.contains('mem-')) return 'Memory';
    if (hay.contains('kata') || hay.contains('wordle') || hay.contains('scr-') || hay.contains('hng-')) return 'Kata';
    if (hay.contains('puzzle') || hay.contains('sudoku') || hay.contains('board') || hay.contains('mine') || hay.contains('sliding') || hay.contains('connect')) {
      return 'Puzzle';
    }
    if (hay.contains('refleks') || hay.contains('otak') || hay.contains('musik') || hay.contains('simon')) return 'Refleks';
    return 'Arcade';
  }

  List<_HubGameItem> _buildAllItems() {
    final items = <_HubGameItem>[
      _HubGameItem(
        id: 'neon-striker',
        title: 'NEON STRIKER',
        subtitle: _strikerBest > 0 ? 'Best $_strikerBest' : 'Arcade Shooter',
        isNative: true,
        category: 'Native',
        colors: const [Color(0xFF00C6FF), Color(0xFF0072FF)],
        icon: Icons.rocket_launch_rounded,
        bestScore: _strikerBest,
        onTap: () => _openGame(const ArcadeScreen()),
      ),
      _HubGameItem(
        id: 'neon-dash',
        title: 'NEON DASH',
        subtitle: _dashBest > 0 ? 'Best $_dashBest' : 'Endless Runner',
        isNative: true,
        category: 'Native',
        colors: const [Color(0xFFFFA726), Color(0xFFFF5722)],
        icon: Icons.bolt_rounded,
        bestScore: _dashBest,
        onTap: () => _openGame(const DashScreen()),
      ),
      _HubGameItem(
        id: 'catur-ori',
        title: 'CATUR ORI',
        subtitle: _chessBest > 0 ? 'Best $_chessBest' : 'Catur Offline AI',
        isNative: true,
        category: 'Native',
        colors: const [Color(0xFFE8C46A), Color(0xFF92400E)],
        icon: Icons.grid_on_rounded,
        emoji: '♟️',
        bestScore: _chessBest,
        onTap: () => _openGame(const ChessScreen()),
      ),
      _HubGameItem(
        id: 'neon-block',
        title: 'NEON BLOCK',
        subtitle: _blockBest > 0 ? 'Best $_blockBest' : 'Block Puzzle 8x8',
        isNative: true,
        category: 'Native',
        colors: const [Color(0xFF00F5FF), Color(0xFF7B2FFF)],
        icon: Icons.grid_view_rounded,
        bestScore: _blockBest,
        onTap: () => _openGame(const NeonBlockScreen()),
      ),
      _HubGameItem(
        id: 'gaple-ori',
        title: 'GAPLE ORI',
        subtitle: _gapleBest > 0 ? 'Best $_gapleBest' : 'Domino 4 Pemain',
        isNative: true,
        category: 'Native',
        colors: const [Color(0xFF10B981), Color(0xFF065F46)],
        icon: Icons.casino_rounded,
        bestScore: _gapleBest,
        onTap: () => _openGame(const GapleScreen()),
      ),
      _HubGameItem(
        id: 'congklak-ori',
        title: 'CONGKLAK ORI',
        subtitle: _congklakBest > 0 ? 'Best $_congklakBest' : 'Dakon Klasik AI',
        isNative: true,
        category: 'Native',
        colors: const [Color(0xFFD9A441), Color(0xFF5C3317)],
        icon: Icons.grain_rounded,
        bestScore: _congklakBest,
        onTap: () => _openGame(const CongklakScreen()),
      ),
      _HubGameItem(
        id: 'ludo-ori',
        title: 'LUDO ORI',
        subtitle: _ludoBest > 0 ? 'Menang $_ludoBest' : 'Ludo 4 Warna AI',
        isNative: true,
        category: 'Native',
        colors: const [Color(0xFFEF4444), Color(0xFF1D4ED8)],
        icon: Icons.casino_rounded,
        bestScore: _ludoBest,
        onTap: () => _openGame(const LudoScreen()),
      ),
      _HubGameItem(
        id: 'ular-tangga-ori',
        title: 'ULAR TANGGA',
        subtitle: _ularBest > 0 ? 'Menang $_ularBest' : 'Papan 1-100 Klasik',
        isNative: true,
        category: 'Native',
        colors: const [Color(0xFF22C55E), Color(0xFF0EA5E9)],
        icon: Icons.stairs_rounded,
        bestScore: _ularBest,
        onTap: () => _openGame(const UlarTanggaScreen()),
      ),
      _HubGameItem(
        id: 'dam-ori',
        title: 'DAM-DAMAN ORI',
        subtitle: _damBest > 0 ? 'Menang $_damBest' : 'Checkers AI / 2P',
        isNative: true,
        category: 'Native',
        colors: const [Color(0xFFDC2626), Color(0xFF78350F)],
        icon: Icons.workspace_premium_rounded,
        bestScore: _damBest,
        onTap: () => _openGame(const DamScreen()),
      ),
      _HubGameItem(
        id: 'water-sort-neon',
        title: 'WATER SORT',
        subtitle: _waterBest > 1 ? 'Level $_waterBest' : 'Puzzle Tabung Neon',
        isNative: true,
        category: 'Native',
        colors: const [Color(0xFF00F5FF), Color(0xFF9333EA)],
        icon: Icons.science_rounded,
        bestScore: _waterBest,
        onTap: () => _openGame(const WaterSortScreen()),
      ),
      _HubGameItem(
        id: 'fruit-merge-neon',
        title: 'FRUIT MERGE',
        subtitle: _fruitBest > 0 ? 'Best $_fruitBest' : 'Fisika Gabung Buah',
        isNative: true,
        category: 'Native',
        colors: const [Color(0xFF22C55E), Color(0xFFF97316)],
        icon: Icons.bubble_chart_rounded,
        bestScore: _fruitBest,
        onTap: () => _openGame(const FruitMergeScreen()),
      ),
      _HubGameItem(
        id: 'karambol-ori',
        title: 'KARAMBOL ORI',
        subtitle: _karambolBest > 0 ? 'Best $_karambolBest' : 'Sentil Karambol 2D',
        isNative: true,
        category: 'Native',
        colors: const [Color(0xFFD9A441), Color(0xFF7C2D12)],
        icon: Icons.adjust_rounded,
        bestScore: _karambolBest,
        onTap: () => _openGame(const KarambolScreen()),
      ),
    ];

    for (int i = 0; i < _remoteGames.length; i++) {
      final g = _remoteGames[i];
      final best = _webBests[g.id] ?? 0;
      items.add(
        _HubGameItem(
          id: g.id,
          title: g.title,
          subtitle: best > 0 ? 'Best $best' : g.genre,
          isNative: false,
          category: _resolveCategory(g),
          colors: [g.accentColor, Color.lerp(g.accentColor, const Color(0xFF0F172A), 0.35)!],
          icon: Icons.layers_rounded,
          emoji: g.emoji,
          bestScore: best,
          onTap: () => _openGame(WebGamePlayerScreen(game: g)),
        ),
      );
    }
    return items;
  }

  void _quickPlayRandom() {
    final all = _buildAllItems();
    if (all.isEmpty) return;
    final pick = all[Random().nextInt(all.length)];
    pick.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final allItems = _buildAllItems();
    final q = _searchCtrl.text.trim().toLowerCase();
    final filtered = allItems.where((g) {
      if (_topTab == 2 && !g.isNative) return false;
      if (_topTab == 3 && g.isNative) return false;
      if (_selectedCategory != 'Semua' && g.category != _selectedCategory) return false;
      if (q.isNotEmpty &&
          !g.title.toLowerCase().contains(q) &&
          !g.subtitle.toLowerCase().contains(q) &&
          !g.category.toLowerCase().contains(q)) {
        return false;
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: _bottomTab == 3
                  ? _buildScoresView(allItems)
                  : _bottomTab == 4
                      ? _buildProfileView(allItems)
                      : _buildGamesHome(allItems, filtered),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildTopBar() {
    const tabs = ['Semua', 'Game', 'Native', 'Cloud'];
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 10, 12, 8),
      child: _searching
          ? Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    autofocus: true,
                    style: const TextStyle(color: Color(0xFF111827), fontSize: 14, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      hintText: 'Cari dari 100+ game Nufat Games...',
                      hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
                      prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF6B7280)),
                      filled: true,
                      fillColor: const Color(0xFFF3F4F6),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(999),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() => _searching = false);
                  },
                  child: const Text('Batal', style: TextStyle(color: Color(0xFF4B5563), fontWeight: FontWeight.w700)),
                ),
              ],
            )
          : Row(
              children: [
                for (int i = 0; i < tabs.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(right: 18),
                    child: GestureDetector(
                      onTap: () => setState(() {
                        _topTab = i;
                        _bottomTab = 0;
                        _selectedCategory = 'Semua';
                      }),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            tabs[i],
                            style: TextStyle(
                              fontSize: _topTab == i ? 20 : 15,
                              fontWeight: _topTab == i ? FontWeight.w900 : FontWeight.w600,
                              color: _topTab == i ? const Color(0xFF111827) : const Color(0xFF9CA3AF),
                            ),
                          ),
                          const SizedBox(height: 3),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            width: _topTab == i ? 18 : 0,
                            height: 3.5,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFACC15),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const Spacer(),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: () => setState(() => _searching = true),
                  icon: const Icon(Icons.search_rounded, color: Color(0xFF374151), size: 24),
                ),
              ],
            ),
    );
  }

  Widget _buildGamesHome(List<_HubGameItem> allItems, List<_HubGameItem> filtered) {
    final featuredItems = allItems.take(8).toList();
    return RefreshIndicator(
      color: const Color(0xFFFF8C42),
      onRefresh: _loadAll,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
        children: [
          // Featured Orange Carousel Banner
          Container(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFF8C42), Color(0xFFFFA94D)],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF8C42).withValues(alpha: 0.25),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0x38000000),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.local_fire_department_rounded, size: 14, color: Color(0xFFFDE047)),
                          SizedBox(width: 4),
                          Text(
                            'Nufat Games Populer',
                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: _loadingRemote ? null : _loadRemoteCatalog,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFFEC4899), Color(0xFF8B5CF6)]),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _loadingRemote ? Icons.sync_rounded : Icons.cloud_done_rounded,
                              size: 13,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _remoteFromServer ? '${allItems.length} Game ›' : 'Sync API ›',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 128,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: featuredItems.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (_, idx) {
                      final g = featuredItems[idx];
                      return GestureDetector(
                        onTap: g.onTap,
                        child: Container(
                          width: 118,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Column(
                            children: [
                              Expanded(
                                child: Stack(
                                  children: [
                                    GameTileArtwork(
                                      id: g.id,
                                      category: g.category,
                                      colors: g.colors,
                                      icon: g.icon,
                                      emoji: g.emoji,
                                      compact: true,
                                    ),
                                    Positioned(
                                      top: 6,
                                      left: 6,
                                      child: _CornerBadge(isNative: g.isNative),
                                    ),
                                  ],
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
                                child: Text(
                                  g.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF9A3412),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Category Filter Chips (effortless browsing across 100+ games)
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, idx) {
                final cat = _categories[idx];
                final active = _selectedCategory == cat;
                return GestureDetector(
                  onTap: () => setState(() => _selectedCategory = cat),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: active ? const Color(0xFF111827) : Colors.white,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: active ? const Color(0xFF111827) : const Color(0xFFE5E7EB),
                      ),
                    ),
                    child: Text(
                      cat,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: active ? Colors.white : const Color(0xFF4B5563),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Text(
                _selectedCategory == 'Semua' ? 'SEMUA GAME' : 'KATEGORI $_selectedCategory'.toUpperCase(),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                  color: Color(0xFF6B7280),
                ),
              ),
              const Spacer(),
              Text(
                '${filtered.length} game',
                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF9CA3AF)),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // 3-Column Clean Square Tile Grid
          if (filtered.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Text(
                  'Tidak ada game yang cocok dengan pencarian.',
                  style: TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w600),
                ),
              ),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filtered.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 14,
                childAspectRatio: 0.76,
              ),
              itemBuilder: (_, idx) => _SquareGameTile(item: filtered[idx]),
            ),
        ],
      ),
    );
  }

  Widget _buildScoresView(List<_HubGameItem> allItems) {
    final played = allItems.where((g) => g.bestScore > 0).toList()
      ..sort((a, b) => b.bestScore.compareTo(a.bestScore));
    final list = played.isNotEmpty ? played : allItems.take(10).toList();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          played.isNotEmpty ? 'Rekor Skor Terbaik (${played.length} game)' : 'Rekor Skor Terbaik',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF111827)),
        ),
        const SizedBox(height: 12),
        for (final g in list)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: g.colors),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: g.emoji != null
                        ? Text(g.emoji!, style: const TextStyle(fontSize: 22))
                        : Icon(g.icon, color: Colors.white, size: 22),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(g.title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Color(0xFF111827))),
                      Text(
                        g.isNative ? 'Ori Native · Offline' : '${g.category} · Cloud WebView',
                        style: const TextStyle(fontSize: 11.5, color: Color(0xFF6B7280)),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${g.bestScore}',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF059669)),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildProfileView(List<_HubGameItem> allItems) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.asset('assets/icon/app_icon.png', width: 52, height: 52, fit: BoxFit.cover),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Nufat Games', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF111827))),
                      SizedBox(height: 2),
                      Text('Package: nufat.id.games', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280), fontWeight: FontWeight.w600)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Total koleksi aktif: ${allItems.length} game (3 Ori Native + ${_remoteGames.length} Cloud WebView).',
                style: const TextStyle(fontSize: 13, color: Color(0xFF374151)),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFF8C42),
                  foregroundColor: Colors.white,
                ),
                onPressed: _loadRemoteCatalog,
                icon: const Icon(Icons.sync_rounded, size: 18),
                label: const Text('Sinkronkan Katalog API', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _NavBtn(
              icon: Icons.sports_esports_rounded,
              label: 'Main',
              active: _bottomTab == 0,
              onTap: () => setState(() {
                _bottomTab = 0;
                _topTab = 1;
              }),
            ),
            _NavBtn(
              icon: Icons.cloud_outlined,
              label: 'Cloud',
              active: _bottomTab == 1,
              onTap: () => setState(() {
                _bottomTab = 1;
                _topTab = 3;
              }),
            ),
            GestureDetector(
              onTap: _quickPlayRandom,
              child: Container(
                width: 46,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFFDE047),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFACC15).withValues(alpha: 0.45),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(Icons.play_arrow_rounded, color: Color(0xFF111827), size: 28),
              ),
            ),
            _NavBtn(
              icon: Icons.emoji_events_outlined,
              label: 'Skor',
              active: _bottomTab == 3,
              onTap: () => setState(() => _bottomTab = 3),
            ),
            _NavBtn(
              icon: Icons.person_outline_rounded,
              label: 'Aku',
              active: _bottomTab == 4,
              onTap: () => setState(() => _bottomTab = 4),
            ),
          ],
        ),
      ),
    );
  }
}

class _SquareGameTile extends StatelessWidget {
  const _SquareGameTile({required this.item});

  final _HubGameItem item;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: item.onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: item.colors.first.withValues(alpha: 0.30),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  GameTileArtwork(
                    id: item.id,
                    category: item.category,
                    colors: item.colors,
                    icon: item.icon,
                    emoji: item.emoji,
                  ),
                  Positioned(
                    top: 7,
                    left: 7,
                    child: _CornerBadge(isNative: item.isNative),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            item.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w900,
              color: Color(0xFF1F2937),
            ),
          ),
          Text(
            item.subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Color(0xFF9CA3AF),
            ),
          ),
        ],
      ),
    );
  }
}

class _CornerBadge extends StatelessWidget {
  const _CornerBadge({required this.isNative});

  final bool isNative;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isNative ? const Color(0xFFFACC15) : const Color(0xFF111827).withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        isNative ? 'ORI' : 'WEB',
        style: TextStyle(
          fontSize: 8.5,
          fontWeight: FontWeight.w900,
          color: isNative ? const Color(0xFF111827) : Colors.white,
        ),
      ),
    );
  }
}

class _NavBtn extends StatelessWidget {
  const _NavBtn({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? const Color(0xFF111827) : const Color(0xFF9CA3AF);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 23),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
