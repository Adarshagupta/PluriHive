import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../domain/entities/territory.dart';
import '../../domain/usecases/capture_territory.dart';
import '../../domain/usecases/get_captured_territories.dart';

// Events
abstract class TerritoryEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class LoadTerritories extends TerritoryEvent {}

class CaptureTerritoryEvent extends TerritoryEvent {
  final Territory territory;
  
  CaptureTerritoryEvent(this.territory);
  
  @override
  List<Object?> get props => [territory];
}

// States
abstract class TerritoryState extends Equatable {
  @override
  List<Object?> get props => [];
}

class TerritoryInitial extends TerritoryState {}

class TerritoryLoading extends TerritoryState {}

class TerritoryLoaded extends TerritoryState {
  final List<Territory> territories;
  
  TerritoryLoaded(this.territories);
  
  @override
  List<Object?> get props => [territories];
}

class TerritoryError extends TerritoryState {
  final String message;
  
  TerritoryError(this.message);
  
  @override
  List<Object?> get props => [message];
}

// BLoC
class TerritoryBloc extends Bloc<TerritoryEvent, TerritoryState> {
  final CaptureTerritory captureTerritory;
  final GetCapturedTerritories getCapturedTerritories;
  
  TerritoryBloc({
    required this.captureTerritory,
    required this.getCapturedTerritories,
  }) : super(TerritoryInitial()) {
    on<LoadTerritories>(_onLoadTerritories);
    on<CaptureTerritoryEvent>(_onCaptureTerritory);
  }
  
  Future<void> _onLoadTerritories(
    LoadTerritories event,
    Emitter<TerritoryState> emit,
  ) async {
    try {
      emit(TerritoryLoading());
      final territories = await getCapturedTerritories();
      emit(TerritoryLoaded(territories));
    } catch (e) {
      emit(TerritoryError(e.toString()));
    }
  }
  
  Future<void> _onCaptureTerritory(
    CaptureTerritoryEvent event,
    Emitter<TerritoryState> emit,
  ) async {
    try {
      await captureTerritory(event.territory);
      
      // Reload territories
      final territories = await getCapturedTerritories();
      emit(TerritoryLoaded(territories));
    } catch (e) {
      emit(TerritoryError(e.toString()));
    }
  }
}
