# OTA Update Implementation Guide

## Overview
Over-the-air (OTA) update functionality has been successfully added to your Territory Fitness Flutter application. This allows users to receive app updates without manually checking the app store.

## What Was Added

### 1. Dependencies (pubspec.yaml)
- `in_app_update: ^4.2.2` - Handles Google Play Store in-app updates for Android
- `package_info_plus: ^8.0.0` - Gets current app version information

### 2. Update Service (lib/core/services/update_service.dart)
A comprehensive service that:
- **Android**: Uses Google Play In-App Update API for seamless updates
  - Flexible updates for optional updates
  - Immediate updates for critical updates
- **iOS & Custom Backend**: Checks your backend API for version information
- Shows appropriate dialogs based on update availability
- Supports forced updates for critical releases
- Displays release notes to users

### 3. Auto-Check on App Start (lib/main.dart)
- Automatically checks for updates 3 seconds after app launch
- Non-intrusive - only shows dialog if update is available

### 4. Manual Check in Settings (lib/features/settings/presentation/pages/settings_screen.dart)
- Added "Check for Updates" option in Settings screen
- Shows current version number
- Users can manually check for updates anytime

## Installation Steps

### Step 1: Install Dependencies
```bash
cd C:\Users\adasg\OneDrive\Pictures\Rugged
flutter pub get
```

### Step 1.5: Authenticate Shorebird (Code Push)
Shorebird code push requires the CLI to be authenticated. Run this once on your dev machine:
```bash
shorebird login
```

For CI, generate a token and store it as `SHOREBIRD_TOKEN` in your CI secrets:
```bash
shorebird login:ci
```

### Step 2: Configure Backend URL
Update the URL in `lib/core/services/update_service.dart`:
```dart
static const String updateCheckUrl = 'https://your-backend.com/api/app-version';
```

### Step 3: Backend Setup (Optional but Recommended)
See `OTA_UPDATE_SETUP.md` for backend API implementation examples.

The backend should return JSON like:
```json
{
  "version": "1.0.1",
  "build_number": "2",
  "force_update": false,
  "download_url": "https://play.google.com/store/apps/details?id=com.yourapp",
  "release_notes": "Bug fixes and improvements"
}
```

### Step 4: Android Configuration
For Android in-app updates to work, your app must be:
1. Published on Google Play Store (or internal test track)
2. Using the same signing key as the Play Store version
3. User must be signed in with the same account used for testing

Add to `android/app/build.gradle` if not already present:
```gradle
dependencies {
    // ... other dependencies
    implementation 'com.google.android.play:app-update:2.1.0'
    implementation 'com.google.android.play:app-update-ktx:2.1.0'
}
```

### Step 5: iOS Configuration (App Store)
For iOS, the update check will redirect users to the App Store. Update the download URL in your backend to point to your App Store listing.

## How It Works

### Automatic Updates (On App Start)
1. App launches
2. After 3 seconds, checks for updates
3. If update available:
   - **Android**: Shows in-app update prompt
   - **iOS/Custom**: Shows update dialog with release notes
4. User can choose to update or dismiss (unless force_update is true)

### Manual Updates (Settings)
1. User opens Settings
2. Taps "Check for Updates"
3. Shows loading indicator
4. Displays result (update available or up-to-date)

### Update Types

**Flexible Update (Android)**
- User can continue using app while update downloads
- Prompted to install when download completes
- Good for non-critical updates

**Immediate Update (Android)**
- Full-screen update flow
- User must update before continuing
- Used for force_update scenarios

**Custom Dialog (iOS/Fallback)**
- Shows version, release notes, and download button
- Opens App Store or custom download URL
- Can be forced (non-dismissible) or optional

## Testing

### Test on Android
1. Build and publish to internal test track on Google Play
2. Install the app from Play Store
3. Increase version number in `pubspec.yaml`
4. Build and upload new version to Play Store
5. Open the app - update dialog should appear

### Test Custom Backend
1. Deploy your backend with version API
2. Set a higher version number in backend response
3. Run the app
4. Update dialog should appear after 3 seconds

### Test Manual Check
1. Open the app
2. Navigate to Settings
3. Tap "Check for Updates"
4. Should show either update available or up-to-date message

## Version Number Format

The app uses semantic versioning (X.Y.Z):
- **X** (Major): Breaking changes
- **Y** (Minor): New features, backward compatible
- **Z** (Patch): Bug fixes

Update in `pubspec.yaml`:
```yaml
version: 1.0.1+2  # 1.0.1 is version, 2 is build number
```

## Best Practices

1. **Use force_update sparingly**: Only for critical security updates or breaking API changes
2. **Write clear release notes**: Help users understand what's new
3. **Test before releasing**: Always test updates on internal tracks first
4. **Version incrementally**: Don't skip versions
5. **Monitor rollout**: Watch for crash reports after updates

## Troubleshooting

### Update not showing on Android
- Ensure app is from Play Store (not sideloaded)
- Check Play Store has the new version
- Wait a few hours for Play Store to propagate
- Try clearing Play Store cache

### Update check fails
- Check network connectivity
- Verify backend URL is correct and accessible
- Check backend response format matches expected JSON
- Look for errors in debug console

### iOS update not working
- Ensure download_url points to App Store
- Verify app is published on App Store
- Check url_launcher permissions

## Files Modified/Created

### Created:
- `lib/core/services/update_service.dart` - Main update service
- `OTA_UPDATE_SETUP.md` - Backend API documentation
- `OTA_UPDATE_GUIDE.md` - This file

### Modified:
- `pubspec.yaml` - Added dependencies
- `lib/main.dart` - Added auto-update check on start
- `lib/features/settings/presentation/pages/settings_screen.dart` - Added manual update check

## Next Steps

1. ✅ Dependencies added
2. ✅ Update service implemented
3. ✅ Auto-check on start added
4. ✅ Manual check in settings added
5. ⏳ Run `flutter pub get`
6. ⏳ Configure backend URL
7. ⏳ Implement backend API endpoint
8. ⏳ Test on device
9. ⏳ Deploy to stores

## Support

For issues or questions:
1. Check Flutter logs: `flutter logs`
2. Check backend API response
3. Verify Play Store setup for Android
4. Test with internal test track first

## Additional Features (Optional)

You can extend this implementation with:
- Update notifications
- Download progress indicators
- Background update downloads
- Changelog viewer in-app
- Update scheduling (update during off-hours)
- A/B testing for updates
- Rollback capabilities

## Resources

- [Google Play In-App Updates](https://developer.android.com/guide/playcore/in-app-updates)
- [Flutter package_info_plus](https://pub.dev/packages/package_info_plus)
- [Flutter in_app_update](https://pub.dev/packages/in_app_update)
