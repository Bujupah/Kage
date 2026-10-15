class_name InputBindings
extends RefCounted
## Default keyboard/mouse and gamepad bindings, registered at runtime. Actions that already exist
## (for example ones remapped in Project Settings) are left untouched.


static func ensure_defaults() -> void:
	_bind("move_forward", [_key(KEY_W), _axis(JOY_AXIS_LEFT_Y, -1.0)])
	_bind("move_back", [_key(KEY_S), _axis(JOY_AXIS_LEFT_Y, 1.0)])
	_bind("move_left", [_key(KEY_A), _axis(JOY_AXIS_LEFT_X, -1.0)])
	_bind("move_right", [_key(KEY_D), _axis(JOY_AXIS_LEFT_X, 1.0)])
	_bind("look_left", [_axis(JOY_AXIS_RIGHT_X, -1.0)])
	_bind("look_right", [_axis(JOY_AXIS_RIGHT_X, 1.0)])
	_bind("look_up", [_axis(JOY_AXIS_RIGHT_Y, -1.0)])
	_bind("look_down", [_axis(JOY_AXIS_RIGHT_Y, 1.0)])
	_bind("attack_light", [_mouse(MOUSE_BUTTON_LEFT), _joy(JOY_BUTTON_RIGHT_SHOULDER)])
	_bind("attack_heavy", [_key(KEY_E), _joy(JOY_BUTTON_Y)])
	_bind("guard", [_mouse(MOUSE_BUTTON_RIGHT), _key(KEY_Q), _joy(JOY_BUTTON_LEFT_SHOULDER)])
	_bind("dodge", [_key(KEY_SPACE), _joy(JOY_BUTTON_B)])
	_bind("sprint", [_key(KEY_SHIFT), _joy(JOY_BUTTON_LEFT_STICK)])
	_bind("lock_on", [_key(KEY_TAB), _mouse(MOUSE_BUTTON_MIDDLE), _joy(JOY_BUTTON_RIGHT_STICK)])
	_bind("sandbox_dummy_mode", [_key(KEY_F1), _joy(JOY_BUTTON_BACK)])
	_bind("sandbox_reset", [_key(KEY_F5)])


static func _bind(action: StringName, events: Array[InputEvent]) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action, 0.25)
	for e in events:
		InputMap.action_add_event(action, e)


static func _key(code: Key) -> InputEvent:
	var e := InputEventKey.new()
	e.physical_keycode = code
	return e


static func _mouse(button: MouseButton) -> InputEvent:
	var e := InputEventMouseButton.new()
	e.button_index = button
	return e


static func _joy(button: JoyButton) -> InputEvent:
	var e := InputEventJoypadButton.new()
	e.button_index = button
	return e


static func _axis(axis: JoyAxis, value: float) -> InputEvent:
	var e := InputEventJoypadMotion.new()
	e.axis = axis
	e.axis_value = value
	return e
