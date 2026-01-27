
# Database Fix Script for Windows PowerShell
# Run this script to automatically fix the missing database columns

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Database Fix Script" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Change to script directory
Set-Location $PSScriptRoot

# Check for Node.js
Write-Host "Checking for Node.js..." -ForegroundColor Yellow
try {
    $nodeVersion = node --version
    Write-Host "✓ Node.js found: $nodeVersion" -ForegroundColor Green
    Write-Host ""
} catch {
    Write-Host "✗ ERROR: Node.js is not installed or not in PATH" -ForegroundColor Red
    Write-Host "Please install Node.js from https://nodejs.org/" -ForegroundColor Yellow
    Write-Host ""
    Read-Host "Press Enter to exit"
    exit 1
}

# Check if .env exists
if (-Not (Test-Path ".env")) {
    Write-Host "✗ WARNING: .env file not found!" -ForegroundColor Yellow
    Write-Host "Make sure you have a .env file with your database credentials" -ForegroundColor Yellow
    Write-Host ""
}

# Run the database fix script
Write-Host "Running database fix script..." -ForegroundColor Yellow
Write-Host ""

try {
    node fix-database.js

    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "========================================" -ForegroundColor Green
        Write-Host "SUCCESS! Database has been fixed." -ForegroundColor Green
        Write-Host "========================================" -ForegroundColor Green
        Write-Host ""
        Write-Host "You can now restart your backend server with:" -ForegroundColor Cyan
        Write-Host "   npm start" -ForegroundColor White
        Write-Host ""
    } else {
        throw "Script returned error code: $LASTEXITCODE"
    }
} catch {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Red
    Write-Host "ERROR: Database fix failed!" -ForegroundColor Red
    Write-Host "========================================" -ForegroundColor Red
    Write-Host ""
    Write-Host "Error details: $_" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please try one of these alternatives:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "1. Run TypeORM migration:" -ForegroundColor Cyan
    Write-Host "   npm run migration:run" -ForegroundColor White
    Write-Host ""
    Write-Host "2. Connect to PostgreSQL and run fix-user-columns.sql:" -ForegroundColor Cyan
    Write-Host "   psql -U postgres -d plurihive -f fix-user-columns.sql" -ForegroundColor White
    Write-Host ""
    Write-Host "3. Manually run this SQL in pgAdmin or any PostgreSQL client:" -ForegroundColor Cyan
    Write-Host '   ALTER TABLE "users" ADD COLUMN IF NOT EXISTS "currentStreak" integer NOT NULL DEFAULT 0;' -ForegroundColor White
    Write-Host '   ALTER TABLE "users" ADD COLUMN IF NOT EXISTS "longestStreak" integer NOT NULL DEFAULT 0;' -ForegroundColor White
    Write-Host '   ALTER TABLE "users" ADD COLUMN IF NOT EXISTS "lastActiveDate" date;' -ForegroundColor White
    Write-Host '   ALTER TABLE "users" ADD COLUMN IF NOT EXISTS "streakFreezes" integer NOT NULL DEFAULT 1;' -ForegroundColor White
    Write-Host '   ALTER TABLE "users" ADD COLUMN IF NOT EXISTS "lastFreezeGrantDate" date;' -ForegroundColor White
    Write-Host ""
}

Write-Host ""
Read-Host "Press Enter to exit"
