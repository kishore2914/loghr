# Fix Android Studio Java on C: Drive
# Run this script as Administrator

$androidStudioPath = "C:\Program Files\Android\Android Studio"
$jrePath = "$androidStudioPath\jre"
$jbrPath = "$androidStudioPath\jbr"

Write-Host "=== Fixing Android Studio Java on C: Drive ===" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path $androidStudioPath)) {
    Write-Host "[ERROR] Android Studio not found at: $androidStudioPath" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $jbrPath)) {
    Write-Host "[ERROR] jbr folder not found at: $jbrPath" -ForegroundColor Red
    exit 1
}

Write-Host "[INFO] Android Studio found at: $androidStudioPath" -ForegroundColor Green
Write-Host "[INFO] jbr folder found at: $jbrPath" -ForegroundColor Green
Write-Host ""

if (Test-Path $jrePath) {
    $existing = Get-Item $jrePath -ErrorAction SilentlyContinue
    if ($existing.LinkType -eq "SymbolicLink" -or $existing.LinkType -eq "Junction") {
        Write-Host "[OK] jre link already exists ($($existing.LinkType))" -ForegroundColor Green
        Write-Host "     Target: $($existing.Target)" -ForegroundColor Cyan
    } else {
        Write-Host "[WARNING] jre exists but is not a link. Removing..." -ForegroundColor Yellow
        Remove-Item $jrePath -Force -Recurse -ErrorAction SilentlyContinue
        Write-Host "[INFO] Creating symbolic link..." -ForegroundColor Yellow
        New-Item -ItemType SymbolicLink -Path $jrePath -Target $jbrPath -Force | Out-Null
        Write-Host "[OK] Symbolic link created successfully" -ForegroundColor Green
    }
} else {
    Write-Host "[FIXING] Creating jre symbolic link..." -ForegroundColor Yellow
    try {
        New-Item -ItemType SymbolicLink -Path $jrePath -Target $jbrPath -Force | Out-Null
        Write-Host "[OK] Symbolic link created successfully" -ForegroundColor Green
    } catch {
        Write-Host "[ERROR] Failed to create symbolic link: $_" -ForegroundColor Red
        Write-Host "[INFO] Try running as Administrator or use: mklink /D `"$jrePath`" `"$jbrPath`"" -ForegroundColor Yellow
        exit 1
    }
}

# Verify
Write-Host ""
Write-Host "[VERIFYING] Checking Java executable..." -ForegroundColor Yellow
if (Test-Path "$jrePath\bin\java.exe") {
    Write-Host "[OK] Java executable is accessible" -ForegroundColor Green
    $javaVersion = & "$jrePath\bin\java.exe" -version 2>&1 | Select-Object -First 1
    Write-Host "     Version: $javaVersion" -ForegroundColor Cyan
} else {
    Write-Host "[ERROR] Java executable not accessible through link" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "=== Fix Complete ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Restart your terminal/IDE" -ForegroundColor White
Write-Host "2. Run: flutter doctor" -ForegroundColor White
Write-Host ""

















