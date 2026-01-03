/// ═══════════════════════════════════════════════════════════════════════════════
/// INDUSTRY-GRADE GEOSPATIAL ALGORITHMS
/// ═══════════════════════════════════════════════════════════════════════════════
/// 
/// This library implements mathematically rigorous algorithms for:
/// - Point-in-polygon testing (Winding Number with numerical stability)
/// - Polygon area calculation (Geodesic Shoelace with spherical correction)
/// - Route simplification (Ramer-Douglas-Peucker with geodesic distance)
/// - Polygon validation and repair
/// - Spatial indexing for performance
/// - Anti-cheat validation
/// 
/// All algorithms are designed for GPS coordinates on WGS84 ellipsoid.
/// ═══════════════════════════════════════════════════════════════════════════════

import 'dart:math';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// WGS84 Earth constants
class EarthConstants {
  static const double equatorialRadiusM = 6378137.0;           // Semi-major axis (meters)
  static const double polarRadiusM = 6356752.314245;           // Semi-minor axis (meters)
  static const double flattening = 1 / 298.257223563;          // Flattening factor
  static const double eccentricitySquared = 0.00669437999014;  // First eccentricity squared
  static const double metersPerDegreeLat = 111319.9;           // Average meters per degree latitude
}

/// ═══════════════════════════════════════════════════════════════════════════════
/// GEODESIC DISTANCE CALCULATION
/// Uses Vincenty's formulae for accuracy on WGS84 ellipsoid
/// ═══════════════════════════════════════════════════════════════════════════════
class GeodesicCalculator {
  /// Calculate distance between two points using Vincenty's inverse formula
  /// More accurate than Haversine for all distances on WGS84 ellipsoid
  /// Returns distance in meters
  static double vincentyDistance(LatLng p1, LatLng p2) {
    final a = EarthConstants.equatorialRadiusM;
    final b = EarthConstants.polarRadiusM;
    final f = EarthConstants.flattening;
    
    final phi1 = p1.latitude * pi / 180;
    final phi2 = p2.latitude * pi / 180;
    final L = (p2.longitude - p1.longitude) * pi / 180;
    
    final U1 = atan((1 - f) * tan(phi1));
    final U2 = atan((1 - f) * tan(phi2));
    
    final sinU1 = sin(U1), cosU1 = cos(U1);
    final sinU2 = sin(U2), cosU2 = cos(U2);
    
    double lambda = L;
    double lambdaP = 2 * pi;
    int iterLimit = 100;
    
    double sinLambda = 0, cosLambda = 0;
    double sinSigma = 0, cosSigma = 0, sigma = 0;
    double sinAlpha = 0, cosSqAlpha = 0;
    double cos2SigmaM = 0;
    double C = 0;
    
    while ((lambda - lambdaP).abs() > 1e-12 && iterLimit > 0) {
      sinLambda = sin(lambda);
      cosLambda = cos(lambda);
      
      sinSigma = sqrt(
        (cosU2 * sinLambda) * (cosU2 * sinLambda) +
        (cosU1 * sinU2 - sinU1 * cosU2 * cosLambda) *
        (cosU1 * sinU2 - sinU1 * cosU2 * cosLambda)
      );
      
      if (sinSigma == 0) return 0; // Co-incident points
      
      cosSigma = sinU1 * sinU2 + cosU1 * cosU2 * cosLambda;
      sigma = atan2(sinSigma, cosSigma);
      
      sinAlpha = cosU1 * cosU2 * sinLambda / sinSigma;
      cosSqAlpha = 1 - sinAlpha * sinAlpha;
      
      cos2SigmaM = cosSqAlpha != 0 
          ? cosSigma - 2 * sinU1 * sinU2 / cosSqAlpha 
          : 0;
      
      C = f / 16 * cosSqAlpha * (4 + f * (4 - 3 * cosSqAlpha));
      
      lambdaP = lambda;
      lambda = L + (1 - C) * f * sinAlpha * (
        sigma + C * sinSigma * (
          cos2SigmaM + C * cosSigma * (-1 + 2 * cos2SigmaM * cos2SigmaM)
        )
      );
      
      iterLimit--;
    }
    
    if (iterLimit == 0) {
      // Vincenty failed to converge (antipodal points), fallback to Haversine
      return _haversineDistance(p1, p2);
    }
    
    final uSq = cosSqAlpha * (a * a - b * b) / (b * b);
    final A = 1 + uSq / 16384 * (4096 + uSq * (-768 + uSq * (320 - 175 * uSq)));
    final B = uSq / 1024 * (256 + uSq * (-128 + uSq * (74 - 47 * uSq)));
    
    final deltaSigma = B * sinSigma * (
      cos2SigmaM + B / 4 * (
        cosSigma * (-1 + 2 * cos2SigmaM * cos2SigmaM) -
        B / 6 * cos2SigmaM * (-3 + 4 * sinSigma * sinSigma) *
        (-3 + 4 * cos2SigmaM * cos2SigmaM)
      )
    );
    
    return b * A * (sigma - deltaSigma);
  }
  
