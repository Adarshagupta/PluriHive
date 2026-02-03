import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../../../core/services/auth_api_service.dart';
import '../../../../core/services/websocket_service.dart';
import '../../../../core/services/offline_sync_service.dart';
import '../../../../core/services/user_data_cleanup_service.dart';
import '../../../../core/services/territory_prefetch_service.dart';

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

class SignInWithGoogle extends AuthEvent {
  final String idToken;
  
  SignInWithGoogle({
    required this.idToken,
  });
  
  @override
  List<Object?> get props => [idToken];
}

class UpdateUserProfile extends AuthEvent {
  final double weightKg;
  final double heightCm;
  final int age;
  final String gender;
  final String? country;
  final String? city;
  
  UpdateUserProfile({
    required this.weightKg,
    required this.heightCm,
    required this.age,
    required this.gender,
    this.country,
    this.city,
  });
  
  @override
  List<Object?> get props => [weightKg, heightCm, age, gender, country, city];
}

class UpdateUserAvatar extends AuthEvent {
  final String avatarModelUrl;
  final String avatarImageUrl;

  UpdateUserAvatar({
    required this.avatarModelUrl,
    required this.avatarImageUrl,
  });

  @override
  List<Object?> get props => [avatarModelUrl, avatarImageUrl];
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
  final OfflineSyncService offlineSyncService;
  final TerritoryPrefetchService territoryPrefetchService;
  
  AuthBloc({
    required this.repository,
    required this.authApiService,
    required this.webSocketService,
    required this.offlineSyncService,
    required this.territoryPrefetchService,
  }) : super(AuthInitial()) {
    on<CheckAuthStatus>(_onCheckAuthStatus);
    on<SignUpUser>(_onSignUpUser);
    on<SignInUser>(_onSignInUser);
    on<SignInWithGoogle>(_onSignInWithGoogle);
    on<UpdateUserProfile>(_onUpdateUserProfile);
    on<UpdateUserAvatar>(_onUpdateUserAvatar);
    on<CompleteOnboarding>(_onCompleteOnboarding);
    on<SignOut>(_onSignOut);
  }

  Future<void> _connectWebSocket(User user) async {
    final token = await authApiService.getToken();
    if (token != null && token.isNotEmpty) {
      await webSocketService.connect(user.id, token: token);
    } else {
      print('⚠️ WebSocket token unavailable - not connecting');
    }

  }

  void _kickoffOfflineSync() {
    offlineSyncService.syncPending().catchError((e) {
      print('[warn] Offline sync failed: $e');
    });
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
          unawaited(_connectWebSocket(localUser));
          emit(Authenticated(localUser));
          _kickoffOfflineSync();
          
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
              country: userData['country']?.toString(),
              city: userData['city']?.toString(),
              avatarModelUrl: userData['avatarModelUrl']?.toString(),
              avatarImageUrl: userData['avatarImageUrl']?.toString(),
            );
            
            // Update local storage with fresh data
            await repository.saveUser(updatedUser);
            print('✅ CheckAuthStatus: Backend sync successful');
            
            // Only emit if data changed
            if (updatedUser.hasCompletedOnboarding != localUser.hasCompletedOnboarding) {
              print('🔄 CheckAuthStatus: Onboarding status changed, updating state');
              emit(Authenticated(updatedUser));
              _kickoffOfflineSync();
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
              country: userData['country']?.toString(),
              city: userData['city']?.toString(),
              avatarModelUrl: userData['avatarModelUrl']?.toString(),
              avatarImageUrl: userData['avatarImageUrl']?.toString(),
            );
            
            // Save locally
            await repository.saveUser(user);
            print('✅ CheckAuthStatus: User fetched and saved locally');
            
            // Connect WebSocket
            unawaited(_connectWebSocket(user));
            
