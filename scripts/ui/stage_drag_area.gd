class_name StageDragArea
extends Control
## Full-screen transparent layer under a menu that turns the MenuStage character on drag.

var shell: UiShell
var _dragging := false


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS
	mouse_default_cursor_shape = Control.CURSOR_DRAG


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
	elif event is InputEventMouseMotion and _dragging and shell != null and shell.stage != null:
		shell.stage.rotate_by((event as InputEventMouseMotion).relative.x)
