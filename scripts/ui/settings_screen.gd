class_name SettingsScreen
extends UiScreen
## MENU-02 / MENU-03: settings by category (GUI.md §6). Changes apply immediately and save per
## device; a display-mode change asks to keep it and reverts after a countdown otherwise.

const REVERT_SECONDS := 10

var _start_tab := ""
var _tabs := TabContainer.new()


func _init(start_tab: String = "") -> void:
	super()
	_start_tab = start_tab


func _ready() -> void:
	var center := CenterContainer.new()
	UiKit.full_rect(center)
	add_child(center)
	var p := UiKit.panel(820)
	p.custom_minimum_size.y = 620
	center.add_child(p)
	var col := UiKit.vbox(UiTokens.S3)
	p.add_child(col)
	col.add_child(UiKit.label("Settings", "H1"))
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_tabs)
	_page("Video", _video())
	_page("Audio", _audio())
	_page("Gameplay", _gameplay())
	_page("Controls", RemapPanel.new())
	_page("Accessibility", _accessibility())
	_page("Network", _network())
	var actions := UiKit.hbox()
	actions.add_child(UiKit.button("Back", func() -> void: shell.pop()))
	var filler := Control.new()
	filler.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(filler)
	actions.add_child(UiKit.button("Reset this tab", _reset_tab))
	col.add_child(actions)
	if not _start_tab.is_empty():
		for i in _tabs.get_tab_count():
			if _tabs.get_tab_title(i) == _start_tab:
				_tabs.current_tab = i


func _page(title: String, content: Control) -> void:
	var scroll := ScrollContainer.new()
	scroll.name = title
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	_tabs.add_child(scroll)


## Video options that belong to presets flip the preset to Custom when changed by hand.
static func _custom(key: String) -> Callable:
	return func(v: Variant) -> void:
		GameSettings.set_value("video", "preset", 4, false)
		GameSettings.set_value("video", key, v)


static func _setter(section: String, key: String) -> Callable:
	return func(v: Variant) -> void: GameSettings.set_value(section, key, v)


func _video() -> Control:
	var v := UiKit.vbox()
	v.add_child(UiKit.option_row("Quality preset", ["Low", "Medium", "High", "Ultra", "Custom"],
			int(GameSettings.get_value("video", "preset")), func(i: int) -> void:
				if i < 4:
					GameSettings.apply_preset(i)
					shell.pop()
					shell.push(SettingsScreen.new("Video"))))
	var upscalers := ["Off (native / bilinear)", "AMD FSR 1", "AMD FSR 2 (temporal)"]
	if GameSettings.metalfx_supported():
		upscalers.append("Apple MetalFX (temporal)")
	v.add_child(UiKit.option_row("Upscaler", upscalers, mini(int(GameSettings.get_value("video", "upscaler")), upscalers.size() - 1),
			_custom("upscaler")))
	v.add_child(UiKit.check_row("Temporal anti-aliasing", bool(GameSettings.get_value("video", "taa")), _custom("taa"),
			"Ignored while a temporal upscaler is active (it already anti-aliases)."))
	v.add_child(UiKit.option_row("Global illumination", ["Off", "Screen-space (SSIL)", "SDFGI (bounce light)"],
			int(GameSettings.get_value("video", "gi")), _custom("gi")))
	v.add_child(UiKit.check_row("Image enhancement", bool(GameSettings.get_value("video", "post_fx")), _setter("video", "post_fx"),
			"Contrast-adaptive sharpening, night colour grade and subtle lens character."))
	v.add_child(UiKit.slider_row("Sharpening", 0.0, 1.0, 0.05, float(GameSettings.get_value("video", "sharpen")), _setter("video", "sharpen")))
	v.add_child(UiKit.option_row("Level of detail", ["Performance", "Balanced", "Quality"],
			int(GameSettings.get_value("video", "lod")), _custom("lod")))
	v.add_child(UiKit.option_row("Display mode", ["Windowed", "Borderless fullscreen", "Exclusive fullscreen"],
			int(GameSettings.get_value("video", "window_mode")), _confirm_window_mode))
	v.add_child(UiKit.check_row("VSync", bool(GameSettings.get_value("video", "vsync")), _setter("video", "vsync")))
	var fps_steps := [0, 30, 60, 120, 144, 240]
	v.add_child(UiKit.option_row("Frame cap", ["Unlimited", "30", "60", "120", "144", "240"],
			maxi(fps_steps.find(int(GameSettings.get_value("video", "max_fps"))), 0),
			func(i: int) -> void: GameSettings.set_value("video", "max_fps", fps_steps[i])))
	v.add_child(UiKit.slider_row("Render scale", 0.5, 1.0, 0.05, float(GameSettings.get_value("video", "render_scale")), _custom("render_scale")))
	v.add_child(UiKit.option_row("Shadows", ["Off", "Low", "High"], int(GameSettings.get_value("video", "shadows")), _custom("shadows")))
	v.add_child(UiKit.option_row("Anti-aliasing (MSAA)", ["Off", "2x", "4x"], int(GameSettings.get_value("video", "msaa")), _custom("msaa")))
	v.add_child(UiKit.check_row("Ambient occlusion", bool(GameSettings.get_value("video", "ssao")), _custom("ssao")))
	v.add_child(UiKit.check_row("Volumetric mist", bool(GameSettings.get_value("video", "mist")), _custom("mist"),
			"Cosmetic only. Turning it off never removes cover or reveals anyone."))
	v.add_child(UiKit.slider_row("Field of view", GameSettings.FOV_MIN, GameSettings.FOV_MAX, 1.0,
			float(GameSettings.get_value("video", "fov")), _setter("video", "fov"), "%d°", 1.0))
	return v


