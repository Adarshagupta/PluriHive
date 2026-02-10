# ADB Permanent Fix Script
# This script ensures ADB runs reliably

Write-Host "=== ADB Permanent Fix ===" -ForegroundColor Cyan

# Kill all ADB processes
Write-Host "`nStep 1: Cleaning up existing ADB processes..." -ForegroundColor Yellow
Get-Process adb -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2

# Clear ADB server socket
Write-Host "Step 2: Clearing ADB environment..." -ForegroundColor Yellow
$env:ADB_SERVER_SOCKET = ''
$env:ADB_LIBUSB = '0'  # Disable libusb which can cause issues

# Kill any process using port 5037
Write-Host "Step 3: Checking port 5037..." -ForegroundColor Yellow
$port5037 = netstat -ano | findstr ":5037" | findstr "LISTENING"
if ($port5037) {
    $pid = ($port5037 -split '\s+')[-1]
    Write-Host "  Found process $pid using port 5037, killing it..." -ForegroundColor Gray
    Stop-Process -Id $pid -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
}

# Start ADB server with retry logic
Write-Host "Step 4: Starting ADB server..." -ForegroundColor Yellow
$maxRetries = 3
$retryCount = 0
$success = $false

while (-not $success -and $retryCount -lt $maxRetries) {
    $retryCount++
    Write-Host "  Attempt $retryCount of $maxRetries..." -ForegroundColor Gray
    
    try {
        # Use cmd to avoid PowerShell treating stderr as errors
        $null = cmd /c "adb start-server 2>&1" 2>&1
        Start-Sleep -Seconds 6
        
        # Verify ADB is running
        $devices = cmd /c "adb devices 2>&1" 2>&1 | Out-String
        if ($devices -match "List of devices attached") {
            $success = $true
            Write-Host "  ADB server started successfully!" -ForegroundColor Green
        } else {
            Write-Host "  Devices output: $devices" -ForegroundColor Gray
        }
    }
    catch {
        Write-Host "  Retry $retryCount failed: $_" -ForegroundColor Red
        Start-Sleep -Seconds 2
    }
}

if (-not $success) {
    Write-Host "`n❌ Failed to start ADB server after $maxRetries attempts" -ForegroundColor Red
    Write-Host "Please try reinstalling Android SDK Platform Tools" -ForegroundColor Yellow
    exit 1
}

# List connected devices
Write-Host "`nStep 5: Checking connected devices..." -ForegroundColor Yellow
$deviceList = cmd /c "adb devices -l 2>&1" 2>&1 | Out-String
Write-Host $deviceList

Write-Host "`n✅ ADB Fix Complete!" -ForegroundColor Green
Write-Host "`nYou can now run: flutter devices" -ForegroundColor Cyan
