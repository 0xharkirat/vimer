#!/usr/bin/env bash
#
# Builds a universal macOS release, then splits it into two thinned, ad-hoc
# re-signed apps - one per architecture - and packages each as a
# drag-to-Applications .dmg in dist/:
#
#   dist/Vimer-arm64.dmg     (Apple Silicon)
#   dist/Vimer-x86_64.dmg    (Intel)
#
# The DMG uses Finder's native appearance-adaptive window (no custom
# background), so icon labels stay readable in both Dark and Light Mode. Built
# headlessly via dmgbuild (writes the .DS_Store directly - no Finder
# automation), so this works over SSH and in CI.
#
# Requires: dmgbuild (pip install dmgbuild). Usage: tool/release_macos.sh
set -euo pipefail
cd "$(dirname "$0")/.."

echo "==> flutter build macos --release (universal)"
flutter build macos --release

SRC="build/macos/Build/Products/Release/Vimer.app"
mkdir -p dist

thin() {
  local arch="$1"
  local out="dist/Vimer-$arch.app"
  echo "==> $out"
  rm -rf "$out"
  cp -R "$SRC" "$out"

  # Thin every fat Mach-O in the bundle down to $arch.
  find "$out" -type f | while read -r f; do
    archs="$(lipo -archs "$f" 2>/dev/null || true)"
    if [[ "$archs" == *"arm64"* && "$archs" == *"x86_64"* ]]; then
      lipo -thin "$arch" "$f" -output "$f"
    fi
  done

  # Re-sign (ad-hoc) so the thinned bundle still runs / verifies.
  codesign --remove-signature "$out" 2>/dev/null || true
  codesign --force --deep --sign - "$out" >/dev/null 2>&1
  echo "    $(du -sh "$out" | cut -f1)  [$(lipo -archs "$out/Contents/MacOS/Vimer")]"
}

thin arm64
thin x86_64

# --- Drag-to-Applications .dmg (headless via dmgbuild) --------------------
DMGBUILD="$(python3 -c 'import sys,os;print(os.path.join(sys.prefix,"bin","dmgbuild"))')"

make_dmg() {
  local arch="$1"
  local app="dist/Vimer-$arch.app"
  local out="dist/Vimer-$arch.dmg"
  local stage="dist/.stage_$arch"
  echo "==> $out"
  rm -f "$out"; rm -rf "$stage"; mkdir -p "$stage"
  # Ship as "Vimer.app" regardless of the per-arch build name.
  cp -R "$app" "$stage/Vimer.app"
  "$DMGBUILD" -s tool/dmg_settings.py \
    -D app="$stage/Vimer.app" \
    -D icon="$stage/Vimer.app/Contents/Resources/AppIcon.icns" \
    "Vimer" "$out" >/dev/null
  rm -rf "$stage"
  echo "    $(du -h "$out" | cut -f1)"
}

make_dmg arm64
make_dmg x86_64

echo "==> done"