            emit(Authenticated(user));
            _kickoffOfflineSync();
          } catch (e) {
            print('❌ CheckAuthStatus: Error fetching user from backend: $e');
            // Clear auth only if we can't get user at all in
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
        avatarModelUrl: userData['avatarModelUrl']?.toString(),
        avatarImageUrl: userData['avatarImageUrl']?.toString(),
        country: userData['country']?.toString(),
        city: userData['city']?.toString(),
      );
      
      // Save locally - don't mark onboarding complete yet
      await repository.saveUser(user);
      print('✅ SignUp: User saved locally: ${user.email}');
      
      // Prefetch territories in background after login completes
      unawaited(territoryPrefetchService.prefetchAroundUser());
      
      
      // Connect WebSocket
      unawaited(_connectWebSocket(user));
      
      emit(Authenticated(user));
      _kickoffOfflineSync();
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
        country: userData['country']?.toString(),
        city: userData['city']?.toString(),
        avatarModelUrl: userData['avatarModelUrl']?.toString(),
        avatarImageUrl: userData['avatarImageUrl']?.toString(),
      );
      
      print('✅ SignIn: User object created: ${user.email}, onboarding: ${user.hasCompletedOnboarding}');
      
      // Save locally
      await repository.saveUser(user);
      print('✅ SignIn: User saved locally: ${user.email}');
      
      // Prefetch territories in background after login completes
      unawaited(territoryPrefetchService.prefetchAroundUser());
      
      
      // Connect WebSocket
      unawaited(_connectWebSocket(user));
      print('✅ SignIn: WebSocket connect started');
      
      emit(Authenticated(user));
      _kickoffOfflineSync();
      print('✅ SignIn: Emitted Authenticated state');
    } catch (e, stackTrace) {
      print('❌ SignIn: Error occurred: $e');
      print('❌ SignIn: Stack trace: $stackTrace');
      emit(AuthError('Sign in failed: ${e.toString()}'));
    }
  }
  
  Future<void> _onSignInWithGoogle(
    SignInWithGoogle event,
    Emitter<AuthState> emit,
  ) async {
    try {
      print('🔵 Google SignIn: Starting Google sign in...');
      emit(AuthLoading());
      
      // Call backend API with Google ID token
      final response = await authApiService.signInWithGoogle(
        idToken: event.idToken,
      );
      
      print('✅ Google SignIn: Backend response received');
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
        country: userData['country']?.toString(),
        city: userData['city']?.toString(),
        avatarModelUrl: userData['avatarModelUrl']?.toString(),
        avatarImageUrl: userData['avatarImageUrl']?.toString(),
      );
      
      print('✅ Google SignIn: User object created: ${user.email}, onboarding: ${user.hasCompletedOnboarding}');
      
      // Save locally
      await repository.saveUser(user);
      print('✅ Google SignIn: User saved locally: ${user.email}');
      
      // Prefetch territories in background after login completes
      unawaited(territoryPrefetchService.prefetchAroundUser());
      
      
      // Connect WebSocket
      unawaited(_connectWebSocket(user));
      print('✅ Google SignIn: WebSocket connect started');
      
      emit(Authenticated(user));
      _kickoffOfflineSync();
      print('✅ Google SignIn: Emitted Authenticated state');
    } catch (e, stackTrace) {
      print('❌ Google SignIn: Error occurred: $e');
      print('❌ Google SignIn: Stack trace: $stackTrace');
      emit(AuthError('Google sign in failed: ${e.toString()}'));
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
        print('📝 Updating profile with data:');
        print('   Weight: ${event.weightKg} kg');
        print('   Height: ${event.heightCm} cm');
        print('   Age: ${event.age}');
        print('   Gender: ${event.gender}');
        
        await authApiService.updateProfile({
          'weight': event.weightKg,
          'height': event.heightCm,
          'age': event.age,
          'gender': event.gender,
          if (event.country != null) 'country': event.country,
          if (event.city != null) 'city': event.city,
        });
        
        print('✅ Profile update complete');
        
        final updatedUser = currentUser.copyWith(
          weightKg: event.weightKg,
          heightCm: event.heightCm,
          age: event.age,
          gender: event.gender,
          country: event.country ?? currentUser.country,
          city: event.city ?? currentUser.city,
        );
        
        await repository.saveUser(updatedUser);
        emit(Authenticated(updatedUser));
        _kickoffOfflineSync();
      }
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> _onUpdateUserAvatar(
    UpdateUserAvatar event,
    Emitter<AuthState> emit,
  ) async {
    try {
      if (state is Authenticated) {
        final currentUser = (state as Authenticated).user;

        await authApiService.updateProfile({
          'avatarModelUrl': event.avatarModelUrl,
          'avatarImageUrl': event.avatarImageUrl,
        });

        final updatedUser = currentUser.copyWith(
          avatarModelUrl: event.avatarModelUrl,
          avatarImageUrl: event.avatarImageUrl,
        );

        await repository.saveUser(updatedUser);
        emit(Authenticated(updatedUser));
        _kickoffOfflineSync();
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
        _kickoffOfflineSync();
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
      
      // Clear backend auth (call endpoint + clear local tokens)
      await authApiService.logout();
      
      // Clear local storage
      await repository.clearUser();

      // Clear all cached user data
      await UserDataCleanupService.clearAll();
      
      emit(Unauthenticated(isFirstTime: false));
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }
}
