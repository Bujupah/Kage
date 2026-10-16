class_name NetClient
extends Node3D
## Windowed game client for a region server (MULTIPLAYER.md §5). It never decides combat outcomes:
## - its own fighter's movement is predicted from quantized inputs, then reconciled every snapshot by
##   rewinding to the server state and replaying the inputs the server has not acknowledged yet;
## - remote fighters are interpolated a couple of ticks behind the newest snapshot;
## - health, posture, hits, parries and death only change when the server says so.
## Attack and dodge starts are not predicted in P1: they appear once confirmed (one RTT later).

signal phase_changed(detail: String, step: int) ## Join progress for LoadingScreen (0..3).
signal ready_to_play
signal failed(title: String, reason: String)

const KATANA := preload("res://data/weapons/katana_starter.tres")
const INTERP_DELAY_TICKS := 2 ## Render remote fighters this far behind the newest snapshot.
const RESYNC_TICKS := 3 ## Re-anchor the server-tick estimate when it drifts further than this.
const INPUT_REDUNDANCY := 4 ## Each packet repeats the newest unacked inputs to survive loss.
const MAX_PENDING_INPUTS := 90 ## ~3 s; older unacked inputs are dropped, not replayed forever.
const SNAP_DISTANCE := 2.0 ## Corrections larger than this teleport instead of blending.
const STATS_EVERY_TICKS := CombatSimulation.TICK_RATE * 10
const JOIN_TIMEOUT_MSEC := 8000
const HIDDEN := Vector3(0, -100, 0) ## Parking spot for bodies and proxies before their first snapshot.
const TARGET_RANGE := 25.0 ## HUD target panel and bots consider fighters this close. ## Give up on connect + join well before ENet's ~30 s timeout.
const COLORS := [Color(0.13, 0.14, 0.18), Color(0.2, 0.15, 0.13)]
const ACCENTS := [Color(0.62, 0.1, 0.08), Color(0.2, 0.28, 0.55)] ## Scarf/sash per slot.

var host := "127.0.0.1"
var port := NetProtocol.DEFAULT_PORT
var player_name := ""
var bot_mode := -1 ## DummyBrain.Mode to drive this client with scripted input (soak/smoke tests).

var session := NetSession.new()
var inbox := SnapshotInbox.new()
var player_controller: PlayerController ## Created with our own fighter, unless a bot drives it.
var camera_rig: CameraRig
var hud: CombatHud ## Created once our own fighter exists.

var local_entity_id := -1
var correction_last := 0.0 ## Metres the last reconciliation moved the local fighter.
var correction_max := 0.0 ## Worst blended correction since the last stats line.
var teleports := 0 ## Corrections beyond SNAP_DISTANCE (respawns, or badly diverged prediction).

var _epoch := 0
var _bodies: Dictionary = {} ## entity_id -> FighterBody
var _buffers: Dictionary = {} ## remote entity_id -> InterpolationBuffer
var _proxies: Dictionary = {} ## remote entity_id -> StaticBody3D at the newest server position
## Jolt only sees a moved static body after the next physics step. For the tick in which a proxy
## jumped (or we respawned) prediction ignores fighters, so a stale proxy cannot shove us.
var _proxies_settling := false
var _names: Dictionary = {} ## entity_id -> display name
var _pending: Array[CombatIntent] = [] ## Sent but not yet acknowledged, oldest first.
var _sequence := 0
var _bot: DummyBrain
var _predict_tick := 0 ## Server tick the newest predicted input is expected to run on.
var _server_tick_est := -1.0
var _status := "connecting…"
var _overview_camera := Camera3D.new()
var _ready_emitted := false
var _join_deadline := 0
var _failed := false


