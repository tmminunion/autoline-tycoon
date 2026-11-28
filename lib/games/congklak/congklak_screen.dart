import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CongklakScreen extends StatefulWidget {
  const CongklakScreen({super.key});

  @override
  State<CongklakScreen> createState() => _CongklakScreenState();
}

class _CongklakScreenState extends State<CongklakScreen> {
  static const String _bestKey = 'nufat_congklak_best_v1';
  // Pits 0..6: Player's small holes (left to right)
  // Pit 7: Player's Lumbung (right)
  // Pits 8..14: AI's small holes (right to left visually)
  // Pit 15: AI's Lumbung (left)
  late List<int> _pits;
  bool _playerTurn = true;
  bool _vsAi = true;
  bool _animating = false;
  bool _gameOver = false;
  int? _activePit;
  int _inHand = 0;
  int _bestScore = 0;
  String _status = 'Giliranmu! Pilih salah satu lubang di bawah.';
  final Random _rng = Random();

  @override
  void initState() {
    super.initState();
    _loadBest();
    _resetGame();
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

      // If last seed lands in a non-empty small pit, pick up and keep sowing (classic Congklak)
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

    // Check capture ("Tembak") if last seed landed in empty pit on own side
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

    // Check if game ended
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

    // Extra turn if last seed landed in own lumbung
    final extraTurn = cur == myStore;
    if (extraTurn) {
      HapticFeedback.mediumImpact();
    }

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
    await Future<void>.delayed(const Duration(milliseconds: 520));
    if (!mounted || _gameOver || _playerTurn || _animating) return;

    final valid = <int>[];
    for (int i = 8; i <= 14; i++) {
      if (_pits[i] > 0) valid.add(i);
    }
    if (valid.isEmpty) return;

    // Smart AI: prefer exact landing in lumbung (15), else highest seeds or random
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
      backgroundColor: const Color(0xFF140D0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1F140E),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'CONGKLAK ORI',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.4, fontSize: 17),
        ),
        actions: [
          TextButton(
            onPressed: _animating
                ? null
                : () {
                    setState(() => _vsAi = !_vsAi);
                    _resetGame();
                  },
            child: Text(
              _vsAi ? 'vs AI' : '2 Pemain',
              style: const TextStyle(color: Color(0xFFFFD43B), fontWeight: FontWeight.w800),
            ),
          ),
          IconButton(
            tooltip: 'Ulangi',
            onPressed: _resetGame,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.1,
                colors: [Color(0xFF2B1B12), Color(0xFF120B08)],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
              child: Column(
                children: [
                  // Score Header
                  Row(
                    children: [
                      Expanded(
                        child: _LumbungCard(
                          title: _vsAi ? 'LUMBUNG AI' : 'PEMAIN 2',
                          value: _pits[15],
                          active: !_playerTurn && !_gameOver,
                          accent: const Color(0xFFFF6B35),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _LumbungCard(
                          title: 'LUMBUNGMU',
                          value: _pits[7],
                          active: _playerTurn && !_gameOver,
                          accent: const Color(0xFFFFD43B),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Status pill
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFFFD43B).withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      _status,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Congklak Wooden Board (Vertical friendly layout for mobile portrait)
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF5C3317), Color(0xFF3A1E0D)],
                        ),
                        borderRadius: BorderRadius.circular(36),
                        border: Border.all(color: const Color(0xFFD9A441), width: 2.2),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.55), blurRadius: 24, offset: const Offset(0, 10)),
                        ],
                      ),
                      child: Column(
                        children: [
                          // AI Lumbung (top)
                          _StorePit(
                            label: _vsAi ? 'AI' : 'P2',
                            count: _pits[15],
                            highlighted: _activePit == 15,
                            accent: const Color(0xFFFF6B35),
                          ),
                          const SizedBox(height: 10),
                          // 7 rows of paired pits: Left = AI (14 down to 8), Right = Player (0 to 6)
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: List.generate(7, (row) {
                                final aiIdx = 14 - row;
                                final myIdx = row;
                                return Row(
                                  children: [
                                    Expanded(
                                      child: _SmallPit(
                                        count: _pits[aiIdx],
                                        active: _activePit == aiIdx,
                                        playable: !_playerTurn && !_vsAi && !_animating && _pits[aiIdx] > 0,
                                        accent: const Color(0xFFFF6B35),
                                        onTap: () => _playPit(aiIdx),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 8),
                                      child: Text(
                                        '${row + 1}',
                                        style: TextStyle(
                                          color: const Color(0xFFFFD43B).withValues(alpha: 0.5),
                                          fontWeight: FontWeight.w800,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: _SmallPit(
                                        count: _pits[myIdx],
                                        active: _activePit == myIdx,
                                        playable: _playerTurn && !_animating && _pits[myIdx] > 0,
                                        accent: const Color(0xFFFFD43B),
                                        onTap: () => _playPit(myIdx),
                                      ),
                                    ),
                                  ],
                                );
                              }),
                            ),
                          ),
                          const SizedBox(height: 10),
                          // Player Lumbung (bottom)
                          _StorePit(
                            label: 'KAMU',
                            count: _pits[7],
                            highlighted: _activePit == 7,
                            accent: const Color(0xFFFFD43B),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Kiri: Lawan  •  Kanan: Lubangmu (Tap untuk main)',
                        style: TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                      Text(
                        'Rekor: $_bestScore',
                        style: const TextStyle(color: Color(0xFFFFD43B), fontSize: 11, fontWeight: FontWeight.w800),
                      ),
                    ],
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
                  margin: const EdgeInsets.all(24),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF24150E),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: const Color(0xFFFFD43B), width: 1.6),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _status,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Color(0xFFFFD43B), fontSize: 20, fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Rekor Lumbung Terbaik: $_bestScore biji',
                        style: const TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      const SizedBox(height: 18),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFD43B),
                          foregroundColor: const Color(0xFF140D0A),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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

