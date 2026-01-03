import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';

// Events
abstract class AuthEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class CheckAuthStatus extends AuthEvent {}

class SignUpUser extends AuthEvent {
  final String name;
  final String email;
  
  SignUpUser({required this.name, required this.email});
  
  @override
  List<Object?> get props => [name, email];
}

class UpdateUserProfile extends AuthEvent {
  final double weightKg;
  final double heightCm;
  final int age;
  final String gender;
  
  UpdateUserProfile({
    required this.weightKg,
    required this.heightCm,
    required this.age,
    required this.gender,
  });
  
  @override
  List<Object?> get props => [weightKg, heightCm, age, gender];
}

class CompleteOnboarding extends AuthEvent {}

class SignOut extends AuthEvent {}

// States
abstract class AuthState extends Equatable {
  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class Unauthenticated extends AuthState {
  final bool isFirstTime;
  
  Unauthenticated({this.isFirstTime = true});
  
  @override
  List<Object?> get props => [isFirstTime];
}

class Authenticated extends AuthState {
  final User user;
  
  Authenticated(this.user);
  
  @override
  List<Object?> get props => [user];
}

class AuthError extends AuthState {
  final String message;
  
  AuthError(this.message);
  
  @override
  List<Object?> get props => [message];
}

// BLoC
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository repository;
  
  AuthBloc({required this.repository}) : super(AuthInitial()) {
    on<CheckAuthStatus>(_onCheckAuthStatus);
    on<SignUpUser>(_onSignUpUser);
    on<UpdateUserProfile>(_onUpdateUserProfile);
    on<CompleteOnboarding>(_onCompleteOnboarding);
    on<SignOut>(_onSignOut);
  }
  
  Future<void> _onCheckAuthStatus(
    CheckAuthStatus event,
    Emitter<AuthState> emit,
  ) async {
    try {
      emit(AuthLoading());
      
      final user = await repository.getCurrentUser();
      final isFirstTime = await repository.isFirstTime();
      
      if (user == null) {
        emit(Unauthenticated(isFirstTime: isFirstTime));
      } else {
        emit(Authenticated(user));
      }
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }
  
  Future<void> _onSignUpUser(
    SignUpUser event,
    Emitter<AuthState> emit,
  ) async {
    try {
      emit(AuthLoading());
      
      final user = User(
        id: const Uuid().v4(),
        name: event.name,
        email: event.email,
        hasCompletedOnboarding: false,
      );
      
      await repository.saveUser(user);
      emit(Authenticated(user));
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }
  
  Future<void> _onUpdateUserProfile(
    UpdateUserProfile event,
    Emitter<AuthState> emit,
  ) async {
    try {
      if (state is Authenticated) {
        final currentUser = (state as Authenticated).user;
        final updatedUser = currentUser.copyWith(
          weightKg: event.weightKg,
          heightCm: event.heightCm,
          age: event.age,
          gender: event.gender,
        );
        
        await repository.saveUser(updatedUser);
        emit(Authenticated(updatedUser));
      }
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }
  
  Future<void> _onCompleteOnboarding(
    CompleteOnboarding event,
    Emitter<AuthState> emit,
  ) async {
    try {
      if (state is Authenticated) {
        final currentUser = (state as Authenticated).user;
        final updatedUser = currentUser.copyWith(hasCompletedOnboarding: true);
        
        await repository.saveUser(updatedUser);
        await repository.markOnboardingComplete();
        emit(Authenticated(updatedUser));
      }
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }
  
  Future<void> _onSignOut(
    SignOut event,
    Emitter<AuthState> emit,
  ) async {
    try {
      await repository.clearUser();
      emit(Unauthenticated(isFirstTime: false));
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }
}
