import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/data/datasources/auth_local_data_source.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';

import '../../features/tracking/data/repositories/location_repository_impl.dart';
import '../../features/tracking/data/datasources/location_data_source.dart';
import '../../features/tracking/domain/repositories/location_repository.dart';
import '../../features/tracking/domain/usecases/start_tracking.dart';
import '../../features/tracking/domain/usecases/stop_tracking.dart';
import '../../features/tracking/domain/usecases/get_current_location.dart';
import '../../features/tracking/presentation/bloc/location_bloc.dart';

import '../../features/territory/data/repositories/territory_repository_impl.dart';
import '../../features/territory/data/datasources/territory_local_data_source.dart';
import '../../features/territory/domain/repositories/territory_repository.dart';
import '../../features/territory/domain/usecases/capture_territory.dart';
import '../../features/territory/domain/usecases/get_captured_territories.dart';
import '../../features/territory/presentation/bloc/territory_bloc.dart';

import '../../features/game/data/repositories/game_repository_impl.dart';
import '../../features/game/data/datasources/game_local_data_source.dart';
import '../../features/game/domain/repositories/game_repository.dart';
import '../../features/game/domain/usecases/calculate_points.dart';
import '../../features/game/domain/usecases/get_user_stats.dart';
import '../../features/game/presentation/bloc/game_bloc.dart';

final getIt = GetIt.instance;

Future<void> initializeDependencies() async {
  // External
  final sharedPreferences = await SharedPreferences.getInstance();
  getIt.registerSingleton<SharedPreferences>(sharedPreferences);
  
  // Data Sources
  getIt.registerLazySingleton<AuthLocalDataSource>(
    () => AuthLocalDataSourceImpl(getIt()),
  );
  
  getIt.registerLazySingleton<LocationDataSource>(
    () => LocationDataSourceImpl(),
  );
  
  getIt.registerLazySingleton<TerritoryLocalDataSource>(
    () => TerritoryLocalDataSourceImpl(getIt()),
  );
  
  getIt.registerLazySingleton<GameLocalDataSource>(
    () => GameLocalDataSourceImpl(getIt()),
  );
  
  // Repositories
  getIt.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(getIt()),
  );
  
  getIt.registerLazySingleton<LocationRepository>(
    () => LocationRepositoryImpl(getIt()),
  );
  
  getIt.registerLazySingleton<TerritoryRepository>(
    () => TerritoryRepositoryImpl(getIt()),
  );
  
  getIt.registerLazySingleton<GameRepository>(
    () => GameRepositoryImpl(getIt()),
  );
  
  // Use Cases
  getIt.registerLazySingleton(() => StartTracking(getIt()));
  getIt.registerLazySingleton(() => StopTracking(getIt()));
  getIt.registerLazySingleton(() => GetCurrentLocation(getIt()));
  
  getIt.registerLazySingleton(() => CaptureTerritory(getIt()));
  getIt.registerLazySingleton(() => GetCapturedTerritories(getIt()));
  
  getIt.registerLazySingleton(() => CalculatePoints(getIt()));
  getIt.registerLazySingleton(() => GetUserStats(getIt()));
  
  // BLoCs
  getIt.registerFactory(() => AuthBloc(repository: getIt()));
  
  getIt.registerFactory(() => LocationBloc(
    startTracking: getIt(),
    stopTracking: getIt(),
    getCurrentLocation: getIt(),
    locationRepository: getIt<LocationRepository>(),
  ));
  
  getIt.registerFactory(() => TerritoryBloc(
    captureTerritory: getIt(),
    getCapturedTerritories: getIt(),
  ));
  
  getIt.registerFactory(() => GameBloc(
    calculatePoints: getIt(),
    getUserStats: getIt(),
    repository: getIt(),
  ));
}
