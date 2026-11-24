#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="FlutterMacManager"
BUNDLE_DIR="$ROOT_DIR/dist/${APP_NAME}.app"
CONTENTS_DIR="$BUNDLE_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"

echo "Building $APP_NAME (release)..."
cd "$ROOT_DIR"
swift build -c release "$@"

BIN_PATH="$ROOT_DIR/.build/release/$APP_NAME"
if [[ ! -f "$BIN_PATH" ]]; then
  echo "Error: compiled binary not found at $BIN_PATH" >&2
  exit 1
fi

rm -rf "$BUNDLE_DIR"
mkdir -p "$MACOS_DIR"
cp "$BIN_PATH" "$MACOS_DIR/$APP_NAME"
chmod +x "$MACOS_DIR/$APP_NAME"

cat > "$CONTENTS_DIR/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>FlutterMacManager</string>
    <key>CFBundleIdentifier</key>
    <string>com.local.FlutterMacManager</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>FlutterMacManager</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

echo "Bundled menu bar app at: $BUNDLE_DIR"
echo "Run with: open \"$BUNDLE_DIR\""
