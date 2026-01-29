import 'dart:math';
import 'package:flutter/material.dart';

class RainOverlay extends StatefulWidget {
  const RainOverlay({
    super.key,
    this.intensity = 0.5,
    this.color = const Color(0xFFFFFFFF),
    this.slant = 0.12,
  });

  final double intensity; // 0.0 - 1.0
  final Color color;
  final double slant; // 0.0 = vertical, 0.2 = diagonal

  @override
  State<RainOverlay> createState() => _RainOverlayState();
}

class _RainOverlayState extends State<RainOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late List<_RainDrop> _drops;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _buildDrops();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void didUpdateWidget(covariant RainOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.intensity != widget.intensity) {
      _buildDrops();
    }
  }

  void _buildDrops() {
    final clamped = widget.intensity.clamp(0.0, 1.0);
    final count = (40 + (140 * clamped)).round();
    _drops = List.generate(count, (_) {
      return _RainDrop(
        x: _random.nextDouble(),
        y: _random.nextDouble(),
        length: 16 + _random.nextDouble() * 20,
        speed: 0.3 + _random.nextDouble() * 0.8,
        width: 0.8 + _random.nextDouble() * 0.8,
        opacity: 0.25 + _random.nextDouble() * 0.35,
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _RainPainter(
        animation: _controller,
        drops: _drops,
        color: widget.color,
        slant: widget.slant,
      ),
      size: Size.infinite,
    );
  }
}

class _RainDrop {
  final double x;
  final double y;
  final double length;
  final double speed;
  final double width;
  final double opacity;

  const _RainDrop({
    required this.x,
    required this.y,
    required this.length,
    required this.speed,
    required this.width,
    required this.opacity,
  });
}

class _RainPainter extends CustomPainter {
  final Animation<double> animation;
  final List<_RainDrop> drops;
  final Color color;
  final double slant;

  _RainPainter({
    required this.animation,
    required this.drops,
    required this.color,
    required this.slant,
  }) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width == 0 || size.height == 0) return;

    final t = animation.value;
    final paint = Paint()..strokeCap = StrokeCap.round;

    for (final drop in drops) {
      final dx = drop.x * size.width;
      final dy = (drop.y + t * drop.speed) % 1.0;
      final start = Offset(
        dx + slant * size.height * dy,
        dy * size.height,
      );
      final end = Offset(
        start.dx + slant * drop.length,
        start.dy + drop.length,
      );

      paint
        ..color = color.withOpacity(drop.opacity)
        ..strokeWidth = drop.width;
      canvas.drawLine(start, end, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RainPainter oldDelegate) {
    return oldDelegate.drops != drops ||
        oldDelegate.color != color ||
        oldDelegate.slant != slant;
  }
}
