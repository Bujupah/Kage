class_name NetProtocol
extends RefCounted
## Single manifest for the P1 gameplay wire protocol (MULTIPLAYER.md §3). Client and headless server
## both read these constants, so channel IDs, limits and the version are never duplicated.

const VERSION := 3 ## Bump on any RPC signature or payload layout change; mismatches are refused.
const DEFAULT_PORT := 7777
const MAX_PLAYERS := 16 ## Default region capacity; servers take --max-players.
const NPC_TEAM := 9000 ## All PvE enemies share one team (no friendly fire among them).
const KIND_PLAYER := 0
const KIND_NPC := 1

# ENet transfer channels. Inputs, snapshots and reliable events never share a channel, so a
# retransmitting reliable event cannot stall the latest-state streams.
const CH_CONTROL := 0
const CH_INPUT := 1
const CH_SNAPSHOT := 2
const CH_EVENTS := 3

const SERVER_PEER := 1

## Confirmed-event whitelist: anything else from the wire is dropped by decode_event().
const EVENT_TYPES: Array[StringName] = [
	&"attack_start", &"feint", &"dodge_start", &"hit", &"guarded", &"parried", &"guard_broken",
	&"dodged", &"round_reset", &"respawned",
]
const EVENT_INT_KEYS: Array[String] = ["tick", "attacker", "target", "attack_serial", "damage"]
const EVENT_BOOL_KEYS: Array[String] = ["critical", "killed", "posture_broken", "attacker_broken"]


## True when `tick` is strictly newer than the newest one already accepted. Snapshots that fail
## this are late or reordered and must never overwrite newer state (MULTIPLAYER.md §12).
static func is_newer(tick: int, newest: int) -> bool:
	return tick > newest


## Reads `--key=value` / `--flag` pairs from the user arguments (those after `--`).
static func parse_args(args: PackedStringArray) -> Dictionary:
	var out := {}
	for arg in args:
		if not arg.begins_with("--"):
			continue
		var body := arg.substr(2)
		var eq := body.find("=")
		if eq < 0:
			out[body] = true
		else:
			out[body.substr(0, eq)] = body.substr(eq + 1)
	return out



## Confirmed combat events go over the wire as plain dictionaries of known keys only.
static func encode_event(ev: Dictionary) -> Dictionary:
	var out := {"type": String(ev["type"])}
	for key in EVENT_INT_KEYS + EVENT_BOOL_KEYS:
		if ev.has(key):
			out[key] = ev[key]
	if ev.has("move"):
		out["move"] = String(ev["move"])
	return out


## Client-side inverse of encode_event: returns {} for anything unexpected.
static func decode_event(raw: Variant) -> Dictionary:
	if typeof(raw) != TYPE_DICTIONARY or typeof(raw.get("type")) != TYPE_STRING:
		return {}
	var type := StringName(raw["type"])
	if not EVENT_TYPES.has(type):
		return {}
	var ev := {"type": type}
	for key in EVENT_INT_KEYS:
		if raw.has(key):
			if typeof(raw[key]) != TYPE_INT:
				return {}
			ev[key] = raw[key]
	for key in EVENT_BOOL_KEYS:
		if raw.has(key):
			if typeof(raw[key]) != TYPE_BOOL:
				return {}
			ev[key] = raw[key]
	if typeof(raw.get("move")) == TYPE_STRING:
		ev["move"] = StringName(raw["move"])
	return ev
