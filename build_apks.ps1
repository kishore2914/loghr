
# Script to build optimized, installable APKs
echo "Building Split APKs (per architecture)..."
echo "This allows you to install a smaller APK directly on your device."

flutter build apk --release --split-per-abi --obfuscate --split-debug-info=./build/app/outputs/symbols

echo "Build complete!"
echo "APKs are located in: build\app\outputs\flutter-apk\"
echo "1. build\app\outputs\flutter-apk\app-arm64-v8a-release.apk (Most modern phones)"
echo "2. build\app\outputs\flutter-apk\app-armeabi-v7a-release.apk (Older phones)"
echo "3. build\app\outputs\flutter-apk\app-x86_64-release.apk (Emulators)"
