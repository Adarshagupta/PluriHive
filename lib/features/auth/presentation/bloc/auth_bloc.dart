import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../../../core/services/auth_api_service.dart';
import '../../../../core/services/websocket_service.dart';

// Events
abstract class AuthEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class CheckAuthStatus extends AuthEvent {}

class SignUpUser extends AuthEvent {
  final String name;
  final String email;
  final String password;
  
  SignUpUser({
    required this.name,
    required this.email,
    required this.password,
  });
  
  @override
  List<Object?> get props => [name, email, password];
}

class SignInUser extends AuthEvent {
  final String email;
  final String password;
  
  SignInUser({
    required this.email,
    required this.password,
  });
  
  @override
  List<Object?> get props => [email, password];
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
  final AuthApiService authApiService;
  final WebSocketService webSocketService;
  
  AuthBloc({
    required this.repository,
    required this.authApiService,
    required this.webSocketService,
  }) : super(AuthInitial()) {
    on<CheckAuthStatus>(_onCheckAuthStatus);
    on<SignUpUser>(_onSignUpUser);
    on<SignInUser>(_onSignInUser);
    on<UpdateUserProfile>(_onUpdateUserProfile);
    on<CompleteOnboarding>(_onCompleteOnboarding);
    on<SignOut>(_onSignOut);
  }
  
  Future<void> _onCheckAuthStatus(
    CheckAuthStatus event,
    Emitter<AuthState> emit,
  ) async {
    try {
      print('🔍 CheckAuthStatus: Starting auth check...');
      emit(AuthLoading());
      
      // Check if user is authenticated via stored token
      final isAuth = await authApiService.isAuthenticated();
      print('🔍 CheckAuthStatus: isAuthenticated = $isAuth');
      
      if (isAuth) {
        // First try to get locally saved user data
        final localUser = await repository.getCurrentUser();
        print('🔍 CheckAuthStatus: Local user = ${localUser?.email ?? "null"}');
        
        if (localUser != null) {
          // Use local user data, connect WebSocket
          print('✅ CheckAuthStatus: Using local user data');
          webSocketService.connect(localUser.id);
          emit(Authenticated(localUser));
          
          // Try to sync with backend in background (don't block or fail)
          try {
            print('🔄 CheckAuthStatus: Syncing with backend...');
            final userData = await authApiService.getCurrentUser();
            
            // Parse hasCompletedOnboarding safely
            bool onboardingComplete = false;
            if (userData['hasCompletedOnboarding'] != null) {
              if (userData['hasCompletedOnboarding'] is bool) {
                onboardingComplete = userData['hasCompletedOnboarding'];
              } else if (userData['hasCompletedOnboarding'] is String) {
                onboardingComplete = userData['hasCompletedOnboarding'].toLowerCase() == 'true';
              }
            }
            
            final updatedUser = User(
              id: userData['id'].toString(),
              name: userData['name']?.toString() ?? '',
              email: userData['email'].toString(),
              hasCompletedOnboarding: onboardingComplete,
              weightKg: userData['weight'] != null ? double.tryParse(userData['weight'].toString()) : null,
              heightCm: userData['height'] != null ? double.tryParse(userData['height'].toString()) : null,
              age: userData['age'] != null ? int.tryParse(userData['age'].toString()) : null,
              gender: userData['gender']?.toString(),
            );
            
            // Update local storage with fresh data
            await repository.saveUser(updatedUser);
            print('✅ CheckAuthStatus: Backend sync successful');
            
            // Only emit if data changed
            if (updatedUser.hasCompletedOnboarding != localUser.hasCompletedOnboarding) {
              print('🔄 CheckAuthStatus: Onboarding status changed, updating state');
              emit(Authenticated(updatedUser));
            }
          } catch (e) {
            print('⚠️ CheckAuthStatus: Background sync failed (using local data): $e');
            // Don't clear auth - just continue with local data
          }
        } else {
          // No local user - fetch from backend
          print('📡 CheckAuthStatus: No local user, fetching from backend...');
          try {
            final userData = await authApiService.getCurrentUser();
            
            // Parse hasCompletedOnboarding safely
            bool onboardingComplete = false;
            if (userData['hasCompletedOnboarding'] != null) {
              if (userData['hasCompletedOnboarding'] is bool) {
                onboardingComplete = userData['hasCompletedOnboarding'];
              } else if (userData['hasCompletedOnboarding'] is String) {
                onboardingComplete = userData['hasCompletedOnboarding'].toLowerCase() == 'true';
              }
            }
            
            final user = User(
              id: userData['id'].toString(),
              name: userData['name']?.toString() ?? '',
              email: userData['email'].toString(),
              hasCompletedOnboarding: onboardingComplete,
              weightKg: userData['weight'] != null ? double.tryParse(userData['weight'].toString()) : null,
              heightCm: userData['height'] != null ? double.tryParse(userData['height'].toString()) : null,
              age: userData['age'] != null ? int.tryParse(userData['age'].toString()) : null,
              gender: userData['gender']?.toString(),
            );
            
            // Save locally
            await repository.saveUser(user);
            print('✅ CheckAuthStatus: User fetched and saved locally');
            
            // Connect WebSocket
            webSocketService.connect(user.id);
            
            emit(Authenticated(user));
          } catch (e) {
            print('❌ CheckAuthStatus: Error fetching user from backend: $e');
            // Clear auth only if we can't get user at all
            await authApiService.clearAuth();
            emit(Unauthenticated(isFirstTime: true));
          }
        }
      } else {
        print('❌ CheckAuthStatus: No token found, user not authenticated');
        final isFirstTime = await repository.isFirstTime();
        emit(Unauthenticated(isFirstTime: isFirstTime));
      }
    } catch (e) {
      print('❌ CheckAuthStatus: Error: $e');
      emit(AuthError(e.toString()));
    }
  }
  
