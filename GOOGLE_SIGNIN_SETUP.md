# Google Sign-In Setup Guide for PluriHive

This guide explains how to configure Google Sign-In for both Android and iOS platforms.

## Overview

Google Sign-In has been successfully integrated into PluriHive with the following components:

### Flutter App
- ✅ `google_sign_in` package added
- ✅ `GoogleSignInService` created
- ✅ `AuthBloc` updated with `SignInWithGoogle` event
- ✅ `AuthApiService` updated with Google endpoint
- ✅ Sign-In screen updated with Google button

### Backend
- ✅ `google-auth-library` package added
- ✅ `AuthService` updated with Google token verification
- ✅ `/auth/google` endpoint created
- ✅ Auto-creates users from Google accounts

---

## 🔧 Configuration Steps

### 1. Get Google OAuth Credentials

#### For Android:

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select existing one
3. Enable **Google+ API**
4. Go to **Credentials** → **Create Credentials** → **OAuth client ID**
5. Select **Android**
6. Get your SHA-1 fingerprint:
   ```bash
   # Debug keystore (for development)
   keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
   
   # Release keystore (for production)
   keytool -list -v -keystore /path/to/your/keystore.jks -alias your-alias
   ```
7. Enter:
   - **Package name**: `com.yourcompany.territory_fitness`
   - **SHA-1 certificate fingerprint**: (from step 6)
8. Click **Create**
9. **Save the Client ID** (you'll need it)

#### For iOS:

1. In the same Google Cloud Console project
2. **Create Credentials** → **OAuth client ID**
3. Select **iOS**
4. Enter:
   - **Bundle ID**: `com.yourcompany.territoryFitness`
5. Click **Create**
6. **Save the Client ID** and **iOS URL scheme**

#### For Web (Backend verification):

1. **Create Credentials** → **OAuth client ID**
2. Select **Web application**
3. Click **Create**
4. **Save the Client ID** (for backend verification)

---

### 2. Configure Android

Edit `android/app/src/main/AndroidManifest.xml`:

```xml
<manifest ...>
    <application ...>
        <!-- Add this inside <application> tag -->
        <meta-data
            android:name="com.google.android.gms.version"
            android:value="@integer/google_play_services_version" />
    </application>
</manifest>
```

---

### 3. Configure iOS

1. Edit `ios/Runner/Info.plist`:

```xml
<dict>
    <!-- Add these entries -->
    <key>CFBundleURLTypes</key>
    <array>
        <dict>
            <key>CFBundleTypeRole</key>
            <string>Editor</string>
            <key>CFBundleURLSchemes</key>
            <array>
                <!-- Replace with your REVERSED_CLIENT_ID from Google Console -->
                <string>com.googleusercontent.apps.YOUR-CLIENT-ID</string>
            </array>
        </dict>
    </array>
    
    <key>GIDClientID</key>
    <string>YOUR-IOS-CLIENT-ID.apps.googleusercontent.com</string>
</dict>
```

2. Run:
```bash
cd ios
pod install
cd ..
```

---

### 4. Update Backend Configuration (Optional but Recommended)

For additional security, add your Google Client ID to backend environment variables.

Edit `backend/.env`:

```env
# Add this line
GOOGLE_CLIENT_ID=YOUR-WEB-CLIENT-ID.apps.googleusercontent.com
```

Then update `backend/src/modules/auth/auth.service.ts`:

```typescript
// In signInWithGoogle method, uncomment this line:
const ticket = await this.googleClient.verifyIdToken({
  idToken,
  audience: process.env.GOOGLE_CLIENT_ID, // ← Uncomment this
});
```

---

### 5. Update Package Name (if needed)

If you want to change the package name from the default:

#### Android:
Edit `android/app/build.gradle`:
```gradle
android {
    defaultConfig {
        applicationId "com.yourcompany.territory_fitness"
        // ...
    }
}
```

#### iOS:
Open `ios/Runner.xcworkspace` in Xcode and update the Bundle Identifier.

---

## 🧪 Testing

### Test on Android:
```bash
flutter run
```

### Test on iOS:
```bash
flutter run
```

### Expected Flow:
1. Tap "Continue with Google" button
2. Google account picker appears
3. Select account
4. App authenticates with backend
5. User is logged in and redirected to dashboard

---

## 🔍 Troubleshooting

### "Sign in failed" on Android
- ✅ Verify SHA-1 fingerprint matches
- ✅ Check package name matches
- ✅ Ensure Google+ API is enabled
- ✅ Wait 5-10 minutes after creating credentials

### "Sign in failed" on iOS
- ✅ Verify Bundle ID matches
- ✅ Check REVERSED_CLIENT_ID is correct
- ✅ Run `pod install` after configuration
- ✅ Clean build: `flutter clean && flutter pub get`

### Backend returns "Invalid Google token"
- ✅ Check backend is running
- ✅ Verify `google-auth-library` is installed
- ✅ Check network connectivity
- ✅ Ensure token is being sent correctly

### "PlatformException" errors
- ✅ Restart the app completely
- ✅ Clear app data
- ✅ Reinstall the app
- ✅ Check Google Play Services is updated (Android)

---

## 📱 Platform-Specific Notes

### Android
- Requires Google Play Services
- Works on emulators with Google Play
- SHA-1 must match for each build type (debug/release)

### iOS
- Requires iOS 12.0 or higher
- Works on simulators
- URL scheme must be correctly configured

---

## 🔒 Security Best Practices

1. **Never commit credentials** to version control
2. **Use environment variables** for sensitive data
3. **Enable backend verification** with GOOGLE_CLIENT_ID
4. **Rotate credentials** periodically
5. **Use different credentials** for debug/release builds

---

## 📚 Additional Resources

- [Google Sign-In for Flutter](https://pub.dev/packages/google_sign_in)
- [Google OAuth 2.0](https://developers.google.com/identity/protocols/oauth2)
- [Google Cloud Console](https://console.cloud.google.com/)

---

## ✅ Checklist

- [ ] Created Google Cloud project
- [ ] Enabled Google+ API
- [ ] Created Android OAuth credentials
- [ ] Created iOS OAuth credentials
- [ ] Created Web OAuth credentials (optional)
- [ ] Configured AndroidManifest.xml
- [ ] Configured Info.plist
- [ ] Updated backend .env (optional)
- [ ] Tested on Android
- [ ] Tested on iOS
- [ ] Verified backend authentication

---

**Need Help?** Check the troubleshooting section or refer to the official documentation.
