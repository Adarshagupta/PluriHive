# Setup Instructions

## Quick Start

### 1. Get Mapbox Tokens

1. Go to [Mapbox](https://account.mapbox.com/)
2. Create an **access token** for runtime maps
3. Create a **downloads token** for Android SDK artifacts

### 2. Configure Mapbox

**Android (downloads token):**
Edit `android/gradle.properties` and set:
```properties
MAPBOX_DOWNLOADS_TOKEN=YOUR_MAPBOX_DOWNLOADS_TOKEN
```

**Runtime access token (all platforms):**
Pass this when running/building:
```bash
flutter run --dart-define=MAPBOX_ACCESS_TOKEN=YOUR_MAPBOX_ACCESS_TOKEN
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
- Android Studio: Use "Extended Controls" â†’ Location to set GPS coordinates
- Xcode Simulator: Features â†’ Location â†’ Custom Location

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
- Verify `MAPBOX_ACCESS_TOKEN` is provided via `--dart-define`
- Verify `MAPBOX_DOWNLOADS_TOKEN` is set in `android/gradle.properties` (Android)
- Ensure your Mapbox token has the required scopes

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
- [Mapbox Maps Flutter](https://pub.dev/packages/mapbox_maps_flutter)
- [Geolocator](https://pub.dev/packages/geolocator)

## Support

For issues or questions, check:
- Flutter GitHub issues
- Stack Overflow with #flutter tag
- Flutter Discord community