func _audio() -> Control:
	var v := UiKit.vbox()
	for bus: String in ["Master", "Music", "Ambience", "Combat", "UI"]:
		v.add_child(UiKit.slider_row(bus, 0.0, 1.0, 0.05, float(GameSettings.get_value("audio", bus)), _setter("audio", bus)))
	v.add_child(UiKit.label("Parry, guard and hit each have a distinct sound, so they read without looking.", "Muted", true))
	return v


func _gameplay() -> Control:
	var v := UiKit.vbox()
	v.add_child(UiKit.slider_row("Camera sensitivity", 0.3, 2.5, 0.05, float(GameSettings.get_value("gameplay", "mouse_sensitivity")),
			_setter("gameplay", "mouse_sensitivity")))
	v.add_child(UiKit.check_row("Invert camera Y", bool(GameSettings.get_value("gameplay", "invert_y")), _setter("gameplay", "invert_y")))
	v.add_child(UiKit.check_row("Camera shake", bool(GameSettings.get_value("gameplay", "camera_shake")), _setter("gameplay", "camera_shake")))
	v.add_child(UiKit.check_row("Tutorial hints", bool(GameSettings.get_value("gameplay", "hints")), _setter("gameplay", "hints")))
	return v


func _accessibility() -> Control:
	var v := UiKit.vbox()
	v.add_child(UiKit.slider_row("Text size", 0.8, 1.6, 0.1, GameSettings.text_scale(), _setter("accessibility", "text_scale")))
	v.add_child(UiKit.check_row("High contrast UI", bool(GameSettings.get_value("accessibility", "high_contrast")), _setter("accessibility", "high_contrast")))
	v.add_child(UiKit.check_row("Reduce motion", GameSettings.reduced_motion(), _setter("accessibility", "reduced_motion")))
	v.add_child(UiKit.check_row("Reduce flashes", GameSettings.reduced_flashes(), _setter("accessibility", "reduced_flashes")))
	v.add_child(UiKit.label("Combat tells are never colour-only: windups also change the blade pose, parries ring, guard breaks have their own sound and banner.", "Muted", true))
	return v


func _network() -> Control:
	var v := UiKit.vbox()
	v.add_child(UiKit.check_row("Show latency", bool(GameSettings.get_value("network", "show_latency")), _setter("network", "show_latency")))
	v.add_child(UiKit.label("Tick rate and other authority settings are fixed by the server and not adjustable.", "Muted", true))
	return v


func _reset_tab() -> void:
	var title := _tabs.get_tab_title(_tabs.current_tab)
	if title == "Controls":
		InputBindings.reset_all()
		GameSettings.clear_bindings()
	else:
		GameSettings.reset_section(title.to_lower())
	Sfx.play_ui(self, "ui_confirm")
	shell.pop()
	shell.push(SettingsScreen.new(title))


## Apply now; revert unless the player confirms within the countdown (GUI.md §6 Video).
func _confirm_window_mode(mode: int) -> void:
	var previous := int(GameSettings.get_value("video", "window_mode"))
	if mode == previous:
		return
	GameSettings.set_value("video", "window_mode", mode)
	var dialog := ConfirmationDialog.new()
	dialog.title = "Keep display mode?"
	dialog.ok_button_text = "Keep"
	dialog.cancel_button_text = "Revert"
	add_child(dialog)
	var remaining := [REVERT_SECONDS]
	dialog.dialog_text = "Reverting in %d s." % remaining[0]
	var timer := Timer.new()
	timer.process_mode = Node.PROCESS_MODE_ALWAYS
	dialog.add_child(timer)
	var revert := func() -> void:
		GameSettings.set_value("video", "window_mode", previous)
		dialog.queue_free()
		shell.pop()
		shell.push(SettingsScreen.new("Video"))
	timer.timeout.connect(func() -> void:
		remaining[0] -= 1
		dialog.dialog_text = "Reverting in %d s." % remaining[0]
		if remaining[0] <= 0:
			revert.call())
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(revert)
	dialog.popup_centered()
	timer.start(1.0)