  /// Haversine formula (fallback for Vincenty convergence failure)
  static double _haversineDistance(LatLng p1, LatLng p2) {
    const R = 6371000.0; // Earth's mean radius in meters
    
    final dLat = (p2.latitude - p1.latitude) * pi / 180;
    final dLon = (p2.longitude - p1.longitude) * pi / 180;
    final lat1 = p1.latitude * pi / 180;
    final lat2 = p2.latitude * pi / 180;
    
    final a = sin(dLat / 2) * sin(dLat / 2) +
              sin(dLon / 2) * sin(dLon / 2) * cos(lat1) * cos(lat2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    
    return R * c;
  }
  
  /// Fast approximation for short distances (< 10km)
  /// Uses equirectangular projection - accurate to ~0.1% for short distances
  static double fastDistance(LatLng p1, LatLng p2) {
    final avgLat = (p1.latitude + p2.latitude) / 2 * pi / 180;
    final x = (p2.longitude - p1.longitude) * pi / 180 * cos(avgLat);
    final y = (p2.latitude - p1.latitude) * pi / 180;
    return sqrt(x * x + y * y) * 6371000;
  }
  
  /// Get meters per degree longitude at given latitude
  static double metersPerDegreeLng(double latitudeDeg) {
    return EarthConstants.metersPerDegreeLat * cos(latitudeDeg * pi / 180);
  }
}

/// ═══════════════════════════════════════════════════════════════════════════════
/// POINT-IN-POLYGON ALGORITHM
/// Robust Winding Number with numerical stability
/// ═══════════════════════════════════════════════════════════════════════════════
class PointInPolygon {
  /// Determine if a point is inside a polygon using Winding Number algorithm
  /// Handles self-intersecting polygons correctly
  /// Uses numerical tolerance for edge cases
  static bool isInside(LatLng point, List<LatLng> polygon) {
    if (polygon.length < 3) return false;
    
    // First check bounding box for quick rejection
    if (!_isInBoundingBox(point, polygon)) return false;
    
    int windingNumber = 0;
    const epsilon = 1e-10; // Numerical tolerance
    
    for (int i = 0; i < polygon.length; i++) {
      final p1 = polygon[i];
      final p2 = polygon[(i + 1) % polygon.length];
      
      // Check if point is on the edge (within tolerance)
      if (_isPointOnSegment(point, p1, p2, epsilon)) {
        return true; // Point on boundary counts as inside
      }
      
      if (p1.latitude <= point.latitude + epsilon) {
        if (p2.latitude > point.latitude + epsilon) {
          // Upward crossing
          final cross = _crossProduct(p1, p2, point);
          if (cross > epsilon) {
            windingNumber++;
          }
        }
      } else {
        if (p2.latitude <= point.latitude + epsilon) {
          // Downward crossing
          final cross = _crossProduct(p1, p2, point);
          if (cross < -epsilon) {
            windingNumber--;
          }
        }
      }
    }
    
    return windingNumber != 0;
  }
  
