# Configure Flutter to use Android Studio from D: Drive
# This script updates Flutter's configuration to point to D: drive

Write-Host "=== Configuring Flutter to use D: Drive Android Studio ===" -ForegroundColor Cyan
Write-Host ""

$androidStudioPath = "D:\Program Files\Android\Android Studio"
$settingsPath = "$env:APPDATA\.flutter_settings"

# Verify Android Studio exists on D: drive
if (-not (Test-Path $androidStudioPath)) {
    Write-Host "[ERROR] Android Studio not found at: $androidStudioPath" -ForegroundColor Red
    exit 1
}

Write-Host "[OK] Android Studio found at: $androidStudioPath" -ForegroundColor Green
Write-Host ""

# Read existing settings
if (Test-Path $settingsPath) {
    Write-Host "[INFO] Reading existing Flutter settings..." -ForegroundColor Yellow
    $settings = Get-Content $settingsPath -Raw | ConvertFrom-Json
} else {
    Write-Host "[INFO] Creating new Flutter settings file..." -ForegroundColor Yellow
    $settings = @{} | ConvertTo-Json | ConvertFrom-Json
}

# Update Android Studio directory
$settings | Add-Member -MemberType NoteProperty -Name "android-studio-dir" -Value $androidStudioPath -Force

# Save settings
$settings | ConvertTo-Json | Set-Content $settingsPath

Write-Host "[OK] Flutter settings updated successfully" -ForegroundColor Green
Write-Host ""
Write-Host "Updated settings:" -ForegroundColor Cyan
Get-Content $settingsPath
Write-Host ""

# Also try Flutter config command
Write-Host "[INFO] Running Flutter config command..." -ForegroundColor Yellow
flutter config --android-studio-dir $androidStudioPath 2>&1 | Out-Null

Write-Host ""
Write-Host "=== Configuration Complete ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Restart your terminal/IDE" -ForegroundColor White
Write-Host "2. Run: flutter doctor" -ForegroundColor White
Write-Host "3. Flutter should now detect Android Studio from D: drive" -ForegroundColor White
Write-Host ""

















