import 'dart:math';
import '../../../../core/algorithms/geospatial_algorithms.dart';
import '../../../../core/models/geo_types.dart';
import '../../domain/entities/territory.dart';

/// ============================================================================
/// INDUSTRY-GRADE TERRITORY GRID HELPER
/// ============================================================================
/// Uses proper hexagonal grid mathematics for consistent territory indexing.
class TerritoryGridHelper {
  // Hex radius in meters - creates ~50m diameter hexes
  static const double hexRadiusMeters = 25.0;
  
  // Default reference latitude (used for consistent grid calculations)
  static const double _defaultReferenceLat = 45.0;
  
  // Lazy-initialized hexagonal grid
  static final HexagonalGrid _hexGrid = HexagonalGrid(
    hexRadiusMeters: hexRadiusMeters,
    referenceLat: _defaultReferenceLat,
  );
  
  /// Get hex ID for a given lat/lng coordinate using true axial coordinates.
  static String getHexId(double lat, double lng) {
    return _hexGrid.getHexId(LatLng(lat, lng));
  }
  
  /// Get the center coordinates of a hex from its ID.
  static (double lat, double lng) getHexCenter(String hexId) {
    final center = _hexGrid.getHexCenter(hexId);
    return (center.latitude, center.longitude);
  }
  
  /// Create a territory at the given location.
  static Territory createTerritory(double lat, double lng, {String? ownerId, String? ownerName}) {
    final hexId = getHexId(lat, lng);
    
    // Use hex center instead of input coordinates for consistency
    final (centerLat, centerLng) = getHexCenter(hexId);
    final boundary = _createHexBoundary(centerLat, centerLng);
    
    return Territory(
      hexId: hexId,
      centerLat: centerLat,
      centerLng: centerLng,
      boundary: boundary,
      capturedAt: DateTime.now(),
      points: 50,
      ownerId: ownerId,
      ownerName: ownerName,
      captureCount: 1,
    );
  }
  
  /// Create hexagonal boundary vertices around center point.
  static List<List<double>> _createHexBoundary(double centerLat, double centerLng) {
    final List<List<double>> boundary = [];
    
    // Use industry-grade constants
    const metersPerDegreeLat = EarthConstants.metersPerDegreeLat;
    final metersPerDegreeLng = GeodesicCalculator.metersPerDegreeLng(centerLat);
    
    final radiusLat = hexRadiusMeters / metersPerDegreeLat;
    final radiusLng = hexRadiusMeters / metersPerDegreeLng;
    
    // Create proper flat-top hexagon (starts at 0°)
    for (int i = 0; i < 6; i++) {
      final angle = pi / 3 * i;
      final lat = centerLat + radiusLat * sin(angle);
      final lng = centerLng + radiusLng * cos(angle);
      boundary.add([lat, lng]);
    }
    
    return boundary;
  }
  
  /// Get all hexes within a given radius from center.
  static List<Territory> getVisibleTerritories(
    double centerLat,
    double centerLng,
    double radiusKm,
  ) {
    final List<Territory> territories = [];
    final radiusMeters = radiusKm * 1000;
    final int gridCount = (radiusMeters / (hexRadiusMeters * 2)).ceil();
    
    for (int i = -gridCount; i <= gridCount; i++) {
      for (int j = -gridCount; j <= gridCount; j++) {
        final latOffset = i * hexRadiusMeters * sqrt(3) / EarthConstants.metersPerDegreeLat;
        final lngOffset = j * hexRadiusMeters * 1.5 / GeodesicCalculator.metersPerDegreeLng(centerLat);
        
        final lat = centerLat + latOffset;
        final lng = centerLng + lngOffset;
        
        final distance = GeodesicCalculator.fastDistance(
          LatLng(centerLat, centerLng),
          LatLng(lat, lng),
        );
        
        if (distance <= radiusMeters) {
          territories.add(createTerritory(lat, lng));
        }
      }
    }
    
    return territories;
  }
  
  /// Check if a point is inside a specific territory.
  static bool isPointInTerritory(LatLng point, Territory territory) {
    final polygon = territory.boundary
        .map((b) => LatLng(b[0], b[1]))
        .toList();
    return PointInPolygon.isInside(point, polygon);
  }
  
  /// Calculate distance between two points using Vincenty formula.
  static double calculateDistance(double lat1, double lng1, double lat2, double lng2) {
    return GeodesicCalculator.vincentyDistance(
      LatLng(lat1, lng1),
      LatLng(lat2, lng2),
    );
  }
  
  /// Calculate area of a territory in square meters.
  static double calculateTerritoryArea(Territory territory) {
    final polygon = territory.boundary
        .map((b) => LatLng(b[0], b[1]))
        .toList();
    return PolygonArea.calculateArea(polygon);
  }
}