func _ready() -> void:
	InputBindings.ensure_defaults()
	ProvinceLevel.build(self)
	_overview_camera.position = Vector3(0, 9, 11)
	_overview_camera.rotation_degrees = Vector3(-38, 0, 0)
	add_child(_overview_camera)
	_overview_camera.make_current()

	session.name = "Session"
	add_child(session)
	session.join_accepted_received.connect(_on_join_accepted)
	session.join_rejected_received.connect(_on_join_rejected)
	session.roster_received.connect(_on_roster)
	session.snapshot_received.connect(inbox.offer)
	session.events_received.connect(_on_events)

	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(host, port)
	if err != OK:
		_status = "cannot create client: %s" % error_string(err)
		_fail.call_deferred("Can't start connection", "%s (%s)." % [_status, host])
		return
	multiplayer.multiplayer_peer = peer
	_join_deadline = Time.get_ticks_msec() + JOIN_TIMEOUT_MSEC
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(func() -> void:
		_status = "connection to %s:%d failed" % [host, port]
		print("client: " + _status)
		_fail("Can't reach server", "No answer from %s:%d. Check the address and that the server is running." % [host, port]))
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	_status = "connecting to %s:%d…" % [host, port]
	phase_changed.emit.call_deferred("Contacting %s:%d" % [host, port], 0)


func _physics_process(delta: float) -> void:
	if local_entity_id < 0 and _join_deadline > 0 and Time.get_ticks_msec() > _join_deadline:
		_join_deadline = 0
		var reached := multiplayer.multiplayer_peer != null and \
				multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED
		_fail("Can't reach server" if not reached else "No answer from server",
				"No response from %s:%d within %d s. Check the address and that the server is running." % [host, port, JOIN_TIMEOUT_MSEC / 1000]
				if not reached else "Connected, but the server never seated you. It may be busy or running another version.")
		if multiplayer.multiplayer_peer != null:
			multiplayer.multiplayer_peer.close()
	if _server_tick_est >= 0.0:
		_server_tick_est += 1.0
	var snapshot := inbox.take()
	if not snapshot.is_empty():
		_apply_snapshot(snapshot, delta)
	var local: FighterBody = _bodies.get(local_entity_id)
	if local != null:
		_predict_and_send(local, delta)
		_proxies_settling = false
		_set_fighter_collision(local, true)
	_update_remotes()
	if hud != null and Engine.get_physics_frames() % 6 == 0:
		hud.set_target(_nearest_target(), _names)
	_update_status()


# --- Session -------------------------------------------------------------------------------------

func _on_connected() -> void:
	_status = "connected, joining…"
	phase_changed.emit("Presenting your identity to the region server", 1)
	session.request_join.rpc_id(NetProtocol.SERVER_PEER, NetProtocol.VERSION, player_name, PlayerProfile.appearance())


func _on_join_accepted(entity_id: Variant, epoch: Variant, server_tick: Variant) -> void:
	if typeof(entity_id) != TYPE_INT or typeof(epoch) != TYPE_INT or typeof(server_tick) != TYPE_INT:
		return
	local_entity_id = entity_id
	_join_deadline = 0
	_epoch = epoch
	_predict_tick = server_tick
	_server_tick_est = server_tick
	_status = "joined"
	print("client: joined as entity %d at server tick %d" % [entity_id, server_tick])
	phase_changed.emit("Waiting for the first world snapshot", 2)


func _on_join_rejected(reason: Variant) -> void:
	_status = "refused by server: %s" % str(reason)
	print("client: " + _status)
	_fail("Join refused", "The server refused to seat you: %s." % str(reason))


func _on_server_disconnected() -> void:
	_status = "disconnected from server"
	print("client: " + _status)
	_fail("Connection lost", "The server closed the connection.")
	multiplayer.multiplayer_peer = null
	local_entity_id = -1
	inbox.reset()


