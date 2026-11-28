import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LudoScreen extends StatefulWidget {
  const LudoScreen({super.key});

  @override
  State<LudoScreen> createState() => _LudoScreenState();
}

class _LudoScreenState extends State<LudoScreen> {
  static const String _bestKey = 'nufat_ludo_best_v1';

  // 4 players: 0=Merah (Kamu), 1=Hijau (Bot), 2=Kuning (Bot), 3=Biru (Bot)
  static const List<Color> _colors = [
    Color(0xFFEF4444),
    Color(0xFF22C55E),
    Color(0xFFEAB308),
    Color(0xFF3B82F6),
  ];
  static const List<String> _names = ['Merah (Kamu)', 'Hijau', 'Kuning', 'Biru'];
  static const List<int> _startOffset = [0, 13, 26, 39];
  static const Set<int> _safeGlobal = {0, 8, 13, 21, 26, 34, 39, 47};

  // Standard 52-cell outer loop on 15x15 grid (row, col)
  static const List<List<int>> _track = [
    [6, 1], [6, 2], [6, 3], [6, 4], [6, 5],
    [5, 6], [4, 6], [3, 6], [2, 6], [1, 6], [0, 6],
    [0, 7], [0, 8],
    [1, 8], [2, 8], [3, 8], [4, 8], [5, 8],
    [6, 9], [6, 10], [6, 11], [6, 12], [6, 13], [6, 14],
    [7, 14], [8, 14],
    [8, 13], [8, 12], [8, 11], [8, 10], [8, 9],
    [9, 8], [10, 8], [11, 8], [12, 8], [13, 8], [14, 8],
    [14, 7], [14, 6],
    [13, 6], [12, 6], [11, 6], [10, 6], [9, 6],
    [8, 5], [8, 4], [8, 3], [8, 2], [8, 1], [8, 0],
    [7, 0], [6, 0],
  ];

  // Home stretch (steps 51..55) for each player; step 56 = finished
  static const List<List<List<int>>> _homeStretch = [
    [[7, 1], [7, 2], [7, 3], [7, 4], [7, 5]],
    [[1, 7], [2, 7], [3, 7], [4, 7], [5, 7]],
    [[7, 13], [7, 12], [7, 11], [7, 10], [7, 9]],
    [[13, 7], [12, 7], [11, 7], [10, 7], [9, 7]],
  ];

  static const List<List<List<int>>> _yardSlots = [
    [[2, 2], [2, 4], [4, 2], [4, 4]],
    [[2, 10], [2, 12], [4, 10], [4, 12]],
    [[10, 10], [10, 12], [12, 10], [12, 12]],
    [[10, 2], [10, 4], [12, 2], [12, 4]],
  ];

  final Random _rng = Random();
  // steps: -1 = in yard, 0..50 = outer track, 51..55 = home stretch, 56 = home
  late List<List<int>> _tokens;
  int _turn = 0;
  int _dice = 1;
  bool _rolled = false;
  bool _rolling = false;
  bool _gameOver = false;
  int _winner = -1;
  int _wins = 0;
  String _status = 'Lempar dadu untuk memulai!';
  Timer? _aiTimer;

  @override
  void initState() {
    super.initState();
    _loadBest();
    _resetGame();
  }

