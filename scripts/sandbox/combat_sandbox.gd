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
	ProvinceLevel.build(self)
	player = _spawn_fighter(PLAYER_ID, 1, Color(0.13, 0.14, 0.18), Color(0.62, 0.1, 0.08), Vector3(0, 0, 3), Vector3.FORWARD)
	dummy = _spawn_fighter(DUMMY_ID, 2, Color(0.24, 0.2, 0.16), Color(0.75, 0.68, 0.52), Vector3(0, 0, -1), Vector3.BACK)

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
	for c in sim.combatants:
		c.zone = RegionMap.rule_at(c.position)
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


func _spawn_fighter(id: int, team: int, color: Color, accent: Color, at: Vector3, face: Vector3) -> FighterBody:
	var body := FighterBody.new()
	body.name = "Fighter%d" % id
	body.setup(sim.add(Combatant.new(id, team, KATANA)), color, at, face, accent)
	# The player wears their equipped look; the training ronin wears black lacquer for contrast.
	body.appearance = PlayerProfile.appearance() if id == PLAYER_ID else \
			{"outfit": "arm.obsidian_vow.v1", "blade": "wpn.katana.sumi.v1", "scarf": "scf.shadow_veil.v1"}
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
	if not ev.has("attacker"):
		return
	var a := sim.find(ev["attacker"])
	if not ev.has("target"):
		CombatFx.present_solo(self, ev, a.position)
		return
	CombatFx.present_event(self, ev, a.position, sim.find(ev["target"]).position)