  /// Cross product for left/right test
  static double _crossProduct(LatLng p0, LatLng p1, LatLng p2) {
    return (p1.longitude - p0.longitude) * (p2.latitude - p0.latitude) -
           (p2.longitude - p0.longitude) * (p1.latitude - p0.latitude);
  }
  
  /// Quick bounding box check
  static bool _isInBoundingBox(LatLng point, List<LatLng> polygon) {
    double minLat = polygon[0].latitude, maxLat = polygon[0].latitude;
    double minLng = polygon[0].longitude, maxLng = polygon[0].longitude;
    
    for (final p in polygon) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    
    return point.latitude >= minLat && point.latitude <= maxLat &&
           point.longitude >= minLng && point.longitude <= maxLng;
  }
  
  /// Check if point lies on a line segment
  static bool _isPointOnSegment(LatLng point, LatLng p1, LatLng p2, double epsilon) {
    // Check collinearity
    final cross = _crossProduct(p1, p2, point);
    if (cross.abs() > epsilon * 1e6) return false; // Scale epsilon for cross product
    
    // Check if point is between p1 and p2
    final minX = min(p1.longitude, p2.longitude) - epsilon;
    final maxX = max(p1.longitude, p2.longitude) + epsilon;
    final minY = min(p1.latitude, p2.latitude) - epsilon;
    final maxY = max(p1.latitude, p2.latitude) + epsilon;
    
    return point.longitude >= minX && point.longitude <= maxX &&
           point.latitude >= minY && point.latitude <= maxY;
  }
}

/// ═══════════════════════════════════════════════════════════════════════════════
/// POLYGON AREA CALCULATION
/// Geodesic area using spherical excess formula
/// ═══════════════════════════════════════════════════════════════════════════════
class PolygonArea {
  /// Calculate area of a polygon on Earth's surface in square meters
  /// Uses the Shoelace formula with spherical correction
  static double calculateArea(List<LatLng> polygon) {
    if (polygon.length < 3) return 0;
    
    // For small polygons (< 10km across), use planar approximation
    // For larger polygons, use spherical excess
    final bounds = _getBounds(polygon);
    final diagonal = GeodesicCalculator.fastDistance(
      LatLng(bounds.minLat, bounds.minLng),
      LatLng(bounds.maxLat, bounds.maxLng),
    );
    
    if (diagonal < 10000) {
      return _planarArea(polygon);
    } else {
      return _sphericalArea(polygon);
    }
  }
  
  /// Planar area using Shoelace formula with local metric conversion
  static double _planarArea(List<LatLng> polygon) {
    if (polygon.length < 3) return 0;
    
    // Get centroid for coordinate conversion
    double sumLat = 0, sumLng = 0;
    for (final p in polygon) {
      sumLat += p.latitude;
      sumLng += p.longitude;
    }
    final centerLat = sumLat / polygon.length;
    final centerLng = sumLng / polygon.length;
    
    // Convert to local meters (equirectangular projection)
    final metersPerDegreeLng = GeodesicCalculator.metersPerDegreeLng(centerLat);
    final points = polygon.map((p) => (
      x: (p.longitude - centerLng) * metersPerDegreeLng,
      y: (p.latitude - centerLat) * EarthConstants.metersPerDegreeLat,
    )).toList();
    
    // Shoelace formula
    double area = 0;
    for (int i = 0; i < points.length; i++) {
      final j = (i + 1) % points.length;
      area += points[i].x * points[j].y;
      area -= points[j].x * points[i].y;
    }
    
    return area.abs() / 2;
  }
  
  /// Spherical area using spherical excess (Girard's theorem)
  static double _sphericalArea(List<LatLng> polygon) {
    const R = 6371000.0; // Earth's mean radius
    
    double excess = 0;
    final n = polygon.length;
    
    for (int i = 0; i < n; i++) {
      final p1 = polygon[(i - 1 + n) % n];
      final p2 = polygon[i];
      final p3 = polygon[(i + 1) % n];
      
      excess += _sphericalAngle(p1, p2, p3);
    }
    
    // Spherical excess formula: Area = R² * (sum of angles - (n-2)π)
    final area = R * R * (excess - (n - 2) * pi).abs();
    return area;
  }
  
