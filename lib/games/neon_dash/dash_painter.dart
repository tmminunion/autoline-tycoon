import 'dart:math';

import 'package:flutter/material.dart';

import 'dash_engine.dart';

class DashPainter extends CustomPainter {
  DashPainter(this.engine) : super(repaint: engine);

  final DashEngine engine;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final groundY = engine.groundY;

    canvas.save();
    if (engine.shakeTimer > 0) {
      final m = engine.shakeTimer * 16;
      final rng = Random();
      canvas.translate((rng.nextDouble() - 0.5) * m, (rng.nextDouble() - 0.5) * m);
    }

    // 1. Deep cyberpunk sky
    final skyPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF040916), Color(0xFF0B1E3D), Color(0xFF071124)],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), skyPaint);

    // 2. Subtle grid
    final gridPaint = Paint()
      ..color = const Color(0xFF22D3EE).withValues(alpha: 0.06)
      ..strokeWidth = 1;
    for (double gx = -(engine.bgOffsetMid % 40); gx < w; gx += 40) {
      canvas.drawLine(Offset(gx, 0), Offset(gx, groundY), gridPaint);
    }

    // 3. Far skyline buildings
    final bldgPaint = Paint()..color = const Color(0xFF0D2347);
    final winPaint = Paint()..color = const Color(0xFF22D3EE).withValues(alpha: 0.24);
    final count = (w / 120).ceil() + 3;
    for (int i = -1; i < count; i++) {
      final bx = i * 120.0 - (engine.bgOffsetFar % 120.0);
      final bh = 65.0 + (((i * 53) % 75) + 75) % 75;
      canvas.drawRect(Rect.fromLTWH(bx, groundY - bh, 100, bh), bldgPaint);
      for (double wy = groundY - bh + 12; wy < groundY - 16; wy += 18) {
        canvas.drawRect(Rect.fromLTWH(bx + 12, wy, 24, 5), winPaint);
        canvas.drawRect(Rect.fromLTWH(bx + 50, wy, 24, 5), winPaint);
      }
    }

    // 4. Mid neon pillars
    final pillarPaint = Paint()..color = const Color(0xFF0F2448).withValues(alpha: 0.85);
    final stripePaint = Paint()..color = const Color(0xFF22D3EE).withValues(alpha: 0.38);
    for (double px = -engine.bgOffsetMid; px < w + 160; px += 160) {
      canvas.drawRect(Rect.fromLTWH(px, 0, 12, groundY), pillarPaint);
      canvas.drawRect(Rect.fromLTWH(px + 4.5, 0, 3, groundY), stripePaint);
    }

    // 5. Ground deck
    final groundPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF10264A), Color(0xFF040A16)],
      ).createShader(Rect.fromLTWH(0, groundY, w, h - groundY));
    canvas.drawRect(Rect.fromLTWH(0, groundY, w, h - groundY), groundPaint);

    // Top track neon rail
    canvas.drawRect(
      Rect.fromLTWH(0, groundY, w, 3),
      Paint()..color = engine.turboTimer > 0 ? const Color(0xFF22D3EE) : const Color(0xFF38BDF8),
    );

    // Hazard chevrons
    final chevPaint = Paint()..color = const Color(0xFFFACC15).withValues(alpha: 0.22);
    for (double fx = -engine.floorOffset; fx < w + 48; fx += 48) {
      final path = Path()
        ..moveTo(fx, groundY + 12)
        ..lineTo(fx + 22, groundY + 12)
        ..lineTo(fx + 12, groundY + 24)
        ..lineTo(fx - 10, groundY + 24)
        ..close();
      canvas.drawPath(path, chevPaint);
    }

    // 6. Pickups
    for (final p in engine.pickups) {
      if (p.type == DashPickupType.coin) {
        canvas.drawCircle(Offset(p.x, p.y), p.r, Paint()..color = const Color(0xFFFACC15));
        canvas.drawCircle(
          Offset(p.x, p.y),
          p.r,
          Paint()
            ..color = const Color(0xFFF97316)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
        _drawCenteredText(canvas, 'N', Offset(p.x, p.y), const Color(0xFF0F172A), 11);
      } else {
        final col = p.type == DashPickupType.shield
            ? const Color(0xFFFACC15)
            : (p.type == DashPickupType.magnet ? const Color(0xFFC084FC) : const Color(0xFF22D3EE));
        canvas.drawCircle(Offset(p.x, p.y), p.r + 2, Paint()..color = const Color(0xFF081226));
        canvas.drawCircle(
          Offset(p.x, p.y),
          p.r + 2,
          Paint()
            ..color = col
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5,
        );
        final sym = p.type == DashPickupType.shield ? 'S' : (p.type == DashPickupType.magnet ? 'M' : 'T');
        _drawCenteredText(canvas, sym, Offset(p.x, p.y), col, 13);
      }
    }

    // 7. Obstacles
    for (final o in engine.obstacles) {
      switch (o.type) {
        case DashObstacleType.oil:
          final rect = Rect.fromLTWH(o.x, o.y, o.w, o.h);
          canvas.drawOval(rect, Paint()..color = const Color(0xFF0F172A));
          canvas.drawOval(
            rect,
            Paint()
              ..color = const Color(0xFFA855F7)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2,
          );
          break;
        case DashObstacleType.crate:
          final bodyRect = RRect.fromRectAndRadius(
            Rect.fromLTWH(o.x, o.y, o.w, o.h - 7),
            const Radius.circular(6),
          );
          canvas.drawRRect(bodyRect, Paint()..color = const Color(0xFFEA580C));
          canvas.drawRect(Rect.fromLTWH(o.x + 4, o.y + 6, o.w - 8, 5), Paint()..color = const Color(0xFFFACC15));
          canvas.drawCircle(Offset(o.x + 10, o.y + o.h - 4), 4.5, Paint()..color = const Color(0xFF1E293B));
          canvas.drawCircle(Offset(o.x + o.w - 10, o.y + o.h - 4), 4.5, Paint()..color = const Color(0xFF1E293B));
          break;
        case DashObstacleType.laser:
          final rect = Rect.fromLTWH(o.x, o.y, o.w, o.h);
          canvas.drawRect(rect, Paint()..color = const Color(0xFFFB7185).withValues(alpha: 0.24));
          canvas.drawRect(
            rect,
            Paint()
              ..color = const Color(0xFFFB7185)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.5,
          );
          _drawCenteredText(canvas, 'SLIDE', Offset(o.x + o.w * 0.5, o.y + o.h * 0.5), const Color(0xFFFFE4E6), 10);
          break;
      }
    }

    // 8. Cyberpunk Runner Hero
    canvas.save();
    final onGround = engine.playerY >= groundY - engine.playerH - 1;
    final bob = (onGround && !engine.sliding) ? sin(engine.runPhase) * 3.0 : 0.0;
    final cx = engine.playerX + engine.playerW * 0.5;
    final cy = engine.playerY + engine.playerH * 0.5 + bob;
    canvas.translate(cx, cy);
    if (engine.sliding) {
      canvas.scale(1.18, 0.62);
    } else if (!onGround) {
      canvas.rotate((engine.playerVy * 0.00035).clamp(-0.22, 0.22));
    }

    final blinkOut = engine.invulnTimer > 0 && ((engine.invulnTimer * 16).floor() % 2 == 0);
    if (!blinkOut) {
      const r = 24.0;
      if (engine.turboTimer > 0) {
        canvas.drawCircle(
          Offset.zero,
          r + 8,
          Paint()
            ..color = const Color(0xFF22D3EE)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3,
        );
      }
      if (engine.hasShield) {
        canvas.drawCircle(Offset.zero, r + 5, Paint()..color = const Color(0xFFFACC15).withValues(alpha: 0.16));
        canvas.drawCircle(
          Offset.zero,
          r + 5,
          Paint()
            ..color = const Color(0xFFFACC15)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.8,
        );
      }

      // Hero orb body + visor + helmet
      canvas.drawCircle(
        Offset.zero,
        r,
        Paint()
          ..shader = const RadialGradient(
            colors: [Color(0xFF1E3A8A), Color(0xFF0A142E)],
          ).createShader(Rect.fromCircle(center: Offset.zero, radius: r)),
      );
      canvas.drawArc(
        Rect.fromCircle(center: const Offset(0, -3), radius: r - 2),
        pi,
        pi,
        true,
        Paint()..color = const Color(0xFFFACC15),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(const Rect.fromLTWH(-12, -2, 24, 9), const Radius.circular(4)),
        Paint()..color = const Color(0xFF22D3EE),
      );
      canvas.drawCircle(
        Offset.zero,
        r,
        Paint()
          ..color = const Color(0xFF22D3EE)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4,
      );
    }
    canvas.restore();

    // 9. Particles
    for (final pt in engine.particles) {
      final alpha = (pt.life / pt.maxLife).clamp(0.0, 1.0);
      canvas.drawCircle(Offset(pt.x, pt.y), pt.r, Paint()..color = pt.color.withValues(alpha: alpha));
    }

    // 10. Floating texts
    for (final ft in engine.floatTexts) {
      final alpha = (ft.life / ft.maxLife).clamp(0.0, 1.0);
      _drawCenteredText(canvas, ft.text, Offset(ft.x, ft.y), ft.color.withValues(alpha: alpha), 12);
    }

    canvas.restore();
  }

  void _drawCenteredText(Canvas canvas, String text, Offset center, Color color, double size) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: color, fontSize: size, fontWeight: FontWeight.w900),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(center.dx - tp.width * 0.5, center.dy - tp.height * 0.5));
  }

  @override
  bool shouldRepaint(covariant DashPainter oldDelegate) => true;
}
