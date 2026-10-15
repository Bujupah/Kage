#!/usr/bin/env bash
# Starts the headless authoritative duel server. Extra args go to the game, e.g. --port=7777.
set -euo pipefail
cd "$(dirname "$0")/.."
exec "$(tools/godot_bin.sh)" --headless --path . -- --server "$@"
