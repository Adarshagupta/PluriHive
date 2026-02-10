# ADB Permanent Fix Guide

## Problem
ADB daemon keeps crashing with "connection reset" errors when running `flutter devices` or `flutter run`.

## Solution

### Quick Fix (Run this whenever you get ADB errors)
```powershell
.\fix-adb.ps1
```

OR use this batch file:
```batch
start-flutter.bat
```

### Run Flutter App (Automatic ADB fix included)
```batch
flutter-run.bat
```

## Manual Fix Steps

If the scripts don't work, run these commands manually:

```powershell
# 1. Kill all ADB processes
Get-Process adb -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 2

# 2. Clear environment and disable libusb
$env:ADB_LIBUSB = '0'
$env:ADB_SERVER_SOCKET = ''

# 3. Start ADB server
adb start-server
Start-Sleep -Seconds 4

# 4. Verify devices
adb devices -l
flutter devices
```

## Root Cause

The issue occurs because:
1. Multiple ADB daemons try to start simultaneously
2. Old connections on port 5037 interfere with new ones
3. libusb can cause protocol faults on some Windows configurations

## Permanent Solution

The fix-adb.ps1 script:
- Kills all existing ADB processes
- Clears the ADB socket and disables problematic libusb
- Starts ADB server with retry logic
- Verifies devices are connected properly

## Alternative: Use Batch Files

- **start-flutter.bat** - Opens a command prompt with ADB already fixed
- **flutter-run.bat** - Automatically fixes ADB and runs your app on the physical device

## Troubleshooting

If you still have issues:

1. **Check for multiple ADB installations:**
   ```batch
   where adb
   ```
   Should show only: `C:\Users\adasg\AppData\Local\Android\Sdk\platform-tools\adb.exe`

2. **Verify ANDROID_HOME:**
   ```powershell
   $env:ANDROID_HOME
   ```
   Should be: `C:\Users\adasg\AppData\Local\Android\Sdk`

3. **Reinstall Platform Tools:**
   - Open Android Studio
   - Go to SDK Manager
   - Uninstall and reinstall "Android SDK Platform-Tools"

4. **Check for port conflicts:**
   ```powershell
   netstat -ano | findstr :5037
   ```

## Integration with VS Code

You can add this to your VS Code tasks.json to auto-fix ADB before running:

```json
{
  "version": "2.0.0",
  "tasks": [
    {
      "label": "Fix ADB and Run Flutter",
      "type": "shell",
      "command": "${workspaceFolder}/flutter-run.bat",
      "problemMatcher": [],
      "group": {
        "kind": "build",
        "isDefault": true
      }
    }
  ]
}
```
