# Manual Fix for Android Studio Java Issue on C: Drive

## Problem
Flutter detects Android Studio at: `C:\Program Files\Android\Android Studio`
But the `jre` folder is missing (only `jbr` exists).

## Solution
Create a symbolic link from `jre` to `jbr` on the **C: drive**.

## Steps (Run as Administrator)

1. **Open PowerShell as Administrator:**
   - Right-click on PowerShell
   - Select "Run as Administrator"

2. **Run this command:**
   ```powershell
   mklink /D "C:\Program Files\Android\Android Studio\jre" "C:\Program Files\Android\Android Studio\jbr"
   ```

3. **Verify it worked:**
   ```powershell
   Test-Path "C:\Program Files\Android\Android Studio\jre\bin\java.exe"
   ```
   Should return: `True`

4. **Restart your terminal/IDE**

5. **Run Flutter Doctor:**
   ```powershell
   flutter doctor
   ```

## Alternative: Use the Script

Run the provided script as Administrator:
```powershell
Start-Process powershell -Verb RunAs -ArgumentList "-ExecutionPolicy Bypass", "-File", "D:\LogHR\fix_android_studio_c_drive.ps1"
```

## Important Note
The fix must be on **C: drive** because that's where Flutter detects Android Studio, even if you also have it on D: drive.

