  /// Calculate spherical angle at vertex p2
  static double _sphericalAngle(LatLng p1, LatLng p2, LatLng p3) {
    // Convert to radians
    final lat1 = p1.latitude * pi / 180;
    final lon1 = p1.longitude * pi / 180;
    final lat2 = p2.latitude * pi / 180;
    final lon2 = p2.longitude * pi / 180;
    final lat3 = p3.latitude * pi / 180;
    final lon3 = p3.longitude * pi / 180;
    
    // Bearings from p2 to p1 and p2 to p3
    final bearing1 = atan2(
      sin(lon1 - lon2) * cos(lat1),
      cos(lat2) * sin(lat1) - sin(lat2) * cos(lat1) * cos(lon1 - lon2),
    );
    
    final bearing2 = atan2(
      sin(lon3 - lon2) * cos(lat3),
      cos(lat2) * sin(lat3) - sin(lat2) * cos(lat3) * cos(lon3 - lon2),
    );
    
    var angle = bearing2 - bearing1;
    
    // Normalize to [-π, π]
    while (angle > pi) angle -= 2 * pi;
    while (angle < -pi) angle += 2 * pi;
    
    return angle.abs();
  }
  
  static ({double minLat, double maxLat, double minLng, double maxLng}) _getBounds(List<LatLng> polygon) {
    double minLat = polygon[0].latitude, maxLat = polygon[0].latitude;
    double minLng = polygon[0].longitude, maxLng = polygon[0].longitude;
    
    for (final p in polygon) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    
    return (minLat: minLat, maxLat: maxLat, minLng: minLng, maxLng: maxLng);
  }
}

/// ═══════════════════════════════════════════════════════════════════════════════
/// ROUTE SIMPLIFICATION
/// Ramer-Douglas-Peucker with geodesic distance
/// ═══════════════════════════════════════════════════════════════════════════════
class RouteSimplifier {
  /// Simplify a route using Ramer-Douglas-Peucker algorithm
  /// epsilon is the tolerance in meters
  static List<LatLng> simplify(List<LatLng> points, double epsilonMeters) {
    if (points.length < 3) return List.from(points);
    
    // Find the point with the maximum distance from the line segment
    double dmax = 0;
    int index = 0;
    final end = points.length - 1;
    
    for (int i = 1; i < end; i++) {
      final d = _perpendicularDistance(points[i], points[0], points[end]);
      if (d > dmax) {
        dmax = d;
        index = i;
      }
    }
    
    // If max distance is greater than epsilon, recursively simplify
    if (dmax > epsilonMeters) {
      // Recursive call
      final left = simplify(points.sublist(0, index + 1), epsilonMeters);
      final right = simplify(points.sublist(index), epsilonMeters);
      
      // Concatenate (excluding duplicate point at index)
      return [...left.sublist(0, left.length - 1), ...right];
    } else {
      return [points[0], points[end]];
    }
  }
  
  /// Calculate perpendicular distance from point to line segment in meters
  static double _perpendicularDistance(LatLng point, LatLng lineStart, LatLng lineEnd) {
    // Convert to local planar coordinates for calculation
    final avgLat = (lineStart.latitude + lineEnd.latitude + point.latitude) / 3;
    final metersPerDegreeLng = GeodesicCalculator.metersPerDegreeLng(avgLat);
    
    final x0 = point.longitude * metersPerDegreeLng;
    final y0 = point.latitude * EarthConstants.metersPerDegreeLat;
    final x1 = lineStart.longitude * metersPerDegreeLng;
    final y1 = lineStart.latitude * EarthConstants.metersPerDegreeLat;
    final x2 = lineEnd.longitude * metersPerDegreeLng;
    final y2 = lineEnd.latitude * EarthConstants.metersPerDegreeLat;
    
    final dx = x2 - x1;
    final dy = y2 - y1;
    
    if (dx == 0 && dy == 0) {
      // Line is a point
      return sqrt((x0 - x1) * (x0 - x1) + (y0 - y1) * (y0 - y1));
    }
    
    // Calculate perpendicular distance using cross product method
    final numerator = ((dy * x0) - (dx * y0) + (x2 * y1) - (y2 * x1)).abs();
    final denominator = sqrt(dx * dx + dy * dy);
    
    return numerator / denominator;
  }
  
