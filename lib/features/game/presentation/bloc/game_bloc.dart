import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:equatable/equatable.dart';
import '../../domain/entities/user_stats.dart';
import '../../domain/usecases/calculate_points.dart';
import '../../domain/usecases/get_user_stats.dart';
import '../../domain/repositories/game_repository.dart';
import '../../../../core/services/auth_api_service.dart';
import '../../../../core/services/websocket_service.dart';
import '../../../../core/services/home_widget_service.dart';

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

  UserStats _statsOrDefault() {
    if (state is GameLoaded) {
      return (state as GameLoaded).stats;
    }
    return const UserStats(
      totalPoints: 0,
      level: 1,
      territoriesCaptured: 0,
      totalDistanceKm: 0,
      totalCaloriesBurned: 0,
      currentStreak: 0,
      longestStreak: 0,
      streakFreezes: 0,
    );
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
      await _updateHomeWidget(stats);
    } catch (e) {
      print('⚠️ Error loading game data from backend: $e');
      // Fallback to local data
      try {
        final stats = await getUserStats();
        print(
            '📥 GameBloc LoadGameData: Loaded from local - distance = ${stats.totalDistanceKm} km');
        emit(GameLoaded(stats));
        await _updateHomeWidget(stats);
      } catch (localError) {
        emit(GameError(localError.toString()));
      }
    }
  }

  Future<void> _updateHomeWidget(UserStats stats) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final steps = prefs.getInt('daily_steps') ??
          int.tryParse(prefs.getString('widget_steps') ?? '') ??
          0;
      final progressPercent =
          ((stats.totalDistanceKm / 5.0) * 100).round().clamp(0, 100);

      await HomeWidgetService.updateStats(
        distanceKm: stats.totalDistanceKm,
        steps: steps,
        progressPercent: progressPercent.toInt(),
      );
    } catch (_) {}
  }

  Future<void> _onAddPoints(
    AddPoints event,
    Emitter<GameState> emit,
  ) async {
    final current = _statsOrDefault();
    final updated = current.copyWith(
      totalPoints: current.totalPoints + event.points,
    );
    emit(GameLoaded(updated));
    await _updateHomeWidget(updated);
  }

  Future<void> _onUpdateDistance(
    UpdateDistance event,
    Emitter<GameState> emit,
  ) async {
    final current = _statsOrDefault();
    final updated = current.copyWith(
      totalDistanceKm: current.totalDistanceKm + event.distanceKm,
    );
    emit(GameLoaded(updated));
    await _updateHomeWidget(updated);
  }

  Future<void> _onAddCalories(
    AddCalories event,
    Emitter<GameState> emit,
  ) async {
    final current = _statsOrDefault();
    final updated = current.copyWith(
      totalCaloriesBurned: current.totalCaloriesBurned + event.calories,
    );
    emit(GameLoaded(updated));
    await _updateHomeWidget(updated);
  }

  Future<void> _onTerritoryCapture(
    TerritoryCapture event,
    Emitter<GameState> emit,
  ) async {
    final current = _statsOrDefault();
    final updated = current.copyWith(
      territoriesCaptured: current.territoriesCaptured + 1,
    );
    emit(GameLoaded(updated));
    await _updateHomeWidget(updated);
  }
}
