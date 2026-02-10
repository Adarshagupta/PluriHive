@echo off
REM Quick script to fix ADB and run Flutter
echo Fixing ADB...
taskkill /F /IM adb.exe >nul 2>&1
timeout /t 2 >nul
adb start-server >nul 2>&1
timeout  /t 5 >nul
adb devices
echo.
echo Running Flutter on your device...
flutter run -d LZEAHQ5TK7NJNZTK
