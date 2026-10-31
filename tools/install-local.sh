#!/bin/bash
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE_APP="$PROJECT_DIR/build/DerivedData/Build/Products/Release/InkNotch.app"
TARGET_APP=/Applications/InkNotch.app
LEGACY_APP=/Applications/Boring\ Notch.app
if [[ ! -d "$SOURCE_APP" ]]; then
    echo '请先运行 tools/build-local.sh。' >&2
    exit 1
fi
codesign --verify --deep --strict "$SOURCE_APP"
# Stop only processes belonging to this installed app before replacing its files.
python3 - "$TARGET_APP" "$LEGACY_APP" <<'PY'
import os, plistlib, signal, subprocess, sys, time
from pathlib import Path
executables = []
for app in sys.argv[1:]:
    info = Path(app) / 'Contents/Info.plist'
    if not info.exists(): continue
    metadata = plistlib.loads(info.read_bytes())
    if not metadata.get('BNLocalChineseBuild'):
        sys.exit(f'发现非本地构建，请先将其移开：{app}')
    executables.append(app + '/Contents/MacOS/' + metadata['CFBundleExecutable'])
def processes():
    rows = subprocess.check_output(['ps', '-axo', 'pid=,args='], text=True).splitlines()
    result = []
    for row in rows:
        parts = row.strip().split(None, 1)
        if len(parts) == 2 and any(parts[1] == main or parts[1].startswith(main + ' ') for main in executables):
            result.append(int(parts[0]))
    return result
for pid in processes():
    try: os.kill(pid, signal.SIGTERM)
    except ProcessLookupError: pass
for _ in range(40):
    if not processes(): break
    time.sleep(0.1)
else:
    sys.exit('应用尚未退出，请退出墨岛或旧的本地 Boring Notch 后重试。')
PY
# Preserve an existing installation for rollback instead of deleting it.
if [[ -e "$TARGET_APP" || -e "$LEGACY_APP" ]]; then
    BACKUP_DIR="$PROJECT_DIR/build/backups/$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$BACKUP_DIR"
    for EXISTING_APP in "$TARGET_APP" "$LEGACY_APP"; do
        if [[ -e "$EXISTING_APP" ]]; then
            mv "$EXISTING_APP" "$BACKUP_DIR/"
        fi
    done
fi
ditto "$SOURCE_APP" "$TARGET_APP"
# Keep the compatibility preference domain, changing only this app's language.
defaults write theboringteam.boringnotch AppleLanguages -array zh-Hans en
codesign --verify --deep --strict "$TARGET_APP"
open "$TARGET_APP"
python3 - "$TARGET_APP" <<'PY'
import plistlib, subprocess, sys, time
from pathlib import Path
metadata = plistlib.loads((Path(sys.argv[1]) / 'Contents/Info.plist').read_bytes())
main = sys.argv[1] + '/Contents/MacOS/' + metadata['CFBundleExecutable']
stable = 0
for _ in range(20):
    rows = subprocess.check_output(['ps', '-axo', 'args='], text=True).splitlines()
    running = any(row == main or row.startswith(main + ' ') for row in rows)
    stable = stable + 1 if running else 0
    if stable >= 6: break
    time.sleep(0.5)
else:
    sys.exit('安装完成，但应用未持续运行。请查看系统诊断报告。')
PY
echo "已安装并启动：$TARGET_APP"
