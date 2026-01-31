import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../theme/app_theme.dart';

/// Patterned background widget with decorative elements
class PatternedBackground extends StatelessWidget {
  final Widget child;

  const PatternedBackground({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
      ),
      child: Stack(
        children: [
          // Pattern overlay
          Positioned.fill(
            child: CustomPaint(
              painter: PatternPainter(),
            ),
          ),
          // Content
          child,
        ],
      ),
    );
  }
}

/// Custom painter for background patterns
class PatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Draw hexagon grid pattern
    _drawHexagonGrid(canvas, size, paint);
    
    // Draw grid lines
    _drawGridPattern(canvas, size, paint);
    
    // Draw wave curves
    _drawWaveLines(canvas, size, paint);
    
    // Draw corner accents
    _drawCornerAccents(canvas, size, paint);
  }

  void _drawHexagonGrid(Canvas canvas, Size size, Paint paint) {
    paint.color = AppTheme.primaryColor.withOpacity(0.09);
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 1.5;
    
    final hexSize = 40.0;
    final spacing = hexSize * 1.5;
    
    for (double x = -hexSize; x < size.width + hexSize; x += spacing) {
      for (double y = -hexSize; y < size.height + hexSize; y += spacing * 0.866) {
        final offset = (y / (spacing * 0.866)).floor() % 2 == 0 ? 0.0 : spacing / 2;
        _drawHexagon(canvas, Offset(x + offset, y), hexSize * 0.8, paint);
      }
    }
  }

  void _drawHexagon(Canvas canvas, Offset center, double size, Paint paint) {
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final angle = (60 * i - 30) * math.pi / 180;
      final x = center.dx + size * math.cos(angle);
      final y = center.dy + size * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  void _drawGridPattern(Canvas canvas, Size size, Paint paint) {
    paint.color = AppTheme.primaryColor.withOpacity(0.05);
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 1.0;
    
    final spacing = 80.0;
    
    // Vertical lines
    for (double x = spacing; x < size.width; x += spacing) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        paint,
      );
    }
    
    // Horizontal lines
    for (double y = spacing; y < size.height; y += spacing) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
    }
  }

  void _drawCornerAccents(Canvas canvas, Size size, Paint paint) {
    paint.color = AppTheme.primaryColor.withOpacity(0.08);
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 2.0;
    
    final accentSize = 60.0;
    
    // Top left corner
    canvas.drawArc(
      Rect.fromLTWH(0, 0, accentSize * 2, accentSize * 2),
      math.pi, // 180 degrees
      math.pi / 2, // 90 degrees
      false,
      paint,
    );
    
    // Top right corner
    canvas.drawArc(
      Rect.fromLTWH(size.width - accentSize * 2, 0, accentSize * 2, accentSize * 2),
      3 * math.pi / 2, // 270 degrees
      math.pi / 2, // 90 degrees
      false,
      paint,
    );
    
    // Bottom left corner
    canvas.drawArc(
      Rect.fromLTWH(0, size.height - accentSize * 2, accentSize * 2, accentSize * 2),
      math.pi / 2, // 90 degrees
      math.pi / 2, // 90 degrees
      false,
      paint,
    );
    
    // Bottom right corner
    canvas.drawArc(
      Rect.fromLTWH(size.width - accentSize * 2, size.height - accentSize * 2, accentSize * 2, accentSize * 2),
      0, // 0 degrees
      math.pi / 2, // 90 degrees
      false,
      paint,
    );
  }

  void _drawWaveLines(Canvas canvas, Size size, Paint paint) {
    paint
      ..color = AppTheme.primaryColor.withOpacity(0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    // Flowing wave across the screen
    final path = Path();
    path.moveTo(0, size.height * 0.3);
    
    for (double x = 0; x <= size.width; x += 20) {
      final y = size.height * 0.3 + math.sin(x / 50) * 30;
      path.lineTo(x, y);
    }
    
    canvas.drawPath(path, paint);
    
    // Second wave
    final path2 = Path();
    path2.moveTo(0, size.height * 0.7);
    
    for (double x = 0; x <= size.width; x += 20) {
      final y = size.height * 0.7 + math.cos(x / 60) * 25;
      path2.lineTo(x, y);
    }
    
    canvas.drawPath(path2, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
