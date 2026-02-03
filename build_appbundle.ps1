
# Helper script to build Android App Bundle
echo "Building Android App Bundle (AAB)..."
echo "This may take a few minutes."

flutter build appbundle --release --obfuscate --split-debug-info=./build/app/outputs/symbols

echo "Build complete!"
echo "App Bundle is located at: build\app\outputs\bundle\release\app-release.aab"
echo "Upload this file to the Google Play Console."
