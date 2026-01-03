import '../entities/position.dart';
import '../repositories/location_repository.dart';

class GetCurrentLocation {
  final LocationRepository repository;
  
  GetCurrentLocation(this.repository);
  
  Future<Position> call() {
    return repository.getCurrentPosition();
  }
}
