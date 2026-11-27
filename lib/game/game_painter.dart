import 'dart:math';

import 'package:flutter/material.dart';

import 'entities.dart';
import 'game_engine.dart';

class ArcadeGamePainter extends CustomPainter {
  final ArcadeGameEngine engine;

  ArcadeGamePainter(this.engine) : super(repaint: engine);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();

    if (engine.shakeTimer > 0) {
      final mag = engine.shakeIntensity * (engine.shakeTimer / 0.45).clamp(0.0, 1.0);
      final dx = sin(engine.elapsedTime * 95) * mag;
      final dy = cos(engine.elapsedTime * 115) * mag;
      canvas.translate(dx, dy);
    }

    _drawBackground(canvas, size);
    _drawShockwaves(canvas);
    _drawCoinOrbs(canvas);
    _drawPowerUps(canvas);
    _drawBullets(canvas);
    _drawEnemies(canvas);
    _drawParticles(canvas);

    if (engine.phase != GamePhase.gameOver) {
      _drawPlayer(canvas);
    }

    _drawFloatingTexts(canvas);
    _drawWaveBanner(canvas, size);

    canvas.restore();
  }

  void _drawBackground(Canvas canvas, Size size) {
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF050714),
          Color(0xFF0B112B),
          Color(0xFF140D2E),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    final gridPaint = Paint()
      ..color = const Color(0xFF00E5FF).withAlpha(22)
      ..strokeWidth = 1.0;

    const double spacing = 48.0;
    for (double x = 0; x <= size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = engine.gridOffset - spacing; y <= size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final starPaint = Paint();
    for (final s in engine.stars) {
      final alpha = (s.brightness * 235).toInt().clamp(30, 255);
      starPaint.color = Color.fromARGB(alpha, 190, 240, 255);
      if (engine.isOverdrive) {
        starPaint.strokeWidth = s.size * 0.8;
        canvas.drawLine(
          Offset(s.x, s.y),
          Offset(s.x, s.y - s.speed * 0.08),
          starPaint,
        );
      } else {
        canvas.drawCircle(Offset(s.x, s.y), s.size, starPaint);
      }
    }
  }

  void _drawPlayer(Canvas canvas) {
    if (engine.phase == GamePhase.playing &&
        engine.invulnTimer > 0 &&
        ((engine.elapsedTime * 16).floor() % 2 == 0)) {
      return;
    }

    final spec = engine.displayedShipSpec;
    final bool isHangar = engine.phase == GamePhase.hangar;
    final double scale = isHangar ? 1.65 : 1.0;

    canvas.save();
    canvas.translate(engine.playerX, engine.playerY);
    canvas.rotate(engine.playerTilt);
    canvas.scale(scale, scale);

    final accent = engine.isOverdrive
        ? const Color(0xFFFFD740)
        : spec.primaryColor;
    final trim = spec.secondaryColor;

    // Hangar holographic platform ring
    if (isHangar) {
      final ringPulse = 0.75 + sin(engine.elapsedTime * 4) * 0.25;
      canvas.drawCircle(
        Offset.zero,
        36,
        Paint()
          ..color = accent.withAlpha((85 * ringPulse).toInt())
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6,
      );
      canvas.drawCircle(
        Offset.zero,
        44,
        Paint()
          ..color = trim.withAlpha((45 * ringPulse).toInt())
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0,
      );
    }

    // Glow aura under ship
    canvas.drawCircle(
      Offset.zero,
      24,
      Paint()
        ..color = accent.withAlpha(80)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );

    final flicker = 0.85 + sin(engine.elapsedTime * 42) * 0.25;

    if (spec.type == ShipType.viper) {
      _drawThruster(canvas, 0, 15, 7, 13 + 10 * flicker, trim);
      final shipPath = Path()
        ..moveTo(0, -25)
        ..lineTo(8, -6)
        ..lineTo(25, 12)
        ..lineTo(20, 18)
        ..lineTo(8, 12)
        ..lineTo(5, 17)
        ..lineTo(-5, 17)
        ..lineTo(-8, 12)
        ..lineTo(-20, 18)
        ..lineTo(-25, 12)
        ..lineTo(-8, -6)
        ..close();

      canvas.drawPath(shipPath, Paint()..color = const Color(0xFF14244B));
      canvas.drawPath(
        shipPath,
        Paint()
          ..color = accent
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2,
      );

      final cockpit = Path()
        ..moveTo(0, -13)
        ..lineTo(4.2, 0)
        ..lineTo(0, 7)
        ..lineTo(-4.2, 0)
        ..close();
      canvas.drawPath(cockpit, Paint()..color = accent);

      final trimPaint = Paint()
        ..color = trim
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(const Offset(11, 2), const Offset(21, 13), trimPaint);
      canvas.drawLine(const Offset(-11, 2), const Offset(-21, 13), trimPaint);
    } else if (spec.type == ShipType.phantom) {
      // Sleek forward-swept stealth delta
      _drawThruster(canvas, 0, 14, 6, 16 + 11 * flicker, trim);
      final shipPath = Path()
        ..moveTo(0, -28)
        ..lineTo(7, -8)
        ..lineTo(22, -12)
        ..lineTo(26, 8)
        ..lineTo(10, 14)
        ..lineTo(4, 18)
        ..lineTo(-4, 18)
        ..lineTo(-10, 14)
        ..lineTo(-26, 8)
        ..lineTo(-22, -12)
        ..lineTo(-7, -8)
        ..close();

      canvas.drawPath(shipPath, Paint()..color = const Color(0xFF280D2B));
      canvas.drawPath(
        shipPath,
        Paint()
          ..color = accent
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2,
      );

      final canopy = Path()
        ..moveTo(0, -18)
        ..lineTo(3.5, -2)
        ..lineTo(0, 6)
        ..lineTo(-3.5, -2)
        ..close();
      canvas.drawPath(canopy, Paint()..color = Colors.white);

      final wingSlash = Paint()
        ..color = trim
        ..strokeWidth = 2.0;
      canvas.drawLine(const Offset(10, -5), const Offset(21, 4), wingSlash);
      canvas.drawLine(const Offset(-10, -5), const Offset(-21, 4), wingSlash);
    } else {
      // Titan-MK4: Heavy twin-nose armored gunship with dual thrusters
      _drawThruster(canvas, -9, 16, 5.5, 13 + 8 * flicker, trim);
      _drawThruster(canvas, 9, 16, 5.5, 13 + 8 * flicker, trim);

      final shipPath = Path()
        ..moveTo(-8, -24)
        ..lineTo(-3, -14)
        ..lineTo(3, -14)
        ..lineTo(8, -24)
        ..lineTo(13, -8)
        ..lineTo(27, 4)
        ..lineTo(25, 17)
        ..lineTo(14, 15)
        ..lineTo(12, 19)
        ..lineTo(-12, 19)
        ..lineTo(-14, 15)
        ..lineTo(-25, 17)
        ..lineTo(-27, 4)
        ..lineTo(-13, -8)
        ..close();

      canvas.drawPath(shipPath, Paint()..color = const Color(0xFF2B210B));
      canvas.drawPath(
        shipPath,
        Paint()
          ..color = accent
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );

      // Armored bridge core
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(-6, -9, 12, 16),
          const Radius.circular(4),
        ),
        Paint()..color = trim.withAlpha(210),
      );
      canvas.drawCircle(const Offset(0, -1), 3.2, Paint()..color = Colors.white);
    }

    // Energy shield dome (only in gameplay)
    if (engine.phase == GamePhase.playing && engine.hasShield) {
      final pulse = 0.75 + sin(engine.elapsedTime * 6) * 0.25;
      canvas.drawCircle(
        Offset.zero,
        30,
        Paint()
          ..color = const Color(0xFF00E676).withAlpha((45 * pulse).toInt()),
      );
      canvas.drawCircle(
        Offset.zero,
        30,
        Paint()
          ..color = const Color(0xFF00E676).withAlpha((210 * pulse).toInt())
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2,
      );
    }

    canvas.restore();
  }

  void _drawThruster(
    Canvas canvas,
    double cx,
    double topY,
    double halfW,
    double len,
    Color outerColor,
  ) {
    final flamePath = Path()
      ..moveTo(cx - halfW, topY)
      ..lineTo(cx, topY + len)
      ..lineTo(cx + halfW, topY)
      ..close();
    canvas.drawPath(flamePath, Paint()..color = outerColor.withAlpha(220));

    final coreFlame = Path()
      ..moveTo(cx - halfW * 0.5, topY)
      ..lineTo(cx, topY + len * 0.65)
      ..lineTo(cx + halfW * 0.5, topY)
      ..close();
    canvas.drawPath(coreFlame, Paint()..color = const Color(0xFFFFD740));
  }

  void _drawCoinOrbs(Canvas canvas) {
    for (final c in engine.coinOrbs) {
      final spin = 0.55 + (sin(c.age * 10).abs()) * 0.45;
      canvas.drawCircle(
        Offset(c.x, c.y),
        10,
        Paint()
          ..color = const Color(0xFFFFD740).withAlpha(75)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
      canvas.save();
      canvas.translate(c.x, c.y);
      canvas.scale(spin, 1.0);
      canvas.drawCircle(Offset.zero, 6.5, Paint()..color = const Color(0xFFFFB300));
      canvas.drawCircle(
        Offset.zero,
        6.5,
        Paint()
          ..color = const Color(0xFFFFF59D)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6,
      );
      canvas.drawCircle(Offset.zero, 2.2, Paint()..color = Colors.white);
      canvas.restore();
    }
  }

  void _drawEnemies(Canvas canvas) {
    for (final e in engine.enemies) {
      canvas.save();
      canvas.translate(e.x, e.y);

      final color = e.hitFlash > 0 ? Colors.white : e.color;

      canvas.drawCircle(
        Offset.zero,
        e.radius * 0.95,
        Paint()
          ..color = e.color.withAlpha(65)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
      );

      if (e.type == EnemyType.scout) {
        final p = Path()
          ..moveTo(0, e.radius)
          ..lineTo(e.radius * 0.9, -e.radius * 0.75)
          ..lineTo(0, -e.radius * 0.35)
          ..lineTo(-e.radius * 0.9, -e.radius * 0.75)
          ..close();
        canvas.drawPath(p, Paint()..color = const Color(0xFF2A0F24));
        canvas.drawPath(
          p,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.2,
        );
        canvas.drawCircle(const Offset(0, -1), 3.5, Paint()..color = color);
      } else if (e.type == EnemyType.striker) {
        final p = Path()
          ..moveTo(0, e.radius)
          ..lineTo(e.radius, -2)
          ..lineTo(e.radius * 0.45, -e.radius * 0.9)
          ..lineTo(0, -e.radius * 0.45)
          ..lineTo(-e.radius * 0.45, -e.radius * 0.9)
          ..lineTo(-e.radius, -2)
          ..close();
        canvas.drawPath(p, Paint()..color = const Color(0xFF331B0A));
        canvas.drawPath(
          p,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.3,
        );
        canvas.drawCircle(Offset.zero, 5.5, Paint()..color = color);
      } else if (e.type == EnemyType.cruiser) {
        final p = Path();
        for (int i = 0; i < 6; i++) {
          final a = (pi / 3) * i + pi / 6;
          final px = cos(a) * e.radius;
          final py = sin(a) * e.radius;
          if (i == 0) {
            p.moveTo(px, py);
          } else {
            p.lineTo(px, py);
          }
        }
        p.close();
        canvas.drawPath(p, Paint()..color = const Color(0xFF240B3B));
        canvas.drawPath(
          p,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.6,
        );
        canvas.drawCircle(
          Offset.zero,
          9,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0,
        );
        canvas.drawCircle(Offset.zero, 4, Paint()..color = Colors.white);
      } else if (e.type == EnemyType.boss) {
        final p = Path()
          ..moveTo(0, e.radius * 0.85)
          ..lineTo(e.radius * 0.55, e.radius * 0.45)
          ..lineTo(e.radius * 1.05, -e.radius * 0.15)
          ..lineTo(e.radius * 0.78, -e.radius * 0.75)
          ..lineTo(e.radius * 0.28, -e.radius * 0.55)
          ..lineTo(0, -e.radius * 0.85)
          ..lineTo(-e.radius * 0.28, -e.radius * 0.55)
          ..lineTo(-e.radius * 0.78, -e.radius * 0.75)
          ..lineTo(-e.radius * 1.05, -e.radius * 0.15)
          ..lineTo(-e.radius * 0.55, e.radius * 0.45)
          ..close();

        canvas.drawPath(p, Paint()..color = const Color(0xFF330A18));
        canvas.drawPath(
          p,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3.2,
        );

        final pulse = 10.0 + sin(engine.elapsedTime * 9) * 3.0;
        canvas.drawCircle(Offset.zero, pulse, Paint()..color = color);
        canvas.drawCircle(Offset.zero, 5, Paint()..color = Colors.white);

        for (final tx in [-28.0, 28.0]) {
          canvas.drawCircle(
            Offset(tx, 14),
            6,
            Paint()..color = const Color(0xFFFFB300),
          );
        }
      }

      if (e.type != EnemyType.boss && e.hp < e.maxHp) {
        final w = e.radius * 1.6;
        final ratio = (e.hp / e.maxHp).clamp(0.0, 1.0);
        canvas.drawRect(
          Rect.fromLTWH(-w / 2, -e.radius - 10, w, 4),
          Paint()..color = const Color(0xFF1E293B),
        );
        canvas.drawRect(
          Rect.fromLTWH(-w / 2, -e.radius - 10, w * ratio, 4),
          Paint()..color = e.color,
        );
      }

      canvas.restore();
    }
  }

  void _drawBullets(Canvas canvas) {
    for (final b in engine.bullets) {
      if (b.isPlayer) {
        final glow = Paint()
          ..color = b.color.withAlpha(120)
          ..strokeWidth = 7.0
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
        canvas.drawLine(Offset(b.x, b.y - 8), Offset(b.x, b.y + 8), glow);

        final core = Paint()
          ..color = Colors.white
          ..strokeWidth = 2.6
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(Offset(b.x, b.y - 7), Offset(b.x, b.y + 7), core);
      } else {
        canvas.drawCircle(
          Offset(b.x, b.y),
          b.radius * 1.7,
          Paint()
            ..color = b.color.withAlpha(110)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
        );
        canvas.drawCircle(Offset(b.x, b.y), b.radius, Paint()..color = b.color);
        canvas.drawCircle(
          Offset(b.x, b.y),
          b.radius * 0.45,
          Paint()..color = Colors.white,
        );
      }
    }
  }

  void _drawPowerUps(Canvas canvas) {
    for (final p in engine.powerUps) {
      final pulse = 1.0 + sin(p.age * 7) * 0.12;
      final r = p.radius * pulse;

      canvas.drawCircle(
        Offset(p.x, p.y),
        r * 1.4,
        Paint()
          ..color = p.color.withAlpha(75)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
      canvas.drawCircle(
        Offset(p.x, p.y),
        r,
        Paint()..color = const Color(0xFF0D1426),
      );
      canvas.drawCircle(
        Offset(p.x, p.y),
        r,
        Paint()
          ..color = p.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );

      final tp = TextPainter(
        text: TextSpan(
          text: p.shortLabel,
          style: TextStyle(
            color: p.color,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(p.x - tp.width / 2, p.y - tp.height / 2));
    }
  }

  void _drawParticles(Canvas canvas) {
    final paint = Paint();
    for (final p in engine.particles) {
      final alpha = ((p.life / p.maxLife).clamp(0.0, 1.0) * 255).toInt();
      paint.color = p.color.withAlpha(alpha);
      canvas.drawCircle(Offset(p.x, p.y), p.size * (p.life / p.maxLife), paint);
    }
  }

  void _drawShockwaves(Canvas canvas) {
    for (final s in engine.shockwaves) {
      final t = (s.life / s.maxLife).clamp(0.0, 1.0);
      canvas.drawCircle(
        Offset(s.x, s.y),
        s.radius,
        Paint()
          ..color = s.color.withAlpha((220 * t).toInt())
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6.0 * t + 1.5,
      );
    }
  }

  void _drawFloatingTexts(Canvas canvas) {
    for (final f in engine.floatingTexts) {
      final alpha = ((f.life / f.maxLife).clamp(0.0, 1.0) * 255).toInt();
      final tp = TextPainter(
        text: TextSpan(
          text: f.text,
          style: TextStyle(
            color: f.color.withAlpha(alpha),
            fontSize: f.fontSize,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.6,
            shadows: [
              Shadow(
                color: Colors.black.withAlpha(alpha),
                blurRadius: 6,
              ),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(f.x - tp.width / 2, f.y - tp.height / 2));
    }
  }

  void _drawWaveBanner(Canvas canvas, Size size) {
    if (engine.waveBannerTimer <= 0 || engine.phase != GamePhase.playing) return;
    final alpha = ((engine.waveBannerTimer / 2.0).clamp(0.0, 1.0) * 255).toInt();
    final label = engine.bossActive ? 'BOSS WAVE ${engine.wave}' : 'WAVE ${engine.wave}';
    final color = engine.bossActive ? const Color(0xFFFF1744) : const Color(0xFF00E5FF);

    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: color.withAlpha(alpha),
          fontSize: 32,
          fontWeight: FontWeight.w900,
          letterSpacing: 3.5,
          shadows: [
            Shadow(color: color.withAlpha((alpha * 0.6).toInt()), blurRadius: 16),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset((size.width - tp.width) / 2, size.height * 0.25));
  }

  @override
  bool shouldRepaint(covariant ArcadeGamePainter oldDelegate) => true;
}