  @override
  void dispose() {
    _aiTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadBest() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() => _wins = prefs.getInt(_bestKey) ?? 0);
    } catch (_) {}
  }

  Future<void> _saveWins(int v) async {
    _wins = v;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_bestKey, v);
    } catch (_) {}
  }

  void _resetGame() {
    _aiTimer?.cancel();
    _tokens = List.generate(4, (_) => [-1, -1, -1, -1]);
    _turn = 0;
    _dice = 1;
    _rolled = false;
    _rolling = false;
    _gameOver = false;
    _winner = -1;
    _status = 'Giliran Merah (Kamu) — Tap Dadu!';
    setState(() {});
  }

  List<int> _movableTokens(int player, int diceVal) {
    final res = <int>[];
    for (int i = 0; i < 4; i++) {
      final s = _tokens[player][i];
      if (s == -1 && diceVal == 6) {
        res.add(i);
      } else if (s >= 0 && s + diceVal <= 56) {
        res.add(i);
      }
    }
    return res;
  }

  Future<void> _rollDice() async {
    if (_rolling || _rolled || _gameOver) return;
    setState(() => _rolling = true);
    HapticFeedback.selectionClick();
    for (int i = 0; i < 6; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 55));
      if (!mounted) return;
      setState(() => _dice = _rng.nextInt(6) + 1);
    }
    final finalRoll = _rng.nextInt(6) + 1;
    final moves = _movableTokens(_turn, finalRoll);
    setState(() {
      _dice = finalRoll;
      _rolling = false;
      _rolled = true;
    });

    if (moves.isEmpty) {
      setState(() => _status = '${_names[_turn]} dapat $finalRoll — tidak ada langkah.');
      _aiTimer = Timer(const Duration(milliseconds: 700), _nextTurn);
      return;
    }

    if (_turn == 0) {
      if (moves.length == 1) {
        _moveToken(0, moves.first);
      } else {
        setState(() => _status = 'Dapat $finalRoll! Tap pion Merah yang berkedip.');
      }
    } else {
      // Bot picks best move: capture > finish > exit yard > advance furthest
      _aiTimer = Timer(const Duration(milliseconds: 480), () {
        if (!mounted || _gameOver) return;
        int best = moves.first;
        int bestScore = -1;
        for (final idx in moves) {
          final s = _tokens[_turn][idx];
          int sc = 0;
          if (s == -1) {
            sc = 80;
          } else if (s + finalRoll == 56) {
            sc = 120;
          } else {
            final ns = s + finalRoll;
            if (ns <= 50) {
              final gPos = (_startOffset[_turn] + ns) % 52;
              if (!_safeGlobal.contains(gPos) && _hasOpponentAt(_turn, gPos)) sc = 150;
            }
            sc += ns;
          }
          if (sc > bestScore) {
            bestScore = sc;
            best = idx;
          }
        }
        _moveToken(_turn, best);
      });
    }
  }

  bool _hasOpponentAt(int player, int gPos) {
    for (int p = 0; p < 4; p++) {
      if (p == player) continue;
      for (int i = 0; i < 4; i++) {
        final s = _tokens[p][i];
        if (s >= 0 && s <= 50 && (_startOffset[p] + s) % 52 == gPos) return true;
      }
    }
    return false;
  }

  void _moveToken(int player, int idx) {
    if (!_rolled || _gameOver || player != _turn) return;
    final movable = _movableTokens(player, _dice);
    if (!movable.contains(idx)) return;

    final s = _tokens[player][idx];
    final nextStep = s == -1 ? 0 : s + _dice;
    _tokens[player][idx] = nextStep;
    bool captured = false;

    if (nextStep <= 50) {
      final gPos = (_startOffset[player] + nextStep) % 52;
      if (!_safeGlobal.contains(gPos)) {
        for (int p = 0; p < 4; p++) {
          if (p == player) continue;
          for (int i = 0; i < 4; i++) {
            final os = _tokens[p][i];
            if (os >= 0 && os <= 50 && (_startOffset[p] + os) % 52 == gPos) {
              _tokens[p][i] = -1;
              captured = true;
            }
          }
        }
      }
    }

    if (captured) HapticFeedback.heavyImpact();

    if (_tokens[player].every((e) => e == 56)) {
      if (player == 0) _saveWins(_wins + 1);
      setState(() {
        _gameOver = true;
        _winner = player;
        _status = '${_names[player]} MENANG LUDO!';
      });
      return;
    }

    final bonus = _dice == 6 || captured || nextStep == 56;
    if (bonus) {
      setState(() {
        _rolled = false;
        _status = captured
            ? '${_names[player]} makan pion lawan! Lempar lagi!'
            : '${_names[player]} dapat giliran ekstra!';
      });
      if (_turn != 0) {
        _aiTimer = Timer(const Duration(milliseconds: 520), _rollDice);
      }
    } else {
      _nextTurn();
    }
  }

  void _nextTurn() {
    if (!mounted || _gameOver) return;
    setState(() {
      _turn = (_turn + 1) % 4;
      _rolled = false;
      _status = 'Giliran ${_names[_turn]}';
    });
    if (_turn != 0) {
      _aiTimer = Timer(const Duration(milliseconds: 500), _rollDice);
    }
  }

  List<int> _tokenGridPos(int p, int idx) {
    final s = _tokens[p][idx];
    if (s == -1) return _yardSlots[p][idx];
    if (s <= 50) return _track[(_startOffset[p] + s) % 52];
    if (s <= 55) return _homeStretch[p][s - 51];
    return [7, 7];
  }

  @override
  Widget build(BuildContext context) {
    final movable = (_turn == 0 && _rolled && !_gameOver) ? _movableTokens(0, _dice) : const <int>[];

    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF101830),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('LUDO ORI', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.4, fontSize: 17)),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text('Menang: $_wins', style: const TextStyle(color: Color(0xFFFFD43B), fontWeight: FontWeight.w800, fontSize: 12)),
            ),
          ),
          IconButton(onPressed: _resetGame, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: _colors[_turn].withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _colors[_turn]),
                ),
                child: Text(
                  _status,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final cell = constraints.maxWidth / 15;
                        return Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFFFD43B), width: 2.2),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Stack(
                              children: [
                                CustomPaint(size: Size.square(constraints.maxWidth), painter: _LudoBoardPainter()),
                                for (int p = 0; p < 4; p++)
                                  for (int i = 0; i < 4; i++)
                                    _buildTokenWidget(p, i, cell, movable.contains(i) && p == 0),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: _turn == 0 && !_rolled ? _rollDice : null,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: _turn == 0 && !_rolled
                              ? [const Color(0xFFFFD43B), const Color(0xFFFF6B35)]
                              : [const Color(0xFF1E293B), const Color(0xFF0F172A)],
                        ),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.casino_rounded, color: _turn == 0 && !_rolled ? Colors.black : Colors.white70, size: 28),
                          const SizedBox(width: 10),
                          Text(
                            _rolling ? 'KOCOK...' : 'DADU: $_dice',
                            style: TextStyle(
                              color: _turn == 0 && !_rolled ? Colors.black : Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              if (_gameOver) ...[
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFD43B), foregroundColor: Colors.black),
                  onPressed: _resetGame,
                  icon: const Icon(Icons.replay_rounded),
                  label: Text('MAIN LAGI (${_names[_winner]} Menang)', style: const TextStyle(fontWeight: FontWeight.w900)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTokenWidget(int p, int idx, double cell, bool canTap) {
    final pos = _tokenGridPos(p, idx);
    final jitterX = (idx % 2 == 0 ? -0.08 : 0.08) * cell;
    final jitterY = (idx < 2 ? -0.08 : 0.08) * cell;
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 220),
      left: pos[1] * cell + cell * 0.1 + jitterX,
      top: pos[0] * cell + cell * 0.1 + jitterY,
      width: cell * 0.8,
      height: cell * 0.8,
      child: GestureDetector(
        onTap: canTap ? () => _moveToken(p, idx) : null,
        child: Container(
          decoration: BoxDecoration(
            color: _colors[p],
            shape: BoxShape.circle,
            border: Border.all(color: canTap ? const Color(0xFFFFD43B) : Colors.white, width: canTap ? 2.6 : 1.6),
            boxShadow: [
              BoxShadow(
                color: canTap ? const Color(0xFFFFD43B) : Colors.black.withValues(alpha: 0.4),
                blurRadius: canTap ? 10 : 4,
              ),
            ],
          ),
          child: Center(
            child: Text(
              '${idx + 1}',
              style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900),
            ),
          ),
        ),
      ),
    );
  }
}

