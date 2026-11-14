#!/bin/bash
set -euo pipefail
BRAMBLE_ROOT="$(cd -- "$(dirname -- "$0")/.." && pwd)"
BRAMBLE_GODOT="${BRAMBLE_GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"
"$BRAMBLE_GODOT" --headless --path "$BRAMBLE_ROOT/game" --editor --import --quit
"$BRAMBLE_GODOT" --headless --path "$BRAMBLE_ROOT/game" --script res://tests/run_tests.gd
"$BRAMBLE_GODOT" --headless --path "$BRAMBLE_ROOT/game" --script res://tests/scene_flow.gd
