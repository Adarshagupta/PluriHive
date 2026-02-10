@echo off
REM ================================================
REM   EMERGENCY FIX - Install APK Without ADB
REM ================================================
echo.
echo Your app was built successfully!
echo APK Location: build\app\outputs\flutter-apk\app-debug.apk
echo.
echo ================================================
echo   Choose Installation Method:
echo ================================================
echo.
echo 1) Copy APK to phone via File Explorer
echo    - Connect phone via USB
echo    - Open File Explorer
echo    - Browse to phone storage
echo    - Copy app-debug.apk to Downloads folder
echo    - On phone: tap the APK to install
echo.
echo 2) Open File Explorer to APK location now
echo.
choice /C 12 /N /M "Select option (1 or 2): "

if errorlevel 2 goto openexplorer
if errorlevel 1 goto instructions

:instructions
echo.
echo Opening APK location...
explorer.exe /select,"%~dp0build\app\outputs\flutter-apk\app-debug.apk"
echo.
echo INSTRUCTIONS:
echo 1. Copy app-debug.apk to your phone's Downloads folder
echo 2. On your phone, open Files/Downloads
echo 3. Tap app-debug.apk
echo 4. Allow "Install Unknown Apps" if prompted
echo 5. Tap Install
echo.
goto end

:openexplorer
echo.
echo Opening APK location...
explorer.exe /select,"%~dp0build\app\outputs\flutter-apk\app-debug.apk"
echo.
echo Copy the APK file to your phone and install it manually.
echo.

:end
pause
