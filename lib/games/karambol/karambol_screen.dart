import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Coin {
  _Coin({required this.x, required this.y, required this.r, required this.kind});
  double x;
  double y;
  double vx = 0;
  double vy = 0;
  final double r;
  final String kind; // 'striker' | 'queen' | 'white' | 'black'
  bool pocketed = false;
}

class KarambolScreen extends StatefulWidget {
  const KarambolScreen({super.key});

  @override
  State<KarambolScreen> createState() => _KarambolScreenState();
}

class _KarambolScreenState extends State<KarambolScreen> with SingleTickerProviderStateMixin {
  static const String _bestKey = 'nufat_karambol_best_v1';
  late final Ticker _ticker;
  final List<_Coin> _coins = [];
  double _boardPx = 320;
  double _strikerX = 0.5; // normalized 0.2..0.8
  Offset? _dragStart;
  Offset? _dragCurrent;
  bool _moving = false;
  int _score = 0;
  int _shots = 0;
  int _best = 0;
  bool _cleared = false;
  Duration _lastTick = Duration.zero;

  @override
  void initState() {
    super.initState();
    _loadBest();
    _setupBoard();
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  Future<void> _loadBest() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() => _best = prefs.getInt(_bestKey) ?? 0);
    } catch (_) {}
  }

  Future<void> _saveBest(int v) async {
    if (v <= _best) return;
    _best = v;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_bestKey, v);
    } catch (_) {}
  }

  void _setupBoard() {
    _coins.clear();
    const cx = 0.5;
    const cy = 0.5;
    const cr = 0.036;
    _coins.add(_Coin(x: cx, y: cy, r: cr, kind: 'queen'));
    for (int i = 0; i < 6; i++) {
      final ang = i * pi / 3;
      _coins.add(_Coin(
        x: cx + cos(ang) * (cr * 2.2),
        y: cy + sin(ang) * (cr * 2.2),
        r: cr,
        kind: i.isEven ? 'white' : 'black',
      ));
    }
    _coins.add(_Coin(x: 0.5, y: 0.82, r: 0.046, kind: 'striker'));

    setState(() {
      _strikerX = 0.5;
      _moving = false;
      _score = 0;
      _shots = 0;
      _cleared = false;
      _dragStart = null;
      _dragCurrent = null;
    });
  }

  _Coin get _striker => _coins.firstWhere((c) => c.kind == 'striker');

  void _onTick(Duration elapsed) {
    final dt = _lastTick == Duration.zero
        ? 0.016
        : ((elapsed - _lastTick).inMicroseconds / 1e6).clamp(0.004, 0.032);
    _lastTick = elapsed;
    if (!_moving) return;

    const pockets = [
      Offset(0.06, 0.06),
      Offset(0.94, 0.06),
      Offset(0.06, 0.94),
      Offset(0.94, 0.94),
    ];

    bool anyMoving = false;
    for (final c in _coins) {
      if (c.pocketed) continue;
      c.x += c.vx * dt;
      c.y += c.vy * dt;
      final friction = pow(0.24, dt).toDouble();
      c.vx *= friction;
      c.vy *= friction;
      if (c.vx.abs() < 0.01 && c.vy.abs() < 0.01) {
        c.vx = 0;
        c.vy = 0;
      } else {
        anyMoving = true;
      }

      // Wall bounce
      if (c.x < c.r + 0.03) {
        c.x = c.r + 0.03;
        c.vx = c.vx.abs() * 0.82;
      } else if (c.x > 0.97 - c.r) {
        c.x = 0.97 - c.r;
        c.vx = -c.vx.abs() * 0.82;
      }
      if (c.y < c.r + 0.03) {
        c.y = c.r + 0.03;
        c.vy = c.vy.abs() * 0.82;
      } else if (c.y > 0.97 - c.r) {
        c.y = 0.97 - c.r;
        c.vy = -c.vy.abs() * 0.82;
      }

      // Pocket check
      for (final p in pockets) {
        if (hypot(c.x - p.dx, c.y - p.dy) < 0.056) {
          if (c.kind == 'striker') {
            c.vx = 0;
            c.vy = 0;
            c.x = _strikerX;
            c.y = 0.82;
            _score = max(0, _score - 10);
          } else {
            c.pocketed = true;
            c.vx = 0;
            c.vy = 0;
            HapticFeedback.heavyImpact();
            _score += c.kind == 'queen' ? 50 : 20;
            if (_score > _best) _saveBest(_score);
          }
          break;
        }
      }
    }

    // Coin-to-coin elastic collisions
    for (int i = 0; i < _coins.length; i++) {
      final a = _coins[i];
      if (a.pocketed) continue;
      for (int j = i + 1; j < _coins.length; j++) {
        final b = _coins[j];
        if (b.pocketed) continue;
        final dx = b.x - a.x;
        final dy = b.y - a.y;
        final d = sqrt(dx * dx + dy * dy);
        final minD = a.r + b.r;
        if (d < minD && d > 0.0001) {
          final nx = dx / d;
          final ny = dy / d;
          final ov = (minD - d) * 0.5;
          a.x -= nx * ov;
          a.y -= ny * ov;
          b.x += nx * ov;
          b.y += ny * ov;

          final vn = (b.vx - a.vx) * nx + (b.vy - a.vy) * ny;
          if (vn < 0) {
            const restitution = 0.88;
            final imp = -(1 + restitution) * vn * 0.5;
            a.vx -= imp * nx;
            a.vy -= imp * ny;
            b.vx += imp * nx;
            b.vy += imp * ny;
            anyMoving = true;
          }
        }
      }
    }

    if (!anyMoving) {
      _moving = false;
      final s = _striker;
      s.x = _strikerX;
      s.y = 0.82;
      final left = _coins.where((c) => c.kind != 'striker' && !c.pocketed).length;
      if (left == 0) {
        _cleared = true;
        _score += max(0, 150 - _shots * 10);
        _saveBest(_score);
      }
    }

    setState(() {});
  }

  double hypot(double a, double b) => sqrt(a * a + b * b);

  void _shoot() {
    if (_dragStart == null || _dragCurrent == null || _moving) return;
    final dx = _dragStart!.dx - _dragCurrent!.dx;
    final dy = _dragStart!.dy - _dragCurrent!.dy;
    final power = hypot(dx, dy).clamp(0.0, 140.0);
    if (power > 14) {
      final s = _striker;
      s.vx = (dx / _boardPx) * 7.2;
      s.vy = (dy / _boardPx) * 7.2;
      _moving = true;
      _shots++;
      HapticFeedback.mediumImpact();
    }
    setState(() {
      _dragStart = null;
      _dragCurrent = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF140C08),
      appBar: AppBar(
        backgroundColor: const Color(0xFF22140D),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('KARAMBOL ORI', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.3, fontSize: 16)),
        actions: [
          IconButton(onPressed: _setupBoard, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('SKOR: $_score  •  Sentil: $_shots', style: const TextStyle(color: Color(0xFFFFD43B), fontSize: 14, fontWeight: FontWeight.w900)),
                  Text('Terbaik: $_best', style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: LayoutBuilder(
                      builder: (context, c) {
                        _boardPx = c.maxWidth;
                        return GestureDetector(
                          onPanStart: _moving
                              ? null
                              : (d) => setState(() {
                                    _dragStart = Offset(_striker.x * _boardPx, _striker.y * _boardPx);
                                    _dragCurrent = d.localPosition;
                                  }),
                          onPanUpdate: _moving ? null : (d) => setState(() => _dragCurrent = d.localPosition),
                          onPanEnd: (_) => _shoot(),
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3DEC0),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: const Color(0xFF5C3317), width: 10),
                              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.55), blurRadius: 18)],
                            ),
                            child: Stack(
                              children: [
                                CustomPaint(
                                  size: Size.square(_boardPx),
                                  painter: _CarromPainter(
                                    coins: _coins,
                                    dragStart: _dragStart,
                                    dragCurrent: _dragCurrent,
                                  ),
                                ),
                                if (_cleared)
                                  Container(
                                    color: Colors.black.withValues(alpha: 0.75),
                                    child: Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Text('MEJA BERSIH!', style: TextStyle(color: Color(0xFFFFD43B), fontSize: 24, fontWeight: FontWeight.w900)),
                                          const SizedBox(height: 8),
                                          Text('Skor Akhir: $_score', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                                          const SizedBox(height: 14),
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFD43B), foregroundColor: Colors.black),
                                            onPressed: _setupBoard,
                                            child: const Text('MAIN LAGI', style: TextStyle(fontWeight: FontWeight.w900)),
                                          ),
                                        ],
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
                ),
              ),
              const SizedBox(height: 10),
              const Text('Geser slider untuk posisi striker, lalu tarik & lepas di papan untuk menyentil!', style: TextStyle(color: Colors.white60, fontSize: 11)),
              Slider(
                value: _strikerX,
                min: 0.2,
                max: 0.8,
                activeColor: const Color(0xFFFFD43B),
                onChanged: _moving
                    ? null
                    : (v) {
                        setState(() {
                          _strikerX = v;
                          _striker.x = v;
                        });
                      },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CarromPainter extends CustomPainter {
  _CarromPainter({required this.coins, required this.dragStart, required this.dragCurrent});
  final List<_Coin> coins;
  final Offset? dragStart;
  final Offset? dragCurrent;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    // Center ring & baseline
    canvas.drawCircle(Offset(s * 0.5, s * 0.5), s * 0.16, Paint()..color = const Color(0xFFB91C1C).withValues(alpha: 0.25)..style = PaintingStyle.stroke..strokeWidth = 2);
    canvas.drawLine(Offset(s * 0.2, s * 0.82), Offset(s * 0.8, s * 0.82), Paint()..color = const Color(0xFF78350F).withValues(alpha: 0.4)..strokeWidth = 2);

    // 4 pockets
    const pockets = [Offset(0.06, 0.06), Offset(0.94, 0.06), Offset(0.06, 0.94), Offset(0.94, 0.94)];
    for (final p in pockets) {
      canvas.drawCircle(Offset(p.dx * s, p.dy * s), s * 0.052, Paint()..color = const Color(0xFF1A0F0A));
    }

    // Aim vector
    if (dragStart != null && dragCurrent != null) {
      final aimEnd = Offset(dragStart!.dx + (dragStart!.dx - dragCurrent!.dx), dragStart!.dy + (dragStart!.dy - dragCurrent!.dy));
      canvas.drawLine(dragStart!, aimEnd, Paint()..color = const Color(0xFFEF4444)..strokeWidth = 2.6..strokeCap = StrokeCap.round);
    }

    for (final c in coins) {
      if (c.pocketed) continue;
      final center = Offset(c.x * s, c.y * s);
      final r = c.r * s;
      Color fill;
      if (c.kind == 'striker') {
        fill = const Color(0xFFFFD43B);
      } else if (c.kind == 'queen') {
        fill = const Color(0xFFDC2626);
      } else if (c.kind == 'white') {
        fill = const Color(0xFFFFFBEB);
      } else {
        fill = const Color(0xFF1E293B);
      }
      canvas.drawCircle(center, r, Paint()..color = fill);
      canvas.drawCircle(center, r, Paint()..color = Colors.black.withValues(alpha: 0.45)..style = PaintingStyle.stroke..strokeWidth = 1.6);
      canvas.drawCircle(center, r * 0.55, Paint()..color = Colors.white.withValues(alpha: 0.35)..style = PaintingStyle.stroke..strokeWidth = 1.2);
    }
  }

  @override
  bool shouldRepaint(covariant _CarromPainter oldDelegate) => true;
}
