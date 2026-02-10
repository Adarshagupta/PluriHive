@echo off
REM Stop O+Connect to prevent ADB conflicts
taskkill /F /IM "O+Connect.exe" /T >nul 2>&1
taskkill /F /IM "oplus_remote_service.exe" /T >nul 2>&1
taskkill /F /IM "oplus_remote_ui.exe" /T >nul 2>&1
taskkill /F /IM "adb.exe" /T >nul 2>&1

echo Waiting for ADB...
timeout /t 3 >nul

REM Start ADB and run Flutter
"%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe" start-server
flutter run -d %1 --dart-define=MAPBOX_ACCESS_TOKEN=pk.eyJ1Ijoic3lsaWNhYWkiLCJhIjoiY21rd3UwcGtvMDFmdDNqcjBhdzc4ejEyaCJ9.yKkADo8N37hnMeJS44VBRQ

echo.
echo Press any key to restart O+Connect...
pause >nul
start "" "C:\Program Files\O+Connect\O+Connect.exe"
