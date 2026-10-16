class_name RemapPanel
extends VBoxContainer
## MENU-03: rebind keyboard/mouse and gamepad per action, with conflict warnings. Escape cancels a
## pending capture. Bindings save immediately; "Reset this tab" restores defaults.

var _capture_action := ""
var _capture_pad := false
var _status := UiKit.label("Select a binding, then press the new key or button.", "Muted", true)
var _grid := GridContainer.new()


func _ready() -> void:
	add_theme_constant_override("separation", UiTokens.S2)
	add_child(_status)
	_grid.columns = 3
	_grid.add_theme_constant_override("h_separation", UiTokens.S3)
	_grid.add_theme_constant_override("v_separation", UiTokens.S1)
	add_child(_grid)
	_rebuild()


func _rebuild() -> void:
	for c in _grid.get_children():
		c.queue_free()
	for h in ["Action", "Keyboard / mouse", "Gamepad"]:
		_grid.add_child(UiKit.label(h, "Muted"))
	for entry: Array in InputBindings.REMAPPABLE:
		var action: String = entry[0]
		var name_label := UiKit.label(entry[1])
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_grid.add_child(name_label)
		_grid.add_child(_bind_button(action, false))
		_grid.add_child(_bind_button(action, true))


func _bind_button(action: String, pad: bool) -> Button:
	var current := _first(action, pad)
	var b := UiKit.button(InputBindings.describe(current) if current != null else "—", func() -> void:
		_capture_action = action
		_capture_pad = pad
		_status.text = "Press a %s for “%s” (Esc to cancel)…" % ["gamepad button" if pad else "key or mouse button", _label_of(action)])
	b.custom_minimum_size.x = 170
	return b


func _input(event: InputEvent) -> void:
	if _capture_action.is_empty() or not event.is_pressed() or event.is_echo():
		return
	if event is InputEventKey and (event as InputEventKey).physical_keycode == KEY_ESCAPE:
		_capture_action = ""
		_status.text = "Cancelled."
		get_viewport().set_input_as_handled()
		return
	var accepts := (event is InputEventJoypadButton) if _capture_pad else (event is InputEventKey or event is InputEventMouseButton)
	if not accepts:
		return
	get_viewport().set_input_as_handled()
	var fresh := _normalized(event)
	var conflict := _conflict(fresh, _capture_action)
	var old := _first(_capture_action, _capture_pad)
	if old != null:
		InputMap.action_erase_event(_capture_action, old)
	InputMap.action_add_event(_capture_action, fresh)
	GameSettings.store_binding(_capture_action)
	_status.text = "“%s” → %s." % [_label_of(_capture_action), InputBindings.describe(fresh)]
	if not conflict.is_empty():
		_status.text += "  Also bound to “%s”; both will trigger." % _label_of(conflict)
		Sfx.play_ui(self, "ui_warning")
	else:
		Sfx.play_ui(self, "ui_confirm")
	_capture_action = ""
	_rebuild.call_deferred()


func _first(action: String, pad: bool) -> InputEvent:
	if not InputMap.has_action(action):
		return null
	for e in InputMap.action_get_events(action):
		var is_pad := e is InputEventJoypadButton or e is InputEventJoypadMotion
		if is_pad == pad:
			return e
	return null


func _conflict(e: InputEvent, except_action: String) -> String:
	for entry: Array in InputBindings.REMAPPABLE:
		var a: String = entry[0]
		if a != except_action and InputMap.action_has_event(a, e):
			return a
	return ""


static func _normalized(event: InputEvent) -> InputEvent:
	if event is InputEventKey:
		var k := InputEventKey.new()
		k.physical_keycode = (event as InputEventKey).physical_keycode
		return k
	if event is InputEventMouseButton:
		var m := InputEventMouseButton.new()
		m.button_index = (event as InputEventMouseButton).button_index
		return m
	var j := InputEventJoypadButton.new()
	j.button_index = (event as InputEventJoypadButton).button_index
	return j


static func _label_of(action: String) -> String:
	for entry: Array in InputBindings.REMAPPABLE:
		if entry[0] == action:
			return entry[1]
	return action
