import '../entities/position.dart';

abstract class LocationRepository {
  Stream<Position> getLocationStream({bool batterySaver = false});
  Future<Position> getCurrentPosition();
  Future<void> startTracking({bool batterySaver = false});
  Future<void> stopTracking();
  Future<bool> isLocationServiceEnabled();
  Future<bool> checkPermissions();
  Future<double> calculateDistance(Position start, Position end);
}
