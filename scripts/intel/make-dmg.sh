#!/usr/bin/env bash
# Adapted from rezzamohammad/herdr-app-intel-mac-builds (Apache-2.0).
# See docs/LICENSE-Apache-2.0.txt for the retained upstream script license.
set -euo pipefail
# Packs an ad-hoc signed Intel Zephium.app into a drag-to-Applications DMG.
# Uses hdiutil instead of upstream's signed/notarized Tauri DMG path.
# This community build does not sign the DMG, notarize or staple.
app="${1:?usage: make-dmg.sh Zephium.app output.dmg}"
out="${2:?usage: make-dmg.sh Zephium.app output.dmg}"
VOLNAME="${VOLNAME:-Zephium}"
[[ "$(uname -s)" == Darwin ]] || { echo 'error: make-dmg.sh requires macOS' >&2; exit 1; }
[[ "$(basename "$app")" == Zephium.app && -d "$app" ]] || { echo "error: expected a Zephium.app bundle: $app" >&2; exit 1; }
[[ "$out" == *.dmg && ! -e "$out" ]] || { echo "error: output must be a new .dmg file: $out" >&2; exit 1; }
exe="$app/Contents/MacOS/zephium-desktop"
[[ -x "$exe" ]] || { echo "error: app executable missing: $exe" >&2; exit 1; }
[[ "$(lipo -archs "$exe")" == x86_64 ]] || { echo "error: main executable is not x86_64: $(lipo -archs "$exe")" >&2; exit 1; }
codesign --verify --deep --strict "$app" || { echo 'error: app signature (ad hoc) does not verify' >&2; exit 1; }
work="$(mktemp -d "${TMPDIR:-/tmp}/zephium-intel-dmg.XXXXXX")"; trap 'rm -rf "$work"' EXIT
mkdir "$work/stage"
ditto "$app" "$work/stage/Zephium.app"
ln -s /Applications "$work/stage/Applications"
for attempt in 1 2 3; do
  if hdiutil create -volname "$VOLNAME" -srcfolder "$work/stage" -fs HFS+ -format UDZO -imagekey zlib-level=9 "$work/Zephium.dmg" > "$work/create.log" 2>&1; then
    cat "$work/create.log"
    break
  else
    status=$?
  fi
  cat "$work/create.log" >&2
  if [[ "$attempt" == 3 ]] || ! grep -q 'Resource busy' "$work/create.log"; then
    exit "$status"
  fi
  echo "DMG creation reported Resource busy; retrying (attempt $((attempt+1))/3)" >&2
  rm -f "$work/Zephium.dmg"
  sleep "$((attempt*5))"
done
[[ -s "$work/Zephium.dmg" ]] || { echo 'error: hdiutil produced an empty DMG' >&2; exit 1; }
hdiutil verify "$work/Zephium.dmg"
mkdir -p "$(dirname "$out")"
mv "$work/Zephium.dmg" "$out"
echo "Created Intel DMG: $out"