## The roster is reliable and idempotent: spawn whoever is new, free whoever is gone.
func _on_roster(entries: Variant) -> void:
	if typeof(entries) != TYPE_ARRAY:
		return
	var seen := {}
	for e: Variant in entries:
		if typeof(e) != TYPE_ARRAY or e.size() != 4 or typeof(e[0]) != TYPE_INT \
				or typeof(e[1]) != TYPE_INT or typeof(e[2]) != TYPE_STRING \
				or not (e[1] in [NetProtocol.KIND_PLAYER, NetProtocol.KIND_NPC]):
			continue
		var id: int = e[0]
		seen[id] = true
		_names[id] = e[2]
		var look := CosmeticCatalog.sanitize(e[3])
		if not _bodies.has(id):
			_spawn(id, e[1], look)
		elif (_bodies[id] as FighterBody).model != null:
			(_bodies[id] as FighterBody).model.apply_appearance(look)
	for id: int in _bodies.keys():
		if not seen.has(id):
			_despawn(id)
	_refresh_hud()


## Players and NPCs look alike to the client; only the roster kind and name differ. Position comes
## from the first snapshot, so a new body stays hidden until then.
func _spawn(id: int, kind: int, look: Dictionary = {}) -> void:
	var body := FighterBody.new()
	body.name = "Fighter%d" % id
	var team := NetProtocol.NPC_TEAM if kind == NetProtocol.KIND_NPC else id
	body.setup(Combatant.new(id, team, KATANA), COLORS[0], HIDDEN, Vector3.FORWARD, ACCENTS[id % ACCENTS.size()])
	body.appearance = look
	add_child(body)
	_bodies[id] = body
	if id == local_entity_id:
		camera_rig = CameraRig.new()
		camera_rig.setup(body, [] as Array[FighterBody])
		add_child(camera_rig)
		if bot_mode < 0:
			player_controller = PlayerController.new()
			player_controller.camera_rig = camera_rig
			add_child(player_controller)
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		# The drawn remote fighter lives in the past, so it never collides. Prediction instead
		# bumps into a proxy at the newest server position, the closest thing to what the server
		# will collide with when our input arrives.
		body.collision_layer = 0
		body.collision_mask = 0
		body.visible = false
		_buffers[id] = InterpolationBuffer.new()
		_proxies[id] = _make_proxy(HIDDEN)
	if camera_rig != null:
		camera_rig.candidates.assign(_bodies.values().filter(
				func(b: FighterBody) -> bool: return b.combatant.entity_id != local_entity_id))


func _despawn(id: int) -> void:
	var body: FighterBody = _bodies[id]
	_bodies.erase(id)
	_buffers.erase(id)
	if _proxies.has(id):
		(_proxies[id] as Node).queue_free()
		_proxies.erase(id)
	_bot = null
	if camera_rig != null:
		camera_rig.candidates.erase(body)
		if camera_rig.lock_target == body:
			camera_rig.lock_target = null
	body.queue_free()


func _make_proxy(at: Vector3) -> StaticBody3D:
	var proxy := StaticBody3D.new()
	proxy.collision_layer = FighterBody.FIGHTER_LAYER
	proxy.collision_mask = 0
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.8
	shape.shape = capsule
	shape.position.y = 0.9
	proxy.add_child(shape)
	add_child(proxy)
	proxy.global_position = at
	return proxy


## Nearest living fighter within TARGET_RANGE (the camera lock target wins when set).
func _nearest_target() -> FighterBody:
	var local: FighterBody = _bodies.get(local_entity_id)
	if local == null:
		return null
	if camera_rig != null and camera_rig.lock_target != null and is_instance_valid(camera_rig.lock_target):
		return camera_rig.lock_target
	var best: FighterBody = null
	var best_d := TARGET_RANGE
	for id: int in _bodies:
		var b: FighterBody = _bodies[id]
		if id == local_entity_id or not b.visible or not b.combatant.is_alive():
			continue
		var d := local.global_position.distance_to(b.global_position)
		if d < best_d:
			best_d = d
			best = b
	return best


