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
    final userJson = sharedPreferences.getString(_userKey);
    if (userJson == null) return null;
    return User.fromJson(jsonDecode(userJson));
  }
  
  @override
  Future<void> saveUser(User user) async {
    final encoded = jsonEncode(user.toJson());
    await sharedPreferences.setString(_userKey, encoded);
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
