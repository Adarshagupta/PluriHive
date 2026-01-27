import '../repositories/location_repository.dart';

class StartTracking {
  final LocationRepository repository;
  
  StartTracking(this.repository);
  
  Future<void> call({bool batterySaver = false}) {
    return repository.startTracking(batterySaver: batterySaver);
  }
}
