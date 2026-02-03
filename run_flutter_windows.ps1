# Script to run Flutter on Windows with correct CMake generator
# This ensures Visual Studio 2022 is used

Write-Host "=== Running Flutter on Windows with VS 2022 ===" -ForegroundColor Cyan
Write-Host ""

# Set CMake generator environment variables
$env:CMAKE_GENERATOR = "Visual Studio 17 2022"
$env:CMAKE_GENERATOR_PLATFORM = "x64"

Write-Host "[OK] CMAKE_GENERATOR set to: $env:CMAKE_GENERATOR" -ForegroundColor Green
Write-Host "[OK] CMAKE_GENERATOR_PLATFORM set to: $env:CMAKE_GENERATOR_PLATFORM" -ForegroundColor Green
Write-Host ""

# Clear build cache if it exists with wrong generator
if (Test-Path "build\windows\x64\CMakeCache.txt") {
    $cacheContent = Get-Content "build\windows\x64\CMakeCache.txt" -Raw
    if ($cacheContent -match "Visual Studio 16 2019") {
        Write-Host "[INFO] Clearing build cache with old generator..." -ForegroundColor Yellow
        Remove-Item "build\windows" -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "[OK] Build cache cleared" -ForegroundColor Green
    }
}

Write-Host "[INFO] Running Flutter..." -ForegroundColor Yellow
Write-Host ""

# Run Flutter
flutter run -d windows

















