#!/usr/bin/env bash
# End-to-end network smoke test: a headless region server (arena spawns) plus two headless bot
# clients fight over real ENet on localhost, with the PvE camps running. Fails on any script error, a missing join, or a duel with no decisive outcome.
#   tools/net_smoke.sh [seconds]
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="$(tools/godot_bin.sh)"
SECS="${1:-30}"
PORT="${PORT:-$((20000 + RANDOM % 20000))}"
LOGS="$(mktemp -d)"
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true

"$GODOT" --headless --path . -- --server --spawn=arena --port="$PORT" --quit-after=$((SECS + 4)) >"$LOGS/server.log" 2>&1 &
sleep 1.5
"$GODOT" --headless --path . -- --client --port="$PORT" --name=Aki --bot=duelist --quit-after="$SECS" >"$LOGS/aki.log" 2>&1 &
"$GODOT" --headless --path . -- --client --port="$PORT" --name=Bo --bot=attack --quit-after="$SECS" >"$LOGS/bo.log" 2>&1 &
wait

for f in server aki bo; do
	echo "--- $f"
	grep -E "^(server|client):|ERROR" "$LOGS/$f.log" || true
done
fail=0
if grep -q "SCRIPT ERROR" "$LOGS"/*.log; then echo "FAIL: script errors"; fail=1; fi
if [ "$(grep -c " joined as entity" "$LOGS/server.log")" -ne 2 ]; then echo "FAIL: expected 2 joins"; fail=1; fi
if ! grep -qE "parried|killed|broke" "$LOGS/server.log"; then echo "FAIL: no decisive server-side outcome"; fail=1; fi
# PvE phase: one bot dropped at the bamboo clearing must end up fighting the server's bandits.
PVE_PORT=$((PORT + 1))
"$GODOT" --headless --path . -- --server --spawn=frontier --port="$PVE_PORT" --quit-after=$((SECS + 4)) >"$LOGS/pve_server.log" 2>&1 &
sleep 1.5
"$GODOT" --headless --path . -- --client --port="$PVE_PORT" --name=Wanderer --bot=duelist --quit-after="$SECS" >"$LOGS/pve_bot.log" 2>&1 &
wait
echo "--- pve server"
grep -E "^server:|ERROR" "$LOGS/pve_server.log" || true
if grep -q "SCRIPT ERROR" "$LOGS"/pve_*.log; then echo "FAIL: script errors (PvE)"; fail=1; fi
if ! grep -qE "entity 50[0-9][0-9] (parried|killed|broke)|(parried|killed|broke)[^·]* entity 50[0-9][0-9]" "$LOGS/pve_server.log"; then
	echo "FAIL: no decisive player-vs-NPC outcome"; fail=1
fi
[ "$fail" -eq 0 ] && echo "net smoke OK (logs in $LOGS)"
exit "$fail"
