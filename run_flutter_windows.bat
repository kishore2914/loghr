@echo off
REM Wrapper script to run Flutter with Visual Studio 2022
REM This ensures CMAKE_GENERATOR is set before Flutter runs

set CMAKE_GENERATOR=Visual Studio 17 2022
set CMAKE_GENERATOR_PLATFORM=x64

echo [INFO] CMAKE_GENERATOR set to: %CMAKE_GENERATOR%
echo [INFO] CMAKE_GENERATOR_PLATFORM set to: %CMAKE_GENERATOR_PLATFORM%
echo.

REM Clear build cache if it has wrong generator
if exist "build\windows\x64\CMakeCache.txt" (
    findstr /C:"Visual Studio 16 2019" "build\windows\x64\CMakeCache.txt" >nul 2>&1
    if %errorlevel% == 0 (
        echo [INFO] Clearing build cache with old generator...
        rmdir /s /q "build\windows" 2>nul
        echo [OK] Build cache cleared
    )
)

echo [INFO] Running Flutter...
echo.

flutter run -d windows

















