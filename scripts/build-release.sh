#!/bin/bash

set -euo pipefail

readonly VERSION="0.1.0"
readonly BUNDLE_ID="com.agentquotabar.app"
readonly SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
readonly PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
readonly PROJECT="$PROJECT_DIR/AgentQuotaBar.xcodeproj"
readonly SCHEME="AgentQuotaBar"
readonly DIST_DIR="$PROJECT_DIR/dist"
readonly ZIP_PATH="$DIST_DIR/AgentQuotaBar-$VERSION.zip"
readonly CHECKSUM_PATH="$ZIP_PATH.sha256"
readonly DERIVED_DATA="$(mktemp -d /private/tmp/AgentQuotaBar-Release.XXXXXX)"
readonly VERIFY_DIR="$(mktemp -d /private/tmp/AgentQuotaBar-Verify.XXXXXX)"

cleanup() {
    rm -rf "$DERIVED_DATA" "$VERIFY_DIR"
}
trap cleanup EXIT

echo "Building Agent Quota Bar $VERSION (arm64 + x86_64)..."
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

readonly APP_PATH="$DERIVED_DATA/Build/Products/Release/AgentQuotaBar.app"
readonly INFO_PLIST="$APP_PATH/Contents/Info.plist"
readonly EXECUTABLE="$APP_PATH/Contents/MacOS/AgentQuotaBar"

test -d "$APP_PATH"
test "$(plutil -extract CFBundleShortVersionString raw "$INFO_PLIST")" = "$VERSION"
test "$(plutil -extract CFBundleVersion raw "$INFO_PLIST")" = "1"
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

readonly PACKAGED_APP="$VERIFY_DIR/AgentQuotaBar.app"
test -d "$PACKAGED_APP"
test "$(plutil -extract CFBundleShortVersionString raw "$PACKAGED_APP/Contents/Info.plist")" = "$VERSION"
test "$(plutil -extract CFBundleIdentifier raw "$PACKAGED_APP/Contents/Info.plist")" = "$BUNDLE_ID"
test "$(lipo -archs "$PACKAGED_APP/Contents/MacOS/AgentQuotaBar")" = "$ARCHITECTURES"
codesign --verify --strict --verbose=2 "$PACKAGED_APP"

echo "Release artifacts:"
echo "  $ZIP_PATH"
echo "  $CHECKSUM_PATH"
cat "$CHECKSUM_PATH"
