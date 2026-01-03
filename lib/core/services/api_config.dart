class ApiConfig {
  // PC IP address for USB debugging (use this when testing on physical device)
  // Try these IPs in order: 172.31.226.185, 10.1.80.22, 172.16.0.2
  static const String baseUrl = 'http://10.1.80.22:3000';
  
  // For emulator testing, use:
  // static const String baseUrl = 'http://10.0.2.2:3000'; // Android Emulator
  // static const String baseUrl = 'http://localhost:3000'; // iOS Simulator
  
  static const String wsUrl = 'ws://10.1.80.22:3000';
  
  // Auth endpoints
  static const String signUpEndpoint = '/auth/signup';
  static const String signInEndpoint = '/auth/signin';
  static const String getMeEndpoint = '/auth/me';
  
  // User endpoints
  static const String userProfileEndpoint = '/users/profile';
  
  // Territory endpoints
  static const String captureTerritoriesEndpoint = '/territories/capture';
  static const String userTerritoriesEndpoint = '/territories/user';
  static const String nearbyTerritoriesEndpoint = '/territories/nearby';
  
  // Activity endpoints
  static const String activitiesEndpoint = '/activities';
  
  // Leaderboard endpoints
  static const String leaderboardEndpoint = '/leaderboard/global';
  
  // Request timeouts
  static const Duration defaultTimeout = Duration(seconds: 30);
  static const Duration uploadTimeout = Duration(minutes: 2);
}
