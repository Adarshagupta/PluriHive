# ADB Complete Reinstall and Fix Script
# This script completely reinstalls ADB platform tools

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "  ADB Complete Reinstall & Fix" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: Kill all ADB processes
Write-Host "[1/6] Stopping all ADB processes..." -ForegroundColor Yellow
Get-Process adb -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2

# Step 2: Check current ADB path
$adbPath = "C:\Users\adasg\AppData\Local\Android\Sdk\platform-tools"
$backupPath = "C:\Users\adasg\AppData\Local\Android\Sdk\platform-tools-backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"

Write-Host "[2/6] Backing up current platform-tools..." -ForegroundColor Yellow
if (Test-Path $adbPath) {
    try {
        Copy-Item -Path $adbPath -Destination $backupPath -Recurse -Force
        Write-Host "  Backup created at: $backupPath" -ForegroundColor Green
    } catch {
        Write-Host "  Warning: Could not create backup: $_" -ForegroundColor Yellow
    }
}

# Step 3: Download fresh platform tools
Write-Host "[3/6] Downloading latest Android Platform Tools..." -ForegroundColor Yellow
$downloadUrl = "https://dl.google.com/android/repository/platform-tools-latest-windows.zip"
$tempZip = "$env:TEMP\platform-tools-latest.zip"
$tempExtract = "$env:TEMP\platform-tools-extract"

try {
    # Download
    Write-Host "  Downloading from Google..." -ForegroundColor Gray
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri $downloadUrl -OutFile $tempZip -UseBasicParsing
    Write-Host "  Downloaded successfully" -ForegroundColor Green
    
    # Extract
    Write-Host "  Extracting..." -ForegroundColor Gray
    if (Test-Path $tempExtract) { Remove-Item $tempExtract -Recurse -Force }
    Expand-Archive -Path $tempZip -DestinationPath $tempExtract -Force
    
    # Install
    Write-Host "[4/6] Installing fresh platform tools..." -ForegroundColor Yellow
    if (Test-Path $adbPath) {
        Remove-Item $adbPath -Recurse -Force
    }
    Move-Item -Path "$tempExtract\platform-tools" -Destination $adbPath -Force
    Write-Host "  Installation complete" -ForegroundColor Green
    
    # Cleanup
    Remove-Item $tempZip -Force -ErrorAction SilentlyContinue
    Remove-Item $tempExtract -Recurse -Force -ErrorAction SilentlyContinue
    
} catch {
    Write-Host "  Error during download/install: $_" -ForegroundColor Red
    Write-Host "  Continuing with existing ADB..." -ForegroundColor Yellow
}

# Step 5: Configure environment and start ADB
Write-Host "[5/6] Configuring and starting ADB..." -ForegroundColor Yellow
$env:ADB_LIBUSB = "0"
$env:ADB_SERVER_SOCKET = ""

Start-Sleep -Seconds 3

# Use cmd to avoid PowerShell stderr issues
Write-Host "  Starting ADB server..." -ForegroundColor Gray
$null = cmd /c "adb start-server 2>&1" 2>&1
Start-Sleep -Seconds 6

# Step 6: Verify
Write-Host "[6/6] Verifying installation..." -ForegroundColor Yellow
$version = cmd /c "adb version 2>&1" 2>&1 | Out-String
if ($version -match "Android Debug Bridge version") {
    Write-Host "  ADB Version:" -ForegroundColor Gray
    $version -split "`n" | Select-Object -First 3 | ForEach-Object { Write-Host "    $_" -ForegroundColor White }
    
    Write-Host ""
    Write-Host "  Checking devices..." -ForegroundColor Gray
    $devices = cmd /c "adb devices 2>&1" 2>&1 | Out-String
    Write-Host $devices
    
    Write-Host ""
    Write-Host "================================================" -ForegroundColor Green
    Write-Host "  Success: ADB Reinstall Complete!" -ForegroundColor Green
    Write-Host "================================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "You can now run: flutter devices" -ForegroundColor Cyan
    Write-Host "Or run your app with: flutter run" -ForegroundColor Cyan
} else {
    Write-Host ""
    Write-Host "================================================" -ForegroundColor Red
    Write-Host "  Error: ADB Installation Failed" -ForegroundColor Red
    Write-Host "================================================" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please try:" -ForegroundColor Yellow
    Write-Host "1. Run this script as Administrator" -ForegroundColor White
    Write-Host "2. Temporarily disable antivirus" -ForegroundColor White
    Write-Host "3. Check Windows Defender settings" -ForegroundColor White
    Write-Host "4. Restore backup from: $backupPath" -ForegroundColor White
}
