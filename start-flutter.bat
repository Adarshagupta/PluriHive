@echo off
REM Ensure ADB is running properly before starting Flutter
echo Starting ADB fix...
powershell -ExecutionPolicy Bypass -File "%~dp0fix-adb.ps1"
if %ERRORLEVEL% NEQ 0 (
    echo Failed to start ADB
    pause
    exit /b 1
)
echo.
echo ADB is ready! Starting Flutter...
echo.
REM You can now run flutter commands
cmd /k
