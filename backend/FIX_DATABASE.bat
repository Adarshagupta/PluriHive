@echo off
echo ========================================
echo Database Fix Script for Windows
echo ========================================
echo.

cd /d "%~dp0"

echo Checking for Node.js...
where node >nul 2>nul
if %errorlevel% neq 0 (
    echo ERROR: Node.js is not installed or not in PATH
    echo Please install Node.js from https://nodejs.org/
    echo.
    pause
    exit /b 1
)

echo Node.js found!
echo.

echo Running database fix script...
echo.
node fix-database.js

if %errorlevel% equ 0 (
    echo.
    echo ========================================
    echo SUCCESS! Database has been fixed.
    echo ========================================
    echo.
    echo You can now restart your backend server with:
    echo    npm start
    echo.
) else (
    echo.
    echo ========================================
    echo ERROR: Database fix failed!
    echo ========================================
    echo.
    echo Please try one of these alternatives:
    echo.
    echo 1. Run TypeORM migration:
    echo    npm run migration:run
    echo.
    echo 2. Connect to PostgreSQL and run fix-user-columns.sql
    echo    psql -U postgres -d plurihive -f fix-user-columns.sql
    echo.
    echo 3. Manually run this SQL in pgAdmin or any PostgreSQL client:
    echo    ALTER TABLE "users" ADD COLUMN IF NOT EXISTS "currentStreak" integer NOT NULL DEFAULT 0;
    echo    ALTER TABLE "users" ADD COLUMN IF NOT EXISTS "longestStreak" integer NOT NULL DEFAULT 0;
    echo    ALTER TABLE "users" ADD COLUMN IF NOT EXISTS "lastActiveDate" date;
    echo    ALTER TABLE "users" ADD COLUMN IF NOT EXISTS "streakFreezes" integer NOT NULL DEFAULT 1;
    echo    ALTER TABLE "users" ADD COLUMN IF NOT EXISTS "lastFreezeGrantDate" date;
    echo.
)

pause
