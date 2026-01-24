import 'package:google_sign_in/google_sign_in.dart';

class GoogleSignInService {
  static final GoogleSignInService _instance = GoogleSignInService._internal();
  factory GoogleSignInService() => _instance;
  GoogleSignInService._internal();

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'email',
      'profile',
    ],
    // IMPORTANT: Add your Web Client ID here for Android to get ID tokens
    serverClientId: '603877706963-ave40d4ic4hhnein0uhcj1iij4o279rs.apps.googleusercontent.com',
  );

  /// Sign in with Google
  Future<GoogleSignInAccount?> signIn() async {
    try {
      print('🔵 Google Sign-In: Starting sign-in process...');
      
      // Sign out first to force account selection
      await _googleSignIn.signOut();
      
      final GoogleSignInAccount? account = await _googleSignIn.signIn();
      
      if (account != null) {
        print('✅ Google Sign-In: Signed in as ${account.email}');
        return account;
      } else {
        print('⚠️ Google Sign-In: User cancelled sign-in');
        return null;
      }
    } catch (error) {
      print('❌ Google Sign-In error: $error');
      return null;
    }
  }

  /// Get ID Token for backend authentication
  Future<String?> getIdToken() async {
    try {
      print('🔵 Getting ID token...');
      
      // First try to get current user
      GoogleSignInAccount? account = _googleSignIn.currentUser;
      
      // If no current user, try to sign in silently
      if (account == null) {
        print('⚠️ No current user, attempting silent sign-in...');
        account = await _googleSignIn.signInSilently();
      }
      
      if (account == null) {
        print('❌ Google Sign-In: No account available');
        return null;
      }

      print('🔵 Getting authentication for: ${account.email}');
      final GoogleSignInAuthentication auth = await account.authentication;
      
      print('🔍 Auth details:');
      print('   - Has accessToken: ${auth.accessToken != null}');
      print('   - Has idToken: ${auth.idToken != null}');
      
      if (auth.idToken == null) {
        print('❌ ID Token is NULL!');
        print('⚠️ This usually means:');
        print('   1. Android OAuth client not created in Google Cloud Console');
        print('   2. SHA-1 fingerprint mismatch');
        print('   3. Package name mismatch');
        print('   4. Need to wait 5-10 minutes after creating OAuth client');
        return null;
      }
      
      print('✅ Google Sign-In: Got ID token (${auth.idToken!.substring(0, 20)}...)');
      return auth.idToken;
    } catch (error) {
      print('❌ Google Sign-In: Error getting ID token: $error');
      return null;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      print('✅ Google Sign-In: Signed out');
    } catch (error) {
      print('❌ Google Sign-In: Error signing out: $error');
    }
  }

  /// Check if user is currently signed in
  Future<bool> isSignedIn() async {
    return await _googleSignIn.isSignedIn();
  }

  /// Get current user
  GoogleSignInAccount? get currentUser => _googleSignIn.currentUser;
}
