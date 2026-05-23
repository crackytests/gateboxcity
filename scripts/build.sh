#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EXPORT_PRESETS="$PROJECT_ROOT/export_presets.cfg"
BUILD_DIR="$PROJECT_ROOT/build"

WINDOWS_PRESET="${WINDOWS_PRESET:-CI Windows Desktop}"
LINUX_PRESET="${LINUX_PRESET:-CI Linux}"

fail() {
  echo "build.sh: $*" >&2
  exit 1
}

require_preset() {
  local preset_name="$1"

  if ! grep -Eq '^name="'"$(printf '%s' "$preset_name" | sed 's/[][\\.^$*+?{}|()]/\\&/g')"'"$' "$EXPORT_PRESETS"; then
    fail "export preset '$preset_name' was not found in export_presets.cfg. Set WINDOWS_PRESET or LINUX_PRESET to an existing preset name."
  fi
}

if [[ -z "${REDOT_BIN:-}" ]]; then
  fail "REDOT_BIN is not set. Example: REDOT_BIN=/path/to/redot ./scripts/build.sh"
fi

if [[ ! -x "$REDOT_BIN" ]]; then
  fail "REDOT_BIN does not point to an executable file: $REDOT_BIN"
fi

if [[ ! -f "$EXPORT_PRESETS" ]]; then
  fail "export_presets.cfg is missing at project root. Create export presets in Redot before running local exports."
fi

require_preset "$WINDOWS_PRESET"
require_preset "$LINUX_PRESET"

mkdir -p "$BUILD_DIR/windows" "$BUILD_DIR/linux"

echo "Using Redot: $REDOT_BIN"
"$REDOT_BIN" --headless --version

echo "Importing project..."
"$REDOT_BIN" --headless --path "$PROJECT_ROOT" --editor --quit

echo "Exporting Windows build with preset '$WINDOWS_PRESET'..."
"$REDOT_BIN" --headless --path "$PROJECT_ROOT" --export-release "$WINDOWS_PRESET" "$BUILD_DIR/windows/GATEBOX_BREACH.exe"

echo "Exporting Linux build with preset '$LINUX_PRESET'..."
"$REDOT_BIN" --headless --path "$PROJECT_ROOT" --export-release "$LINUX_PRESET" "$BUILD_DIR/linux/GATEBOX_BREACH.x86_64"
chmod +x "$BUILD_DIR/linux/GATEBOX_BREACH.x86_64"

echo "Builds written to:"
echo "  $BUILD_DIR/windows"
echo "  $BUILD_DIR/linux"
