import 'dart:math';
import 'package:flutter/material.dart';

enum TerritoryIllustrationVariant { welcome, capture, points, progress, launch }

class TerritoryIllustration extends StatelessWidget {
  final Color accent;
  final IconData? icon;
  final double size;
  final String? chip;
  final String? label;
  final TerritoryIllustrationVariant variant;

  const TerritoryIllustration({
    super.key,
    required this.accent,
    this.icon,
    this.size = 240,
    this.chip,
    this.label,
    this.variant = TerritoryIllustrationVariant.capture,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _TerritoryPainter(accent, variant),
          ),
          if (icon != null)
            Container(
              width: size * 0.28,
              height: size * 0.28,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(size * 0.12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Icon(
                icon,
                size: size * 0.14,
                color: accent,
              ),
            ),
          if (chip != null)
            Positioned(
              left: size * 0.1,
              top: size * 0.12,
              child: _InfoChip(
                text: chip!,
                accent: accent,
              ),
            ),
          if (label != null)
            Positioned(
              right: size * 0.1,
              bottom: size * 0.12,
              child: _InfoChip(
                text: label!,
                accent: accent,
                invert: true,
              ),
            ),
        ],
      ),
    );
  }
}

class _TerritoryPainter extends CustomPainter {
  final Color accent;
  final TerritoryIllustrationVariant variant;

  _TerritoryPainter(this.accent, this.variant);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final radius = Radius.circular(size.width * 0.16);
    final baseRect = rect.deflate(size.width * 0.02);

