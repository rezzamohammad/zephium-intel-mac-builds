#!/usr/bin/env bash
set -euo pipefail
# Exercise the real DMG helper with Tauri's executable name before compiling
# the browser. This fixture is never launched and uses no browser profile.
helper="$(cd "$(dirname "$0")" && pwd)/make-dmg.sh"
work="$(mktemp -d "${TMPDIR:-/tmp}/zephium-packaging-test.XXXXXX")"
mounted=false
cleanup() {
  if [[ "$mounted" == true ]]; then hdiutil detach "$work/mount" >/dev/null 2>&1 || true; fi
  rm -rf "$work"
}
trap cleanup EXIT
app="$work/Zephium.app"
mkdir -p "$app/Contents/MacOS" "$work/mount"
printf 'int main(void) { return 0; }\n' > "$work/fixture.c"
xcrun clang -arch x86_64 -mmacosx-version-min=14.0 "$work/fixture.c" -o "$app/Contents/MacOS/zephium-desktop"
python3 - "$app/Contents/Info.plist" <<'PY'
import plistlib
import sys
with open(sys.argv[1], 'wb') as output:
    plistlib.dump({
        'CFBundleExecutable': 'zephium-desktop',
        'CFBundleIdentifier': 'io.github.zephium-intel-builds.packaging-test',
        'CFBundleName': 'Zephium',
        'CFBundlePackageType': 'APPL',
        'CFBundleShortVersionString': '0.0.0',
        'CFBundleVersion': '0.0.0',
        'LSMinimumSystemVersion': '14.0',
    }, output)
PY
codesign --force --sign - "$app"
"$helper" "$app" "$work/test.dmg"
hdiutil attach -readonly -nobrowse -mountpoint "$work/mount" "$work/test.dmg" >/dev/null
mounted=true
exe="$work/mount/Zephium.app/Contents/MacOS/zephium-desktop"
test -x "$exe"
[[ "$(lipo -archs "$exe")" == x86_64 ]]
[[ "$(readlink "$work/mount/Applications")" == /Applications ]]
codesign --verify --deep --strict "$work/mount/Zephium.app"
hdiutil detach "$work/mount" >/dev/null
mounted=false
echo 'PASS: signed Intel app with Tauri executable name survives DMG packaging and mounting'