func _refresh_hud() -> void:
	var local: FighterBody = _bodies.get(local_entity_id)
	var opponent := _nearest_target()
	if hud != null:
		hud.set_target(opponent, _names)
	elif local != null:
		hud = CombatHud.new()
		hud.setup(local, opponent, _names)
		hud.online = true
		add_child(hud)


# --- Prediction and reconciliation ---------------------------------------------------------------

func _predict_and_send(local: FighterBody, delta: float) -> void:
	var intent := InputCodec.quantize(_sample_intent(local))
	_pending.append(intent)
	while _pending.size() > MAX_PENDING_INPUTS:
		_pending.pop_front()
	var start := maxi(_pending.size() - INPUT_REDUNDANCY, 0)
	session.submit_inputs.rpc_id(NetProtocol.SERVER_PEER, _epoch, InputCodec.encode(_pending.slice(start)))
	_predict_tick += 1
	_predict_step(local, intent, _predict_tick, delta)
	local.update_presentation(_predict_tick)


func _sample_intent(local: FighterBody) -> CombatIntent:
	var intent: CombatIntent
	if bot_mode < 0:
		intent = player_controller.sample_intent(local)
	else:
		var opponent := _nearest_target()
		if _bot == null and opponent != null:
			_bot = DummyBrain.new(local, opponent)
			_bot.mode = bot_mode as DummyBrain.Mode
			_bot.reset(_predict_tick)
		elif _bot != null and opponent != null:
			_bot.target = opponent
		intent = _bot.sample_intent(_predict_tick + 1) if _bot != null else CombatIntent.new()
	_sequence += 1
	intent.sequence = _sequence
	return intent


func _predict_step(local: FighterBody, intent: CombatIntent, tick: int, delta: float) -> void:
	local.combatant.update_timers(tick) # Expire attack/dodge/stagger locally; the server re-confirms.
	local.simulate_movement(intent, tick, delta)


func _apply_snapshot(snapshot: Dictionary, delta: float) -> void:
	var tick: int = snapshot["tick"]
	if _server_tick_est < 0.0 or absf(_server_tick_est - tick) > RESYNC_TICKS:
		_server_tick_est = tick
	# Move collision proxies first so the local replay below collides against this snapshot.
	for rec: Array in snapshot["entities"]:
		var proxy: StaticBody3D = _proxies.get(rec[SnapshotCodec.ID])
		if proxy != null:
			var to := SnapshotCodec.position_of(rec)
			if proxy.global_position.distance_to(to) > SNAP_DISTANCE:
				_proxies_settling = true
			proxy.global_position = to
	for rec: Array in snapshot["entities"]:
		var id: int = rec[SnapshotCodec.ID]
		if not _bodies.has(id):
			continue # Roster (reliable) has not arrived yet.
		if id == local_entity_id:
			_reconcile(_bodies[id], rec, tick, snapshot["ack"], delta)
			if not _ready_emitted:
				_ready_emitted = true
				phase_changed.emit("In the province", 3)
				ready_to_play.emit()
		elif _buffers.has(id):
			(_buffers[id] as InterpolationBuffer).push(tick, SnapshotCodec.position_of(rec),
					rec[SnapshotCodec.YAW], rec)


## Rewind to the authoritative state at `tick`, drop acknowledged inputs, replay the rest.
func _reconcile(local: FighterBody, rec: Array, tick: int, ack: int, delta: float) -> void:
	var predicted := local.global_position
	var c := local.combatant
	var respawned: bool = rec[SnapshotCodec.LIFE] != c.life
	SnapshotCodec.apply_combat_state(c, rec)
	c.position = SnapshotCodec.position_of(rec)
	c.facing = SnapshotCodec.facing_of(rec)
	local.global_position = c.position
	local.velocity = Vector3.ZERO
	if respawned:
		_proxies_settling = true
	_set_fighter_collision(local, not _proxies_settling)
	while not _pending.is_empty() and _pending[0].sequence <= ack:
		_pending.pop_front()
	var t := tick
	for intent in _pending:
		t += 1
		_predict_step(local, intent, t, delta)
	local.rotation.y = atan2(-c.facing.x, -c.facing.z)
	_predict_tick = t
	correction_last = predicted.distance_to(local.global_position)
	if respawned or correction_last > SNAP_DISTANCE:
		teleports += 1
		local.clear_visual_correction()
		local.reset_physics_interpolation()
	else:
		correction_max = maxf(correction_max, correction_last)
		local.add_visual_correction(predicted - local.global_position)


