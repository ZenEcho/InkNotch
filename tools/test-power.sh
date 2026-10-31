#!/bin/bash
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"
if [[ -z "${DEVELOPER_DIR:-}" && -d /Applications/Xcode.app/Contents/Developer ]]; then
    export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi
mkdir -p build/tests
xcrun swiftc Shared/PowerTelemetry/*.swift tools/tests/PowerTelemetryTests.swift \
    -framework IOKit -o build/tests/PowerTelemetryTests
build/tests/PowerTelemetryTests "$@"