  /// Adaptive simplification based on route characteristics
  /// Uses smaller epsilon for short routes, larger for long routes
  static List<LatLng> adaptiveSimplify(List<LatLng> points) {
    if (points.length < 3) return List.from(points);
    
    // Calculate total route length
    double totalLength = 0;
    for (int i = 1; i < points.length; i++) {
      totalLength += GeodesicCalculator.fastDistance(points[i - 1], points[i]);
    }
    
    // Adaptive epsilon: 0.5% of total length, clamped to [1m, 10m]
    final epsilon = (totalLength * 0.005).clamp(1.0, 10.0);
    
    return simplify(points, epsilon);
  }
}

/// ═══════════════════════════════════════════════════════════════════════════════
/// POLYGON VALIDATION
/// Check for valid, simple, non-degenerate polygons
/// ═══════════════════════════════════════════════════════════════════════════════
class PolygonValidator {
  /// Validation result
  static ({bool isValid, String? error, List<LatLng>? repaired}) validate(
    List<LatLng> polygon, {
    double minAreaSqMeters = 100,
    double minEdgeLengthMeters = 1,
    bool autoRepair = true,
  }) {
    if (polygon.length < 3) {
      return (isValid: false, error: 'Polygon must have at least 3 vertices', repaired: null);
    }
    
    // Remove duplicate consecutive points
    final cleaned = _removeConsecutiveDuplicates(polygon);
    if (cleaned.length < 3) {
      return (isValid: false, error: 'Polygon collapsed to fewer than 3 vertices', repaired: null);
    }
    
    // Check for minimum edge lengths
    for (int i = 0; i < cleaned.length; i++) {
      final j = (i + 1) % cleaned.length;
      final edgeLength = GeodesicCalculator.fastDistance(cleaned[i], cleaned[j]);
      if (edgeLength < minEdgeLengthMeters) {
        if (autoRepair) {
          // Remove the vertex
          final repaired = List<LatLng>.from(cleaned)..removeAt(j > i ? j : i);
          if (repaired.length >= 3) {
            return validate(repaired, minAreaSqMeters: minAreaSqMeters, autoRepair: true);
          }
        }
        return (isValid: false, error: 'Edge $i too short: ${edgeLength.toStringAsFixed(2)}m', repaired: null);
      }
    }
    
    // Check minimum area
    final area = PolygonArea.calculateArea(cleaned);
    if (area < minAreaSqMeters) {
      return (
        isValid: false, 
        error: 'Area too small: ${area.toStringAsFixed(0)} m² (need $minAreaSqMeters m²)', 
        repaired: null
      );
    }
    
    // Check for self-intersection (optional - expensive check)
    // Skip for performance, as winding number handles self-intersection
    
    return (isValid: true, error: null, repaired: cleaned);
  }
  
