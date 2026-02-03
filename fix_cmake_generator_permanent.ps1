# Permanent Fix for CMake Visual Studio Generator
# This ensures Flutter uses Visual Studio 2022 instead of 2019

Write-Host "=== Fixing CMake Generator Permanently ===" -ForegroundColor Cyan
Write-Host ""

# 1. Set environment variable for current session
$generator = "Visual Studio 17 2022"
$env:CMAKE_GENERATOR = $generator
Write-Host "[OK] CMAKE_GENERATOR set for current session: $generator" -ForegroundColor Green

# 2. Set permanently in user environment
[System.Environment]::SetEnvironmentVariable("CMAKE_GENERATOR", $generator, "User")
Write-Host "[OK] CMAKE_GENERATOR set permanently in user environment" -ForegroundColor Green

# 3. Clear Flutter build cache
Write-Host ""
Write-Host "[INFO] Clearing Flutter build cache..." -ForegroundColor Yellow
if (Test-Path "build\windows") {
    Remove-Item "build\windows" -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "[OK] Build cache cleared" -ForegroundColor Green
} else {
    Write-Host "[INFO] No build cache to clear" -ForegroundColor Cyan
}

# 4. Run flutter clean
Write-Host "[INFO] Running flutter clean..." -ForegroundColor Yellow
flutter clean 2>&1 | Out-Null
Write-Host "[OK] Flutter clean completed" -ForegroundColor Green

Write-Host ""
Write-Host "=== Fix Complete ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "The CMAKE_GENERATOR is now set to: $generator" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. The environment variable is set for this session" -ForegroundColor White
Write-Host "2. Restart your terminal/IDE to load the permanent setting" -ForegroundColor White
Write-Host "3. Run: flutter run -d windows" -ForegroundColor White
Write-Host ""
Write-Host "Note: If you still see the error, make sure to:" -ForegroundColor Yellow
Write-Host "- Close and reopen your terminal/IDE completely" -ForegroundColor White
Write-Host "- Verify with: `$env:CMAKE_GENERATOR" -ForegroundColor White
Write-Host ""

















