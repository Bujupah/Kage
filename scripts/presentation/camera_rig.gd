class_name CameraRig
extends Node3D
## Third-person orbit camera with lock-on. Runs at render rate and reads interpolated transforms,
## so it stays smooth while the simulation ticks at 30 Hz.

const MOUSE_SENSITIVITY := 0.0025
const STICK_SENSITIVITY := 2.6
const PITCH_MIN := -1.1
const PITCH_MAX := 0.35
const LOCK_RANGE := 15.0
const FOCUS_HEIGHT := 1.9

var target: FighterBody
var candidates: Array[FighterBody] = []
var lock_target: FighterBody
var yaw := 0.0
var pitch := -0.38

var _spring := SpringArm3D.new()
var _camera := Camera3D.new()


func setup(follow: FighterBody, lockables: Array[FighterBody]) -> void:
	target = follow
	candidates = lockables
	yaw = follow.rotation.y


func _ready() -> void:
	top_level = true
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_spring.spring_length = 4.6
	_spring.margin = 0.2
	_spring.collision_mask = FighterBody.WORLD_LAYER
	_spring.position.x = 0.6 # over-the-shoulder offset
	_spring.add_excluded_object(target.get_rid())
	add_child(_spring)
	_camera.fov = 70.0
	_spring.add_child(_camera)
	_camera.make_current()


func toggle_lock() -> void:
	if lock_target != null:
		lock_target = null
		return
	var forward := Vector3(-sin(yaw), 0.0, -cos(yaw))
	var best_score := INF
	for c in candidates:
		if not c.combatant.is_alive():
			continue
		var to := c.global_position - target.global_position
		var dist := to.length()
		if dist > LOCK_RANGE:
			continue
		var score := forward.angle_to(Vector3(to.x, 0.0, to.z)) * 4.0 + dist * 0.1
		if score < best_score:
			best_score = score
			lock_target = c


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion := event as InputEventMouseMotion
		if lock_target == null:
			yaw -= motion.relative.x * MOUSE_SENSITIVITY
		pitch = clampf(pitch - motion.relative.y * MOUSE_SENSITIVITY, PITCH_MIN, PITCH_MAX)


func _process(delta: float) -> void:
	if target == null:
		return
	if lock_target != null and not lock_target.combatant.is_alive():
		lock_target = null

	var stick := Input.get_vector("look_left", "look_right", "look_up", "look_down")
	pitch = clampf(pitch - stick.y * STICK_SENSITIVITY * delta, PITCH_MIN, PITCH_MAX)
	var focus := target.get_global_transform_interpolated().origin + Vector3.UP * FOCUS_HEIGHT
	if lock_target != null:
		var to := lock_target.get_global_transform_interpolated().origin - target.get_global_transform_interpolated().origin
		if Vector2(to.x, to.z).length() > 0.1:
			yaw = lerp_angle(yaw, atan2(-to.x, -to.z), 1.0 - exp(-10.0 * delta))
	else:
		yaw -= stick.x * STICK_SENSITIVITY * delta
	global_position = focus
	rotation = Vector3(pitch, yaw, 0.0)
