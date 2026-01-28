import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../domain/entities/user_stats.dart';
import '../../domain/usecases/calculate_points.dart';
import '../../domain/usecases/get_user_stats.dart';
import '../../domain/repositories/game_repository.dart';
import '../../../../core/services/auth_api_service.dart';
import '../../../../core/services/websocket_service.dart';

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
  final AuthApiService authApiService;
  final WebSocketService webSocketService;
  late final void Function(dynamic) _statsUpdateListener;

  GameBloc({
    required this.calculatePoints,
    required this.getUserStats,
    required this.repository,
    required this.authApiService,
    required this.webSocketService,
  }) : super(GameInitial()) {
    on<LoadGameData>(_onLoadGameData);
    on<AddPoints>(_onAddPoints);
    on<UpdateDistance>(_onUpdateDistance);
    on<AddCalories>(_onAddCalories);
    on<TerritoryCapture>(_onTerritoryCapture);

    _statsUpdateListener = (_) {
      add(LoadGameData());
    };
    webSocketService.onUserStatsUpdate(_statsUpdateListener);
  }

  @override
  Future<void> close() {
    webSocketService.offUserStatsUpdate(_statsUpdateListener);
    return super.close();
  }

  Future<void> _onLoadGameData(
    LoadGameData event,
    Emitter<GameState> emit,
  ) async {
    try {
      final hadData = state is GameLoaded;
      if (!hadData) {
        emit(GameLoading());
      }

      // Fetch user data from backend
      final userData = await authApiService.getCurrentUser();

      // Convert backend user data to UserStats with proper type handling
      final stats = UserStats(
        totalPoints: userData['totalPoints'] is int
            ? userData['totalPoints']
            : (userData['totalPoints'] as num?)?.toInt() ?? 0,
        level: userData['level'] is int
            ? userData['level']
            : (userData['level'] as num?)?.toInt() ?? 1,
        totalDistanceKm: userData['totalDistanceKm'] is String
            ? double.parse(userData['totalDistanceKm'])
            : (userData['totalDistanceKm'] as num?)?.toDouble() ?? 0.0,
        totalCaloriesBurned: 0, // Calculate from activities if needed
        territoriesCaptured: userData['totalTerritoriesCaptured'] is int
            ? userData['totalTerritoriesCaptured']
            : (userData['totalTerritoriesCaptured'] as num?)?.toInt() ?? 0,
        currentStreak: userData['currentStreak'] is int
            ? userData['currentStreak']
            : (userData['currentStreak'] as num?)?.toInt() ?? 0,
        longestStreak: userData['longestStreak'] is int
            ? userData['longestStreak']
            : (userData['longestStreak'] as num?)?.toInt() ?? 0,
        streakFreezes: userData['streakFreezes'] is int
            ? userData['streakFreezes']
            : (userData['streakFreezes'] as num?)?.toInt() ?? 0,
      );

      print(
          '📥 GameBloc LoadGameData: Loaded from backend - distance = ${stats.totalDistanceKm} km, points = ${stats.totalPoints}');
      emit(GameLoaded(stats));
    } catch (e) {
      print('⚠️ Error loading game data from backend: $e');
      // Fallback to local data
      try {
        final stats = await getUserStats();
        print(
            '📥 GameBloc LoadGameData: Loaded from local - distance = ${stats.totalDistanceKm} km');
        emit(GameLoaded(stats));
      } catch (localError) {
        emit(GameError(localError.toString()));
      }
    }
  }

  Future<void> _onAddPoints(
    AddPoints event,
    Emitter<GameState> emit,
  ) async {
    if (state is! GameLoaded) return;
    final current = state as GameLoaded;
    final updated = current.stats.copyWith(
      totalPoints: current.stats.totalPoints + event.points,
    );
    emit(GameLoaded(updated));
  }

  Future<void> _onUpdateDistance(
    UpdateDistance event,
    Emitter<GameState> emit,
  ) async {
    if (state is! GameLoaded) return;
    final current = state as GameLoaded;
    final updated = current.stats.copyWith(
      totalDistanceKm: current.stats.totalDistanceKm + event.distanceKm,
    );
    emit(GameLoaded(updated));
  }

  Future<void> _onAddCalories(
    AddCalories event,
    Emitter<GameState> emit,
  ) async {
    if (state is! GameLoaded) return;
    final current = state as GameLoaded;
    final updated = current.stats.copyWith(
      totalCaloriesBurned: current.stats.totalCaloriesBurned + event.calories,
    );
    emit(GameLoaded(updated));
  }

  Future<void> _onTerritoryCapture(
    TerritoryCapture event,
    Emitter<GameState> emit,
  ) async {
    if (state is! GameLoaded) return;
    final current = state as GameLoaded;
    final updated = current.stats.copyWith(
      territoriesCaptured: current.stats.territoriesCaptured + 1,
    );
    emit(GameLoaded(updated));
  }
}
