class_name InputBindings
extends RefCounted
## Default keyboard/mouse and gamepad bindings, registered at runtime, then overridden by any saved
## custom bindings (GameSettings). Actions that already exist (for example ones remapped in Project
## Settings) are left untouched by ensure_defaults().

## Player-facing actions in remap order: [action, label].
const REMAPPABLE := [
	["move_forward", "Move forward"], ["move_back", "Move back"], ["move_left", "Move left"],
	["move_right", "Move right"], ["sprint", "Sprint"], ["attack_light", "Light attack"],
	["attack_heavy", "Heavy attack"], ["guard", "Guard / parry"], ["dodge", "Dodge"],
	["lock_on", "Lock on"], ["toggle_help", "Show controls"],
]


static func defaults() -> Dictionary:
	return {
		"move_forward": [_key(KEY_W), _axis(JOY_AXIS_LEFT_Y, -1.0)],
		"move_back": [_key(KEY_S), _axis(JOY_AXIS_LEFT_Y, 1.0)],
		"move_left": [_key(KEY_A), _axis(JOY_AXIS_LEFT_X, -1.0)],
		"move_right": [_key(KEY_D), _axis(JOY_AXIS_LEFT_X, 1.0)],
		"look_left": [_axis(JOY_AXIS_RIGHT_X, -1.0)],
		"look_right": [_axis(JOY_AXIS_RIGHT_X, 1.0)],
		"look_up": [_axis(JOY_AXIS_RIGHT_Y, -1.0)],
		"look_down": [_axis(JOY_AXIS_RIGHT_Y, 1.0)],
		"attack_light": [_mouse(MOUSE_BUTTON_LEFT), _joy(JOY_BUTTON_RIGHT_SHOULDER)],
		"attack_heavy": [_key(KEY_E), _joy(JOY_BUTTON_Y)],
		"guard": [_mouse(MOUSE_BUTTON_RIGHT), _key(KEY_Q), _joy(JOY_BUTTON_LEFT_SHOULDER)],
		"dodge": [_key(KEY_SPACE), _joy(JOY_BUTTON_B)],
		"sprint": [_key(KEY_SHIFT), _joy(JOY_BUTTON_LEFT_STICK)],
		"lock_on": [_key(KEY_TAB), _mouse(MOUSE_BUTTON_MIDDLE), _joy(JOY_BUTTON_RIGHT_STICK)],
		"toggle_help": [_key(KEY_H), _joy(JOY_BUTTON_START)],
		"sandbox_dummy_mode": [_key(KEY_F1), _joy(JOY_BUTTON_BACK)],
		"sandbox_reset": [_key(KEY_F5)],
	}


static func ensure_defaults() -> void:
	var d := defaults()
	for action: String in d:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action, 0.25)
		for e: InputEvent in d[action]:
			InputMap.action_add_event(action, e)


static func reset_all() -> void:
	var d := defaults()
	for action: String in d:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.25)
		InputMap.action_erase_events(action)
		for e: InputEvent in d[action]:
			InputMap.action_add_event(action, e)


## Short glyph text for the first keyboard/mouse binding of `action` (HUD and help).
static func glyph(action: String) -> String:
	if not InputMap.has_action(action):
		return "?"
	for e in InputMap.action_get_events(action):
		if e is InputEventKey:
			return OS.get_keycode_string((e as InputEventKey).physical_keycode)
		if e is InputEventMouseButton:
			match (e as InputEventMouseButton).button_index:
				MOUSE_BUTTON_LEFT:
					return "LMB"
				MOUSE_BUTTON_RIGHT:
					return "RMB"
				MOUSE_BUTTON_MIDDLE:
					return "MMB"
				_:
					return "Mouse %d" % (e as InputEventMouseButton).button_index
	return "—"


static func describe(e: InputEvent) -> String:
	if e is InputEventKey:
		return OS.get_keycode_string((e as InputEventKey).physical_keycode)
	if e is InputEventMouseButton:
		return ["", "LMB", "RMB", "MMB"][(e as InputEventMouseButton).button_index] if (e as InputEventMouseButton).button_index <= 3 \
				else "Mouse %d" % (e as InputEventMouseButton).button_index
	if e is InputEventJoypadButton:
		return "Pad %d" % (e as InputEventJoypadButton).button_index
	if e is InputEventJoypadMotion:
		var m := e as InputEventJoypadMotion
		return "Axis %d%s" % [m.axis, "+" if m.axis_value > 0 else "−"]
	return "?"


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
