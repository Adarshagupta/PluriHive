import '../../domain/entities/position.dart';
import '../../domain/repositories/location_repository.dart';
import '../datasources/location_data_source.dart';

class LocationRepositoryImpl implements LocationRepository {
  final LocationDataSource dataSource;
  
  LocationRepositoryImpl(this.dataSource);
  
  @override
  Stream<Position> getLocationStream({bool batterySaver = false}) {
    return dataSource.getLocationStream(batterySaver: batterySaver);
  }
  
  @override
  Future<Position> getCurrentPosition() {
    return dataSource.getCurrentPosition();
  }
  
  @override
  Future<void> startTracking({bool batterySaver = false}) async {
    // Implementation for starting tracking service
    // This would be expanded with background service in production
  }
  
  @override
  Future<void> stopTracking() async {
    // Implementation for stopping tracking service
  }
  
  @override
  Future<bool> isLocationServiceEnabled() {
    return dataSource.isLocationServiceEnabled();
  }
  
  @override
  Future<bool> checkPermissions() {
    return dataSource.checkPermissions();
  }
  
  @override
  Future<double> calculateDistance(Position start, Position end) {
    return dataSource.calculateDistance(start, end);
  }
}
