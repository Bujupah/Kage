class_name UiScreen
extends Control
## Base for every full screen or overlay hosted by UiShell (GUI.md §2 navigation rules).

var shell: UiShell
## Back (Esc / controller B) closes this screen unless it returns false from on_back().
var closable := true
## Dim the game behind it (overlays in a live game keep the world visible).
var dim_background := true


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP


## Called when Back is pressed while this screen is on top. Return false to refuse.
func on_back() -> bool:
	return closable


## First control that should take focus (controller navigation needs a focus owner).
func focus_first() -> void:
	var b := find_children("*", "BaseButton", true, false)
	for c: Control in b:
		if c.is_visible_in_tree() and c.focus_mode != Control.FOCUS_NONE and not (c as BaseButton).disabled:
			c.grab_focus.call_deferred()
			return
