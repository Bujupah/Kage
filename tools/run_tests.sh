#!/usr/bin/env bash
# Runs the headless GDScript test suite. Set GODOT to override the engine binary.
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-$(command -v godot || echo /Applications/Godot.app/Contents/MacOS/Godot)}"
# Refresh the import/global class cache so new class_name scripts resolve.
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
exec "$GODOT" --headless --path . -s res://tests/test_runner.gd
