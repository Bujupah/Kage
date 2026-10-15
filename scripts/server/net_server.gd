class_name NetServer
extends Node3D
## Headless authoritative duel server (MULTIPLAYER.md §15 P1). Owns the only CombatSimulation and
## the only collision-authoritative FighterBodies. Each 30 Hz physics tick it consumes one queued
## input per player, steps rules and movement, broadcasts confirmed events reliably and sends every
## player an unreliable-ordered snapshot carrying that player's input ack.
##
## No persistence and no real login: admission is the local stub in PeerRegistry.

const KATANA := preload("res://data/weapons/katana_starter.tres")
const AUTO_RESET_TICKS := 90
const JOIN_TIMEOUT_MSEC := 5000 ## Connected peers that never ask to join are dropped.
const REJECT_DISCONNECT_SEC := 0.5 ## Lets the reliable rejection reach the client first.
const STATS_EVERY_TICKS := CombatSimulation.TICK_RATE * 10

var port := NetProtocol.DEFAULT_PORT
var sim := CombatSimulation.new()
var registry := PeerRegistry.new()
var session := NetSession.new()

var _bodies: Dictionary = {} ## entity_id -> FighterBody
var _connected_at: Dictionary = {} ## peer_id awaiting join -> Time.get_ticks_msec()
var _dead_since := -1
var _tick_usec_max := 0
var _last_logged_rejects := 0


func _ready() -> void:
	DojoLevel.build(self)
	session.name = "Session"
	add_child(session)
	session.join_requested.connect(_on_join_requested)
	session.inputs_received.connect(_on_inputs_received)

	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, NetProtocol.MAX_PLAYERS + 2)
	if err != OK:
		push_error("server: cannot listen on UDP %d (%s)" % [port, error_string(err)])
		get_tree().quit(1)
		return
	# No client-to-client relaying: peers only ever talk to the server, and never learn each
	# other's peer IDs.
	(multiplayer as SceneMultiplayer).server_relay = false
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	print("server: listening on UDP %d, protocol v%d, %d Hz" % [port, NetProtocol.VERSION, CombatSimulation.TICK_RATE])


func _physics_process(delta: float) -> void:
	var started := Time.get_ticks_usec()
	var now := sim.tick
	var intents := registry.collect_intents()
	sim.begin_tick(intents)
	for id: int in _bodies:
		var body: FighterBody = _bodies[id]
		body.simulate_movement(intents.get(id, CombatIntent.new()), now, delta)
	var events := sim.end_tick()
	_auto_reset(now, events)
	_broadcast(now, events)
	_log_events(events)
	_drop_silent_peers()
	_tick_usec_max = maxi(_tick_usec_max, Time.get_ticks_usec() - started)
	if now > 0 and now % STATS_EVERY_TICKS == 0:
		_log_stats(now)


# --- Lifecycle -----------------------------------------------------------------------------------

func _on_peer_connected(peer_id: int) -> void:
	_connected_at[peer_id] = Time.get_ticks_msec()
	print("server: peer %d connected" % peer_id)


func _on_peer_disconnected(peer_id: int) -> void:
	_connected_at.erase(peer_id)
	var p := registry.leave(peer_id)
	if p == null:
		return
	sim.remove(p.entity_id)
	var body: FighterBody = _bodies.get(p.entity_id)
	_bodies.erase(p.entity_id)
	if body != null:
		body.queue_free()
	print("server: %s (peer %d, entity %d) left" % [p.display_name, peer_id, p.entity_id])
	_send_roster()


