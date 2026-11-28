import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Orb {
  _Orb({required this.x, required this.y, required this.tier, this.vx = 0, this.vy = 0});
  double x;
  double y;
  double vx;
  double vy;
  int tier;
  double age = 0;
}

class FruitMergeScreen extends StatefulWidget {
  const FruitMergeScreen({super.key});

  @override
  State<FruitMergeScreen> createState() => _FruitMergeScreenState();
}

class _FruitMergeScreenState extends State<FruitMergeScreen> with SingleTickerProviderStateMixin {
  static const String _bestKey = 'nufat_fruitmerge_best_v1';
  static const List<double> _radii = [14, 18, 23, 28, 34, 40, 47, 54, 62];
  static const List<Color> _colors = [
    Color(0xFFEF4444), // Cherry
    Color(0xFFF97316), // Berry
    Color(0xFFA855F7), // Grape
    Color(0xFFFACC15), // Lemon
    Color(0xFFFB923C), // Orange
    Color(0xFFEC4899), // Peach
    Color(0xFF22C55E), // Melon
    Color(0xFF06B6D4), // Starfruit
    Color(0xFF16A34A), // Watermelon
  ];
  static const List<String> _labels = ['1', '2', '3', '4', '5', '6', '7', '8', '9'];

  late final Ticker _ticker;
  final Random _rng = Random();
  final List<_Orb> _orbs = [];
  double _w = 320;
  double _h = 460;
  double _aimX = 160;
  int _nextTier = 0;
  int _score = 0;
  int _best = 0;
  bool _gameOver = false;
  double _dropCooldown = 0;
  Duration _lastTick = Duration.zero;

