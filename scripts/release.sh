#!/bin/bash

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
readonly PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

usage() {
    echo "Usage: ./scripts/release.sh vX.Y.Z" >&2
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

cd "$PROJECT_DIR"

if [[ "$(git branch --show-current)" != "main" ]]; then
    echo "Release must be triggered from the main branch." >&2
    exit 1
fi

if [[ -n "$(git status --porcelain)" ]]; then
    echo "Release requires a clean working tree." >&2
    exit 1
fi

git fetch --quiet origin main

readonly LOCAL_COMMIT="$(git rev-parse HEAD)"
readonly REMOTE_MAIN_COMMIT="$(git rev-parse origin/main)"
if [[ "$LOCAL_COMMIT" != "$REMOTE_MAIN_COMMIT" ]]; then
    echo "Local main must exactly match origin/main before releasing." >&2
    exit 1
fi

if ! gh auth status -h github.com >/dev/null 2>&1; then
    echo "GitHub CLI is not authenticated. Run: gh auth login -h github.com" >&2
    exit 1
fi

gh workflow run release.yml --ref main -f "tag=$TAG"
echo "Release workflow started for $TAG. Follow it with: gh run watch"
