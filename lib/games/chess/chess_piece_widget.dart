import 'package:flutter/material.dart';

/// Crisp vector Staunton chess piece renderer so White (#FFFFFF with dark outline)
/// and Black (#18181B with crisp light detail lines) are unmistakably distinct on all Android fonts.
class ChessPieceWidget extends StatelessWidget {
  const ChessPieceWidget({
    super.key,
    required this.code,
    this.size = 34,
  });

  final String code; // e.g. 'wK', 'bQ', 'wP'
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _ChessPiecePainter(code: code),
      ),
    );
  }
}

class _ChessPiecePainter extends CustomPainter {
  const _ChessPiecePainter({required this.code});

  final String code;

  @override
  void paint(Canvas canvas, Size size) {
    if (code.length < 2) return;
    final isWhite = code[0] == 'w';
    final type = code[1];

    canvas.save();
    canvas.scale(size.width / 45.0, size.height / 45.0);

    final fillPaint = Paint()
      ..color = isWhite ? const Color(0xFFFFFFFF) : const Color(0xFF18181B)
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = isWhite ? const Color(0xFF1C1917) : const Color(0xFF09090B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = isWhite ? 2.1 : 1.5
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    final detailPaint = Paint()
      ..color = isWhite ? const Color(0xFF1C1917) : const Color(0xFFE4E4E7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.45
      ..strokeCap = StrokeCap.round;

    final detailFill = Paint()
      ..color = isWhite ? const Color(0xFF1C1917) : const Color(0xFFE4E4E7)
      ..style = PaintingStyle.fill;

    void drawShape(Path p) {
      canvas.drawPath(p, fillPaint);
      canvas.drawPath(p, strokePaint);
    }

    if (type == 'P') {
      // Head
      canvas.drawCircle(const Offset(22.5, 13.5), 5.4, fillPaint);
      canvas.drawCircle(const Offset(22.5, 13.5), 5.4, strokePaint);
      // Neck/Body
      final body = Path()
        ..moveTo(16.5, 29.3)
        ..quadraticBezierTo(16.2, 19.5, 22.5, 19.2)
        ..quadraticBezierTo(28.8, 19.5, 28.5, 29.3)
        ..close();
      drawShape(body);
      // Base
      final base = Path()
        ..moveTo(12.5, 38.5)
        ..lineTo(12.5, 35.8)
        ..quadraticBezierTo(15.5, 30.5, 22.5, 30.5)
        ..quadraticBezierTo(29.5, 30.5, 32.5, 35.8)
        ..lineTo(32.5, 38.5)
        ..close();
      drawShape(base);
      canvas.drawLine(const Offset(15.5, 35.5), const Offset(29.5, 35.5), detailPaint);
    } else if (type == 'R') {
      final rook = Path()
        ..moveTo(11, 10)
        ..lineTo(15.5, 10)
        ..lineTo(15.5, 13.5)
        ..lineTo(20, 13.5)
        ..lineTo(20, 10)
        ..lineTo(25, 10)
        ..lineTo(25, 13.5)
        ..lineTo(29.5, 13.5)
        ..lineTo(29.5, 10)
        ..lineTo(34, 10)
        ..lineTo(34, 17.5)
        ..lineTo(30.5, 20.5)
        ..lineTo(30.5, 31)
        ..lineTo(34, 34.5)
        ..lineTo(34, 38.5)
        ..lineTo(11, 38.5)
        ..lineTo(11, 34.5)
        ..lineTo(14.5, 31)
        ..lineTo(14.5, 20.5)
        ..lineTo(11, 17.5)
        ..close();
      drawShape(rook);
      canvas.drawLine(const Offset(14.5, 20.5), const Offset(30.5, 20.5), detailPaint);
      canvas.drawLine(const Offset(14.5, 31), const Offset(30.5, 31), detailPaint);
      canvas.drawLine(const Offset(12.5, 35), const Offset(32.5, 35), detailPaint);
    } else if (type == 'N') {
      final knight = Path()
        ..moveTo(13, 38.5)
        ..lineTo(13, 35)
        ..lineTo(16, 32)
        ..quadraticBezierTo(16.8, 25.5, 13.5, 22.5)
        ..lineTo(11.5, 21)
        ..lineTo(14, 14.5)
        ..lineTo(18.5, 11)
        ..lineTo(20, 8)
        ..lineTo(23.5, 10)
        ..quadraticBezierTo(33.5, 11.2, 33.5, 22.5)
        ..quadraticBezierTo(33.5, 28.5, 30.5, 33)
        ..lineTo(33, 35)
        ..lineTo(33, 38.5)
        ..close();
      drawShape(knight);
      canvas.drawCircle(const Offset(19, 16.5), 1.5, detailFill);
      final mane = Path()
        ..moveTo(23.5, 13)
        ..quadraticBezierTo(29.8, 16.5, 29.2, 26);
      canvas.drawPath(mane, detailPaint);
      canvas.drawLine(const Offset(14.5, 35), const Offset(31.5, 35), detailPaint);
    } else if (type == 'B') {
      canvas.drawCircle(const Offset(22.5, 9), 2.5, fillPaint);
      canvas.drawCircle(const Offset(22.5, 9), 2.5, strokePaint);
      final body = Path()
        ..moveTo(17.5, 31.5)
        ..quadraticBezierTo(13.5, 26.5, 15, 20)
        ..quadraticBezierTo(16.8, 12.5, 22.5, 11.5)
        ..quadraticBezierTo(28.2, 12.5, 30, 20)
        ..quadraticBezierTo(31.5, 26.5, 27.5, 31.5)
        ..close();
      drawShape(body);
      final base = Path()
        ..moveTo(11, 38.5)
        ..quadraticBezierTo(13.5, 33.5, 22.5, 33.5)
        ..quadraticBezierTo(31.5, 33.5, 34, 38.5)
        ..close();
      drawShape(base);
      canvas.drawLine(const Offset(22.5, 16), const Offset(22.5, 23), detailPaint);
      canvas.drawLine(const Offset(19, 19.5), const Offset(26, 19.5), detailPaint);
      canvas.drawLine(const Offset(16.8, 29.5), const Offset(28.2, 29.5), detailPaint);
    } else if (type == 'Q') {
      for (final pt in const [
        Offset(9.5, 14),
        Offset(16, 10.5),
        Offset(22.5, 9),
        Offset(29, 10.5),
        Offset(35.5, 14),
      ]) {
        canvas.drawCircle(pt, 2.3, fillPaint);
        canvas.drawCircle(pt, 2.3, strokePaint);
      }
      final crown = Path()
        ..moveTo(10.5, 16.5)
        ..lineTo(15, 31.5)
        ..lineTo(30, 31.5)
        ..lineTo(34.5, 16.5)
        ..lineTo(29, 23.5)
        ..lineTo(26, 12.5)
        ..lineTo(22.5, 23)
        ..lineTo(19, 12.5)
        ..lineTo(16, 23.5)
        ..close();
      drawShape(crown);
      final base = Path()
        ..moveTo(13, 31.5)
        ..lineTo(32, 31.5)
        ..lineTo(33.5, 38.5)
        ..lineTo(11.5, 38.5)
        ..close();
      drawShape(base);
      canvas.drawLine(const Offset(14, 35), const Offset(31, 35), detailPaint);
    } else if (type == 'K') {
      final crossPaint = Paint()
        ..color = isWhite ? const Color(0xFF1C1917) : const Color(0xFFF4F4F5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(const Offset(22.5, 6.5), const Offset(22.5, 13.5), crossPaint);
      canvas.drawLine(const Offset(19, 9.5), const Offset(26, 9.5), crossPaint);
      final body = Path()
        ..moveTo(14.5, 31.5)
        ..quadraticBezierTo(8.5, 24.5, 11.5, 18.5)
        ..quadraticBezierTo(15, 13.5, 20.5, 19)
        ..quadraticBezierTo(22.5, 15.5, 24.5, 19)
        ..quadraticBezierTo(30, 13.5, 33.5, 18.5)
        ..quadraticBezierTo(36.5, 24.5, 30.5, 31.5)
        ..close();
      drawShape(body);
      final base = Path()
        ..moveTo(13, 31.5)
        ..lineTo(32, 31.5)
        ..lineTo(33.5, 38.5)
        ..lineTo(11.5, 38.5)
        ..close();
      drawShape(base);
      canvas.drawLine(const Offset(22.5, 19), const Offset(22.5, 29), detailPaint);
      canvas.drawLine(const Offset(14, 35), const Offset(31, 35), detailPaint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ChessPiecePainter oldDelegate) => oldDelegate.code != code;
}