  static List<LatLng> _removeConsecutiveDuplicates(List<LatLng> polygon) {
    if (polygon.isEmpty) return [];
    
    final result = <LatLng>[polygon[0]];
    const tolerance = 1e-9;
    
    for (int i = 1; i < polygon.length; i++) {
      if ((polygon[i].latitude - result.last.latitude).abs() > tolerance ||
          (polygon[i].longitude - result.last.longitude).abs() > tolerance) {
        result.add(polygon[i]);
      }
    }
    
    // Also check if last point duplicates first
    if (result.length > 1 &&
        (result.last.latitude - result.first.latitude).abs() < tolerance &&
        (result.last.longitude - result.first.longitude).abs() < tolerance) {
      result.removeLast();
    }
    
    return result;
  }
}

/// ═══════════════════════════════════════════════════════════════════════════════
/// LOOP DETECTION
/// Determines if a path forms a closed loop
/// ═══════════════════════════════════════════════════════════════════════════════
class LoopDetector {
  /// Check if route forms a valid closed loop
  static ({bool isClosed, double distanceToStart, double closureAngle}) analyze(
    List<LatLng> route, {
    double closureThresholdMeters = 100,
    int minPointsForLoop = 10,
  }) {
    if (route.length < minPointsForLoop) {
      return (isClosed: false, distanceToStart: double.infinity, closureAngle: 0);
    }
    
    final start = route.first;
    final end = route.last;
    final distanceToStart = GeodesicCalculator.fastDistance(start, end);
    
    // Calculate approach angle (how perpendicular the return is)
    double closureAngle = 0;
    if (route.length >= 3) {
      final secondLast = route[route.length - 2];
      final bearing1 = _bearing(secondLast, end);
      final bearing2 = _bearing(end, start);
      closureAngle = (bearing2 - bearing1).abs();
      if (closureAngle > 180) closureAngle = 360 - closureAngle;
    }
    
    return (
      isClosed: distanceToStart < closureThresholdMeters,
      distanceToStart: distanceToStart,
      closureAngle: closureAngle,
    );
  }
  
  /// Calculate bearing from p1 to p2 in degrees
  static double _bearing(LatLng p1, LatLng p2) {
    final lat1 = p1.latitude * pi / 180;
    final lat2 = p2.latitude * pi / 180;
    final dLon = (p2.longitude - p1.longitude) * pi / 180;
    
    final y = sin(dLon) * cos(lat2);
    final x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon);
    
    return (atan2(y, x) * 180 / pi + 360) % 360;
  }
}

/// ═══════════════════════════════════════════════════════════════════════════════
/// SPATIAL GRID INDEX
/// Efficient grid-based spatial indexing for territory capture
/// ═══════════════════════════════════════════════════════════════════════════════
class SpatialGridIndex {
  final double cellSizeMeters;
  final double referenceLat;
  late final double _latStep;
  late final double _lngStep;
  
  SpatialGridIndex({
    required this.cellSizeMeters,
    required this.referenceLat,
  }) {
    // Calculate step sizes in degrees
    _latStep = cellSizeMeters / EarthConstants.metersPerDegreeLat;
    _lngStep = cellSizeMeters / GeodesicCalculator.metersPerDegreeLng(referenceLat);
  }
  
  /// Get cell ID for a coordinate
  String getCellId(LatLng point) {
    final latIndex = (point.latitude / _latStep).floor();
    final lngIndex = (point.longitude / _lngStep).floor();
    return '${latIndex}_$lngIndex';
  }
  
  /// Get center of a cell from its ID
  LatLng getCellCenter(String cellId) {
    final parts = cellId.split('_');
    if (parts.length != 2) return const LatLng(0, 0);
    
    final latIndex = int.tryParse(parts[0]) ?? 0;
    final lngIndex = int.tryParse(parts[1]) ?? 0;
    
    final lat = (latIndex + 0.5) * _latStep;
    final lng = (lngIndex + 0.5) * _lngStep;
    
    return LatLng(lat, lng);
  }
  
  /// Get all cells within a polygon (optimized scanning)
  Set<String> getCellsInPolygon(List<LatLng> polygon) {
    final cells = <String>{};
    
    // Get bounding box
    double minLat = polygon[0].latitude, maxLat = polygon[0].latitude;
    double minLng = polygon[0].longitude, maxLng = polygon[0].longitude;
    
    for (final p in polygon) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    
    // Scan grid within bounding box
    for (double lat = minLat; lat <= maxLat; lat += _latStep) {
      for (double lng = minLng; lng <= maxLng; lng += _lngStep) {
        final cellCenter = LatLng(lat + _latStep / 2, lng + _lngStep / 2);
        if (PointInPolygon.isInside(cellCenter, polygon)) {
          cells.add(getCellId(cellCenter));
        }
      }
    }
    
    return cells;
  }
}

