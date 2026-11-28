import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../utils/game_orientation.dart';

class CongklakScreen extends StatefulWidget {
  const CongklakScreen({super.key});

  @override
  State<CongklakScreen> createState() => _CongklakScreenState();
}

class _CongklakScreenState extends State<CongklakScreen> {
  static const String _bestKey = 'nufat_congklak_best_v1';
  // Pits 0..6: Player's small holes (left to right on bottom row)
  // Pit 7: Player's Lumbung (right)
  // Pits 8..14: AI's small holes (right to left on top row)
  // Pit 15: AI's Lumbung (left)
  late List<int> _pits;
  bool _playerTurn = true;
  bool _vsAi = true;
  bool _animating = false;
  bool _gameOver = false;
  int? _activePit;
  int _inHand = 0;
  int _bestScore = 0;
  String _status = 'Giliranmu! Pilih lubang di baris bawah.';
  final Random _rng = Random();

  @override
  void initState() {
    super.initState();
    GameOrientation.lockLandscape();
    _loadBest();
    _resetGame();
  }

  @override
  void dispose() {
    GameOrientation.lockPortrait();
    super.dispose();
  }

  Future<void> _loadBest() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() => _bestScore = prefs.getInt(_bestKey) ?? 0);
    } catch (_) {}
  }

  Future<void> _saveBest(int val) async {
    if (val <= _bestScore) return;
    _bestScore = val;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_bestKey, val);
    } catch (_) {}
  }

  void _resetGame() {
    _pits = List<int>.filled(16, 7);
    _pits[7] = 0;
    _pits[15] = 0;
    _playerTurn = true;
    _animating = false;
    _gameOver = false;
    _activePit = null;
    _inHand = 0;
    _status = 'Giliranmu! Pilih lubang di baris bawah.';
    setState(() {});
  }

  bool _sideEmpty(bool isPlayer) {
    final start = isPlayer ? 0 : 8;
    for (int i = start; i < start + 7; i++) {
      if (_pits[i] > 0) return false;
    }
    return true;
  }

  Future<void> _playPit(int startIdx) async {
    if (_animating || _gameOver) return;
    if (_playerTurn && (startIdx < 0 || startIdx > 6)) return;
    if (!_playerTurn && (startIdx < 8 || startIdx > 14)) return;
    if (_pits[startIdx] == 0) return;

    final isPlayer = _playerTurn;
    final myStore = isPlayer ? 7 : 15;
    final oppStore = isPlayer ? 15 : 7;

    setState(() {
      _animating = true;
      _inHand = _pits[startIdx];
      _pits[startIdx] = 0;
      _activePit = startIdx;
      _status = '${isPlayer ? "Kamu" : (_vsAi ? "Bot AI" : "Pemain 2")} menebar $_inHand biji...';
    });
    HapticFeedback.selectionClick();

    int cur = startIdx;
    while (_inHand > 0) {
      await Future<void>.delayed(const Duration(milliseconds: 115));
      if (!mounted) return;

      cur = (cur + 1) % 16;
      if (cur == oppStore) cur = (cur + 1) % 16;

      setState(() {
        _pits[cur]++;
        _inHand--;
        _activePit = cur;
      });

      if (_inHand == 0 && cur != myStore && _pits[cur] > 1) {
        await Future<void>.delayed(const Duration(milliseconds: 160));
        if (!mounted) return;
        setState(() {
          _inHand = _pits[cur];
          _pits[cur] = 0;
          _status = 'Lanjut menebar $_inHand biji!';
        });
      }
    }

    // Capture ("Tembak")
    final onOwnSide = isPlayer ? (cur >= 0 && cur <= 6) : (cur >= 8 && cur <= 14);
    if (onOwnSide && _pits[cur] == 1) {
      final opposite = 14 - cur;
      if (_pits[opposite] > 0) {
        final captured = _pits[opposite] + 1;
        await Future<void>.delayed(const Duration(milliseconds: 180));
        if (!mounted) return;
        HapticFeedback.heavyImpact();
        setState(() {
          _pits[myStore] += captured;
          _pits[cur] = 0;
          _pits[opposite] = 0;
          _status = 'TEMBAK! Dapat $captured biji ke lumbung!';
        });
      }
    }

    // Game over check
    if (_sideEmpty(true) || _sideEmpty(false)) {
      for (int i = 0; i < 7; i++) {
        _pits[7] += _pits[i];
        _pits[i] = 0;
      }
      for (int i = 8; i < 15; i++) {
        _pits[15] += _pits[i];
        _pits[i] = 0;
      }
      _saveBest(_pits[7]);
      setState(() {
        _animating = false;
        _gameOver = true;
        _activePit = null;
        if (_pits[7] > _pits[15]) {
          _status = 'KAMU MENANG! (${_pits[7]} vs ${_pits[15]})';
        } else if (_pits[7] < _pits[15]) {
          _status = '${_vsAi ? "BOT AI" : "PEMAIN 2"} MENANG! (${_pits[15]} vs ${_pits[7]})';
        } else {
          _status = 'SERI! (${_pits[7]} vs ${_pits[15]})';
        }
      });
      return;
    }

    final extraTurn = cur == myStore;
    if (extraTurn) HapticFeedback.mediumImpact();

    setState(() {
      _animating = false;
      _activePit = null;
      if (!extraTurn) {
        _playerTurn = !_playerTurn;
      }
      if (extraTurn) {
        _status = isPlayer
            ? 'Masuk Lumbung! Giliran ekstra untukmu!'
            : '${_vsAi ? "Bot AI" : "Pemain 2"} masuk lumbung — giliran ekstra!';
      } else {
        _status = _playerTurn
            ? 'Giliranmu! Pilih lubang di baris bawah.'
            : 'Giliran ${_vsAi ? "Bot AI" : "Pemain 2"}...';
      }
    });

    if (!_playerTurn && _vsAi && !_gameOver) {
      _runAiTurn();
    }
  }

  Future<void> _runAiTurn() async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!mounted || _gameOver || _playerTurn || _animating) return;

    final valid = <int>[];
    for (int i = 8; i <= 14; i++) {
      if (_pits[i] > 0) valid.add(i);
    }
    if (valid.isEmpty) return;

    int? chosen;
    for (final idx in valid) {
      if (idx + _pits[idx] == 15) {
        chosen = idx;
        break;
      }
    }
    chosen ??= valid[_rng.nextInt(valid.length)];
    await _playPit(chosen);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF160E09),
      body: Stack(
        children: [
          // Warm Nusantara batik/wooden tabletop backdrop
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.15,
                colors: [Color(0xFF321E12), Color(0xFF160D08)],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
              child: Column(
                children: [
                  // Sleek Horizontal Top HUD
                  Row(
                    children: [
                      _HudIconBtn(
                        icon: Icons.arrow_back_rounded,
                        onTap: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: 10),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'CONGKLAK ORI',
                            style: TextStyle(
                              color: Color(0xFFFDE68A),
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                              letterSpacing: 1.2,
                            ),
                          ),
                          Text(
                            'Papan Dakon Nusantara',
                            style: TextStyle(color: Colors.white54, fontSize: 10),
                          ),
                        ],
                      ),
                      const SizedBox(width: 14),
                      // Center Status Pill
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.38),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: (_playerTurn ? const Color(0xFFF59E0B) : const Color(0xFFFF6B35))
                                  .withValues(alpha: 0.45),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (_inHand > 0) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  margin: const EdgeInsets.only(right: 8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF59E0B),
                                    borderRadius: BorderRadius.circular(99),
                                  ),
                                  child: Text(
                                    'Tangan: $_inHand',
                                    style: const TextStyle(
                                      color: Color(0xFF1A0E07),
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ],
                              Flexible(
                                child: Text(
                                  _status,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Text(
                          'Rekor: $_bestScore',
                          style: const TextStyle(
                            color: Color(0xFFFDE68A),
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _animating
                            ? null
                            : () {
                                setState(() => _vsAi = !_vsAi);
                                _resetGame();
                              },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B).withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.6)),
                          ),
                          child: Text(
                            _vsAi ? 'vs AI' : '2 Pemain',
                            style: const TextStyle(
                              color: Color(0xFFFDE68A),
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      _HudIconBtn(
                        icon: Icons.refresh_rounded,
                        onTap: _resetGame,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Authentic Horizontal Carved Wooden Congklak Board
                  Expanded(
                    child: Center(
                      child: Container(
                        width: double.infinity,
                        constraints: const BoxConstraints(maxHeight: 270),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0xFF8B4E24),
                              Color(0xFF6B3917),
                              Color(0xFF4A250D),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(96),
                          border: Border.all(color: const Color(0xFFD4A24C), width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.7),
                              blurRadius: 28,
                              offset: const Offset(0, 14),
                            ),
                            BoxShadow(
                              color: const Color(0xFFD4A24C).withValues(alpha: 0.15),
                              blurRadius: 16,
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(93),
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: CustomPaint(painter: _WoodGrainPainter()),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                                child: Row(
                                  children: [
                                    // Left Lumbung (AI / Pemain 2)
                                    _CarvedLumbung(
                                      label: _vsAi ? 'AI' : 'P2',
                                      count: _pits[15],
                                      highlighted: _activePit == 15,
                                      isTurn: !_playerTurn && !_gameOver,
                                      accent: const Color(0xFFFF7849),
                                    ),
                                    const SizedBox(width: 14),
                                    // Center 2 Horizontal Rows of 7 Pits
                                    Expanded(
                                      child: Column(
                                        children: [
                                          // Top Row: Opponent (14 down to 8, left-to-right)
                                          Expanded(
                                            child: Row(
                                              children: List.generate(7, (col) {
                                                final idx = 14 - col;
                                                return Expanded(
                                                  child: Padding(
                                                    padding: const EdgeInsets.symmetric(horizontal: 3),
                                                    child: _CarvedHole(
                                                      count: _pits[idx],
                                                      active: _activePit == idx,
                                                      playable: !_playerTurn && !_vsAi && !_animating && _pits[idx] > 0,
                                                      accent: const Color(0xFFFF7849),
                                                      onTap: () => _playPit(idx),
                                                    ),
                                                  ),
                                                );
                                              }),
                                            ),
                                          ),
                                          // Decorative center divider ridge
                                          Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
                                            child: Row(
                                              children: [
                                                Text(
                                                  _vsAi ? '▲ BARIS LAWAN (AI)' : '▲ BARIS PEMAIN 2',
                                                  style: TextStyle(
                                                    color: const Color(0xFFFDE68A).withValues(alpha: 0.55),
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.w800,
                                                    letterSpacing: 0.8,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Container(
                                                    height: 1.2,
                                                    decoration: BoxDecoration(
                                                      gradient: LinearGradient(
                                                        colors: [
                                                          const Color(0xFFD4A24C).withValues(alpha: 0.15),
                                                          const Color(0xFFD4A24C).withValues(alpha: 0.55),
                                                          const Color(0xFFD4A24C).withValues(alpha: 0.15),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  '▼ BARISMU (TAP)',
                                                  style: TextStyle(
                                                    color: const Color(0xFFFDE68A).withValues(alpha: 0.85),
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.w800,
                                                    letterSpacing: 0.8,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          // Bottom Row: Player (0 to 6, left-to-right)
                                          Expanded(
                                            child: Row(
                                              children: List.generate(7, (col) {
                                                final idx = col;
                                                return Expanded(
                                                  child: Padding(
                                                    padding: const EdgeInsets.symmetric(horizontal: 3),
                                                    child: _CarvedHole(
                                                      count: _pits[idx],
                                                      active: _activePit == idx,
                                                      playable: _playerTurn && !_animating && _pits[idx] > 0,
                                                      accent: const Color(0xFFFBBF24),
                                                      onTap: () => _playPit(idx),
                                                    ),
                                                  ),
                                                );
                                              }),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    // Right Lumbung (Player)
                                    _CarvedLumbung(
                                      label: 'KAMU',
                                      count: _pits[7],
                                      highlighted: _activePit == 7,
                                      isTurn: _playerTurn && !_gameOver,
                                      accent: const Color(0xFFFBBF24),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_gameOver)
            Container(
              color: Colors.black.withValues(alpha: 0.8),
              child: Center(
                child: Container(
                  width: 360,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: const Color(0xFF26160D),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: const Color(0xFFD4A24C), width: 1.8),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _status,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFFFDE68A),
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Rekor Lumbung Terbaik: $_bestScore biji',
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF59E0B),
                          foregroundColor: const Color(0xFF1A0E07),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 11),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _resetGame,
                        icon: const Icon(Icons.replay_rounded),
                        label: const Text('MAIN LAGI', style: TextStyle(fontWeight: FontWeight.w900)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _HudIconBtn extends StatelessWidget {
  const _HudIconBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white12),
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }
}

class _CarvedLumbung extends StatelessWidget {
  const _CarvedLumbung({
    required this.label,
    required this.count,
    required this.highlighted,
    required this.isTurn,
    required this.accent,
  });

  final String label;
  final int count;
  final bool highlighted;
  final bool isTurn;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      width: 92,
      height: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        gradient: const RadialGradient(
          center: Alignment.center,
          radius: 0.9,
          colors: [Color(0xFF1F0F06), Color(0xFF33190B)],
        ),
        borderRadius: BorderRadius.circular(48),
        border: Border.all(
          color: highlighted
              ? Colors.white
              : isTurn
                  ? accent
                  : const Color(0xFFD4A24C).withValues(alpha: 0.4),
          width: highlighted ? 2.6 : (isTurn ? 2 : 1.4),
        ),
        boxShadow: [
          if (highlighted || isTurn)
            BoxShadow(color: accent.withValues(alpha: 0.35), blurRadius: 14),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isTurn ? accent : Colors.white60,
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: _SeedCluster(count: count, maxDots: 18, accent: accent),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: accent.withValues(alpha: 0.5)),
            ),
            child: Text(
              '$count',
              style: TextStyle(color: accent, fontSize: 15, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

class _CarvedHole extends StatelessWidget {
  const _CarvedHole({
    required this.count,
    required this.active,
    required this.playable,
    required this.accent,
    required this.onTap,
  });

  final int count;
  final bool active;
  final bool playable;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: playable ? onTap : null,
      child: LayoutBuilder(
        builder: (_, constraints) {
          final size = min(constraints.maxWidth, constraints.maxHeight);
          return Center(
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  width: size,
                  height: size,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      center: const Alignment(-0.2, -0.2),
                      radius: 0.9,
                      colors: active
                          ? [accent.withValues(alpha: 0.35), const Color(0xFF281308)]
                          : const [Color(0xFF1A0D05), Color(0xFF341A0B)],
                    ),
                    border: Border.all(
                      color: active
                          ? Colors.white
                          : playable
                              ? accent.withValues(alpha: 0.85)
                              : const Color(0xFFD4A24C).withValues(alpha: 0.25),
                      width: active ? 2.4 : (playable ? 1.8 : 1.1),
                    ),
                    boxShadow: [
                      if (active || playable)
                        BoxShadow(
                          color: accent.withValues(alpha: active ? 0.5 : 0.2),
                          blurRadius: active ? 12 : 6,
                        ),
                    ],
                  ),
                  child: _SeedCluster(count: count, maxDots: 12, accent: accent),
                ),
                Positioned(
                  bottom: -3,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A0E07),
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(
                        color: count > 0 ? accent.withValues(alpha: 0.7) : Colors.white12,
                      ),
                    ),
                    child: Text(
                      '$count',
                      style: TextStyle(
                        color: count > 0 ? Colors.white : Colors.white30,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Renders natural glossy cowrie/seed beads inside a Congklak pit.
class _SeedCluster extends StatelessWidget {
  const _SeedCluster({
    required this.count,
    required this.maxDots,
    required this.accent,
  });

  final int count;
  final int maxDots;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    final shown = min(count, maxDots);
    return LayoutBuilder(
      builder: (_, box) {
        final cx = box.maxWidth / 2;
        final cy = box.maxHeight / 2;
        final radius = min(cx, cy) * 0.62;
        return Stack(
          children: List.generate(shown, (i) {
            final ring = i == 0 ? 0.0 : (i <= 6 ? 0.52 : 0.92);
            final angle = i * 2.39996; // Golden angle for organic seed spread
            final dx = cx + cos(angle) * radius * ring - 4.2;
            final dy = cy + sin(angle) * radius * ring - 3.6;
            return Positioned(
              left: dx.clamp(1.0, max(1.0, box.maxWidth - 9.5)),
              top: dy.clamp(1.0, max(1.0, box.maxHeight - 8.5)),
              child: Container(
                width: 8.5,
                height: 7.2,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(99),
                  gradient: RadialGradient(
                    center: const Alignment(-0.35, -0.35),
                    colors: [
                      const Color(0xFFFFFBEB),
                      Color.lerp(const Color(0xFFF5D0A9), accent, 0.35)!,
                      const Color(0xFF92400E),
                    ],
                  ),
                  boxShadow: const [
                    BoxShadow(color: Colors.black54, blurRadius: 2, offset: Offset(0, 1)),
                  ],
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

class _WoodGrainPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.black.withValues(alpha: 0.09)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    for (double y = 14; y < size.height; y += 18) {
      final path = Path()..moveTo(0, y);
      path.quadraticBezierTo(size.width * 0.35, y + 6, size.width * 0.7, y - 4);
      path.quadraticBezierTo(size.width * 0.88, y - 8, size.width, y + 2);
      canvas.drawPath(path, p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
