#!/bin/bash
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

if [[ -z "${DEVELOPER_DIR:-}" && -d /Applications/Xcode.app/Contents/Developer ]]; then
    export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi
if ! xcodebuild -version >/dev/null 2>&1; then
    echo '请先安装并打开完整的 Xcode，完成首次启动设置。' >&2
    exit 1
fi
python3 tools/localize.py sync
python3 tools/localize.py check
tools/test-quick-apps.sh
tools/test-power.sh
mkdir -p build
xcodebuild -resolvePackageDependencies -project boringNotch.xcodeproj \
    -scheme boringNotch -clonedSourcePackagesDirPath "$PROJECT_DIR/build/SourcePackages" \
    -onlyUsePackageVersionsFromResolvedFile
xcodebuild -project boringNotch.xcodeproj -scheme boringNotch \
    -configuration Release -destination 'platform=macOS' \
    -derivedDataPath "$PROJECT_DIR/build/DerivedData" \
    -clonedSourcePackagesDirPath "$PROJECT_DIR/build/SourcePackages" \
    -disableAutomaticPackageResolution \
    CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM= \
    ENABLE_HARDENED_RUNTIME=NO \
    build "$@"

python3 tools/localize.py check --compiled \
    build/DerivedData/Build/Intermediates.noindex/boringNotch.build/Release/boringNotch.build

APP_PATH="$PROJECT_DIR/build/DerivedData/Build/Products/Release/InkNotch.app"
# The checked-in MediaRemoteAdapter retains its vendor signature when Xcode copies
# it. Match its identity to this ad-hoc development build, then reseal the app
# without dropping its existing sandbox entitlements. Apple Developer signing is
# required for distribution with library validation and a hardened runtime.
codesign --force --sign - --timestamp=none "$APP_PATH/Contents/Frameworks/MediaRemoteAdapter.framework"
codesign --force --sign - --timestamp=none \
    --preserve-metadata=entitlements,requirements,flags,runtime "$APP_PATH"
codesign --verify --deep --strict "$APP_PATH"
echo "已生成：$APP_PATH"
