#!/bin/bash

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
readonly PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
readonly PROJECT="$PROJECT_DIR/AIUsageMeter.xcodeproj"
readonly SCHEME="AIUsageMeter"
readonly TARGET="AIUsageMeter"

build_setting() {
    xcodebuild \
        -showBuildSettings \
        -project "$PROJECT" \
        -target "$TARGET" \
        -configuration Release | \
        awk -v name="$1" '$1 == name && $2 == "=" { print $3; exit }'
}

readonly VERSION="$(build_setting MARKETING_VERSION)"
readonly BUILD_NUMBER="$(build_setting CURRENT_PROJECT_VERSION)"
readonly BUNDLE_ID="$(build_setting PRODUCT_BUNDLE_IDENTIFIER)"

test -n "$VERSION"
test -n "$BUILD_NUMBER"
test -n "$BUNDLE_ID"

readonly DIST_DIR="$PROJECT_DIR/dist"
readonly ZIP_PATH="$DIST_DIR/AIUsageMeter-$VERSION.zip"
readonly CHECKSUM_PATH="$ZIP_PATH.sha256"
readonly DMG_FILENAME="AI-Usage-Meter.dmg"
readonly DMG_PATH="$DIST_DIR/$DMG_FILENAME"
readonly DMG_CHECKSUM_PATH="$DMG_PATH.sha256"
readonly DERIVED_DATA="$(mktemp -d /private/tmp/AIUsageMeter-Release.XXXXXX)"
readonly VERIFY_DIR="$(mktemp -d /private/tmp/AIUsageMeter-Verify.XXXXXX)"
readonly DMG_STAGE="$(mktemp -d /private/tmp/AIUsageMeter-DMG.XXXXXX)"
readonly DMG_MOUNT_POINT="$(mktemp -d /private/tmp/AIUsageMeter-DMG-Mount.XXXXXX)"

cleanup() {
    hdiutil detach "$DMG_MOUNT_POINT" -force >/dev/null 2>&1 || true
    rm -rf "$DERIVED_DATA" "$VERIFY_DIR" "$DMG_STAGE" "$DMG_MOUNT_POINT"
}
trap cleanup EXIT

echo "Building AI Usage Meter $VERSION (arm64 + x86_64)..."
xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration Release \
    -destination 'generic/platform=macOS' \
    -derivedDataPath "$DERIVED_DATA" \
    ARCHS='arm64 x86_64' \
    ONLY_ACTIVE_ARCH=NO \
    CODE_SIGNING_ALLOWED=NO \
    build

readonly APP_PATH="$DERIVED_DATA/Build/Products/Release/AI Usage Meter.app"
readonly INFO_PLIST="$APP_PATH/Contents/Info.plist"
readonly EXECUTABLE="$APP_PATH/Contents/MacOS/AI Usage Meter"

test -d "$APP_PATH"
test "$(plutil -extract CFBundleShortVersionString raw "$INFO_PLIST")" = "$VERSION"
test "$(plutil -extract CFBundleVersion raw "$INFO_PLIST")" = "$BUILD_NUMBER"
test "$(plutil -extract CFBundleIdentifier raw "$INFO_PLIST")" = "$BUNDLE_ID"

readonly ARCHITECTURES="$(lipo -archs "$EXECUTABLE")"
case " $ARCHITECTURES " in
    *" arm64 "*) ;;
    *) echo "Missing arm64 architecture" >&2; exit 1 ;;
esac
case " $ARCHITECTURES " in
    *" x86_64 "*) ;;
    *) echo "Missing x86_64 architecture" >&2; exit 1 ;;
esac

codesign --force --sign - --timestamp=none --options runtime "$APP_PATH"
codesign --verify --strict --verbose=2 "$APP_PATH"

mkdir -p "$DIST_DIR"
rm -f "$ZIP_PATH" "$CHECKSUM_PATH"
ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$ZIP_PATH"

(
    cd "$DIST_DIR"
    shasum -a 256 "$(basename "$ZIP_PATH")" > "$(basename "$CHECKSUM_PATH")"
)

unzip -t "$ZIP_PATH"
ditto -x -k "$ZIP_PATH" "$VERIFY_DIR"

readonly PACKAGED_APP="$VERIFY_DIR/AI Usage Meter.app"
test -d "$PACKAGED_APP"
test "$(plutil -extract CFBundleShortVersionString raw "$PACKAGED_APP/Contents/Info.plist")" = "$VERSION"
test "$(plutil -extract CFBundleVersion raw "$PACKAGED_APP/Contents/Info.plist")" = "$BUILD_NUMBER"
test "$(plutil -extract CFBundleIdentifier raw "$PACKAGED_APP/Contents/Info.plist")" = "$BUNDLE_ID"
test "$(lipo -archs "$PACKAGED_APP/Contents/MacOS/AI Usage Meter")" = "$ARCHITECTURES"
codesign --verify --strict --verbose=2 "$PACKAGED_APP"

echo "Release artifacts:"
echo "  $ZIP_PATH"
echo "  $CHECKSUM_PATH"
cat "$CHECKSUM_PATH"

mkdir -p "$DMG_STAGE"
ditto "$APP_PATH" "$DMG_STAGE/AI Usage Meter.app"
ln -s /Applications "$DMG_STAGE/Applications"

rm -f "$DMG_PATH" "$DMG_CHECKSUM_PATH"
hdiutil create \
    -volname "AI Usage Meter" \
    -srcfolder "$DMG_STAGE" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -ov \
    "$DMG_PATH"

(
    cd "$DIST_DIR"
    shasum -a 256 "$DMG_FILENAME" > "$(basename "$DMG_CHECKSUM_PATH")"
)
hdiutil attach \
    -readonly \
    -nobrowse \
    -mountpoint "$DMG_MOUNT_POINT" \
    "$DMG_PATH"

test -d "$DMG_MOUNT_POINT/AI Usage Meter.app"
test -L "$DMG_MOUNT_POINT/Applications"
codesign --verify --strict --verbose=2 "$DMG_MOUNT_POINT/AI Usage Meter.app"
hdiutil detach "$DMG_MOUNT_POINT"

echo "  $DMG_PATH"
echo "  $DMG_CHECKSUM_PATH"
cat "$DMG_CHECKSUM_PATH"