  Future<void> _onSignUpUser(
    SignUpUser event,
    Emitter<AuthState> emit,
  ) async {
    try {
      print('📝 SignUp: Starting sign up for ${event.email}');
      emit(AuthLoading());
      
      // Call backend API
      final response = await authApiService.signUp(
        email: event.email,
        password: event.password,
        name: event.name,
      );
      
      print('✅ SignUp: Backend response received');
      final userData = response['user'];
      final user = User(
        id: userData['id'].toString(),
        name: userData['name']?.toString() ?? event.name,
        email: userData['email'].toString(),
        hasCompletedOnboarding: false,
      );
      
      // Save locally - don't mark onboarding complete yet
      await repository.saveUser(user);
      print('✅ SignUp: User saved locally: ${user.email}');
      
      // Connect WebSocket
      webSocketService.connect(user.id);
      
      emit(Authenticated(user));
    } catch (e) {
      emit(AuthError('Sign up failed: ${e.toString()}'));
    }
  }
  
  Future<void> _onSignInUser(
    SignInUser event,
    Emitter<AuthState> emit,
  ) async {
    try {
      print('🔐 SignIn: Starting sign in for ${event.email}');
      emit(AuthLoading());
      
      // Call backend API
      final response = await authApiService.signIn(
        email: event.email,
        password: event.password,
      );
      
      print('✅ SignIn: Backend response received');
      final userData = response['user'];
      
      // Parse hasCompletedOnboarding safely
      bool onboardingComplete = false;
      if (userData['hasCompletedOnboarding'] != null) {
        if (userData['hasCompletedOnboarding'] is bool) {
          onboardingComplete = userData['hasCompletedOnboarding'];
        } else if (userData['hasCompletedOnboarding'] is String) {
          onboardingComplete = userData['hasCompletedOnboarding'].toLowerCase() == 'true';
        }
      }
      
      final user = User(
        id: userData['id'].toString(),
        name: userData['name']?.toString() ?? '',
        email: userData['email'].toString(),
        hasCompletedOnboarding: onboardingComplete,
        weightKg: userData['weight'] != null ? double.tryParse(userData['weight'].toString()) : null,
        heightCm: userData['height'] != null ? double.tryParse(userData['height'].toString()) : null,
        age: userData['age'] != null ? int.tryParse(userData['age'].toString()) : null,
        gender: userData['gender']?.toString(),
      );
      
      print('✅ SignIn: User object created: ${user.email}, onboarding: ${user.hasCompletedOnboarding}');
      
      // Save locally
      await repository.saveUser(user);
      print('✅ SignIn: User saved locally: ${user.email}');
      
      // Connect WebSocket
      webSocketService.connect(user.id);
      print('✅ SignIn: WebSocket connected');
      
      emit(Authenticated(user));
      print('✅ SignIn: Emitted Authenticated state');
    } catch (e, stackTrace) {
      print('❌ SignIn: Error occurred: $e');
      print('❌ SignIn: Stack trace: $stackTrace');
      emit(AuthError('Sign in failed: ${e.toString()}'));
    }
  }
  
  Future<void> _onUpdateUserProfile(
    UpdateUserProfile event,
    Emitter<AuthState> emit,
  ) async {
    try {
      if (state is Authenticated) {
        final currentUser = (state as Authenticated).user;
        
        // Update backend
        await authApiService.updateProfile({
          'weight': event.weightKg,
          'height': event.heightCm,
          'age': event.age,
          'gender': event.gender,
        });
        
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
        
        // Call backend to mark onboarding complete
        await authApiService.completeOnboarding();
        
        // Update local state
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
      // Disconnect WebSocket
      webSocketService.disconnect();
      
      // Clear backend auth
      await authApiService.clearAuth();
      
      // Clear local storage
      await repository.clearUser();
      
      emit(Unauthenticated(isFirstTime: false));
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }
}
