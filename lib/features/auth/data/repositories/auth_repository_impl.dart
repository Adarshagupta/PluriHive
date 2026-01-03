import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_local_data_source.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthLocalDataSource localDataSource;
  
  AuthRepositoryImpl(this.localDataSource);
  
  @override
  Future<User?> getCurrentUser() {
    return localDataSource.getCurrentUser();
  }
  
  @override
  Future<void> saveUser(User user) {
    return localDataSource.saveUser(user);
  }
  
  @override
  Future<void> clearUser() {
    return localDataSource.clearUser();
  }
  
  @override
  Future<bool> isFirstTime() {
    return localDataSource.isFirstTime();
  }
  
  @override
  Future<void> markOnboardingComplete() {
    return localDataSource.markOnboardingComplete();
  }
}
