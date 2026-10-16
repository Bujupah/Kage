class_name PeerRegistry
extends RefCounted
## Server-side admission and input routing, kept free of nodes so it can be tested headless.
##
## Login is a local stub for P1 (MULTIPLAYER.md §15): a matching protocol version and a free slot
## admit the peer. The server assigns the entity ID and a random session epoch; the ENet peer ID is
## only a connection handle and never becomes identity. Every input names neither entity nor peer —
## the sender ID chooses the queue, so one client can never drive another's fighter.

class Peer:
	var peer_id: int
	var entity_id: int
	var epoch: int
	var slot: int
	var display_name: String
	var appearance: Dictionary = CosmeticCatalog.DEFAULTS.duplicate() ## Sanitised cosmetic IDs.
	var inputs := PeerInputQueue.new()

const MAX_NAME_LENGTH := 16
const FIRST_ENTITY_ID := 100

var rejected_inputs := 0
var _peers: Dictionary = {} ## peer_id -> Peer
var _next_entity_id := FIRST_ENTITY_ID
var _rng := RandomNumberGenerator.new()


var max_players := NetProtocol.MAX_PLAYERS


func _init(seed_value: int = 0, capacity: int = NetProtocol.MAX_PLAYERS) -> void:
	max_players = capacity
	if seed_value != 0:
		_rng.seed = seed_value
	else:
		_rng.randomize()


## Returns {"peer": Peer} on success or {"reason": String} on refusal.
func try_join(peer_id: int, version: Variant, requested_name: Variant, now: int = 0, appearance: Variant = {}) -> Dictionary:
	if typeof(version) != TYPE_INT or version != NetProtocol.VERSION:
		return {"reason": "protocol version mismatch (server %d)" % NetProtocol.VERSION}
	if _peers.has(peer_id):
		return {"reason": "already joined"}
	var slot := _free_slot()
	if slot < 0:
		return {"reason": "server full"}
	var p := Peer.new()
	p.peer_id = peer_id
	p.slot = slot
	p.entity_id = _next_entity_id
	_next_entity_id += 1
	p.epoch = _rng.randi_range(1, 0x7fffffff)
	p.display_name = sanitize_name(requested_name, "Ronin %d" % (slot + 1))
	p.inputs.last_received_tick = now
	p.appearance = CosmeticCatalog.sanitize(appearance)
	_peers[peer_id] = p
	return {"peer": p}


func leave(peer_id: int) -> Peer:
	var p: Peer = _peers.get(peer_id)
	_peers.erase(peer_id)
	return p


func get_peer(peer_id: int) -> Peer:
	return _peers.get(peer_id)


func peers() -> Array[Peer]:
	var out: Array[Peer] = []
	for p: Peer in _peers.values():
		out.append(p)
	return out


func count() -> int:
	return _peers.size()


## Routes an input packet by its sender. Returns false (and counts it) when rejected.
func submit_inputs(sender_id: int, epoch: Variant, payload: Variant, now: int) -> bool:
	var p: Peer = _peers.get(sender_id)
	if p == null or typeof(epoch) != TYPE_INT or epoch != p.epoch:
		rejected_inputs += 1
		return false
	if p.inputs.receive(payload, now) < 0:
		rejected_inputs += 1
		return false
	return true


## This tick's intents keyed by entity ID; consumes one queued input per peer.
func collect_intents() -> Dictionary:
	var intents := {}
	for p: Peer in _peers.values():
		intents[p.entity_id] = p.inputs.next_intent()
	return intents


static func sanitize_name(value: Variant, fallback: String) -> String:
	if typeof(value) != TYPE_STRING:
		return fallback
	var clean := ""
	for ch in (value as String).strip_edges():
		if clean.length() >= MAX_NAME_LENGTH:
			break
		var code := ch.unicode_at(0)
		if code >= 32 and code != 127:
			clean += ch
	return clean if not clean.is_empty() else fallback


func _free_slot() -> int:
	for slot in max_players:
		if not _peers.values().any(func(p: Peer) -> bool: return p.slot == slot):
			return slot
	return -1
