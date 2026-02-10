@echo off
echo ================================================
echo   Flutter App Runner - ADB Automatic Fix
echo ================================================
echo.

echo [1/4] Cleaning ADB processes...
taskkill /F /IM adb.exe >nul 2>&1
ping localhost -n 3 >nul

echo [2/4] Starting ADB server...
adb start-server >nul 2>&1
ping localhost -n 6 >nul

echo [3/4] Verifying device connection...
adb devices
echo.

echo [4/4] Launching Flutter app...
echo.
flutter run --verbose

pause
