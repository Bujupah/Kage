extends Node3D
## M0 combat sandbox (GDD §16): one player against a configurable training dummy, driven by the same
## CombatSimulation the headless region server will own. No networking yet; inputs already flow as
## CombatIntents so P1 can move the simulation behind ENet without touching the rules.

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
	_build_environment()
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
	hud.set_mode_text(dummy_brain.mode_name())
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
		hud.set_mode_text(dummy_brain.mode_name())
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
	var a := sim.find(ev["attacker"])
	var t := sim.find(ev["target"])
	var at := a.position.lerp(t.position, 0.7) + Vector3.UP * 1.2
	match ev["type"]:
		&"hit":
			_spark(at, Color(1, 0.25, 0.2), 0.35 if ev.get("critical", false) else 0.22)
		&"guarded":
			_spark(at, Color(1, 0.8, 0.4), 0.18)
		&"parried":
			_spark(at, Color(0.9, 0.95, 1), 0.5)
		&"guard_broken":
			_spark(at, Color(1, 0.85, 0.2), 0.45)


func _spark(at: Vector3, color: Color, size: float) -> void:
	var spark := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = size
	mesh.height = size * 2.0
	spark.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = color
	spark.material_override = mat
	spark.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(spark)
	spark.global_position = at
	var tween := spark.create_tween().set_parallel()
	tween.tween_property(spark, "scale", Vector3.ONE * 2.2, 0.18)
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.18)
	tween.chain().tween_callback(spark.queue_free)


# --- Placeholder dojo courtyard ------------------------------------------------------------------

func _build_environment() -> void:
	var env := WorldEnvironment.new()
	var environment := Environment.new()
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.22, 0.2, 0.38)
	sky_mat.sky_horizon_color = Color(0.95, 0.55, 0.38)
	sky_mat.ground_horizon_color = Color(0.4, 0.28, 0.25)
	sky_mat.ground_bottom_color = Color(0.1, 0.08, 0.1)
	sky.sky_material = sky_mat
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.glow_enabled = true
	environment.fog_enabled = true
	environment.fog_density = 0.008
	environment.fog_light_color = Color(0.75, 0.5, 0.45)
	env.environment = environment
	add_child(env)

	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.8, 0.6)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-35, -40, 0)
	add_child(sun)

	_block(Vector3(0, -0.5, 0), Vector3(40, 1, 40), Color(0.42, 0.36, 0.3)) # courtyard
	_block(Vector3(0, 0.01, 0), Vector3(10, 0.02, 10), Color(0.62, 0.55, 0.42), false) # sand duel ring
	# Torii gate as a landmark for orientation.
	var red := Color(0.7, 0.12, 0.08)
	_block(Vector3(-2.5, 2.25, -9), Vector3(0.45, 4.5, 0.45), red)
	_block(Vector3(2.5, 2.25, -9), Vector3(0.45, 4.5, 0.45), red)
	_block(Vector3(0, 4.6, -9), Vector3(7.2, 0.4, 0.6), red)
	_block(Vector3(0, 3.8, -9), Vector3(6.0, 0.25, 0.35), red)
	# Low walls and stone lanterns give sight lines and something for the camera spring to hit.
	var stone := Color(0.5, 0.48, 0.45)
	_block(Vector3(-12, 0.6, 0), Vector3(0.6, 1.2, 18), stone)
	_block(Vector3(12, 0.6, 0), Vector3(0.6, 1.2, 18), stone)
	for p: Vector3 in [Vector3(-6, 0, 6), Vector3(6, 0, 6), Vector3(-6, 0, -6), Vector3(6, 0, -6)]:
		_block(p + Vector3(0, 0.6, 0), Vector3(0.5, 1.2, 0.5), stone)
		var lamp := OmniLight3D.new()
		lamp.light_color = Color(1.0, 0.6, 0.3)
		lamp.light_energy = 1.5
		lamp.omni_range = 5.0
		lamp.position = p + Vector3(0, 1.45, 0)
		add_child(lamp)


func _block(center: Vector3, size: Vector3, color: Color, solid: bool = true) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.95
	mesh.material_override = mat
	if not solid:
		mesh.position = center
		add_child(mesh)
		return
	var body := StaticBody3D.new()
	body.collision_layer = FighterBody.WORLD_LAYER
	body.position = center
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	shape.shape = box_shape
	body.add_child(shape)
	body.add_child(mesh)
	add_child(body)
