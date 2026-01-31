import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/geo_types.dart';

class RoutePreview extends StatelessWidget {
  final List<LatLng> routePoints;
  final Set<Polygon>? polygons;
  final Uint8List? snapshotBytes;
  final Color lineColor;
  final double lineWidth;
  final bool showStartEnd;
  final LatLng? currentPoint;
  final Color currentPointColor;
  final double currentPointRadius;

  const RoutePreview({
    super.key,
    required this.routePoints,
    this.polygons,
    this.snapshotBytes,
    this.lineColor = const Color(0xFF667EEA),
    this.lineWidth = 4,
    this.showStartEnd = true,
    this.currentPoint,
    this.currentPointColor = const Color(0xFF38BDF8),
    this.currentPointRadius = 6,
  });

  @override
  Widget build(BuildContext context) {
    final hasGeometry = routePoints.isNotEmpty ||
        (polygons != null && polygons!.isNotEmpty) ||
        currentPoint != null ||
        (snapshotBytes != null && snapshotBytes!.isNotEmpty);
    if (!hasGeometry) {
      return Container(
        color: const Color(0xFFF3F4F6),
        child: const Center(
          child: Icon(Icons.map, size: 48, color: Color(0xFF9CA3AF)),
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        if (snapshotBytes != null && snapshotBytes!.isNotEmpty)
          Image.memory(snapshotBytes!, fit: BoxFit.cover)
        else
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF101827), Color(0xFF1F2A44)],
              ),
            ),
          ),
        CustomPaint(
          painter: _RoutePreviewPainter(
            routePoints: routePoints,
            polygons: polygons,
            lineColor: lineColor,
            lineWidth: lineWidth,
            showStartEnd: showStartEnd,
            currentPoint: currentPoint,
            currentPointColor: currentPointColor,
            currentPointRadius: currentPointRadius,
          ),
        ),
      ],
    );
  }
}

class _RoutePreviewPainter extends CustomPainter {
  final List<LatLng> routePoints;
  final Set<Polygon>? polygons;
  final Color lineColor;
  final double lineWidth;
  final bool showStartEnd;
  final LatLng? currentPoint;
  final Color currentPointColor;
  final double currentPointRadius;

  _RoutePreviewPainter({
    required this.routePoints,
    required this.polygons,
    required this.lineColor,
    required this.lineWidth,
    required this.showStartEnd,
    required this.currentPoint,
    required this.currentPointColor,
    required this.currentPointRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (routePoints.isEmpty &&
        (polygons == null || polygons!.isEmpty) &&
        currentPoint == null) {
      return;
    }

    final bounds = _calculateBounds(routePoints, polygons, currentPoint);
    final minLat = bounds.minLat;
    final maxLat = bounds.maxLat;
    final minLng = bounds.minLng;
    final maxLng = bounds.maxLng;

    double width = (maxLng - minLng).abs();
    double height = (maxLat - minLat).abs();
    if (width == 0) width = 0.000001;
    if (height == 0) height = 0.000001;

    final padX = size.width * 0.08;
    final padY = size.height * 0.08;
    final drawWidth = size.width - padX * 2;
    final drawHeight = size.height - padY * 2;

    Offset mapPoint(LatLng point) {
      final x = ((point.longitude - minLng) / width) * drawWidth + padX;
      final y = ((maxLat - point.latitude) / height) * drawHeight + padY;
      return Offset(x, y);
    }

    if (polygons != null) {
      for (final polygon in polygons!) {
        if (polygon.points.length < 3) continue;
        final path = Path();
        for (int i = 0; i < polygon.points.length; i++) {
          final offset = mapPoint(polygon.points[i]);
          if (i == 0) {
            path.moveTo(offset.dx, offset.dy);
          } else {
            path.lineTo(offset.dx, offset.dy);
          }
        }
        path.close();

        final fillPaint = Paint()
          ..style = PaintingStyle.fill
          ..color = polygon.fillColor.withOpacity(0.35);
        canvas.drawPath(path, fillPaint);

        final strokePaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = max(1.0, polygon.strokeWidth.toDouble())
          ..color = polygon.strokeColor.withOpacity(0.7);
        canvas.drawPath(path, strokePaint);
      }
    }

    final routePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = lineWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = lineColor;

    if (routePoints.isNotEmpty) {
      final routePath = Path();
      for (int i = 0; i < routePoints.length; i++) {
        final offset = mapPoint(routePoints[i]);
        if (i == 0) {
          routePath.moveTo(offset.dx, offset.dy);
        } else {
          routePath.lineTo(offset.dx, offset.dy);
        }
      }
      canvas.drawPath(routePath, routePaint);
    }

    if (showStartEnd && routePoints.length >= 2) {
      final start = mapPoint(routePoints.first);
      final end = mapPoint(routePoints.last);
      final startPaint = Paint()..color = const Color(0xFF22C55E);
      final endPaint = Paint()..color = const Color(0xFFEF4444);
      canvas.drawCircle(start, 5.5, startPaint);
      canvas.drawCircle(end, 5.5, endPaint);
    }

    if (currentPoint != null) {
      final offset = mapPoint(currentPoint!);
      final haloPaint = Paint()
        ..color = currentPointColor.withOpacity(0.25)
        ..style = PaintingStyle.fill;
      final dotPaint = Paint()
        ..color = currentPointColor
        ..style = PaintingStyle.fill;
      canvas.drawCircle(offset, currentPointRadius + 3, haloPaint);
      canvas.drawCircle(offset, currentPointRadius, dotPaint);
    }
  }

  _RouteBounds _calculateBounds(
    List<LatLng> points,
    Set<Polygon>? polygons,
    LatLng? currentPoint,
  ) {
    LatLng? seed;
    if (points.isNotEmpty) {
      seed = points.first;
    } else if (currentPoint != null) {
      seed = currentPoint;
    } else if (polygons != null && polygons.isNotEmpty) {
      final firstPolygon = polygons.first;
      if (firstPolygon.points.isNotEmpty) {
        seed = firstPolygon.points.first;
      }
    }

    if (seed == null) {
      return const _RouteBounds(0, 0, 0, 0);
    }

    double minLat = seed.latitude;
    double maxLat = seed.latitude;
    double minLng = seed.longitude;
    double maxLng = seed.longitude;

    void includePoint(LatLng point) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    for (final point in points) {
      includePoint(point);
    }

    if (currentPoint != null) {
      includePoint(currentPoint);
    }

    if (polygons != null) {
      for (final polygon in polygons) {
        for (final point in polygon.points) {
          includePoint(point);
        }
      }
    }

    return _RouteBounds(minLat, maxLat, minLng, maxLng);
  }

  @override
  bool shouldRepaint(covariant _RoutePreviewPainter oldDelegate) {
    return oldDelegate.routePoints != routePoints ||
        oldDelegate.polygons != polygons ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.lineWidth != lineWidth ||
        oldDelegate.showStartEnd != showStartEnd ||
        oldDelegate.currentPoint != currentPoint ||
        oldDelegate.currentPointColor != currentPointColor ||
        oldDelegate.currentPointRadius != currentPointRadius;
  }
}

class _RouteBounds {
  final double minLat;
  final double maxLat;
  final double minLng;
  final double maxLng;

  const _RouteBounds(this.minLat, this.maxLat, this.minLng, this.maxLng);
}
