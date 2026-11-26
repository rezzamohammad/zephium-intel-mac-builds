#!/usr/bin/env bash
set -euo pipefail
app="$PWD/target/x86_64-apple-darwin/release/bundle/macos/Zephium.app"
exe="$app/Contents/MacOS/zephium-desktop"
dmg="$PWD/dist/Zephium-macOS-x86_64.dmg"
test -x "$exe"
[[ "$(lipo -archs "$exe")" == x86_64 ]] || { echo 'error: executable is not Intel-only' >&2; exit 1; }
count=0
while IFS= read -r -d '' f; do
  if [[ "$(file -b "$f")" == *Mach-O* ]]; then
    [[ "$(lipo -archs "$f")" == x86_64 ]] || { echo "error: non-Intel-only Mach-O: $f" >&2; exit 1; }
    count=$((count+1))
  fi
done < <(find "$app" -type f -print0)
(( count > 0 ))
foreign="$(otool -L "$exe" | tail -n +2 | awk '{print $1}' | grep -Ev '^(/usr/lib/|/System/Library/)' || true)"
[[ -z "$foreign" ]] || { echo "error: executable links non-system libraries: $foreign" >&2; exit 1; }
codesign --verify --deep --strict "$app"
codesign -dvv "$app" > codesign.txt 2>&1
grep -qx 'Signature=adhoc' codesign.txt
version="$(sed -n 's/^version=//p' intel-pins.txt)"
plist="$app/Contents/Info.plist"
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$plist")" == "$version" ]]
[[ "$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "$plist")" == 14.0 ]]
cmp "$app/Contents/Resources/licenses/Zephium-MPL-2.0.txt" LICENSE
cmp "$app/Contents/Resources/licenses/THIRD_PARTY_NOTICES.txt" target/THIRD_PARTY_NOTICES.txt
cmp "$app/Contents/Resources/licenses/COMMUNITY-BUILD.txt" target/COMMUNITY-BUILD.txt
for name in CC-BY-SA-3.0.txt GPL-3.0.txt NOTICE.txt; do
  test -s "$app/Contents/Resources/licenses/blocker/$name"
done
codesign -d --entitlements - --xml "$exe" > entitlements.plist 2>/dev/null
python3 - <<'PY'
import plistlib
from pathlib import Path
actual = plistlib.loads(Path('entitlements.plist').read_bytes())
expected = plistlib.loads(Path('desktop/Entitlements.plist').read_bytes())
if actual != expected:
    raise SystemExit(f'error: entitlements changed: {actual}')
PY
grep -qx 'const SUPPORTED: bool = false;' desktop/src/updates.rs
minos="$(otool -l "$exe" | awk '/LC_BUILD_VERSION/ { f = 1 } f && $1 == "minos" { print $2; exit }')"
{
  echo "zephium_version=$version"
  echo "main_executable=$(file -b "$exe")"
  echo "lipo_archs=$(lipo -archs "$exe")"
  echo "native_macho_files=$count"
  echo 'non_x86_64_macho_files=0'
  echo 'linked_libraries=system only (/usr/lib, /System/Library)'
  echo "minos=${minos:-unknown}"
  echo 'plist_minimum_macos=14.0; upstream runtime macOS/Safari admission retained'
  echo 'codesign=adhoc; not Developer ID signed; not notarized'
  echo 'self_update=disabled; manual DMG installation required'
  echo 'native_policy_tests=passed; GUI/browser/Work acceptance=not run'
} > runtime-diagnostics.txt
test -s "$dmg"
[[ "$(find dist -maxdepth 1 -name '*.dmg' -type f | wc -l | tr -d ' ')" == 1 ]]
hdiutil verify "$dmg"
mnt="$(mktemp -d)"
hdiutil attach -readonly -nobrowse -mountpoint "$mnt" "$dmg" >/dev/null
trap 'hdiutil detach "$mnt" >/dev/null 2>&1 || true; rmdir "$mnt"' EXIT
[[ "$(lipo -archs "$mnt/Zephium.app/Contents/MacOS/zephium-desktop")" == x86_64 ]]
codesign --verify --deep --strict "$mnt/Zephium.app"
[[ -L "$mnt/Applications" && "$(readlink "$mnt/Applications")" == /Applications ]]
hdiutil detach "$mnt" >/dev/null
rmdir "$mnt"
trap - EXIT
cp target/THIRD_PARTY_NOTICES.txt target/COMMUNITY-BUILD.txt dist/
(
  cd dist
  shasum -a 256 Zephium-macOS-x86_64.dmg community-build.patch THIRD_PARTY_NOTICES.txt COMMUNITY-BUILD.txt
) > SHA256SUMS
{
  echo "archive_workflow_commit=$GITHUB_SHA"
  echo "archive_branch=$GITHUB_REF_NAME"
  echo "workflow_run=$GITHUB_SERVER_URL/$GITHUB_REPOSITORY/actions/runs/$GITHUB_RUN_ID"
  echo "source_repository=https://github.com/$ZEPHIUM_SOURCE_REPOSITORY"
  echo "source_ref=$ZEPHIUM_SOURCE_REF"
  echo "source_commit=$(git rev-parse HEAD)"
  cat intel-pins.txt
  echo "rust_target=x86_64-apple-darwin"
  echo "target_architecture=x86_64"
  echo "runner_macos=$(sw_vers -productVersion)"
  echo "xcode=$(xcodebuild -version | head -1)"
  cat runtime-diagnostics.txt
  cat SHA256SUMS
} > build-manifest.txt
file "$dmg" > dmg-file.txt
cat build-manifest.txt
