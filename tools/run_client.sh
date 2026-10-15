#!/usr/bin/env bash
# Starts a windowed duel client. Extra args go to the game, e.g. --host=10.0.0.5 --name=Musashi.
set -euo pipefail
cd "$(dirname "$0")/.."
exec "$(tools/godot_bin.sh)" --path . -- --client "$@"
