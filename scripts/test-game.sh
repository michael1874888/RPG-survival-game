#!/bin/bash
set -euo pipefail
BRAMBLE_ROOT="$(cd -- "$(dirname -- "$0")/.." && pwd)"
BRAMBLE_GODOT="${BRAMBLE_GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"
"$BRAMBLE_GODOT" --headless --path "$BRAMBLE_ROOT/game" --editor --import --quit

run_checks() {
  local script="$1"
  local marker="$2"
  local output
  output="$(mktemp -t bramble-test)"
  if ! "$BRAMBLE_GODOT" --headless --path "$BRAMBLE_ROOT/game" --script "$script" 2>&1 | tee "$output"; then
    rm -f "$output"
    return 1
  fi
  if grep -q 'SCRIPT ERROR' "$output" || ! grep -Eq "$marker" "$output"; then
    rm -f "$output"
    return 1
  fi
  rm -f "$output"
}

run_checks res://tests/run_tests.gd '^RESULT: [0-9]+ checks, 0 failures$'
run_checks res://tests/nana_build_tests.gd '^BUILD EXPERIMENT: [0-9]+ checks, 0 failures$'
run_checks res://tests/nana_series_tests.gd '^SERIES RESULT: [0-9]+ checks, 0 failures$'
run_checks res://tests/nana_growth_tests.gd '^GROWTH RESULT: [0-9]+ checks, 0 failures$'
run_checks res://tests/treasure_tests.gd '^TREASURE RESULT: [0-9]+ checks, 0 failures$'
run_checks res://tests/scene_flow.gd '^SCENE RESULT: [0-9]+ checks, 0 failures$'
run_checks res://tests/r1_tests.gd '^R1 RESULT: [0-9]+ checks, 0 failures$'
run_checks res://tests/r1_mechanics.gd '^R1 MECHANICS: [0-9]+ checks, 0 failures$'
run_checks res://tests/r1_scene_flow.gd '^R1 SCENE RESULT: [0-9]+ checks, 0 failures$'
run_checks res://tests/x1_data_tests.gd '^X1 DATA: [0-9]+ checks, 0 failures$'
run_checks res://tests/x1_combat_tests.gd '^X1 COMBAT: [0-9]+ checks, 0 failures$'
run_checks res://tests/x1_enemy_tests.gd '^X1 ENEMY: [0-9]+ checks, 0 failures$'
run_checks res://tests/x1_build_tests.gd '^X1 BUILD: [0-9]+ checks, 0 failures$'
run_checks res://tests/x1_run_tests.gd '^X1 RUN: [0-9]+ checks, 0 failures$'
run_checks res://tests/x1_scene_flow.gd '^X1 SCENE: [0-9]+ checks, 0 failures$'