func _on_join_requested(peer_id: int, version: Variant, player_name: Variant) -> void:
	if not _connected_at.has(peer_id):
		return # Already joined (or unknown): a repeated join is ignored, never a second fighter.
	var result := registry.try_join(peer_id, version, player_name, sim.tick)
	if not result.has("peer"):
		print("server: refused peer %d: %s" % [peer_id, result["reason"]])
		session.join_rejected.rpc_id(peer_id, result["reason"])
		_connected_at.erase(peer_id)
		get_tree().create_timer(REJECT_DISCONNECT_SEC).timeout.connect(
				func() -> void: multiplayer.multiplayer_peer.disconnect_peer(peer_id))
		return
	_connected_at.erase(peer_id)
	var p: PeerRegistry.Peer = result["peer"]
	var spawn: Array = DojoLevel.SPAWNS[p.slot]
	var body := FighterBody.new()
	body.name = "Fighter%d" % p.entity_id
	body.setup(sim.add(Combatant.new(p.entity_id, p.slot + 1, KATANA)), Color.WHITE, spawn[0], spawn[1])
	add_child(body)
	body.respawn(sim.tick)
	_bodies[p.entity_id] = body
	print("server: %s joined as entity %d (peer %d, slot %d)" % [p.display_name, p.entity_id, peer_id, p.slot])
	session.join_accepted.rpc_id(peer_id, p.entity_id, p.epoch, sim.tick)
	_send_roster()


func _on_inputs_received(peer_id: int, epoch: Variant, payload: Variant) -> void:
	registry.submit_inputs(peer_id, epoch, payload, sim.tick)


func _drop_silent_peers() -> void:
	var now := Time.get_ticks_msec()
	for peer_id: int in _connected_at.keys():
		if now - int(_connected_at[peer_id]) > JOIN_TIMEOUT_MSEC:
			_connected_at.erase(peer_id)
			print("server: peer %d never joined; disconnecting" % peer_id)
			multiplayer.multiplayer_peer.disconnect_peer(peer_id)


# --- Replication ---------------------------------------------------------------------------------

func _send_roster() -> void:
	var entries := []
	for p in registry.peers():
		entries.append([p.entity_id, p.slot, p.display_name])
	for p in registry.peers():
		if _is_connected(p.peer_id):
			session.receive_roster.rpc_id(p.peer_id, entries)


func _broadcast(now: int, events: Array[Dictionary]) -> void:
	var entities := []
	for c in sim.combatants:
		entities.append(SnapshotCodec.encode_entity(c))
	var wire_events := []
	for ev in events:
		wire_events.append(NetProtocol.encode_event(ev))
	for p in registry.peers():
		if not _is_connected(p.peer_id):
			continue
		if not wire_events.is_empty():
			session.receive_events.rpc_id(p.peer_id, wire_events)
		session.receive_snapshot.rpc_id(p.peer_id, now, p.inputs.last_applied, entities)


## A peer can drop between ENet noticing and peer_disconnected firing; don't send into the void.
func _is_connected(peer_id: int) -> bool:
	var enet := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	var packet_peer := enet.get_peer(peer_id) if enet != null else null
	return packet_peer != null and packet_peer.get_state() == ENetPacketPeer.STATE_CONNECTED


# --- Match rules ---------------------------------------------------------------------------------

func _auto_reset(now: int, events: Array[Dictionary]) -> void:
	var anyone_dead := sim.combatants.any(func(c: Combatant) -> bool: return not c.is_alive())
	if not anyone_dead:
		_dead_since = -1
	elif _dead_since < 0:
		_dead_since = now
	elif now - _dead_since >= AUTO_RESET_TICKS:
		_dead_since = -1
		for body: FighterBody in _bodies.values():
			body.respawn(sim.tick)
		events.append({"type": &"round_reset", "tick": now})


## Decisive outcomes only; routine swings and guards stay off the console.
func _log_events(events: Array[Dictionary]) -> void:
	for ev in events:
		var line := ""
		match ev["type"]:
			&"parried":
				line = "entity %d parried entity %d" % [ev["target"], ev["attacker"]]
			&"guard_broken":
				line = "entity %d broke entity %d's guard" % [ev["attacker"], ev["target"]]
			&"hit":
				if ev.get("killed", false):
					line = "entity %d killed entity %d" % [ev["attacker"], ev["target"]]
			&"round_reset":
				line = "round reset"
		if not line.is_empty():
			print("server: tick %d · %s" % [ev["tick"], line])


func _log_stats(now: int) -> void:
	var rejects := registry.rejected_inputs
	var line := "server: tick %d · %d player(s) · worst tick %.2f ms" % [now, registry.count(), _tick_usec_max / 1000.0]
	if rejects != _last_logged_rejects:
		line += " · %d rejected input packet(s) total" % rejects
		_last_logged_rejects = rejects
	print(line)
	_tick_usec_max = 0
