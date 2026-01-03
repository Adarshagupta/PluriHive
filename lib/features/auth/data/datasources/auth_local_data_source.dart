import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/user.dart';

abstract class AuthLocalDataSource {
  Future<User?> getCurrentUser();
  Future<void> saveUser(User user);
  Future<void> clearUser();
  Future<bool> isFirstTime();
  Future<void> markOnboardingComplete();
}

class AuthLocalDataSourceImpl implements AuthLocalDataSource {
  final SharedPreferences sharedPreferences;
  static const String _userKey = 'current_user';
  static const String _firstTimeKey = 'is_first_time';
  
  AuthLocalDataSourceImpl(this.sharedPreferences);
  
  @override
  Future<User?> getCurrentUser() async {
    print('👤 AuthLocalDataSource: Getting current user from SharedPreferences...');
    final userJson = sharedPreferences.getString(_userKey);
    print('👤 AuthLocalDataSource: User JSON = ${userJson != null ? "EXISTS (${userJson.length} chars)" : "NULL"}');
    if (userJson == null) return null;
    final user = User.fromJson(jsonDecode(userJson));
    print('👤 AuthLocalDataSource: Loaded user = ${user.email}');
    return user;
  }
  
  @override
  Future<void> saveUser(User user) async {
    print('💾 AuthLocalDataSource: Saving user ${user.email} to SharedPreferences...');
    final encoded = jsonEncode(user.toJson());
    print('💾 AuthLocalDataSource: JSON length = ${encoded.length} chars');
    await sharedPreferences.setString(_userKey, encoded);
    print('💾 AuthLocalDataSource: User saved successfully');
  }
  
  @override
  Future<void> clearUser() async {
    await sharedPreferences.remove(_userKey);
  }
  
  @override
  Future<bool> isFirstTime() async {
    return sharedPreferences.getBool(_firstTimeKey) ?? true;
  }
  
  @override
  Future<void> markOnboardingComplete() async {
    await sharedPreferences.setBool(_firstTimeKey, false);
  }
}
