#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_DIR="${1:-"$HOME/Desktop"}"
APP_PATH="$OUTPUT_DIR/PromptPalette.app"
ICON_PATH="$ROOT_DIR/Assets/PromptPalette.icns"
INFO_PLIST="$APP_PATH/Contents/Info.plist"

if [[ ! -f "$ICON_PATH" ]]; then
    echo "Missing app icon: $ICON_PATH" >&2
    exit 1
fi

swift build -c release --package-path "$ROOT_DIR"
BIN_DIR="$(swift build -c release --package-path "$ROOT_DIR" --show-bin-path)"
EXECUTABLE="$BIN_DIR/PromptPalette"

if [[ ! -x "$EXECUTABLE" ]]; then
    echo "Missing release executable: $EXECUTABLE" >&2
    exit 1
fi

mkdir -p "$OUTPUT_DIR"
rm -rf "$APP_PATH"
mkdir -p "$APP_PATH/Contents/MacOS" "$APP_PATH/Contents/Resources"

cp "$EXECUTABLE" "$APP_PATH/Contents/MacOS/PromptPalette"
cp "$ICON_PATH" "$APP_PATH/Contents/Resources/PromptPalette.icns"
chmod +x "$APP_PATH/Contents/MacOS/PromptPalette"

BUILD_NUMBER="$(git -C "$ROOT_DIR" rev-list --count HEAD 2>/dev/null || date +%Y%m%d%H%M%S)"

/usr/libexec/PlistBuddy -c "Clear dict" "$INFO_PLIST"
/usr/libexec/PlistBuddy -c "Add :CFBundleExecutable string PromptPalette" "$INFO_PLIST"
/usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier string com.bald-ai.PromptPalette" "$INFO_PLIST"
/usr/libexec/PlistBuddy -c "Add :CFBundleName string PromptPalette" "$INFO_PLIST"
/usr/libexec/PlistBuddy -c "Add :CFBundleDisplayName string PromptPalette" "$INFO_PLIST"
/usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string PromptPalette" "$INFO_PLIST"
/usr/libexec/PlistBuddy -c "Add :CFBundlePackageType string APPL" "$INFO_PLIST"
/usr/libexec/PlistBuddy -c "Add :CFBundleShortVersionString string 1.0" "$INFO_PLIST"
/usr/libexec/PlistBuddy -c "Add :CFBundleVersion string $BUILD_NUMBER" "$INFO_PLIST"
/usr/libexec/PlistBuddy -c "Add :LSMinimumSystemVersion string 26.0" "$INFO_PLIST"
/usr/libexec/PlistBuddy -c "Add :LSUIElement bool true" "$INFO_PLIST"
/usr/libexec/PlistBuddy -c "Add :NSHighResolutionCapable bool true" "$INFO_PLIST"

if command -v codesign >/dev/null 2>&1; then
    codesign --force --deep --sign - "$APP_PATH" >/dev/null
    codesign --verify --deep --strict "$APP_PATH"
fi

echo "Built $APP_PATH"
