#!/bin/bash
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
if [[ -z "${DEVELOPER_DIR:-}" && -d /Applications/Xcode.app/Contents/Developer ]]; then
    export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi
mkdir -p "$PROJECT_DIR/build/tools"
xcrun swiftc "$PROJECT_DIR/tools/render-app-icon.swift" -o "$PROJECT_DIR/build/tools/render-app-icon"
"$PROJECT_DIR/build/tools/render-app-icon" "$PROJECT_DIR"