  @override
  void initState() {
    super.initState();
    _loadBest();
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

  void _reset() {
    setState(() {
      _orbs.clear();
      _score = 0;
      _nextTier = _rng.nextInt(3);
      _gameOver = false;
      _dropCooldown = 0;
    });
  }

  void _drop() {
    if (_gameOver || _dropCooldown > 0) return;
    final r = _radii[_nextTier];
    final clampedX = _aimX.clamp(r + 4, _w - r - 4);
    _orbs.add(_Orb(x: clampedX, y: 34, tier: _nextTier));
    _nextTier = _rng.nextInt(4);
    _dropCooldown = 0.32;
    HapticFeedback.selectionClick();
  }

  void _onTick(Duration elapsed) {
    final dt = _lastTick == Duration.zero
        ? 0.016
        : ((elapsed - _lastTick).inMicroseconds / 1e6).clamp(0.004, 0.032);
    _lastTick = elapsed;
    if (_gameOver) return;

    if (_dropCooldown > 0) _dropCooldown -= dt;

    const gravity = 820.0;
    for (final o in _orbs) {
      o.age += dt;
      o.vy += gravity * dt;
      o.x += o.vx * dt;
      o.y += o.vy * dt;
      o.vx *= 0.992;

      final r = _radii[o.tier];
      if (o.x < r) {
        o.x = r;
        o.vx = o.vx.abs() * 0.4;
      } else if (o.x > _w - r) {
        o.x = _w - r;
        o.vx = -o.vx.abs() * 0.4;
      }
      if (o.y > _h - r) {
        o.y = _h - r;
        o.vy = -o.vy.abs() * 0.22;
        o.vx *= 0.94;
      }
    }

    // Collisions & merges
    final toRemove = <int>{};
    final toAdd = <_Orb>[];
    for (int i = 0; i < _orbs.length; i++) {
      if (toRemove.contains(i)) continue;
      for (int j = i + 1; j < _orbs.length; j++) {
        if (toRemove.contains(j)) continue;
        final a = _orbs[i];
        final b = _orbs[j];
        final ra = _radii[a.tier];
        final rb = _radii[b.tier];
        final dx = b.x - a.x;
        final dy = b.y - a.y;
        final dist = sqrt(dx * dx + dy * dy);
        final minDist = ra + rb;

        if (dist < minDist && dist > 0.001) {
          if (a.tier == b.tier && a.tier < _radii.length - 1) {
            toRemove.add(i);
            toRemove.add(j);
            final nt = a.tier + 1;
            toAdd.add(_Orb(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2, tier: nt, vy: -80));
            _score += (nt + 1) * 20;
            if (_score > _best) _saveBest(_score);
            HapticFeedback.mediumImpact();
            break;
          } else {
            final nx = dx / dist;
            final ny = dy / dist;
            final overlap = (minDist - dist) * 0.5;
            a.x -= nx * overlap;
            a.y -= ny * overlap;
            b.x += nx * overlap;
            b.y += ny * overlap;

            final rvx = b.vx - a.vx;
            final rvy = b.vy - a.vy;
            final vn = rvx * nx + rvy * ny;
            if (vn < 0) {
              const e = 0.25;
              final imp = -(1 + e) * vn * 0.5;
              a.vx -= imp * nx;
              a.vy -= imp * ny;
              b.vx += imp * nx;
              b.vy += imp * ny;
            }
          }
        }
      }
    }

    if (toRemove.isNotEmpty) {
      final sorted = toRemove.toList()..sort((a, b) => b.compareTo(a));
      for (final idx in sorted) {
        _orbs.removeAt(idx);
      }
      _orbs.addAll(toAdd);
    }

    // Overflow check (danger line at y = 70)
    for (final o in _orbs) {
      if (o.age > 1.2 && o.y - _radii[o.tier] < 64) {
        _gameOver = true;
        HapticFeedback.heavyImpact();
        _saveBest(_score);
        break;
      }
    }

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070814),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0E1226),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('FRUIT MERGE NEON', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2, fontSize: 16)),
        actions: [
          IconButton(onPressed: _reset, icon: const Icon(Icons.refresh_rounded)),
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
                  Text('SKOR: $_score', style: const TextStyle(color: Color(0xFF00F5FF), fontSize: 17, fontWeight: FontWeight.w900)),
                  Text('TERBAIK: $_best', style: const TextStyle(color: Color(0xFFFFD43B), fontSize: 14, fontWeight: FontWeight.w800)),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, c) {
                    _w = c.maxWidth;
                    _h = c.maxHeight;
                    _aimX = _aimX.clamp(20, _w - 20);
                    return GestureDetector(
                      onPanUpdate: (d) => setState(() => _aimX = d.localPosition.dx.clamp(20, _w - 20)),
                      onPanEnd: (_) => _drop(),
                      onTapDown: (d) {
                        setState(() => _aimX = d.localPosition.dx.clamp(20, _w - 20));
                        _drop();
                      },
                      child: Container(
                        width: double.infinity,
                        height: double.infinity,
                        decoration: BoxDecoration(
                          color: const Color(0xFF0C1024),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFF232C55), width: 2),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Stack(
                            children: [
                              CustomPaint(
                                size: Size(_w, _h),
                                painter: _FruitPainter(
                                  orbs: _orbs,
                                  radii: _radii,
                                  colors: _colors,
                                  labels: _labels,
                                  aimX: _aimX,
                                  nextTier: _nextTier,
                                ),
                              ),
                              if (_gameOver)
                                Container(
                                  color: Colors.black.withValues(alpha: 0.78),
                                  child: Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Text('KOTAK PENUH!', style: TextStyle(color: Color(0xFFFF2D78), fontSize: 24, fontWeight: FontWeight.w900)),
                                        const SizedBox(height: 8),
                                        Text('Skor: $_score', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                                        const SizedBox(height: 14),
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00F5FF), foregroundColor: Colors.black),
                                          onPressed: _reset,
                                          child: const Text('MAIN LAGI', style: TextStyle(fontWeight: FontWeight.w900)),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              const Text('Geser & lepas untuk menjatuhkan bola — gabungkan angka yang sama!', style: TextStyle(color: Colors.white54, fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }
}

class _FruitPainter extends CustomPainter {
  _FruitPainter({
    required this.orbs,
    required this.radii,
    required this.colors,
    required this.labels,
    required this.aimX,
    required this.nextTier,
  });

  final List<_Orb> orbs;
  final List<double> radii;
  final List<Color> colors;
  final List<String> labels;
  final double aimX;
  final int nextTier;

  @override
  void paint(Canvas canvas, Size size) {
    // Danger line
    canvas.drawLine(
      const Offset(0, 64),
      Offset(size.width, 64),
      Paint()..color = const Color(0xFFFF2D78).withValues(alpha: 0.4)..strokeWidth = 1.4,
    );

    // Aim guide
    canvas.drawLine(
      Offset(aimX, 34),
      Offset(aimX, size.height),
      Paint()..color = Colors.white.withValues(alpha: 0.14)..strokeWidth = 1.2,
    );
    _drawOrb(canvas, aimX, 34, radii[nextTier], colors[nextTier], labels[nextTier]);

    for (final o in orbs) {
      _drawOrb(canvas, o.x, o.y, radii[o.tier], colors[o.tier], labels[o.tier]);
    }
  }

  void _drawOrb(Canvas canvas, double x, double y, double r, Color c, String lbl) {
    final rect = Rect.fromCircle(center: Offset(x, y), radius: r);
    canvas.drawCircle(
      Offset(x, y),
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.35, -0.35),
          colors: [Colors.white.withValues(alpha: 0.7), c, Color.lerp(c, Colors.black, 0.35)!],
        ).createShader(rect),
    );
    canvas.drawCircle(Offset(x, y), r, Paint()..color = Colors.white.withValues(alpha: 0.4)..style = PaintingStyle.stroke..strokeWidth = 1.5);
    final tp = TextPainter(
      text: TextSpan(text: lbl, style: TextStyle(color: Colors.white, fontSize: r * 0.72, fontWeight: FontWeight.w900)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(x - tp.width / 2, y - tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _FruitPainter oldDelegate) => true;
}
