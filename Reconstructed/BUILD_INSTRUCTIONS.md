# Build Instructions for TheT2BoysSN-Changer

## Prerequisites

- macOS 10.14+ (Mojave or later)
- Xcode 12+ with Command Line Tools
- CocoaPods or Swift Package Manager (for ORSSerialPort)

---

## Option 1: Xcode Project (Recommended)

### Step 1: Create New Xcode Project

1. Open Xcode
2. File → New → Project
3. Select **macOS** → **App**
4. Configure:
   - Product Name: `T2BoysSN-Changer`
   - Team: Your development team
   - Organization Identifier: `com.yourname`
   - Interface: **XIB** (not SwiftUI/Storyboard)
   - Language: **Objective-C**
5. Save to desired location

### Step 2: Add Source Files

1. Delete the auto-generated `ViewController.h/m` and `AppDelegate.h/m`
2. Drag all `.h` and `.m` files from `Reconstructed/` into the project
3. Make sure "Copy items if needed" is checked

### Step 3: Install ORSSerialPort via CocoaPods

Create a `Podfile` in your project directory:

```ruby
platform :osx, '10.14'

target 'T2BoysSN-Changer' do
  use_frameworks!
  pod 'ORSSerialPort', '~> 2.1'
end
```

Then run:
```bash
pod install
```

Open the `.xcworkspace` file (not `.xcodeproj`) after installation.

### Step 4: Configure Build Settings

In Xcode, select your target and go to **Build Settings**:

1. Set **Header Search Paths** to include `$(PODS_ROOT)/ORSSerialPort`
2. Ensure these frameworks are linked (Build Phases → Link Binary):
   - `Cocoa.framework`
   - `IOKit.framework`
   - `Security.framework`

### Step 5: Build & Run

Press `Cmd+B` to build or `Cmd+R` to build and run.

---

## Option 2: Command Line (Without Xcode Project)

### Step 1: Install ORSSerialPort

```bash
# Clone ORSSerialPort
cd /Users/rhcp/SN_CHANGE/Reconstructed
git clone https://github.com/armadsen/ORSSerialPort.git

# Build the framework
cd ORSSerialPort
xcodebuild -project ORSSerialPort.xcodeproj \
           -scheme "ORSSerial-Mac" \
           -configuration Release \
           -derivedDataPath build \
           ONLY_ACTIVE_ARCH=NO

# Copy framework to our directory
cp -R build/Build/Products/Release/ORSSerial.framework ../
cd ..
```

### Step 2: Compile with clang

```bash
cd /Users/rhcp/SN_CHANGE/Reconstructed

# Compile all source files
clang -fobjc-arc \
      -framework Cocoa \
      -framework IOKit \
      -framework Security \
      -F . \
      -framework ORSSerial \
      -rpath @executable_path/../Frameworks \
      -o T2BoysSN-Changer \
      main.m \
      AppDelegate.m \
      ViewController.m \
      EncryptionUtility.m \
      Encryption.m
```

### Step 3: Create App Bundle (Optional)

```bash
# Create app bundle structure
mkdir -p T2BoysSN-Changer.app/Contents/MacOS
mkdir -p T2BoysSN-Changer.app/Contents/Frameworks
mkdir -p T2BoysSN-Changer.app/Contents/Resources

# Copy executable
cp T2BoysSN-Changer T2BoysSN-Changer.app/Contents/MacOS/

# Copy framework
cp -R ORSSerial.framework T2BoysSN-Changer.app/Contents/Frameworks/

# Create Info.plist
cat > T2BoysSN-Changer.app/Contents/Info.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>T2BoysSN-Changer</string>
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
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
EOF
```

---

## Option 3: Makefile

Save this as `Makefile` in the Reconstructed directory:

