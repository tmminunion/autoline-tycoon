import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UlarTanggaScreen extends StatefulWidget {
  const UlarTanggaScreen({super.key});

  @override
  State<UlarTanggaScreen> createState() => _UlarTanggaScreenState();
}

class _UlarTanggaScreenState extends State<UlarTanggaScreen> {
  static const String _bestKey = 'nufat_ulartangga_best_v1';

  static const Map<int, int> _ladders = {
    4: 25,
    13: 46,
    33: 49,
    42: 63,
    50: 69,
    62: 81,
    74: 92,
  };

  static const Map<int, int> _snakes = {
    27: 5,
    40: 3,
    43: 18,
    54: 31,
    66: 45,
    76: 58,
    89: 53,
    99: 41,
  };

  final Random _rng = Random();
  int _p1Pos = 1;
  int _p2Pos = 1;
  bool _p1Turn = true;
  bool _vsAi = true;
  int _dice = 1;
  bool _busy = false;
  bool _gameOver = false;
  int _wins = 0;
  String _status = 'Giliranmu! Tap dadu untuk melangkah.';

  @override
  void initState() {
    super.initState();
    _loadBest();
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

  void _reset() {
    setState(() {
      _p1Pos = 1;
      _p2Pos = 1;
      _p1Turn = true;
      _dice = 1;
      _busy = false;
      _gameOver = false;
      _status = 'Giliranmu! Tap dadu untuk melangkah.';
    });
  }

  Future<void> _roll() async {
    if (_busy || _gameOver) return;
    setState(() => _busy = true);
    HapticFeedback.selectionClick();

    for (int i = 0; i < 6; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 55));
      if (!mounted) return;
      setState(() => _dice = _rng.nextInt(6) + 1);
    }
    final roll = _rng.nextInt(6) + 1;
    setState(() => _dice = roll);

    final isP1 = _p1Turn;
    final name = isP1 ? 'Kamu' : (_vsAi ? 'Bot AI' : 'Pemain 2');
    int cur = isP1 ? _p1Pos : _p2Pos;

    if (cur + roll > 100) {
      setState(() => _status = '$name dapat $roll (butuh pas ke 100!)');
    } else {
      for (int s = 0; s < roll; s++) {
        await Future<void>.delayed(const Duration(milliseconds: 140));
        if (!mounted) return;
        cur++;
        setState(() {
          if (isP1) {
            _p1Pos = cur;
          } else {
            _p2Pos = cur;
          }
        });
      }

      if (_ladders.containsKey(cur)) {
        final dest = _ladders[cur]!;
        HapticFeedback.mediumImpact();
        setState(() => _status = '$name naik TANGGA $cur → $dest!');
        await Future<void>.delayed(const Duration(milliseconds: 280));
        if (!mounted) return;
        cur = dest;
        setState(() {
          if (isP1) {
            _p1Pos = cur;
          } else {
            _p2Pos = cur;
          }
        });
      } else if (_snakes.containsKey(cur)) {
        final dest = _snakes[cur]!;
        HapticFeedback.heavyImpact();
        setState(() => _status = '$name kena ULAR $cur → $dest!');
        await Future<void>.delayed(const Duration(milliseconds: 280));
        if (!mounted) return;
        cur = dest;
        setState(() {
          if (isP1) {
            _p1Pos = cur;
          } else {
            _p2Pos = cur;
          }
        });
      } else {
        setState(() => _status = '$name maju ke kotak $cur.');
      }

      if (cur == 100) {
        if (isP1) _saveWins(_wins + 1);
        setState(() {
          _busy = false;
          _gameOver = true;
          _status = '$name MENANG ULAR TANGGA!';
        });
        return;
      }
    }

    final extra = roll == 6;
    setState(() {
      _busy = false;
      if (!extra) _p1Turn = !_p1Turn;
      if (extra) {
        _status = '$name dapat 6! Lempar dadu lagi!';
      }
    });

