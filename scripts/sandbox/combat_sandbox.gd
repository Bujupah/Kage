extends Node3D
## M0 combat sandbox (GDD §16): one player against a configurable training dummy, driven by the same
## CombatSimulation the headless duel server runs (scripts/server/). Fully local; networked duels go
## through Boot with --server / --client.

const KATANA := preload("res://data/weapons/katana_starter.tres")
const PLAYER_ID := 1
const DUMMY_ID := 2
const AUTO_RESET_TICKS := 90

var sim := CombatSimulation.new()
var player: FighterBody
var dummy: FighterBody
var player_controller := PlayerController.new()
var dummy_brain: DummyBrain
var camera_rig := CameraRig.new()
var hud := CombatHud.new()

var _fighters: Array[FighterBody] = []
var _dead_since := -1


func _ready() -> void:
	InputBindings.ensure_defaults()
	DojoLevel.build(self)
	player = _spawn_fighter(PLAYER_ID, 1, Color(0.22, 0.25, 0.4), Vector3(0, 0, 3), Vector3.FORWARD)
	dummy = _spawn_fighter(DUMMY_ID, 2, Color(0.5, 0.18, 0.15), Vector3(0, 0, -1), Vector3.BACK)

	var lockables: Array[FighterBody] = [dummy]
	camera_rig.setup(player, lockables)
	add_child(camera_rig)
	player_controller.camera_rig = camera_rig
	add_child(player_controller)
	dummy_brain = DummyBrain.new(dummy, player)

	hud.setup(player, dummy, {PLAYER_ID: "You", DUMMY_ID: "Training Ronin"})
	add_child(hud)
	hud.set_mode_text("Dummy: " + dummy_brain.mode_name())
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	var started := Time.get_ticks_usec()
	var now := sim.tick
	var intents := {
		PLAYER_ID: player_controller.sample_intent(player),
		DUMMY_ID: dummy_brain.sample_intent(now),
	}
	sim.begin_tick(intents)
	for f in _fighters:
		f.simulate_movement(intents[f.combatant.entity_id], now, delta)
	var events := sim.end_tick()
	for f in _fighters:
		f.update_presentation(now)
	for ev in events:
		_present_event(ev)
	hud.push_events(events)
	_auto_reset(now)
	hud.set_tick_stats(now, Time.get_ticks_usec() - started)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("sandbox_dummy_mode"):
		dummy_brain.cycle_mode(sim.tick)
		hud.set_mode_text("Dummy: " + dummy_brain.mode_name())
	elif event.is_action_pressed("sandbox_reset"):
		_reset_all()


func _spawn_fighter(id: int, team: int, color: Color, at: Vector3, face: Vector3) -> FighterBody:
	var body := FighterBody.new()
	body.name = "Fighter%d" % id
	body.setup(sim.add(Combatant.new(id, team, KATANA)), color, at, face)
	add_child(body)
	_fighters.append(body)
	return body


func _auto_reset(now: int) -> void:
	var anyone_dead := _fighters.any(func(f: FighterBody) -> bool: return not f.combatant.is_alive())
	if not anyone_dead:
		_dead_since = -1
	elif _dead_since < 0:
		_dead_since = now
	elif now - _dead_since >= AUTO_RESET_TICKS:
		_reset_all()


func _reset_all() -> void:
	_dead_since = -1
	for f in _fighters:
		f.respawn(sim.tick)
	dummy_brain.reset(sim.tick)
	camera_rig.lock_target = null


# --- Presentation of confirmed events ------------------------------------------------------------

func _present_event(ev: Dictionary) -> void:
	if not ev.has("target"):
		return
	CombatFx.present_event(self, ev, sim.find(ev["attacker"]).position, sim.find(ev["target"]).position)
