@echo off
setlocal enabledelayedexpansion

echo ========================================
echo Getting SHA-1 Fingerprint for Google Sign-In
echo ========================================
echo.

REM Try to find keytool
set KEYTOOL_PATH=

where keytool >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    set KEYTOOL_PATH=keytool
    goto :run_keytool
)

if exist "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe" (
    set KEYTOOL_PATH="C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe"
    goto :run_keytool
)

for /d %%i in ("C:\Program Files\Java\jdk*") do (
    if exist "%%i\bin\keytool.exe" (
        set KEYTOOL_PATH="%%i\bin\keytool.exe"
        goto :run_keytool
    )
)

echo ERROR: Could not find keytool!
pause
exit /b 1

:run_keytool
echo Using keytool: %KEYTOOL_PATH%
echo.

if not exist "%USERPROFILE%\.android\debug.keystore" (
    echo ERROR: Debug keystore not found at %USERPROFILE%\.android\debug.keystore
    pause
    exit /b 1
)

echo Extracting SHA-1 fingerprint...
echo.
echo ========================================
echo YOUR SHA-1 FINGERPRINT:
echo ========================================

REM Extract just the SHA1 line
%KEYTOOL_PATH% -list -v -keystore "%USERPROFILE%\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android 2>nul | findstr /C:"SHA1:"

echo.
echo ========================================
echo.
echo Copy the SHA1 value above (after "SHA1: ")
echo Use it in Google Cloud Console for Android OAuth client
echo.
echo Package name: com.example.territory_fitness
echo.
echo ========================================
echo Full Certificate Details:
echo ========================================
%KEYTOOL_PATH% -list -v -keystore "%USERPROFILE%\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android 2>nul

echo.
echo ========================================
pause