func _set_fighter_collision(local: FighterBody, enabled: bool) -> void:
	local.collision_mask = FighterBody.WORLD_LAYER | (FighterBody.FIGHTER_LAYER if enabled else 0)


func _fail(title: String, reason: String) -> void:
	if _failed:
		return # One explanation per session; a timeout followed by ENet's own failure is one event.
	_failed = true
	failed.emit(title, reason)


func _exit_tree() -> void:
	if multiplayer.multiplayer_peer != null and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null


# --- Remote interpolation ------------------------------------------------------------------------

func _update_remotes() -> void:
	if _server_tick_est < 0.0:
		return
	var render_tick := _server_tick_est - INTERP_DELAY_TICKS
	for id: int in _buffers:
		var buffer: InterpolationBuffer = _buffers[id]
		var s := buffer.sample(render_tick)
		if s.is_empty():
			continue
		var body: FighterBody = _bodies[id]
		var c := body.combatant
		if not body.visible:
			body.visible = true
			body.global_position = s["position"]
			body.reset_physics_interpolation()
		var jump := body.global_position.distance_to(s["position"])
		var respawned: bool = s["record"][SnapshotCodec.LIFE] != c.life
		SnapshotCodec.apply_combat_state(c, s["record"])
		c.position = s["position"]
		c.facing = Vector3(sin(s["yaw"]), 0.0, cos(s["yaw"]))
		body.global_position = c.position
		body.rotation.y = atan2(-c.facing.x, -c.facing.z)
		if respawned or jump > SNAP_DISTANCE:
			body.reset_physics_interpolation()
		body.update_presentation(int(render_tick))


# --- Confirmed events ----------------------------------------------------------------------------

func _on_events(raw: Variant) -> void:
	if typeof(raw) != TYPE_ARRAY:
		return
	var events: Array[Dictionary] = []
	for r: Variant in raw:
		var ev := NetProtocol.decode_event(r)
		if not ev.is_empty():
			events.append(ev)
	for ev in events:
		var a: FighterBody = _bodies.get(ev.get("attacker", -1))
		var t: FighterBody = _bodies.get(ev.get("target", -1))
		if a != null and t != null:
			CombatFx.present_event(self, ev, a.global_position, t.global_position)
		elif a != null:
			CombatFx.present_solo(self, ev, a.global_position)
	if hud != null:
		hud.push_events(events)


func _update_status() -> void:
	var rtt := -1
	var enet := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	if enet != null and enet.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		var server := enet.get_peer(NetProtocol.SERVER_PEER)
		if server != null:
			rtt = int(server.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME))
	var text := "%s · %s · server tick %d · rtt %d ms · unacked %d · last correction %.2f m · %d fps" % [
		player_name if not player_name.is_empty() else "client", _status, int(_server_tick_est), rtt,
		_pending.size(), correction_last, Engine.get_frames_per_second()]
	if hud != null:
		hud.set_status_text(text)
		hud.set_latency(rtt)
	if local_entity_id >= 0 and _predict_tick % STATS_EVERY_TICKS == 0:
		print("client: tick %d · rtt %d ms · unacked %d · worst correction %.3f m · teleports %d · stale snapshots dropped %d" % [
			_predict_tick, rtt, _pending.size(), correction_max, teleports, inbox.stale_dropped])
		correction_max = 0.0