class _LumbungCard extends StatelessWidget {
  const _LumbungCard({
    required this.title,
    required this.value,
    required this.active,
    required this.accent,
  });
  final String title;
  final int value;
  final bool active;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: active ? accent.withValues(alpha: 0.16) : Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: active ? accent : Colors.white.withValues(alpha: 0.14), width: active ? 1.6 : 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: TextStyle(color: active ? accent : Colors.white60, fontSize: 11, fontWeight: FontWeight.w800)),
          Text('$value', style: TextStyle(color: accent, fontSize: 20, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _StorePit extends StatelessWidget {
  const _StorePit({required this.label, required this.count, required this.highlighted, required this.accent});
  final String label;
  final int count;
  final bool highlighted;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      height: 52,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF241208),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: highlighted ? accent : accent.withValues(alpha: 0.4),
          width: highlighted ? 2.4 : 1.4,
        ),
        boxShadow: highlighted ? [BoxShadow(color: accent.withValues(alpha: 0.45), blurRadius: 12)] : null,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('$label  •  ', style: const TextStyle(color: Colors.white60, fontSize: 12, fontWeight: FontWeight.w800)),
          Text('$count biji', style: TextStyle(color: accent, fontSize: 18, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _SmallPit extends StatelessWidget {
  const _SmallPit({
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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        height: 46,
        decoration: BoxDecoration(
          color: active ? accent.withValues(alpha: 0.25) : const Color(0xFF26140A),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: active
                ? Colors.white
                : playable
                    ? accent.withValues(alpha: 0.75)
                    : Colors.white.withValues(alpha: 0.14),
            width: active ? 2.2 : (playable ? 1.6 : 1),
          ),
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (count > 0)
                Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [Colors.white, accent]),
                  ),
                ),
              Text(
                '$count',
                style: TextStyle(
                  color: count > 0 ? Colors.white : Colors.white30,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
