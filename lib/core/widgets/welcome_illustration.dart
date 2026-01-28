import 'package:flutter/material.dart';

class WelcomeIllustration extends StatelessWidget {
  final double size;
  final Color accent;
  final Color ink;

  const WelcomeIllustration({
    super.key,
    required this.accent,
    required this.ink,
    this.size = 260,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        size: Size(size, size),
        painter: _WelcomePainter(accent, ink),
      ),
    );
  }
}

class _WelcomePainter extends CustomPainter {
  final Color accent;
  final Color ink;

  _WelcomePainter(this.accent, this.ink);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final radius = Radius.circular(size.width * 0.16);
    final cardRect = rect.deflate(size.width * 0.03);

    final cardPath = Path()
      ..addRRect(RRect.fromRectAndRadius(cardRect, radius));
    canvas.drawShadow(cardPath, Colors.black.withOpacity(0.15),
        size.width * 0.05, true);

    final cardPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFFFFFFF),
          Color(0xFFF2FDF5),
        ],
      ).createShader(cardRect);
    canvas.drawRRect(RRect.fromRectAndRadius(cardRect, radius), cardPaint);

    final overlayPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          accent.withOpacity(0.12),
          accent.withOpacity(0.02),
        ],
      ).createShader(cardRect);
    canvas.drawRRect(RRect.fromRectAndRadius(cardRect, radius), overlayPaint);

    _drawBlocks(canvas, size);
    _drawRoute(canvas, size);
    _drawPulse(canvas, size);
  }

  void _drawBlocks(Canvas canvas, Size size) {
    final blockPaint = Paint()
      ..color = ink.withOpacity(0.06)
      ..style = PaintingStyle.fill;

    final blocks = [
      Rect.fromLTWH(size.width * 0.18, size.height * 0.22, size.width * 0.22,
          size.height * 0.14),
      Rect.fromLTWH(size.width * 0.5, size.height * 0.2, size.width * 0.26,
          size.height * 0.18),
      Rect.fromLTWH(size.width * 0.22, size.height * 0.46, size.width * 0.2,
          size.height * 0.2),
      Rect.fromLTWH(size.width * 0.52, size.height * 0.48, size.width * 0.24,
          size.height * 0.16),
      Rect.fromLTWH(size.width * 0.32, size.height * 0.72, size.width * 0.34,
          size.height * 0.1),
    ];

    for (final block in blocks) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(block, Radius.circular(size.width * 0.04)),
        blockPaint,
      );
    }
  }

  void _drawRoute(Canvas canvas, Size size) {
    final route = Path()
      ..moveTo(size.width * 0.2, size.height * 0.74)
      ..cubicTo(size.width * 0.32, size.height * 0.52, size.width * 0.48,
          size.height * 0.76, size.width * 0.64, size.height * 0.56)
      ..cubicTo(size.width * 0.72, size.height * 0.46, size.width * 0.82,
          size.height * 0.48, size.width * 0.82, size.height * 0.32);

    final glowPaint = Paint()
      ..color = accent.withOpacity(0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.06
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(route, glowPaint);

    final routePaint = Paint()
      ..color = accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.028
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(route, routePaint);

    final nodePaint = Paint()..color = Colors.white;
    final nodeBorder = Paint()
      ..color = accent.withOpacity(0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.01;

    final nodes = [
      Offset(size.width * 0.2, size.height * 0.74),
      Offset(size.width * 0.64, size.height * 0.56),
      Offset(size.width * 0.82, size.height * 0.32),
    ];

    for (final node in nodes) {
      canvas.drawCircle(node, size.width * 0.03, nodePaint);
      canvas.drawCircle(node, size.width * 0.03, nodeBorder);
    }
  }

  void _drawPulse(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.72, size.height * 0.34);
    final ringPaint = Paint()
      ..color = accent.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.014;
    canvas.drawCircle(center, size.width * 0.12, ringPaint);
    canvas.drawCircle(center, size.width * 0.2, ringPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
