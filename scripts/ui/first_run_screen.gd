class_name FirstRunScreen
extends UiScreen
## BOOT-03: accessibility before anything else (GUI.md §5.1 step 3). Shown once; every option here
## stays available later in Settings.


func _init() -> void:
	super()
	closable = false


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.04, 0.05)
	UiKit.full_rect(bg)
	add_child(bg)
	var col := UiKit.centered_panel(self, 640)
	col.add_child(UiKit.label("Before you begin", "H1"))
	col.add_child(UiKit.label("Choose how the game should look and move. You can change all of this later in Settings.", "Muted", true))
	col.add_child(UiKit.spacer(8))
	col.add_child(UiKit.option_row("Language", ["English"], 0, func(_i: int) -> void: pass))
	col.add_child(UiKit.slider_row("Text size", 0.8, 1.6, 0.1, GameSettings.text_scale(),
			func(v: float) -> void: GameSettings.set_value("accessibility", "text_scale", v)))
	col.add_child(UiKit.check_row("Reduce motion", GameSettings.reduced_motion(),
			func(v: bool) -> void: GameSettings.set_value("accessibility", "reduced_motion", v),
			"Static menus, no drifting camera, shorter transitions."))
	col.add_child(UiKit.check_row("Reduce flashes", GameSettings.reduced_flashes(),
			func(v: bool) -> void: GameSettings.set_value("accessibility", "reduced_flashes", v),
			"Dimmer sparks and blade glints. Every combat cue keeps its shape and sound."))
	col.add_child(UiKit.check_row("High contrast UI", bool(GameSettings.get_value("accessibility", "high_contrast")),
			func(v: bool) -> void: GameSettings.set_value("accessibility", "high_contrast", v)))
	col.add_child(UiKit.spacer(8))
	col.add_child(UiKit.label("Photosensitivity notice: combat includes brief bright sparks. Reduce flashes softens them.", "Muted", true))
	var go := UiKit.button("Continue", func() -> void:
		GameSettings.set_value("meta", "first_run_done", true)
		shell.show_main_menu())
	col.add_child(go)
