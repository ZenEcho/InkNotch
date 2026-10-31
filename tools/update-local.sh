#!/bin/bash
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"
if [[ -n "$(git status --porcelain)" ]]; then
    echo '工作区存在未提交修改。请先提交本地汉化，或手动处理修改，再更新。' >&2
    exit 1
fi
git fetch origin --tags
if [[ $# -gt 0 ]]; then
    UPSTREAM_REF="$1"
else
    UPSTREAM_REF="$(git tag --list 'v[0-9]*' --sort=-version:refname | awk '/^v[0-9]+\.[0-9]+(\.[0-9]+)?$/ {print; exit}')"
fi
if [[ -z "$UPSTREAM_REF" ]]; then
    echo '未找到正式版标签。可显式传入上游引用，例如 origin/main。' >&2
    exit 1
fi
echo "准备合并上游版本：$UPSTREAM_REF"
git merge --no-edit -- "$UPSTREAM_REF"
python3 tools/localize.py sync
python3 tools/localize.py check
echo '上游已同步，汉化已校验。请检查差异并提交，再运行 tools/build-local.sh 和 tools/install-local.sh。'
