#!/bin/bash
# Build script for T2BoysSN-Changer
set -e

echo "=== T2BoysSN-Changer Build Script ==="
cd "$(dirname "$0")"

# Check for Xcode Command Line Tools
if ! command -v xcodebuild &> /dev/null; then
    echo "Error: Xcode Command Line Tools not installed"
    echo "Run: xcode-select --install"
    exit 1
fi

# Clone and build ORSSerialPort if not present
if [ ! -d "ORSSerial.framework" ]; then
    echo ">>> Building ORSSerialPort dependency..."

    # Clean up any previous attempts
    rm -rf ORSSerialPort_src 2>/dev/null || true

    git clone --depth 1 https://github.com/armadsen/ORSSerialPort.git ORSSerialPort_src

    # The xcodeproj is inside "Framework Project" subdirectory
    cd "ORSSerialPort_src/Framework Project"

    xcodebuild -project ORSSerialPort.xcodeproj \
               -scheme "ORSSerial" \
               -configuration Release \
               -derivedDataPath build \
               ONLY_ACTIVE_ARCH=NO \
               BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
               MACOSX_DEPLOYMENT_TARGET=10.14

    # Copy framework to our directory
    cp -R build/Build/Products/Release/ORSSerial.framework ../../
    cd ../..

    # Clean up source
    rm -rf ORSSerialPort_src

    echo ">>> ORSSerialPort built successfully"
fi

# Verify framework exists
if [ ! -d "ORSSerial.framework" ]; then
    echo "Error: ORSSerial.framework not found"
    exit 1
fi

# Compile the application
echo ">>> Compiling T2BoysSN-Changer..."
clang -fobjc-arc \
      -framework Cocoa \
      -framework IOKit \
      -framework Security \
      -F . \
      -framework ORSSerial \
      -rpath @executable_path/../Frameworks \
      -rpath @executable_path \
      -rpath "$(pwd)" \
      -o T2BoysSN-Changer \
      main.m \
      AppDelegate.m \
      ViewController.m \
      EncryptionUtility.m \
      Encryption.m

echo ">>> Build successful!"
echo ""
echo "To run: ./T2BoysSN-Changer"
echo "Or create an app bundle with: ./build.sh --bundle"

# Create app bundle if requested
if [ "$1" == "--bundle" ]; then
    echo ""
    echo ">>> Creating app bundle..."

    APP="T2BoysSN-Changer.app"
    rm -rf "$APP"

    mkdir -p "$APP/Contents/MacOS"
    mkdir -p "$APP/Contents/Frameworks"
    mkdir -p "$APP/Contents/Resources"

    cp T2BoysSN-Changer "$APP/Contents/MacOS/"
    cp -R ORSSerial.framework "$APP/Contents/Frameworks/"

    # Copy Resources if they exist
    RESOURCES_DIR="../Resources"
    if [ -d "$RESOURCES_DIR" ]; then
        echo ">>> Copying Resources..."

        # Copy app icon
        [ -f "$RESOURCES_DIR/AppIcon.icns" ] && cp "$RESOURCES_DIR/AppIcon.icns" "$APP/Contents/Resources/"

        # Copy storyboard
        [ -d "$RESOURCES_DIR/Main.storyboardc" ] && cp -R "$RESOURCES_DIR/Main.storyboardc" "$APP/Contents/Resources/"

        # Copy RES folder (contains binaries and bootchains)
        [ -d "$RESOURCES_DIR/RES" ] && cp -R "$RESOURCES_DIR/RES" "$APP/Contents/Resources/"

        # Copy macserial
        [ -f "$RESOURCES_DIR/macserial" ] && cp "$RESOURCES_DIR/macserial" "$APP/Contents/Resources/"

        # Copy asset catalog
        [ -f "$RESOURCES_DIR/Assets.car" ] && cp "$RESOURCES_DIR/Assets.car" "$APP/Contents/Resources/"
    fi

    # Fix framework path
    install_name_tool -change \
        "@rpath/ORSSerial.framework/Versions/A/ORSSerial" \
        "@executable_path/../Frameworks/ORSSerial.framework/Versions/A/ORSSerial" \
        "$APP/Contents/MacOS/T2BoysSN-Changer" 2>/dev/null || true

    # Create Info.plist
    cat > "$APP/Contents/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>T2BoysSN-Changer</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.t2boys.sn-changer</string>
    <key>CFBundleName</key>
    <string>T2Boys SN Changer</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>10.14</string>
    <key>NSMainStoryboardFile</key>
    <string>Main</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
PLIST

    # Ad-hoc sign
    codesign --force --deep --sign - "$APP" 2>/dev/null || true

    echo ">>> App bundle created: $APP"
    echo ">>> Run with: open $APP"
fi
