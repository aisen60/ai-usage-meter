#!/bin/bash

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
readonly PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
readonly CHANGELOG="$PROJECT_DIR/CHANGELOG.md"

usage() {
    echo "Usage: ./scripts/release-notes.sh vX.Y.Z" >&2
    exit 64
}

if [[ $# -ne 1 ]]; then
    usage
fi

readonly TAG="$1"
if [[ ! "$TAG" =~ ^v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]]; then
    echo "Release tag must use stable SemVer format vX.Y.Z: $TAG" >&2
    exit 64
fi

readonly VERSION="${TAG#v}"
if [[ ! -f "$CHANGELOG" ]]; then
    echo "CHANGELOG.md is missing." >&2
    exit 1
fi

readonly NOTES_FILE="$(mktemp "${TMPDIR:-/tmp}/AIUsageMeter-ReleaseNotes.XXXXXX")"
cleanup() {
    rm -f "$NOTES_FILE"
}
trap cleanup EXIT

awk -v version="$VERSION" '
    $0 ~ "^## " version " - [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]$" {
        found = 1
        next
    }
    found && /^## / { exit }
    found { print }
' "$CHANGELOG" > "$NOTES_FILE"

if ! awk 'NF { found = 1 } END { exit !found }' "$NOTES_FILE"; then
    echo "CHANGELOG.md does not contain a non-empty entry for $VERSION." >&2
    exit 1
fi

cat "$NOTES_FILE"
cat <<'EOF'

## 安装提示

下载 ZIP 文件后解压，将 `AI Usage Meter.app` 移动到 `/Applications`。当前发行包使用 ad-hoc 签名，未经过 Apple 公证。首次启动若出现安全提示，请在 Finder 中右键点击应用并选择“打开”，然后在“系统设置 → 隐私与安全性”中确认一次。
EOF
