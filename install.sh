#!/bin/bash

# Build the project
swift build -c release

# Create the widget bundle directory
BUNDLE_NAME="BatteryClock"
BUNDLE_DIR=".build/release/$BUNDLE_NAME.pock/Contents"

# Clean up any existing bundle
rm -rf ".build/release/$BUNDLE_NAME.pock"

# Create bundle structure
mkdir -p "$BUNDLE_DIR/MacOS"
mkdir -p "$BUNDLE_DIR/Resources"

# Copy the library
cp ".build/arm64-apple-macosx/release/libBatteryClock.dylib" "$BUNDLE_DIR/MacOS/$BUNDLE_NAME"
chmod +x "$BUNDLE_DIR/MacOS/$BUNDLE_NAME"

# Create Frameworks directory and copy dependencies if needed
mkdir -p "$BUNDLE_DIR/Frameworks"

# Copy resources
cp -r Sources/BatteryClock/Resources/* "$BUNDLE_DIR/Resources/" 2>/dev/null || true

# Create Info.plist
cat > "$BUNDLE_DIR/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>$BUNDLE_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>com.andreashworth.batteryclock</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$BUNDLE_NAME</string>
    <key>CFBundlePackageType</key>
    <string>BNDL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2024 Andre Ashworth. All rights reserved.</string>
    <key>NSPrincipalClass</key>
    <string>BatteryClock.BatteryClockWidget</string>
    <key>PKWidgetAuthor</key>
    <string>Andre Ashworth</string>
    <key>LSMinimumSystemVersion</key>
    <string>11.0</string>
</dict>
</plist>
EOF

echo "Widget bundle created at: .build/release/$BUNDLE_NAME.pock"
echo "You can now install this widget by dragging it into Pock's widget manager." 