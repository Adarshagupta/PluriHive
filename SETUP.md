# Setup Instructions

## Quick Start

### 1. Get Google Maps API Key

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select existing one
3. Enable **Maps SDK for Android** and **Maps SDK for iOS**
4. Create credentials → API Key
5. Copy your API key

### 2. Configure API Keys

**For Android:**
Edit `android/app/src/main/AndroidManifest.xml` and replace:
```xml
android:value="YOUR_GOOGLE_MAPS_API_KEY_HERE"
```
with your actual API key.

**For iOS:**
1. Create `ios/Runner/AppDelegate.swift` if it doesn't exist
2. Add this code:
```swift
import UIKit
import Flutter
import GoogleMaps

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GMSServices.provideAPIKey("YOUR_GOOGLE_MAPS_API_KEY_HERE")
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
```

### 3. Run the App

```bash
# Check for connected devices
flutter devices

# Run on connected device
flutter run

# Or run with specific device
flutter run -d <device-id>
```

### 4. Test Location Services

**On Emulator:**
- Android Studio: Use "Extended Controls" → Location to set GPS coordinates
- Xcode Simulator: Features → Location → Custom Location

**On Physical Device:**
- Make sure location services are enabled
- Grant location permissions when prompted

## Project Features to Test

1. **Initial Load**
   - App should load and center on your current location
   - Stats overlay should show Level 1, 0 points

2. **Start Tracking**
   - Tap green play button
   - Move around (or simulate location changes)
   - Route should draw on map as blue line

3. **Territory Capture**
   - As you move, territories should be captured automatically
   - Purple hexagons should appear on the map
   - Stats should update with points and territories

4. **Stop Tracking**
   - Tap red stop button
   - You'll see a success message with captured territories
   - Stats persist for next session

## Troubleshooting

### Location Permission Issues
- Android: Check AndroidManifest.xml permissions
- iOS: Check Info.plist location usage descriptions

### Map Not Loading
- Verify Google Maps API key is correct
- Check billing is enabled on Google Cloud Console
- Ensure Maps SDK is enabled

### Build Errors
```bash
# Clean and rebuild
flutter clean
flutter pub get
flutter run
```

### Gradle Issues (Android)
Edit `android/app/build.gradle`:
```gradle
android {
    compileSdkVersion 34
    
    defaultConfig {
        minSdkVersion 21
        targetSdkVersion 34
    }
}
```

## Next Steps

### Enhance the Prototype
1. Add user profile with weight/height for accurate calorie calculation
2. Implement achievements system
3. Add daily/weekly challenges
4. Create leaderboard with mock data
5. Add route history and activity list

### Production Ready Features
1. Firebase integration for cloud sync
2. User authentication
3. Real H3 hexagonal grid library
4. Background location tracking
5. Push notifications for achievements
6. Social features (friends, sharing)

## Development Tips

### Hot Reload
Press `r` in terminal to hot reload changes while app is running.

### Debug Mode
Add breakpoints in VS Code and use F5 to debug.

### State Management
- Use BLoC DevTools to inspect state changes
- Add logging to BLoCs for debugging

### Performance
- Profile with `flutter run --profile`
- Check for memory leaks with DevTools

## Resources

- [Flutter Documentation](https://docs.flutter.dev/)
- [BLoC Pattern](https://bloclibrary.dev/)
- [Google Maps Flutter](https://pub.dev/packages/google_maps_flutter)
- [Geolocator](https://pub.dev/packages/geolocator)

## Support

For issues or questions, check:
- Flutter GitHub issues
- Stack Overflow with #flutter tag
- Flutter Discord community