class _LudoBoardPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / 15;
    final gridPaint = Paint()
      ..color = const Color(0xFFCBD5E1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    // 4 yards
    void yard(int r, int c, Color color) {
      canvas.drawRect(Rect.fromLTWH(c * cell, r * cell, 6 * cell, 6 * cell), Paint()..color = color);
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH((c + 1) * cell, (r + 1) * cell, 4 * cell, 4 * cell), const Radius.circular(8)),
        Paint()..color = Colors.white,
      );
    }

    yard(0, 0, const Color(0xFFEF4444));
    yard(0, 9, const Color(0xFF22C55E));
    yard(9, 9, const Color(0xFFEAB308));
    yard(9, 0, const Color(0xFF3B82F6));

    // Home stretches
    for (int i = 1; i <= 5; i++) {
      canvas.drawRect(Rect.fromLTWH(i * cell, 7 * cell, cell, cell), Paint()..color = const Color(0xFFFCA5A5));
      canvas.drawRect(Rect.fromLTWH(7 * cell, i * cell, cell, cell), Paint()..color = const Color(0xFF86EFAC));
      canvas.drawRect(Rect.fromLTWH((14 - i) * cell, 7 * cell, cell, cell), Paint()..color = const Color(0xFFFDE047));
      canvas.drawRect(Rect.fromLTWH(7 * cell, (14 - i) * cell, cell, cell), Paint()..color = const Color(0xFF93C5FD));
    }

    // Center home star box
    canvas.drawRect(Rect.fromLTWH(6 * cell, 6 * cell, 3 * cell, 3 * cell), Paint()..color = const Color(0xFF1E293B));
    canvas.drawCircle(Offset(7.5 * cell, 7.5 * cell), cell * 0.9, Paint()..color = const Color(0xFFFFD43B));

    // Grid lines
    for (int i = 0; i <= 15; i++) {
      canvas.drawLine(Offset(i * cell, 0), Offset(i * cell, size.height), gridPaint);
      canvas.drawLine(Offset(0, i * cell), Offset(size.width, i * cell), gridPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
