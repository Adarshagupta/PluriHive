import 'dart:typed_data';
import 'dart:ui';

class LatLng {
  final double latitude;
  final double longitude;

  const LatLng(this.latitude, this.longitude);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LatLng &&
        other.latitude == latitude &&
        other.longitude == longitude;
  }

  @override
  int get hashCode => Object.hash(latitude, longitude);

  @override
  String toString() => 'LatLng($latitude, $longitude)';
}

class LatLngBounds {
  final LatLng southwest;
  final LatLng northeast;

  const LatLngBounds({required this.southwest, required this.northeast});
}

class MarkerId {
  final String value;
  const MarkerId(this.value);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is MarkerId && other.value == value;

  @override
  int get hashCode => value.hashCode;
}

class PolylineId {
  final String value;
  const PolylineId(this.value);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is PolylineId && other.value == value;

  @override
  int get hashCode => value.hashCode;
}

class PolygonId {
  final String value;
  const PolygonId(this.value);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is PolygonId && other.value == value;

  @override
  int get hashCode => value.hashCode;
}

class CircleId {
  final String value;
  const CircleId(this.value);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is CircleId && other.value == value;

  @override
  int get hashCode => value.hashCode;
}

enum MapType { normal, satellite, hybrid }

class BitmapDescriptor {
  final Uint8List? bytes;
  final double? hue;
  final bool isDefault;

  const BitmapDescriptor._({this.bytes, this.hue, required this.isDefault});

  static const double hueRed = 0.0;
  static const double hueOrange = 30.0;
  static const double hueYellow = 60.0;
  static const double hueGreen = 120.0;
  static const double hueAzure = 210.0;
  static const double hueBlue = 240.0;
  static const double hueViolet = 270.0;
  static const double hueMagenta = 300.0;
  static const double hueRose = 330.0;

  factory BitmapDescriptor.defaultMarkerWithHue(double hue) {
    return BitmapDescriptor._(hue: hue, isDefault: true);
  }

  factory BitmapDescriptor.fromBytes(Uint8List bytes) {
    return BitmapDescriptor._(bytes: bytes, isDefault: false);
  }
}

class Cap {
  final String value;
  const Cap._(this.value);

  static const Cap roundCap = Cap._('round');
  static const Cap buttCap = Cap._('butt');
  static const Cap squareCap = Cap._('square');
}

enum JointType { round, bevel, miter }

class PatternItem {
  final String type;
  final double length;

  const PatternItem._(this.type, this.length);

  static PatternItem dash(double length) => PatternItem._('dash', length);
  static PatternItem gap(double length) => PatternItem._('gap', length);
}

class Marker {
  final MarkerId markerId;
  final LatLng position;
  final BitmapDescriptor? icon;
  final Offset? anchor;
  final double zIndex;
  final VoidCallback? onTap;

  const Marker({
    required this.markerId,
    required this.position,
    this.icon,
    this.anchor,
    this.zIndex = 0.0,
    this.onTap,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Marker && other.markerId == markerId;

  @override
  int get hashCode => markerId.hashCode;
}

class Polyline {
  final PolylineId polylineId;
  final List<LatLng> points;
  final Color color;
  final int width;
  final bool geodesic;
  final Cap startCap;
  final Cap endCap;
  final JointType jointType;
  final List<PatternItem> patterns;
  final bool consumeTapEvents;
  final VoidCallback? onTap;

  const Polyline({
    required this.polylineId,
    required this.points,
    this.color = const Color(0xFF2196F3),
    this.width = 5,
    this.geodesic = false,
    this.startCap = Cap.buttCap,
    this.endCap = Cap.buttCap,
    this.jointType = JointType.miter,
    this.patterns = const [],
    this.consumeTapEvents = false,
    this.onTap,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Polyline && other.polylineId == polylineId;

  @override
  int get hashCode => polylineId.hashCode;
}

class Polygon {
  final PolygonId polygonId;
  final List<LatLng> points;
  final Color fillColor;
  final Color strokeColor;
  final int strokeWidth;
  final bool consumeTapEvents;
  final VoidCallback? onTap;

  const Polygon({
    required this.polygonId,
    required this.points,
    this.fillColor = const Color(0x00000000),
    this.strokeColor = const Color(0xFF000000),
    this.strokeWidth = 1,
    this.consumeTapEvents = false,
    this.onTap,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Polygon && other.polygonId == polygonId;

  @override
  int get hashCode => polygonId.hashCode;
}

class Circle {
  final CircleId circleId;
  final LatLng center;
  final double radius;
  final Color fillColor;
  final Color strokeColor;
  final int strokeWidth;

  const Circle({
    required this.circleId,
    required this.center,
    required this.radius,
    this.fillColor = const Color(0x00000000),
    this.strokeColor = const Color(0xFF000000),
    this.strokeWidth = 1,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Circle && other.circleId == circleId;

  @override
  int get hashCode => circleId.hashCode;
}
