import 'dart:math' as math;

import 'package:flutter/material.dart';

class GameTileArtwork extends StatelessWidget {
  const GameTileArtwork({
    super.key,
    required this.id,
    required this.category,
    required this.colors,
    required this.icon,
    this.emoji,
    this.compact = false,
  });

  final String id;
  final String category;
  final List<Color> colors;
  final IconData icon;
  final String? emoji;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c1 = colors.isNotEmpty ? colors.first : const Color(0xFF2563EB);
    final c2 = colors.length > 1 ? colors[1] : c1.withValues(alpha: 0.72);
    final keyId = id.toLowerCase();

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [c1, c2],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Ambient radial glow + subtle arcade grid/bubbles
          CustomPaint(
            painter: _BackdropPainter(accent: c1, secondary: c2),
          ),
          // Top-left glossy glass reflection
          Positioned(
            top: -28,
            left: -24,
            right: -10,
            height: 76,
            child: Transform.rotate(
              angle: -0.22,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withValues(alpha: 0.28),
                      Colors.white.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Centerpiece artwork
          Center(
            child: _buildCenterpiece(keyId, c1),
          ),
        ],
      ),
    );
  }

  Widget _buildCenterpiece(String keyId, Color accent) {
    final artSize = compact ? 52.0 : 62.0;

    if (keyId.contains('striker') || keyId.contains('space') || keyId.contains('shooter')) {
      return SizedBox(
        width: artSize,
        height: artSize,
        child: CustomPaint(painter: _JetArtworkPainter()),
      );
    }
    if (keyId.contains('dash') || keyId.contains('runner') || keyId.contains('reflex')) {
      return SizedBox(
        width: artSize,
        height: artSize,
        child: CustomPaint(painter: _BoltArtworkPainter()),
      );
    }
    if (keyId.contains('catur') || keyId.contains('chess')) {
      return SizedBox(
        width: artSize,
        height: artSize,
        child: CustomPaint(painter: _ChessArtworkPainter()),
      );
    }
    if (keyId.contains('sos') || keyId.contains('tic')) {
      return SizedBox(
        width: artSize,
        height: artSize,
        child: CustomPaint(painter: _SosArtworkPainter()),
      );
    }
    if (keyId.contains('match') || keyId.contains('gem') || keyId.contains('jewel')) {
      return SizedBox(
        width: artSize,
        height: artSize,
        child: CustomPaint(painter: _GemArtworkPainter()),
      );
    }
    if (keyId.contains('stack') || keyId.contains('tower')) {
      return SizedBox(
        width: artSize,
        height: artSize,
        child: CustomPaint(painter: _StackArtworkPainter()),
      );
    }
    if (keyId.contains('2048')) {
      return _Badge2048(compact: compact);
    }

    // Modern 3D glassmorphic squircle emblem for all 100+ cloud games
    final boxSize = compact ? 50.0 : 58.0;
    final glyphSize = compact ? 26.0 : 30.0;
    return Container(
      width: boxSize,
      height: boxSize,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.30),
            Colors.white.withValues(alpha: 0.10),
          ],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.45),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.20),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Center(
        child: emoji != null && emoji!.trim().isNotEmpty
            ? Text(
                emoji!,
                style: TextStyle(
                  fontSize: glyphSize,
                  shadows: [
                    Shadow(
                      color: Colors.black.withValues(alpha: 0.28),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              )
            : Icon(
                icon,
                size: glyphSize,
                color: Colors.white,
                shadows: [
                  Shadow(
                    color: Colors.black.withValues(alpha: 0.28),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
      ),
    );
  }
}

class _BackdropPainter extends CustomPainter {
  const _BackdropPainter({required this.accent, required this.secondary});
  final Color accent;
  final Color secondary;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.5, size.height * 0.52);
    final glow = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: 0.24),
          Colors.white.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: size.width * 0.48));
    canvas.drawCircle(center, size.width * 0.48, glow);

    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = Colors.white.withValues(alpha: 0.14);
    canvas.drawCircle(Offset(size.width * 0.86, size.height * 0.18), size.width * 0.20, ringPaint);
    canvas.drawCircle(Offset(size.width * 0.14, size.height * 0.86), size.width * 0.16, ringPaint);

    final dotPaint = Paint()..color = Colors.white.withValues(alpha: 0.20);
    canvas.drawCircle(Offset(size.width * 0.80, size.height * 0.78), 2.2, dotPaint);
    canvas.drawCircle(Offset(size.width * 0.22, size.height * 0.30), 1.8, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _BackdropPainter oldDelegate) =>
      oldDelegate.accent != accent || oldDelegate.secondary != secondary;
}

