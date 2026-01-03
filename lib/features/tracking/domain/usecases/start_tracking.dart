import '../repositories/location_repository.dart';

class StartTracking {
  final LocationRepository repository;
  
  StartTracking(this.repository);
  
  Future<void> call() {
    return repository.startTracking();
  }
}