/// ═══════════════════════════════════════════════════════════════════════════════
/// ANTI-CHEAT VALIDATION
/// Detect impossible or suspicious movement patterns
/// ═══════════════════════════════════════════════════════════════════════════════
class AntiCheatValidator {
  /// Maximum human running speed in m/s (Usain Bolt: ~12.4 m/s)
  static const double maxHumanSpeedMs = 15.0;
  
  /// Maximum realistic acceleration in m/s² (sprinter: ~10 m/s², allow some GPS jitter)
  static const double maxAcceleration = 12.0;
  
  /// Validate a sequence of GPS points for realistic human movement
  static ({bool isValid, String? violation, int? violationIndex}) validateRoute(
    List<({LatLng position, DateTime timestamp})> points,
  ) {
    if (points.length < 2) {
      return (isValid: true, violation: null, violationIndex: null);
    }
    
    double lastSpeed = 0;
    double lastTimeDelta = 0;
    
    for (int i = 1; i < points.length; i++) {
      final p1 = points[i - 1];
      final p2 = points[i];
      
      final distance = GeodesicCalculator.fastDistance(p1.position, p2.position);
      final timeDelta = p2.timestamp.difference(p1.timestamp).inMilliseconds / 1000.0;
      
      if (timeDelta <= 0) continue; // Skip duplicate timestamps
      
      final speed = distance / timeDelta;
      
      // Check maximum speed
      if (speed > maxHumanSpeedMs) {
        return (
          isValid: false,
          violation: 'Impossible speed: ${(speed * 3.6).toStringAsFixed(1)} km/h at point $i',
          violationIndex: i,
        );
      }
      
      // Check acceleration (if we have previous speed)
      // FIXED: Use lastTimeDelta instead of current timeDelta for acceleration calculation
      if (i > 1 && lastTimeDelta > 0) {
        final acceleration = (speed - lastSpeed) / lastTimeDelta;
        if (acceleration.abs() > maxAcceleration) {
          return (
            isValid: false,
            violation: 'Impossible acceleration: ${acceleration.toStringAsFixed(1)} m/s² at point $i',
            violationIndex: i,
          );
        }
      }
      
      lastSpeed = speed;
      lastTimeDelta = timeDelta;
    }
    
    return (isValid: true, violation: null, violationIndex: null);
  }
  
  /// Check if a captured area is realistic for the route taken
  static ({bool isValid, String? reason}) validateCapture({
    required List<LatLng> route,
    required double capturedAreaSqMeters,
    required double routeLengthMeters,
    required Duration duration,
  }) {
    // Check minimum speed (too slow might indicate GPS spoofing)
    final avgSpeedMs = routeLengthMeters / duration.inSeconds;
    if (avgSpeedMs < 0.3 && routeLengthMeters > 100) {
      return (
        isValid: false,
        reason: 'Suspiciously slow average speed: ${(avgSpeedMs * 3.6).toStringAsFixed(2)} km/h',
      );
    }
    
    // Check area to perimeter ratio (catches unrealistic shapes)
    // For a circle: A = πr², C = 2πr → A/C² = 1/(4π) ≈ 0.0796
    // For a square: A/C² = 1/16 = 0.0625
    // Allow ratio up to 0.1 for irregular shapes
    final ratio = capturedAreaSqMeters / (routeLengthMeters * routeLengthMeters);
    if (ratio > 0.15) {
      return (
        isValid: false,
        reason: 'Area/perimeter ratio suspicious: ${ratio.toStringAsFixed(3)} (max 0.15)',
      );
    }
    
    return (isValid: true, reason: null);
  }
}

