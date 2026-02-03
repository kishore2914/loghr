# Flutter Doctor Fix Script
# This script helps fix common Flutter doctor issues on Windows

Write-Host "=== Flutter Doctor Fix Script ===" -ForegroundColor Cyan
Write-Host ""

# Check Android Studio Java fix
Write-Host "1. Checking Android Studio Java configuration..." -ForegroundColor Yellow
# Check Flutter configuration first, then check D: and C: drive locations
Write-Host "   [INFO] Checking Flutter configuration..." -ForegroundColor Cyan
$settingsPath = "$env:APPDATA\.flutter_settings"
$configuredPath = $null
if (Test-Path $settingsPath) {
    try {
        $settings = Get-Content $settingsPath -Raw | ConvertFrom-Json
        if ($settings.'android-studio-dir') {
            $configuredPath = $settings.'android-studio-dir'
            Write-Host "   [INFO] Flutter configured to use: $configuredPath" -ForegroundColor Cyan
        }
    } catch {
        Write-Host "   [WARNING] Could not read Flutter settings" -ForegroundColor Yellow
    }
}

# Check both D: and C: drive locations (prioritize D: drive)
$androidStudioPaths = @(
    "D:\Program Files\Android\Android Studio",
    "C:\Program Files\Android\Android Studio"
)

# Use configured path if it exists, otherwise search
if ($configuredPath -and (Test-Path $configuredPath)) {
    $androidStudioPath = $configuredPath
    Write-Host "   [INFO] Using configured Android Studio path: $androidStudioPath" -ForegroundColor Green
} else {
    $androidStudioPath = $null
    foreach ($path in $androidStudioPaths) {
        if (Test-Path $path) {
            $androidStudioPath = $path
            Write-Host "   [INFO] Found Android Studio at: $path" -ForegroundColor Cyan
            break
        }
    }
}

if (-not $androidStudioPath) {
    Write-Host "   [ERROR] Android Studio not found in standard locations" -ForegroundColor Red
    exit
}

$jrePath = "$androidStudioPath\jre"
$jbrPath = "$androidStudioPath\jbr"

if (Test-Path $jrePath) {
    $link = Get-Item $jrePath -ErrorAction SilentlyContinue
    if ($link.LinkType -eq "SymbolicLink" -or $link.LinkType -eq "Junction") {
        Write-Host "   [OK] Android Studio jre link exists ($($link.LinkType))" -ForegroundColor Green
        # Verify Java is accessible
        if (Test-Path "$jrePath\bin\java.exe") {
            Write-Host "   [OK] Java executable is accessible through link" -ForegroundColor Green
        } else {
            Write-Host "   [WARNING] Link exists but Java not accessible" -ForegroundColor Yellow
        }
    } else {
        Write-Host "   [OK] Android Studio jre folder exists" -ForegroundColor Green
    }
} else {
    Write-Host "   [FIXING] Creating jre link..." -ForegroundColor Yellow
    try {
        # Try junction first (works without admin on Windows)
        New-Item -ItemType Junction -Path $jrePath -Target $jbrPath -Force | Out-Null
        Write-Host "   [OK] Junction link created successfully" -ForegroundColor Green
    } catch {
        try {
            # Fallback to symbolic link (requires admin)
            New-Item -ItemType SymbolicLink -Path $jrePath -Target $jbrPath -Force | Out-Null
            Write-Host "   [OK] Symbolic link created successfully" -ForegroundColor Green
        } catch {
            Write-Host "   [ERROR] Failed to create link. Run as Administrator." -ForegroundColor Red
            Write-Host "   Manual fix: Run as Admin: mklink /D `"$jrePath`" `"$jbrPath`"" -ForegroundColor Yellow
        }
    }
}

# Check if Flutter can detect it
Write-Host "   [INFO] If Flutter still shows the error, try:" -ForegroundColor Cyan
Write-Host "         - Restart your terminal/IDE" -ForegroundColor White
Write-Host "         - Run: flutter doctor -v to see detailed error" -ForegroundColor White
Write-Host "         - Clear Flutter cache if needed" -ForegroundColor White

Write-Host ""

# Check Visual Studio components
Write-Host "2. Checking Visual Studio installation..." -ForegroundColor Yellow
$vsPath = "D:\Program Files\Microsoft Visual Studio\2022\Community"
$msbuildPath = "$vsPath\MSBuild\Current\Bin\MSBuild.exe"
$clPath = "$vsPath\VC\Tools\MSVC\*\bin\Hostx64\x64\cl.exe"