    if (!_p1Turn && _vsAi && !_gameOver) {
      await Future<void>.delayed(const Duration(milliseconds: 520));
      if (mounted && !_p1Turn && !_gameOver) _roll();
    }
  }

  Offset _squareCenter(int sq, double cell) {
    final idx = sq - 1;
    final rowFromBottom = idx ~/ 10;
    final colInRow = idx % 10;
    final col = rowFromBottom.isEven ? colInRow : 9 - colInRow;
    final row = 9 - rowFromBottom;
    return Offset((col + 0.5) * cell, (row + 0.5) * cell);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1022),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121A36),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('ULAR TANGGA ORI', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2, fontSize: 16)),
        actions: [
          TextButton(
            onPressed: _busy
                ? null
                : () {
                    setState(() => _vsAi = !_vsAi);
                    _reset();
                  },
            child: Text(_vsAi ? 'vs AI' : '2P', style: const TextStyle(color: Color(0xFFFFD43B), fontWeight: FontWeight.w800)),
          ),
          IconButton(onPressed: _reset, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _PlayerChip(
                      label: 'KAMU',
                      pos: _p1Pos,
                      color: const Color(0xFF00F5FF),
                      active: _p1Turn && !_gameOver,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _PlayerChip(
                      label: _vsAi ? 'BOT AI' : 'PEMAIN 2',
                      pos: _p2Pos,
                      color: const Color(0xFFFF2D78),
                      active: !_p1Turn && !_gameOver,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(_status, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: LayoutBuilder(
                      builder: (context, c) {
                        final cell = c.maxWidth / 10;
                        final p1Pt = _squareCenter(_p1Pos, cell);
                        final p2Pt = _squareCenter(_p2Pos, cell);
                        return Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFFFD43B), width: 2),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Stack(
                              children: [
                                CustomPaint(
                                  size: Size.square(c.maxWidth),
                                  painter: _SnakesLaddersPainter(_ladders, _snakes),
                                ),
                                AnimatedPositioned(
                                  duration: const Duration(milliseconds: 140),
                                  left: p1Pt.dx - cell * 0.34,
                                  top: p1Pt.dy - cell * 0.34,
                                  width: cell * 0.68,
                                  height: cell * 0.68,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF00F5FF),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 2),
                                    ),
                                    child: const Center(child: Text('1', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 10))),
                                  ),
                                ),
                                AnimatedPositioned(
                                  duration: const Duration(milliseconds: 140),
                                  left: p2Pt.dx - cell * 0.24,
                                  top: p2Pt.dy - cell * 0.24,
                                  width: cell * 0.62,
                                  height: cell * 0.62,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFF2D78),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 2),
                                    ),
                                    child: const Center(child: Text('2', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 10))),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Menang: $_wins', style: const TextStyle(color: Color(0xFFFFD43B), fontWeight: FontWeight.w800, fontSize: 13)),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFD43B),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: (_busy || (!_p1Turn && _vsAi)) ? null : (_gameOver ? _reset : _roll),
                    icon: Icon(_gameOver ? Icons.replay_rounded : Icons.casino_rounded),
                    label: Text(_gameOver ? 'MAIN LAGI' : 'DADU: $_dice', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlayerChip extends StatelessWidget {
  const _PlayerChip({required this.label, required this.pos, required this.color, required this.active});
  final String label;
  final int pos;
  final Color color;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: active ? color.withValues(alpha: 0.16) : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: active ? color : Colors.white24),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 12)),
          Text('#$pos', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15)),
        ],
      ),
    );
  }
}

class _SnakesLaddersPainter extends CustomPainter {
  _SnakesLaddersPainter(this.ladders, this.snakes);
  final Map<int, int> ladders;
  final Map<int, int> snakes;

  Offset _pt(int sq, double cell) {
    final idx = sq - 1;
    final rBot = idx ~/ 10;
    final cIn = idx % 10;
    final col = rBot.isEven ? cIn : 9 - cIn;
    final row = 9 - rBot;
    return Offset((col + 0.5) * cell, (row + 0.5) * cell);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / 10;
    final palette = [
      const Color(0xFF1E293B),
      const Color(0xFF162033),
      const Color(0xFF1B2B44),
      const Color(0xFF132238),
    ];

    for (int sq = 1; sq <= 100; sq++) {
      final idx = sq - 1;
      final rBot = idx ~/ 10;
      final cIn = idx % 10;
      final col = rBot.isEven ? cIn : 9 - cIn;
      final row = 9 - rBot;
      final rect = Rect.fromLTWH(col * cell, row * cell, cell, cell);
      canvas.drawRect(rect, Paint()..color = palette[(row + col) % palette.length]);
      canvas.drawRect(rect, Paint()..color = Colors.white.withValues(alpha: 0.08)..style = PaintingStyle.stroke..strokeWidth = 0.6);

      final tp = TextPainter(
        text: TextSpan(
          text: '$sq',
          style: TextStyle(color: sq == 100 ? const Color(0xFFFFD43B) : Colors.white54, fontSize: 9, fontWeight: FontWeight.w800),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(rect.left + 3, rect.top + 2));
    }

    // Ladders (gold)
    final ladderPaint = Paint()
      ..color = const Color(0xFFFFD43B).withValues(alpha: 0.85)
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round;
    ladders.forEach((a, b) {
      final p1 = _pt(a, cell);
      final p2 = _pt(b, cell);
      canvas.drawLine(p1, p2, ladderPaint);
    });

    // Snakes (emerald/crimson)
    final snakePaint = Paint()
      ..color = const Color(0xFF22C55E).withValues(alpha: 0.85)
      ..strokeWidth = 3.6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    snakes.forEach((a, b) {
      final p1 = _pt(a, cell);
      final p2 = _pt(b, cell);
      final mid = Offset((p1.dx + p2.dx) / 2 + 12, (p1.dy + p2.dy) / 2);
      final path = Path()..moveTo(p1.dx, p1.dy)..quadraticBezierTo(mid.dx, mid.dy, p2.dx, p2.dy);
      canvas.drawPath(path, snakePaint);
    });
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