class _JetArtworkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Thruster glow
    final flame = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFFDE047), Color(0xFFF97316), Color(0x00F97316)],
      ).createShader(Rect.fromLTWH(w * 0.35, h * 0.65, w * 0.30, h * 0.30));
    canvas.drawOval(Rect.fromLTWH(w * 0.42, h * 0.68, w * 0.16, h * 0.24), flame);

    // Jet body
    final body = Path()
      ..moveTo(w * 0.50, h * 0.08)
      ..lineTo(w * 0.63, h * 0.40)
      ..lineTo(w * 0.88, h * 0.64)
      ..lineTo(w * 0.60, h * 0.62)
      ..lineTo(w * 0.56, h * 0.74)
      ..lineTo(w * 0.44, h * 0.74)
      ..lineTo(w * 0.40, h * 0.62)
      ..lineTo(w * 0.12, h * 0.64)
      ..lineTo(w * 0.37, h * 0.40)
      ..close();

    canvas.drawShadow(body, Colors.black.withValues(alpha: 0.45), 6, true);
    canvas.drawPath(
      body,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, Color(0xFFBAE6FD)],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );

    // Cockpit
    canvas.drawOval(
      Rect.fromCenter(center: Offset(w * 0.50, h * 0.39), width: w * 0.13, height: h * 0.22),
      Paint()..color = const Color(0xFF0284C7),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BoltArtworkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Speed lines
    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.45)
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(w * 0.10, h * 0.34), Offset(w * 0.28, h * 0.34), linePaint);
    canvas.drawLine(Offset(w * 0.06, h * 0.52), Offset(w * 0.22, h * 0.52), linePaint);
    canvas.drawLine(Offset(w * 0.74, h * 0.64), Offset(w * 0.92, h * 0.64), linePaint);

    final bolt = Path()
      ..moveTo(w * 0.58, h * 0.08)
      ..lineTo(w * 0.26, h * 0.54)
      ..lineTo(w * 0.48, h * 0.54)
      ..lineTo(w * 0.40, h * 0.92)
      ..lineTo(w * 0.76, h * 0.44)
      ..lineTo(w * 0.52, h * 0.44)
      ..close();

    canvas.drawShadow(bolt, Colors.black.withValues(alpha: 0.4), 6, true);
    canvas.drawPath(
      bolt,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFEF08A), Colors.white],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ChessArtworkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Mini 2x2 board badge behind knight
    final boardRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(w * 0.5, h * 0.56), width: w * 0.74, height: h * 0.64),
      const Radius.circular(10),
    );
    canvas.drawRRect(boardRect, Paint()..color = const Color(0x33000000));

    // King/Pawn modern silhouette
    final piece = Path()
      ..moveTo(w * 0.50, h * 0.14)
      ..addOval(Rect.fromCircle(center: Offset(w * 0.50, h * 0.26), radius: w * 0.13))
      ..moveTo(w * 0.36, h * 0.40)
      ..lineTo(w * 0.64, h * 0.40)
      ..lineTo(w * 0.58, h * 0.68)
      ..lineTo(w * 0.72, h * 0.80)
      ..lineTo(w * 0.28, h * 0.80)
      ..lineTo(w * 0.42, h * 0.68)
      ..close();

    canvas.drawShadow(piece, Colors.black.withValues(alpha: 0.45), 5, true);
    canvas.drawPath(
      piece,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, Color(0xFFFDE68A)],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SosArtworkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(Offset(w * 0.36, h * 0.16), Offset(w * 0.36, h * 0.84), gridPaint);
    canvas.drawLine(Offset(w * 0.64, h * 0.16), Offset(w * 0.64, h * 0.84), gridPaint);
    canvas.drawLine(Offset(w * 0.16, h * 0.36), Offset(w * 0.84, h * 0.36), gridPaint);
    canvas.drawLine(Offset(w * 0.16, h * 0.64), Offset(w * 0.84, h * 0.64), gridPaint);

    // Neon O in center & winning strike
    canvas.drawCircle(
      Offset(w * 0.50, h * 0.50),
      w * 0.10,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0
        ..color = const Color(0xFFFEF08A),
    );
    canvas.drawLine(
      Offset(w * 0.18, h * 0.82),
      Offset(w * 0.82, h * 0.18),
      Paint()
        ..color = Colors.white
        ..strokeWidth = 3.2
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _GemArtworkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final gem = Path()
      ..moveTo(w * 0.28, h * 0.18)
      ..lineTo(w * 0.72, h * 0.18)
      ..lineTo(w * 0.88, h * 0.42)
      ..lineTo(w * 0.50, h * 0.86)
      ..lineTo(w * 0.12, h * 0.42)
      ..close();

    canvas.drawShadow(gem, Colors.black.withValues(alpha: 0.4), 6, true);
    canvas.drawPath(
      gem,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, Color(0xFFA5F3FC), Color(0xFF38BDF8)],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );

    final facetPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    canvas.drawLine(Offset(w * 0.12, h * 0.42), Offset(w * 0.88, h * 0.42), facetPaint);
    canvas.drawLine(Offset(w * 0.28, h * 0.18), Offset(w * 0.50, h * 0.86), facetPaint);
    canvas.drawLine(Offset(w * 0.72, h * 0.18), Offset(w * 0.50, h * 0.86), facetPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _StackArtworkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final colors = [
      Colors.white.withValues(alpha: 0.95),
      const Color(0xFFFEF08A),
      const Color(0xFFA5F3FC),
    ];
    for (int i = 0; i < 3; i++) {
      final y = h * (0.64 - i * 0.18);
      final inset = i * 4.0;
      final r = RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.18 + inset, y, w * 0.64 - inset * 2, h * 0.14),
        const Radius.circular(6),
      );
      canvas.drawRRect(r, Paint()..color = colors[i]);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Badge2048 extends StatelessWidget {
  const _Badge2048({required this.compact});
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final s = compact ? 48.0 : 56.0;
    return Container(
      width: s,
      height: s,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFEF08A), Color(0xFFF59E0B)],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Text(
          '2048',
          style: TextStyle(
            fontSize: compact ? 14 : 16,
            fontWeight: FontWeight.w900,
            color: const Color(0xFF78350F),
            letterSpacing: -0.5,
          ),
        ),
      ),
    );
  }
}
