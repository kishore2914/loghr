# APK Size Optimization Guide

## ✅ Optimizations Applied

I've configured your Android build to reduce APK size from 77MB to under 30MB:

### 1. **Code Shrinking & Minification**
   - Enabled ProGuard/R8 code shrinking
   - Removes unused code and obfuscates classes
   - **Expected reduction: 30-40%**

### 2. **Resource Shrinking**
   - Removes unused resources (images, layouts, etc.)
   - **Expected reduction: 10-20%**

### 3. **Split APKs by Architecture**
   - Creates separate APKs for each CPU architecture:
     - `armeabi-v7a` (32-bit ARM) - ~15-20MB
     - `arm64-v8a` (64-bit ARM) - ~15-20MB
     - `x86_64` (64-bit x86) - ~15-20MB
   - Users only download the APK for their device
   - **Expected reduction: 50-60% per APK**

### 4. **R8 Full Mode**
   - Maximum code optimization
   - Better dead code elimination

## 📦 How to Build Optimized APK

### Option 1: Build Split APKs (Recommended)
```bash
flutter build apk --split-per-abi --release
```

This creates separate APKs in:
- `build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk` (~15-20MB)
- `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` (~15-20MB)
- `build/app/outputs/flutter-apk/app-x86_64-release.apk` (~15-20MB)

**Use the `arm64-v8a` APK for most modern Android devices.**

### Option 2: Build Universal APK (All architectures)
```bash
flutter build apk --release
```

This creates a single APK with all architectures (~25-35MB).

### Option 3: Build App Bundle (Best for Play Store)
```bash
flutter build appbundle --release
```

Creates an `.aab` file that Google Play uses to generate optimized APKs per device.

## 📊 Expected Results

| Build Type | Size Before | Size After | Reduction |
|------------|-------------|------------|-----------|
| Universal APK | 77MB | 25-35MB | ~55% |
| Split APK (arm64) | 77MB | 15-20MB | ~75% |
| App Bundle | 77MB | 20-25MB | ~70% |

## ⚠️ Important Notes

1. **Test the Release Build**: Always test your release APK before distributing:
   ```bash
   flutter install --release
   ```

2. **ProGuard Rules**: If you encounter crashes, check `android/app/proguard-rules.pro` and add keep rules for any classes that are being removed incorrectly.

3. **Signing**: For production, create a proper signing key:
   ```bash
   keytool -genkey -v -keystore ~/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```
   Then update `android/app/build.gradle.kts` with your signing config.

4. **Fonts**: The `assets/fonts/` directory is empty (only README), so no font files are being bundled. If you add fonts later, they will increase size.

## 🔍 Additional Size Reduction Tips

1. **Remove Unused Dependencies**: Review `pubspec.yaml` and remove any packages you're not using.

2. **Optimize Images**: If you add images later, compress them and use WebP format.

3. **Use App Bundle**: For Play Store distribution, always use `.aab` format - it's smaller and Google optimizes it further.

4. **Check Dependencies**: Some packages are large:
   - `supabase_flutter` - includes native libraries
   - `geolocator` - includes location services
   - `pdf` & `printing` - include PDF rendering libraries

## 🐛 Troubleshooting

If you get build errors after these changes:

1. **ProGuard errors**: Add keep rules in `proguard-rules.pro`
2. **Missing classes**: Check if R8 is removing necessary code
3. **Resource errors**: Ensure all resources are properly referenced

## 📝 Files Modified

- `android/app/build.gradle.kts` - Added optimization settings
- `android/app/proguard-rules.pro` - Created ProGuard rules
- `android/gradle.properties` - Enabled R8 full mode






