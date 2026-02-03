# Fix CMake Visual Studio Generator Issue
# This script configures CMake to use Visual Studio 2022 instead of 2019

Write-Host "=== Fixing CMake Visual Studio Generator ===" -ForegroundColor Cyan
Write-Host ""

# Set CMAKE_GENERATOR to Visual Studio 17 2022
$generator = "Visual Studio 17 2022"
Write-Host "[INFO] Setting CMAKE_GENERATOR to: $generator" -ForegroundColor Yellow

# Set for current session
$env:CMAKE_GENERATOR = $generator
Write-Host "[OK] CMAKE_GENERATOR set for current session" -ForegroundColor Green

# Set permanently in user environment
[System.Environment]::SetEnvironmentVariable("CMAKE_GENERATOR", $generator, "User")
Write-Host "[OK] CMAKE_GENERATOR set permanently in user environment" -ForegroundColor Green

# Verify Visual Studio 2022 exists
$vs2022Path = "D:\Program Files\Microsoft Visual Studio\2022\Community"
if (Test-Path $vs2022Path) {
    Write-Host "[OK] Visual Studio 2022 found at: $vs2022Path" -ForegroundColor Green
} else {
    Write-Host "[WARNING] Visual Studio 2022 not found at expected location" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=== Configuration Complete ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Restart your terminal/IDE" -ForegroundColor White
Write-Host "2. Run: flutter clean" -ForegroundColor White
Write-Host "3. Run: flutter run" -ForegroundColor White
Write-Host ""

















