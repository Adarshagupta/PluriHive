import '../entities/position.dart';

abstract class LocationRepository {
  Stream<Position> getLocationStream();
  Future<Position> getCurrentPosition();
  Future<void> startTracking();
  Future<void> stopTracking();
  Future<bool> isLocationServiceEnabled();
  Future<bool> checkPermissions();
  Future<double> calculateDistance(Position start, Position end);
}