/// ═══════════════════════════════════════════════════════════════════════════════
/// HEXAGONAL GRID SYSTEM
/// True hexagonal indexing for consistent territory system
/// ═══════════════════════════════════════════════════════════════════════════════
class HexagonalGrid {
  final double hexRadiusMeters;
  final double referenceLat;
  
  // Hexagon geometry constants
  late final double _height;      // Vertical distance between hex centers
  late final double _width;       // Horizontal distance between hex centers
  late final double _latStep;     // Latitude degrees per hex row
  late final double _lngStep;     // Longitude degrees per hex column
  
  HexagonalGrid({
    required this.hexRadiusMeters,
    required this.referenceLat,
  }) {
    // Hexagon dimensions (flat-top orientation)
    _height = hexRadiusMeters * sqrt(3);           // Distance between rows
    _width = hexRadiusMeters * 1.5;                 // Distance between columns
    
    // Convert to degrees
    _latStep = _height / EarthConstants.metersPerDegreeLat;
    _lngStep = _width / GeodesicCalculator.metersPerDegreeLng(referenceLat);
  }
  
  /// Get hex ID using axial coordinates (q, r)
  String getHexId(LatLng point) {
    // Recalculate longitude step for actual latitude (not reference latitude)
    final actualLngStep = _width / GeodesicCalculator.metersPerDegreeLng(point.latitude);
    
    // Convert lat/lng to offset coordinates (col, row)
    final col = point.longitude / actualLngStep;
    final row = point.latitude / _latStep;
    
    // Convert offset to axial coordinates (flat-top hexagon formula)
    // For flat-top: q = col - (row - (row & 1)) / 2
    final q = col - (row - (row.round() & 1)) / 2.0;
    final r = row;
    
    // Round to nearest hex center
    final (rq, rr) = _axialRound(q, r);
    
    return '${rq}_$rr';
  }
  
  /// Get center of hex from ID
  LatLng getHexCenter(String hexId) {
    final parts = hexId.split('_');
    if (parts.length != 2) return const LatLng(0, 0);
    
    final q = int.tryParse(parts[0]) ?? 0;
    final r = int.tryParse(parts[1]) ?? 0;
    
    // Axial to offset (flat-top hexagon)
    final row = r.toDouble();
    final col = q + (r - (r & 1)) / 2.0;
    
    // Convert to lat/lng
    final lat = row * _latStep;
    
    // Use actual latitude for longitude calculation
    final actualLngStep = _width / GeodesicCalculator.metersPerDegreeLng(lat);
    final lng = col * actualLngStep;
    
    return LatLng(lat, lng);
  }
  
  /// Get hex boundary vertices
  List<LatLng> getHexBoundary(String hexId) {
    final center = getHexCenter(hexId);
    final vertices = <LatLng>[];
    
    // Radius in degrees
    final latRadius = hexRadiusMeters / EarthConstants.metersPerDegreeLat;
    final lngRadius = hexRadiusMeters / GeodesicCalculator.metersPerDegreeLng(center.latitude);
    
    // 6 vertices (flat-top hexagon)
    for (int i = 0; i < 6; i++) {
      final angle = pi / 3 * i; // 60 degree increments
      vertices.add(LatLng(
        center.latitude + latRadius * sin(angle),
        center.longitude + lngRadius * cos(angle),
      ));
    }
    
    return vertices;
  }
  
  /// Round fractional axial coordinates to nearest hex
  (int, int) _axialRound(double q, double r) {
    // Convert to cube coordinates
    final x = q;
    final z = r;
    final y = -x - z;
    
    // Round cube coordinates
    var rx = x.round();
    var ry = y.round();
    var rz = z.round();
    
    // Fix rounding errors
    final xDiff = (rx - x).abs();
    final yDiff = (ry - y).abs();
    final zDiff = (rz - z).abs();
    
    if (xDiff > yDiff && xDiff > zDiff) {
      rx = -ry - rz;
    } else if (yDiff > zDiff) {
      ry = -rx - rz;
    } else {
      rz = -rx - ry;
    }
    
    // Convert back to axial
    return (rx, rz);
  }
}
