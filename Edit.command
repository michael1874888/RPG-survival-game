#!/bin/bash
set -euo pipefail
BRAMBLE_ROOT="$(cd -- "$(dirname -- "$0")" && pwd)"
BRAMBLE_GODOT="${BRAMBLE_GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"
if [[ ! -x "$BRAMBLE_GODOT" ]]; then
  echo "Set BRAMBLE_GODOT_BIN to the Godot 4.7.2 executable, or install it at /Applications/Godot.app."
  exit 1
fi
exec "$BRAMBLE_GODOT" --editor --path "$BRAMBLE_ROOT/game" "$@"