if (Test-Path $msbuildPath) {
    Write-Host "   [OK] MSBuild found" -ForegroundColor Green
} else {
    Write-Host "   [WARNING] MSBuild not found" -ForegroundColor Yellow
}

if ((Get-ChildItem $clPath -ErrorAction SilentlyContinue).Count -gt 0) {
    Write-Host "   [OK] MSVC Compiler found" -ForegroundColor Green
} else {
    Write-Host "   [WARNING] MSVC Compiler not found" -ForegroundColor Yellow
}

# Check Windows SDK
$windowsKitsPath = "C:\Program Files (x86)\Windows Kits\10"
if (Test-Path "$windowsKitsPath\Include") {
    Write-Host "   [OK] Windows SDK Include found" -ForegroundColor Green
} else {
    Write-Host "   [MISSING] Windows SDK not found" -ForegroundColor Red
    Write-Host ""
    Write-Host "   To fix Visual Studio issue:" -ForegroundColor Yellow
    Write-Host "   1. Open Visual Studio Installer" -ForegroundColor White
    Write-Host "   2. Click 'Modify' on Visual Studio Community 2022" -ForegroundColor White
    Write-Host "   3. Ensure 'Desktop development with C++' workload is checked" -ForegroundColor White
    Write-Host "   4. Under Individual components, ensure Windows 10/11 SDK is selected" -ForegroundColor White
    Write-Host "   5. Click 'Modify' to install" -ForegroundColor White
    Write-Host ""
}

Write-Host ""

# Check Visual Studio Installer
Write-Host "3. Checking Visual Studio Installer..." -ForegroundColor Yellow
$vsInstallerPaths = @(
    "D:\Program Files (x86)\Microsoft Visual Studio\Installer\vs_installer.exe",
    "C:\Program Files (x86)\Microsoft Visual Studio\Installer\vs_installer.exe"
)
$vsInstallerPath = $null
foreach ($path in $vsInstallerPaths) {
    if (Test-Path $path) {
        $vsInstallerPath = $path
        break
    }
}

if ($vsInstallerPath) {
    Write-Host "   [OK] Visual Studio Installer found" -ForegroundColor Green
    Write-Host ""
    Write-Host "   To complete Visual Studio installation:" -ForegroundColor Yellow
    Write-Host "   - The installer will open automatically, or run:" -ForegroundColor White
    Write-Host "     Start-Process '$vsInstallerPath'" -ForegroundColor Cyan
    Write-Host "   - Click 'Modify' on Visual Studio Community 2022" -ForegroundColor White
    Write-Host "   - Ensure 'Desktop development with C++' workload is checked" -ForegroundColor White
    Write-Host "   - Under Individual components, ensure Windows 10/11 SDK is selected" -ForegroundColor White
    Write-Host "   - Click 'Modify' to install missing components" -ForegroundColor White
    Write-Host ""
    
    $openInstaller = Read-Host "   Open Visual Studio Installer now? (Y/N)"
    if ($openInstaller -eq "Y" -or $openInstaller -eq "y") {
        Start-Process $vsInstallerPath
        Write-Host "   [OK] Visual Studio Installer opened" -ForegroundColor Green
    }
} else {
    Write-Host "   [WARNING] Visual Studio Installer not found at standard location" -ForegroundColor Yellow
    Write-Host "   Please manually open Visual Studio Installer and complete the installation" -ForegroundColor White
}

Write-Host ""
Write-Host "4. Running Flutter Doctor..." -ForegroundColor Yellow
Write-Host ""
flutter doctor

Write-Host ""
Write-Host "=== Script Complete ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Troubleshooting Tips:" -ForegroundColor Yellow
Write-Host "- If Android Studio Java issue persists:" -ForegroundColor White
Write-Host "  * Restart your terminal/IDE completely" -ForegroundColor Cyan
Write-Host "  * Close and reopen VS Code/Android Studio" -ForegroundColor Cyan
Write-Host "  * Run: flutter doctor -v for detailed diagnostics" -ForegroundColor Cyan
Write-Host "- If Visual Studio issue persists:" -ForegroundColor White
Write-Host "  * Complete installation via Visual Studio Installer" -ForegroundColor Cyan
Write-Host "  * Restart your computer after installation" -ForegroundColor Cyan
Write-Host ""

