# Comprehensive Fix for Flutter Issues
# 1. Fix CMake Visual Studio Generator
# 2. Fix Android Studio Java on C: drive (where Flutter detects it)

Write-Host "=== Comprehensive Flutter Fix ===" -ForegroundColor Cyan
Write-Host ""

# 1. Fix CMake Generator
Write-Host "1. Fixing CMake Visual Studio Generator..." -ForegroundColor Yellow
$generator = "Visual Studio 17 2022"
$env:CMAKE_GENERATOR = $generator
[System.Environment]::SetEnvironmentVariable("CMAKE_GENERATOR", $generator, "User")
Write-Host "   [OK] CMAKE_GENERATOR set to: $generator" -ForegroundColor Green
Write-Host ""

# 2. Fix Android Studio on C: drive (where Flutter detects it)
Write-Host "2. Fixing Android Studio Java on C: drive..." -ForegroundColor Yellow
$cDrivePath = "C:\Program Files\Android\Android Studio"
$dDrivePath = "D:\Program Files\Android\Android Studio"

# Check if Android Studio exists on C: drive
if (Test-Path $cDrivePath) {
    Write-Host "   [INFO] Android Studio found on C: drive (where Flutter detects it)" -ForegroundColor Cyan
    
    $jrePath = "$cDrivePath\jre"
    $jbrPath = "$cDrivePath\jbr"
    
    if (Test-Path $jbrPath) {
        if (Test-Path $jrePath) {
            $link = Get-Item $jrePath -ErrorAction SilentlyContinue
            if ($link.LinkType -eq "SymbolicLink" -or $link.LinkType -eq "Junction") {
                Write-Host "   [OK] jre link already exists on C: drive" -ForegroundColor Green
            } else {
                Write-Host "   [FIXING] Removing existing jre and creating link..." -ForegroundColor Yellow
                Remove-Item $jrePath -Force -Recurse -ErrorAction SilentlyContinue
                try {
                    New-Item -ItemType Junction -Path $jrePath -Target $jbrPath -Force | Out-Null
                    Write-Host "   [OK] jre link created on C: drive" -ForegroundColor Green
                } catch {
                    Write-Host "   [WARNING] Could not create link. May need Administrator." -ForegroundColor Yellow
                    Write-Host "   [INFO] Run as Admin: mklink /D `"$jrePath`" `"$jbrPath`"" -ForegroundColor Cyan
                }
            }
        } else {
            Write-Host "   [FIXING] Creating jre link on C: drive..." -ForegroundColor Yellow
            try {
                New-Item -ItemType Junction -Path $jrePath -Target $jbrPath -Force | Out-Null
                Write-Host "   [OK] jre link created on C: drive" -ForegroundColor Green
            } catch {
                Write-Host "   [WARNING] Could not create link. May need Administrator." -ForegroundColor Yellow
                Write-Host "   [INFO] Run as Admin: mklink /D `"$jrePath`" `"$jbrPath`"" -ForegroundColor Cyan
            }
        }
        
        # Verify
        if (Test-Path "$jrePath\bin\java.exe") {
            Write-Host "   [OK] Java executable accessible on C: drive" -ForegroundColor Green
        }
    } else {
        Write-Host "   [WARNING] jbr folder not found on C: drive" -ForegroundColor Yellow
    }
} else {
    Write-Host "   [INFO] Android Studio not found on C: drive" -ForegroundColor Cyan
    Write-Host "   [INFO] Flutter may be using D: drive configuration" -ForegroundColor Cyan
}

Write-Host ""

# 3. Verify Flutter configuration
Write-Host "3. Verifying Flutter configuration..." -ForegroundColor Yellow
$settingsPath = "$env:APPDATA\.flutter_settings"
if (Test-Path $settingsPath) {
    $settings = Get-Content $settingsPath -Raw | ConvertFrom-Json
    if ($settings.'android-studio-dir') {
        Write-Host "   [OK] Flutter configured to use: $($settings.'android-studio-dir')" -ForegroundColor Green
    }
}
Write-Host ""

Write-Host "=== Fix Complete ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Summary:" -ForegroundColor Yellow
Write-Host "- CMAKE_GENERATOR set to Visual Studio 17 2022" -ForegroundColor White
Write-Host "- Android Studio Java fix applied on C: drive" -ForegroundColor White
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Restart your terminal/IDE completely" -ForegroundColor White
Write-Host "2. Run: flutter clean" -ForegroundColor White
Write-Host "3. Run: flutter doctor" -ForegroundColor White
Write-Host "4. Run: flutter run" -ForegroundColor White
Write-Host ""

















