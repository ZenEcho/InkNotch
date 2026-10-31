#!/usr/bin/env python3
"""Apply the local Chinese overlay and fail on missing UI translations or bad formats."""
import argparse
from collections import Counter
import json
import os
from pathlib import Path
import re
import sys
import subprocess

ROOT = Path(__file__).resolve().parents[1]
CATALOG = ROOT / "boringNotch/Localizable.xcstrings"
OVERLAY = ROOT / "localization/zh-Hans.json"
ALLOW_ENGLISH = {"Boring Notch", "boring.notch", "GitHub", "Apple Music", "Spotify", "YouTube Music", "AirDrop", "Lottie", "PNG", "JPEG", "HEIC", "TIFF", "BMP", "PDF"}
FORMAT = re.compile(r"%(?:\d+\$)?[-+#0 ]*(?:\d+|\*)?(?:\.(?:\d+|\*))?(?:hh|ll|h|l|L|z|j|t)?[@diuoxXfFeEgGaAcCsSp%]")
LITERAL = r'"((?:\\.|[^"\\])*)"'
UI_PATTERNS = [
    re.compile(r'\b(?:Text|Label|Button|Toggle|Picker|Link|LabeledContent|TextField|Recorder|NSMenuItem|addMenuItem|customBadge)\s*\(\s*(?:(?:title|text):\s*)?' + LITERAL),
    re.compile(r'\b(?:title|description|privacyNote):\s*' + LITERAL),
    re.compile(r'\bString\(localized:\s*' + LITERAL),
    re.compile(r'\bNSLocalizedString\(\s*' + LITERAL),
    re.compile(r'\.help\(\s*' + LITERAL),
    re.compile(r'\bcase\s+\w+\s*=\s*' + LITERAL),
]


def read(path):
    return json.loads(path.read_text())


def write(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2, separators=(",", " : ")) + "\n")


def format_tokens(value):
    return Counter(token for token in FORMAT.findall(value) if token != "%%")


def needs_chinese(key):
    if key in ALLOW_ENGLISH or key.startswith(("https://", "http://")):
        return False
    return bool(re.search(r"[A-Za-z]", FORMAT.sub("", key)))


def source_candidates():
    found = {}
    for path in sorted((ROOT / "boringNotch").rglob("*.swift")):
        source = path.read_text().split("#Preview")[0]
        source = re.sub(r"(?m)^\s*//.*$", "", source)
        for pattern in UI_PATTERNS:
            for match in pattern.finditer(source):
                raw = match[1]
                # Xcode extracts interpolated strings with their exact Swift argument types.
                # They are validated from the string catalog; do not guess their format types.
                if "\\(" in raw or not raw or "_" in raw:
                    continue
                try:
                    key = json.loads('"' + raw + '"')
                except json.JSONDecodeError:
                    continue
                if not needs_chinese(key) or not re.search(r"[a-z]", key):
                    continue
                found.setdefault(key, str(path.relative_to(ROOT)))
    return found


def apple_candidates():
    """Use Apple's extractor in addition to the conservative static fallback."""
    developer = os.environ.get("DEVELOPER_DIR", "/Applications/Xcode.app/Contents/Developer")
    if not Path(developer).is_dir():
        return {}
    output = ROOT / "build/localization-extracted"
    output.mkdir(parents=True, exist_ok=True)
    sources = sorted(str(p) for p in (ROOT / "boringNotch").rglob("*.swift"))
    command = ["xcrun", "xcstringstool", "extract", "--SwiftUI",
               "--modern-localizable-strings", "--legacy-localizable-strings",
               "--avoid-arg-placeholder", "--output-format", "xcstrings",
               "--output-directory", str(output), *sources]
    with (output / "extract.log").open("w") as log:
        subprocess.run(command, env={**os.environ, "DEVELOPER_DIR": developer},
                       stdout=log, stderr=log, check=True)
    path = output / "Localizable.xcstrings"
    return {key: "Apple 文案提取结果" for key in read(path)["strings"]} if path.exists() else {}


def compiled_candidates(folder):
    found = {}
    files = list(folder.rglob("*.stringsdata"))
    if not files:
        raise ValueError(f"没有编译器提取结果：{folder}")
    for path in files:
        data = read(path)
        for entry in data.get("tables", {}).get("Localizable", []):
            found[entry["key"]] = data.get("source", str(path))
    return found


def sync():
    data, overlay = read(CATALOG), read(OVERLAY)
    for key, chinese in overlay.items():
        entry = data["strings"].setdefault(key, {"extractionState": "manual"})
        entry.setdefault("localizations", {})["zh-Hans"] = {
            "stringUnit": {"state": "translated", "value": chinese}
        }
    write(CATALOG, data)
    print(f"已同步 {len(overlay)} 条简体中文文案。")


def check(compiled=None):
    data, overlay = read(CATALOG), read(OVERLAY)
    errors = []
    # These controls have ordinary String overloads that silently bypass the
    # catalog even when a translation exists. Require an explicit Text label.
    for path in (ROOT / "boringNotch").rglob("*.swift"):
        source = re.sub(r"(?m)^\s*//.*$", "", path.read_text())
        for match in re.finditer(r'\b(?:Defaults|LaunchAtLogin)\s*\.Toggle\(\s*"([^"\n]+)"', source):
            errors.append(f"控件标题未接入本地化，请改用 Text 标签：{match[1]!r} [{path.relative_to(ROOT)}]")
    for key, entry in data["strings"].items():
        if entry.get("shouldTranslate") is False:
            continue
        unit = entry.get("localizations", {}).get("zh-Hans", {}).get("stringUnit", {})
        value = unit.get("value", "")
        if key and not value:
            errors.append(f"缺少译文：{key}")
        if needs_chinese(key) and not re.search(r"[\u3400-\u9fff]", value):
            errors.append(f"尚未汉化：{key}")
        if format_tokens(key) != format_tokens(value):
            errors.append(f"占位符不匹配：{key!r} -> {value!r}")
        if key in overlay and value != overlay[key]:
            errors.append(f"词典尚未同步：{key}")
    candidates = {**source_candidates(), **apple_candidates()}
    if compiled:
        candidates.update(compiled_candidates(compiled))
    for key, path in candidates.items():
        if key not in overlay and needs_chinese(key):
            errors.append(f"新增界面文案（请补充词典）：{key!r} [{path}]")
    if errors:
        print("\n".join(sorted(set(errors))), file=sys.stderr)
        return 1
    print(f"校验通过：{len(data['strings'])} 条文案，无漏译或格式占位符错误。")
    return 0


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["sync", "check", "report"])
    parser.add_argument("--compiled", type=Path, help="校验编译器提取的文案，包括插值的精确格式")
    args = parser.parse_args()
    if args.command == "sync":
        sync()
    elif args.command == "report":
        print(json.dumps(source_candidates(), ensure_ascii=False, indent=2))
    else:
        sys.exit(check(args.compiled))