```makefile
# Makefile for T2BoysSN-Changer

CC = clang
FRAMEWORKS = -framework Cocoa -framework IOKit -framework Security
ORS_FRAMEWORK = -F . -framework ORSSerial
CFLAGS = -fobjc-arc -Wall
LDFLAGS = -rpath @executable_path/../Frameworks

SOURCES = main.m AppDelegate.m ViewController.m EncryptionUtility.m Encryption.m
TARGET = T2BoysSN-Changer
APP_BUNDLE = $(TARGET).app

all: $(TARGET)

$(TARGET): $(SOURCES)
	$(CC) $(CFLAGS) $(FRAMEWORKS) $(ORS_FRAMEWORK) $(LDFLAGS) -o $@ $^

bundle: $(TARGET)
	mkdir -p $(APP_BUNDLE)/Contents/MacOS
	mkdir -p $(APP_BUNDLE)/Contents/Frameworks
	mkdir -p $(APP_BUNDLE)/Contents/Resources
	cp $(TARGET) $(APP_BUNDLE)/Contents/MacOS/
	cp -R ORSSerial.framework $(APP_BUNDLE)/Contents/Frameworks/
	cp Info.plist $(APP_BUNDLE)/Contents/

clean:
	rm -f $(TARGET)
	rm -rf $(APP_BUNDLE)

.PHONY: all bundle clean
```

Then run:
```bash
make          # Compile
make bundle   # Create .app bundle
make clean    # Clean build artifacts
```

---

## Troubleshooting

### Error: "ORSSerial/ORSSerial.h not found"

Make sure ORSSerialPort is installed and the framework search path is correct:
```bash
# Check if framework exists
ls -la ORSSerial.framework

# Add to header search paths in Xcode or use -F flag
```

### Error: "Library not loaded: @rpath/ORSSerial.framework"

The framework isn't being found at runtime. Fix with:
```bash
# Set rpath in executable
install_name_tool -add_rpath @executable_path/../Frameworks T2BoysSN-Changer
```

### Error: "Code signing" issues

For development, disable code signing or sign with your developer ID:
```bash
codesign --force --deep --sign - T2BoysSN-Changer.app
```

### Missing UI Elements

The reconstructed code creates a programmatic UI. For a full UI with buttons/text fields, you'll need to either:
1. Create an XIB/NIB file in Interface Builder
2. Add the UI programmatically in `ViewController.m`

---

## Quick Start Script

Save as `build.sh` and run with `bash build.sh`:

```bash
#!/bin/bash
set -e

echo "=== T2BoysSN-Changer Build Script ==="

# Check for Xcode
if ! command -v xcodebuild &> /dev/null; then
    echo "Error: Xcode Command Line Tools not installed"
    echo "Run: xcode-select --install"
    exit 1
fi

# Clone and build ORSSerialPort if not present
if [ ! -d "ORSSerial.framework" ]; then
    echo "Building ORSSerialPort..."
    git clone https://github.com/armadsen/ORSSerialPort.git ORSSerialPort_src
    cd ORSSerialPort_src
    xcodebuild -project ORSSerialPort.xcodeproj \
               -scheme "ORSSerial-Mac" \
               -configuration Release \
               -derivedDataPath build \
               ONLY_ACTIVE_ARCH=NO \
               -quiet
    cp -R build/Build/Products/Release/ORSSerial.framework ../
    cd ..
    rm -rf ORSSerialPort_src
fi

# Compile
echo "Compiling..."
clang -fobjc-arc \
      -framework Cocoa \
      -framework IOKit \
      -framework Security \
      -F . \
      -framework ORSSerial \
      -rpath @executable_path/../Frameworks \
      -o T2BoysSN-Changer \
      main.m AppDelegate.m ViewController.m EncryptionUtility.m Encryption.m

echo "Build successful!"
echo "Run with: ./T2BoysSN-Changer"
```

Make it executable:
```bash
chmod +x build.sh
./build.sh
```

---

## Notes

- The app requires **root privileges** or **SIP disabled** to modify serial numbers on real devices
- For testing encryption without hardware, the encryption classes work standalone
- The UI is minimal in the reconstructed version - enhance as needed