    final basePaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFFFFFFF),
          Color(0xFFF3F4F6),
        ],
      ).createShader(baseRect);
    canvas.drawRRect(RRect.fromRectAndRadius(baseRect, radius), basePaint);

    final washPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          accent.withOpacity(0.16),
          accent.withOpacity(0.02),
        ],
      ).createShader(baseRect);
    canvas.drawRRect(RRect.fromRectAndRadius(baseRect, radius), washPaint);

    _drawGrid(canvas, size);

    switch (variant) {
      case TerritoryIllustrationVariant.welcome:
        _drawWelcome(canvas, size);
        break;
      case TerritoryIllustrationVariant.capture:
        _drawCapture(canvas, size);
        break;
      case TerritoryIllustrationVariant.points:
        _drawPoints(canvas, size);
        break;
      case TerritoryIllustrationVariant.progress:
        _drawProgress(canvas, size);
        break;
      case TerritoryIllustrationVariant.launch:
        _drawLaunch(canvas, size);
        break;
    }
  }

  void _drawGrid(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = const Color(0xFF111827).withOpacity(0.06)
      ..strokeWidth = size.width * 0.004;

    final step = size.width * 0.14;
    for (double dx = size.width * 0.14;
        dx < size.width * 0.86;
        dx += step) {
      canvas.drawLine(Offset(dx, size.height * 0.08),
          Offset(dx, size.height * 0.92), gridPaint);
    }
    for (double dy = size.height * 0.14;
        dy < size.height * 0.86;
        dy += step) {
      canvas.drawLine(Offset(size.width * 0.08, dy),
          Offset(size.width * 0.92, dy), gridPaint);
    }
  }

  void _drawCapture(Canvas canvas, Size size) {
    final territory = Path()
      ..moveTo(size.width * 0.18, size.height * 0.38)
      ..lineTo(size.width * 0.42, size.height * 0.24)
      ..lineTo(size.width * 0.7, size.height * 0.34)
      ..lineTo(size.width * 0.62, size.height * 0.62)
      ..lineTo(size.width * 0.32, size.height * 0.66)
      ..close();

    _fillTerritory(canvas, size, territory);

    final route = Path()
      ..moveTo(size.width * 0.18, size.height * 0.76)
      ..cubicTo(size.width * 0.32, size.height * 0.6, size.width * 0.46,
          size.height * 0.8, size.width * 0.62, size.height * 0.6)
      ..cubicTo(size.width * 0.72, size.height * 0.48, size.width * 0.82,
          size.height * 0.56, size.width * 0.82, size.height * 0.42);

    _drawRoute(canvas, size, route, withPulse: true);
  }

  void _drawWelcome(Canvas canvas, Size size) {
    final territory = Path()
      ..moveTo(size.width * 0.2, size.height * 0.3)
      ..lineTo(size.width * 0.48, size.height * 0.2)
      ..lineTo(size.width * 0.78, size.height * 0.36)
      ..lineTo(size.width * 0.64, size.height * 0.7)
      ..lineTo(size.width * 0.3, size.height * 0.68)
      ..close();

    _fillTerritory(canvas, size, territory);

    final ringPaint = Paint()
      ..color = accent.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.012;
    canvas.drawCircle(
      Offset(size.width * 0.62, size.height * 0.45),
      size.width * 0.16,
      ringPaint,
    );

    final route = Path()
      ..moveTo(size.width * 0.16, size.height * 0.78)
      ..quadraticBezierTo(size.width * 0.38, size.height * 0.52,
          size.width * 0.6, size.height * 0.64)
      ..quadraticBezierTo(size.width * 0.76, size.height * 0.74,
          size.width * 0.84, size.height * 0.48);

    _drawRoute(canvas, size, route, withPulse: false);
  }

  void _drawPoints(Canvas canvas, Size size) {
    final coinPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white,
          accent.withOpacity(0.15),
        ],
      ).createShader(
        Rect.fromCircle(
          center: Offset(size.width * 0.36, size.height * 0.58),
          radius: size.width * 0.14,
        ),
      );

    final coinBorder = Paint()
      ..color = accent.withOpacity(0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.014;

    final coins = [
      Offset(size.width * 0.34, size.height * 0.62),
      Offset(size.width * 0.46, size.height * 0.52),
      Offset(size.width * 0.58, size.height * 0.62),
    ];

    for (final center in coins) {
      canvas.drawCircle(center, size.width * 0.12, coinPaint);
      canvas.drawCircle(center, size.width * 0.12, coinBorder);
    }

    final star = _starPath(
      center: Offset(size.width * 0.62, size.height * 0.34),
      radius: size.width * 0.08,
    );
    final starPaint = Paint()
      ..color = accent.withOpacity(0.9)
      ..style = PaintingStyle.fill;
    canvas.drawPath(star, starPaint);

    final dottedPaint = Paint()
      ..color = accent.withOpacity(0.5)
      ..style = PaintingStyle.fill;
    for (int i = 0; i < 9; i++) {
      final t = i / 8;
      final x = size.width * 0.18 + (size.width * 0.82 - size.width * 0.18) * t;
      final y = size.height * (0.3 + 0.1 * sin(t * pi * 2));
      canvas.drawCircle(Offset(x, y), size.width * 0.01, dottedPaint);
    }
  }

  void _drawProgress(Canvas canvas, Size size) {
    final barPaint = Paint()
      ..color = accent.withOpacity(0.18)
      ..style = PaintingStyle.fill;
    final barWidth = size.width * 0.09;
    final barHeights = [0.24, 0.36, 0.18, 0.44];
    for (int i = 0; i < barHeights.length; i++) {
      final left = size.width * (0.2 + i * 0.13);
      final top = size.height * (0.7 - barHeights[i]);
      final barRect = Rect.fromLTWH(
        left,
        top,
        barWidth,
        size.height * barHeights[i],
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(barRect, Radius.circular(size.width * 0.03)),
        barPaint,
      );
    }

    final line = Path()
      ..moveTo(size.width * 0.18, size.height * 0.62)
      ..cubicTo(size.width * 0.36, size.height * 0.4, size.width * 0.48,
          size.height * 0.66, size.width * 0.64, size.height * 0.46)
      ..cubicTo(size.width * 0.74, size.height * 0.36, size.width * 0.82,
          size.height * 0.42, size.width * 0.86, size.height * 0.28);

    final lineGlow = Paint()
      ..color = accent.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.05
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(line, lineGlow);

    final linePaint = Paint()
      ..color = accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.02
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(line, linePaint);
  }

  void _drawLaunch(Canvas canvas, Size size) {
    final ringPaint = Paint()
      ..color = accent.withOpacity(0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.02;
    canvas.drawCircle(
      Offset(size.width * 0.34, size.height * 0.36),
      size.width * 0.18,
      ringPaint,
    );

    final arrowPath = Path()
      ..moveTo(size.width * 0.2, size.height * 0.68)
      ..quadraticBezierTo(
        size.width * 0.46,
        size.height * 0.52,
        size.width * 0.74,
        size.height * 0.32,
      );

    final arrowPaint = Paint()
      ..color = accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.028
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(arrowPath, arrowPaint);

    final arrowHead = Path()
      ..moveTo(size.width * 0.74, size.height * 0.32)
      ..lineTo(size.width * 0.68, size.height * 0.32)
      ..lineTo(size.width * 0.74, size.height * 0.26)
      ..close();
    final headPaint = Paint()
      ..color = accent
      ..style = PaintingStyle.fill;
    canvas.drawPath(arrowHead, headPaint);

    final dottedPaint = Paint()
      ..color = accent.withOpacity(0.4)
      ..style = PaintingStyle.fill;
    for (int i = 0; i < 6; i++) {
      final t = i / 5;
      final x = size.width * 0.2 + (size.width * 0.7 - size.width * 0.2) * t;
      final y = size.height * 0.68 + (size.height * 0.32 - size.height * 0.68) * t;
      canvas.drawCircle(
        Offset(x, y),
        size.width * 0.012,
        dottedPaint,
      );
    }
  }

  void _fillTerritory(Canvas canvas, Size size, Path territory) {
    final territoryFill = Paint()
      ..color = accent.withOpacity(0.18)
      ..style = PaintingStyle.fill;
    final territoryStroke = Paint()
      ..color = accent.withOpacity(0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.014;
    canvas.drawShadow(territory, Colors.black.withOpacity(0.2),
        size.width * 0.05, true);
    canvas.drawPath(territory, territoryFill);
    canvas.drawPath(territory, territoryStroke);
  }

  void _drawRoute(Canvas canvas, Size size, Path route,
      {required bool withPulse}) {
    final routeGlow = Paint()
      ..color = accent.withOpacity(0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.06
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(route, routeGlow);

    final routePaint = Paint()
      ..color = accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.028
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(route, routePaint);

    final nodePaint = Paint()..color = Colors.white;
    final nodeBorder = Paint()
      ..color = accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.01;

    final nodes = [
      Offset(size.width * 0.18, size.height * 0.76),
      Offset(size.width * 0.62, size.height * 0.6),
      Offset(size.width * 0.82, size.height * 0.42),
    ];

    for (final node in nodes) {
      canvas.drawCircle(node, size.width * 0.03, nodePaint);
      canvas.drawCircle(node, size.width * 0.03, nodeBorder);
    }

    if (withPulse) {
      final pulsePaint = Paint()
        ..color = accent.withOpacity(0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.012;
      canvas.drawCircle(nodes.last, size.width * 0.06, pulsePaint);
    }
  }

  Path _starPath({required Offset center, required double radius}) {
    final path = Path();
    const points = 5;
    final angle = (2 * pi) / points;
    for (int i = 0; i < points * 2; i++) {
      final r = i.isEven ? radius : radius * 0.45;
      final theta = i * angle / 2 - pi / 2;
      final x = center.dx + r * cos(theta);
      final y = center.dy + r * sin(theta);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _InfoChip extends StatelessWidget {
  final String text;
  final Color accent;
  final bool invert;

  const _InfoChip({
    required this.text,
    required this.accent,
    this.invert = false,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = invert ? accent : Colors.white;
    final textColor = invert ? Colors.white : const Color(0xFF111827);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: invert ? accent : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }
}
