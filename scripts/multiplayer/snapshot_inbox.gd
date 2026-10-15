class_name SnapshotInbox
extends RefCounted
## Client-side gate for server snapshots. Only strictly newer, well-formed snapshots get through;
## late or reordered packets are counted and dropped so they can never roll state backwards
## (MULTIPLAYER.md §12 "Late server packet"). The newest accepted snapshot waits here until the next
## physics tick consumes it, because reconciliation must run inside the physics step.

var newest_tick := -1
var newest_ack := 0
var stale_dropped := 0
var malformed_dropped := 0

var _pending: Dictionary = {}


## Returns true when the snapshot was accepted as the newest state.
func offer(server_tick: Variant, ack_sequence: Variant, entities: Variant) -> bool:
	if typeof(server_tick) != TYPE_INT or typeof(ack_sequence) != TYPE_INT \
			or typeof(entities) != TYPE_ARRAY or server_tick < 0 or ack_sequence < 0:
		malformed_dropped += 1
		return false
	if not NetProtocol.is_newer(server_tick, newest_tick) or ack_sequence < newest_ack:
		stale_dropped += 1
		return false
	for rec: Variant in entities:
		if not SnapshotCodec.is_valid(rec):
			malformed_dropped += 1
			return false
	newest_tick = server_tick
	newest_ack = ack_sequence
	_pending = {"tick": server_tick, "ack": ack_sequence, "entities": entities}
	return true


## Hands over the newest unconsumed snapshot, or an empty dictionary.
func take() -> Dictionary:
	var out := _pending
	_pending = {}
	return out


func reset() -> void:
	newest_tick = -1
	newest_ack = 0
	_pending = {}
