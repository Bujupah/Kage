class_name PlayerController
extends Node
## Turns local device input into CombatIntents. Presses are accumulated between ticks so a tap
## shorter than one 33 ms tick is never lost. While a menu is open (UiShell) it sends idle intents,
## so opening the menu online never leaves a button stuck down.

var camera_rig: CameraRig
var _pressed := 0
var _sequence := 0


func _unhandled_input(event: InputEvent) -> void:
	if UiShell.gameplay_blocked():
		return
	if event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("attack_light"):
		_pressed |= CombatIntent.LIGHT
	if event.is_action_pressed("attack_heavy"):
		_pressed |= CombatIntent.HEAVY
	if event.is_action_pressed("guard"):
		_pressed |= CombatIntent.GUARD
	if event.is_action_pressed("dodge"):
		_pressed |= CombatIntent.DODGE
	if event.is_action_pressed("lock_on"):
		camera_rig.toggle_lock()


func sample_intent(body: FighterBody) -> CombatIntent:
	var intent := CombatIntent.new()
	_sequence += 1
	intent.sequence = _sequence
	intent.pressed = _pressed
	_pressed = 0
	if UiShell.gameplay_blocked():
		intent.pressed = 0
		return intent
	if Input.is_action_pressed("guard"):
		intent.held |= CombatIntent.GUARD
	if Input.is_action_pressed("sprint"):
		intent.held |= CombatIntent.SPRINT

	# Camera-relative movement converted to world XZ.
	var stick := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var yaw := camera_rig.yaw
	var forward := Vector3(-sin(yaw), 0.0, -cos(yaw))
	var right := Vector3(cos(yaw), 0.0, -sin(yaw))
	var world := right * stick.x - forward * stick.y
	intent.move = Vector2(world.x, world.z)

	var lock := camera_rig.lock_target
	if lock != null:
		var to := lock.global_position - body.global_position
		to.y = 0.0
		if to.length_squared() > 0.01:
			intent.face_dir = to.normalized()
	return intent
