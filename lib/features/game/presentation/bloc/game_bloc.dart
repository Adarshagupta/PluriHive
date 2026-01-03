import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../domain/entities/user_stats.dart';
import '../../domain/usecases/calculate_points.dart';
import '../../domain/usecases/get_user_stats.dart';
import '../../domain/repositories/game_repository.dart';
import '../../../tracking/data/datasources/activity_local_data_source.dart';

// Events
abstract class GameEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class LoadGameData extends GameEvent {}

class AddPoints extends GameEvent {
  final int points;
  
  AddPoints(this.points);
  
  @override
  List<Object?> get props => [points];
}

class UpdateDistance extends GameEvent {
  final double distanceKm;
  
  UpdateDistance(this.distanceKm);
  
  @override
  List<Object?> get props => [distanceKm];
}

class AddCalories extends GameEvent {
  final int calories;
  
  AddCalories(this.calories);
  
  @override
  List<Object?> get props => [calories];
}

class TerritoryCapture extends GameEvent {}

// States
abstract class GameState extends Equatable {
  @override
  List<Object?> get props => [];
}

class GameInitial extends GameState {}

class GameLoading extends GameState {}

class GameLoaded extends GameState {
  final UserStats stats;
  
  GameLoaded(this.stats);
  
  @override
  List<Object?> get props => [stats];
}

class GameError extends GameState {
  final String message;
  
  GameError(this.message);
  
  @override
  List<Object?> get props => [message];
}

// BLoC
class GameBloc extends Bloc<GameEvent, GameState> {
  final CalculatePoints calculatePoints;
  final GetUserStats getUserStats;
  final GameRepository repository;
  
  GameBloc({
    required this.calculatePoints,
    required this.getUserStats,
    required this.repository,
  }) : super(GameInitial()) {
    on<LoadGameData>(_onLoadGameData);
    on<AddPoints>(_onAddPoints);
    on<UpdateDistance>(_onUpdateDistance);
    on<AddCalories>(_onAddCalories);
    on<TerritoryCapture>(_onTerritoryCapture);
  }
  
  Future<void> _onLoadGameData(
    LoadGameData event,
    Emitter<GameState> emit,
  ) async {
    try {
      emit(GameLoading());
      final stats = await getUserStats();
      
      // If distance is 0, calculate from all saved activities
      if (stats.totalDistanceKm == 0.0) {
        try {
          final activityDataSource = ActivityLocalDataSourceImpl();
          final activities = await activityDataSource.getAllActivities();
          
          // Sum all distances from activities
          double totalDistance = 0.0;
          for (final activity in activities) {
            totalDistance += activity.distanceMeters / 1000; // Convert meters to km
          }
          
          if (totalDistance > 0) {
            final updatedStats = stats.copyWith(totalDistanceKm: totalDistance);
            await repository.updateStats(updatedStats);
            print('📥 GameBloc LoadGameData: Calculated distance from ${activities.length} activities = ${totalDistance.toStringAsFixed(3)} km');
            emit(GameLoaded(updatedStats));
            return;
          }
        } catch (e) {
          print('⚠️ Error calculating distance from activities: $e');
        }
      }
      
      print('📥 GameBloc LoadGameData: Loaded distance = ${stats.totalDistanceKm} km');
      emit(GameLoaded(stats));
    } catch (e) {
      emit(GameError(e.toString()));
    }
  }
  
  Future<void> _onAddPoints(
    AddPoints event,
    Emitter<GameState> emit,
  ) async {
    if (state is GameLoaded) {
      final currentStats = (state as GameLoaded).stats;
      final newPoints = currentStats.totalPoints + event.points;
      final newLevel = (newPoints / 1000).floor() + 1;
      
      final updatedStats = currentStats.copyWith(
        totalPoints: newPoints,
        level: newLevel,
      );
      
      await repository.updateStats(updatedStats);
      emit(GameLoaded(updatedStats));
    }
  }
  
  Future<void> _onUpdateDistance(
    UpdateDistance event,
    Emitter<GameState> emit,
  ) async {
    if (state is GameLoaded) {
      final currentStats = (state as GameLoaded).stats;
      final updatedStats = currentStats.copyWith(
        totalDistanceKm: currentStats.totalDistanceKm + event.distanceKm,
      );
      
      print('💾 GameBloc: Distance updated from ${currentStats.totalDistanceKm.toStringAsFixed(3)} to ${updatedStats.totalDistanceKm.toStringAsFixed(3)} km');
      await repository.updateStats(updatedStats);
      emit(GameLoaded(updatedStats));
    }
  }
  
  Future<void> _onAddCalories(
    AddCalories event,
    Emitter<GameState> emit,
  ) async {
    if (state is GameLoaded) {
      final currentStats = (state as GameLoaded).stats;
      final updatedStats = currentStats.copyWith(
        totalCaloriesBurned: currentStats.totalCaloriesBurned + event.calories,
      );
      
      await repository.updateStats(updatedStats);
      emit(GameLoaded(updatedStats));
    }
  }
  
  Future<void> _onTerritoryCapture(
    TerritoryCapture event,
    Emitter<GameState> emit,
  ) async {
    if (state is GameLoaded) {
      final currentStats = (state as GameLoaded).stats;
      final updatedStats = currentStats.copyWith(
        territoriesCaptured: currentStats.territoriesCaptured + 1,
      );
      
      await repository.updateStats(updatedStats);
      emit(GameLoaded(updatedStats));
    }
  }
}
