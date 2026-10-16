class_name GameSettings
extends RefCounted
## Player settings (GUI.md §6), saved per device in user://settings.cfg. Static so presentation code
## (camera, HUD, FX) can read a value without plumbing; changes are announced on `bus`.
## Nothing here touches simulation or network authority: no tick or exploit-sensitive values.

const PATH := "user://settings.cfg"
const BUSES: Array[String] = ["Music", "Ambience", "Combat", "UI"]

const DEFAULTS := {
	"video": {
		"window_mode": 0, # 0 windowed, 1 borderless fullscreen, 2 exclusive fullscreen
		"vsync": true,
		"max_fps": 0,
		"render_scale": 1.0,
		"shadows": 2, # 0 off, 1 low, 2 high
		"ssao": true,
		"mist": true,
		"msaa": 1, # 0 off, 1 2x, 2 4x
		"fov": 70.0,
		"preset": 2, # 0 low, 1 medium, 2 high, 3 ultra, 4 custom
		"upscaler": 0, # 0 off, 1 FSR 1, 2 FSR 2, 3 MetalFX (temporal)
		"taa": false,
		"gi": 1, # 0 off, 1 SSIL, 2 SDFGI
		"lod": 1, # 0 performance, 1 balanced, 2 quality
	},
	"audio": {"Master": 0.8, "Music": 0.7, "Ambience": 0.6, "Combat": 0.9, "UI": 0.7},
	"gameplay": {"mouse_sensitivity": 1.0, "invert_y": false, "camera_shake": true, "hints": true},
	"accessibility": {"text_scale": 1.0, "reduced_motion": false, "reduced_flashes": false, "high_contrast": false},
	"network": {"show_latency": true, "player_name": "", "servers": ["127.0.0.1:7777"]},
	"meta": {"first_run_done": false},
}
const FOV_MIN := 60.0 ## Fair-play bounds (GUI.md §6 Video).
const FOV_MAX := 90.0

class Bus extends RefCounted:
	signal changed(section: String, key: String)

static var bus := Bus.new()
static var _data: Dictionary = {}
static var _bindings: Dictionary = {} ## action -> Array[Dictionary]
static var _loaded := false


static func ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	_data = DEFAULTS.duplicate(true)
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	for section: String in DEFAULTS:
		for key: String in DEFAULTS[section]:
			var v: Variant = cfg.get_value(section, key, DEFAULTS[section][key])
			if typeof(v) == typeof(DEFAULTS[section][key]) or (typeof(v) in [TYPE_INT, TYPE_FLOAT] and typeof(DEFAULTS[section][key]) in [TYPE_INT, TYPE_FLOAT]):
				_data[section][key] = v
	if cfg.has_section("controls"):
		for action in cfg.get_section_keys("controls"):
			var events: Variant = cfg.get_value("controls", action, [])
			if typeof(events) == TYPE_ARRAY:
				_bindings[action] = events


static func get_value(section: String, key: String) -> Variant:
	ensure_loaded()
	return _data[section][key]


static func set_value(section: String, key: String, value: Variant, persist: bool = true) -> void:
	ensure_loaded()
	_data[section][key] = value
	if persist:
		save()
	bus.changed.emit(section, key)


static func save() -> void:
	var cfg := ConfigFile.new()
	for section: String in _data:
		for key: String in _data[section]:
			cfg.set_value(section, key, _data[section][key])
	for action: String in _bindings:
		cfg.set_value("controls", action, _bindings[action])
	cfg.save(PATH)


static func reset_section(section: String) -> void:
	ensure_loaded()
	_data[section] = DEFAULTS[section].duplicate(true)
	save()
	for key: String in _data[section]:
		bus.changed.emit(section, key)


# --- Input bindings ------------------------------------------------------------------------------

## Saved custom bindings override InputBindings defaults (GUI.md MENU-03).
static func apply_bindings() -> void:
	ensure_loaded()
	for action: String in _bindings:
		if not InputMap.has_action(action):
			continue
		InputMap.action_erase_events(action)
		for d: Dictionary in _bindings[action]:
			var e := event_from_dict(d)
			if e != null:
				InputMap.action_add_event(action, e)


static func store_binding(action: String) -> void:
	var list := []
	for e in InputMap.action_get_events(action):
		var d := event_to_dict(e)
		if not d.is_empty():
			list.append(d)
	_bindings[action] = list
	save()


static func clear_bindings() -> void:
	_bindings.clear()
	save()


static func event_to_dict(e: InputEvent) -> Dictionary:
	if e is InputEventKey:
		return {"type": "key", "code": (e as InputEventKey).physical_keycode}
	if e is InputEventMouseButton:
		return {"type": "mouse", "button": (e as InputEventMouseButton).button_index}
	if e is InputEventJoypadButton:
		return {"type": "joy_button", "button": (e as InputEventJoypadButton).button_index}
	if e is InputEventJoypadMotion:
		return {"type": "joy_axis", "axis": (e as InputEventJoypadMotion).axis, "value": (e as InputEventJoypadMotion).axis_value}
	return {}


static func event_from_dict(d: Dictionary) -> InputEvent:
	match d.get("type", ""):
		"key":
			var k := InputEventKey.new()
			k.physical_keycode = int(d.get("code", 0))
			return k
		"mouse":
			var m := InputEventMouseButton.new()
			m.button_index = int(d.get("button", 1))
			return m
		"joy_button":
			var j := InputEventJoypadButton.new()
			j.button_index = int(d.get("button", 0))
			return j
		"joy_axis":
			var a := InputEventJoypadMotion.new()
			a.axis = int(d.get("axis", 0))
			a.axis_value = float(d.get("value", 1.0))
			return a
	return null


# --- Applying ------------------------------------------------------------------------------------

static func apply_all(tree: SceneTree) -> void:
	ensure_loaded()
	ensure_buses()
	apply_audio()
	apply_window()
	apply_world(tree.root)


static func ensure_buses() -> void:
	for name in BUSES:
		if AudioServer.get_bus_index(name) < 0:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, name)
			AudioServer.set_bus_send(idx, &"Master")


static func apply_audio() -> void:
	for name: String in DEFAULTS["audio"]:
		var idx := AudioServer.get_bus_index(name)
		if idx >= 0:
			var linear: float = get_value("audio", name)
			AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear, 0.0001)))
			AudioServer.set_bus_mute(idx, linear <= 0.001)


static func apply_window() -> void:
	if DisplayServer.get_name() == "headless":
		return
	match int(get_value("video", "window_mode")):
		1:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		2:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		_:
			if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if get_value("video", "vsync") else DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = int(get_value("video", "max_fps"))


## Graphics options that live on the world: render scale, MSAA, shadows, SSAO, mist.
static func apply_world(root: Node) -> void:
	if root == null:
		return
	var vp := root.get_viewport()
	vp.scaling_3d_scale = clampf(float(get_value("video", "render_scale")), 0.5, 1.0)
	vp.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X][clampi(int(get_value("video", "msaa")), 0, 2)]
	var upscaler := int(get_value("video", "upscaler"))
	if upscaler == 3 and not metalfx_supported():
		upscaler = 2
	vp.scaling_3d_mode = [Viewport.SCALING_3D_MODE_BILINEAR, Viewport.SCALING_3D_MODE_FSR,
			Viewport.SCALING_3D_MODE_FSR2, Viewport.SCALING_3D_MODE_METALFX_TEMPORAL][clampi(upscaler, 0, 3)]
	# Temporal upscalers do their own anti-aliasing; TAA on top would only blur.
	vp.use_taa = bool(get_value("video", "taa")) and upscaler < 2
	vp.mesh_lod_threshold = [4.0, 1.5, 0.75][clampi(int(get_value("video", "lod")), 0, 2)]
	var gi := int(get_value("video", "gi"))
	var shadows := int(get_value("video", "shadows"))
	for n in root.find_children("*", "DirectionalLight3D", true, false):
		var light := n as DirectionalLight3D
		if light.name == "Moon":
			light.shadow_enabled = shadows > 0
			light.directional_shadow_max_distance = 40.0 if shadows == 1 else 70.0
	RenderingServer.directional_shadow_atlas_set_size(2048 if shadows == 1 else 4096, true)
	for n in root.find_children("*", "WorldEnvironment", true, false):
		var env := (n as WorldEnvironment).environment
		if env != null:
			env.ssao_enabled = bool(get_value("video", "ssao"))
			env.ssil_enabled = gi >= 1
			env.sdfgi_enabled = gi == 2
			env.sdfgi_use_occlusion = true
			env.volumetric_fog_enabled = bool(get_value("video", "mist"))
			env.volumetric_fog_density = 0.0018


## Quality presets set several options at once (GUI.md §6 "preset"). Any manual change afterwards
## marks the preset as Custom.
const PRESETS := [
	{"render_scale": 0.75, "upscaler": 1, "shadows": 1, "ssao": false, "mist": false, "msaa": 0, "taa": false, "gi": 0, "lod": 0},
	{"render_scale": 0.85, "upscaler": 2, "shadows": 1, "ssao": true, "mist": true, "msaa": 0, "taa": false, "gi": 1, "lod": 1},
	{"render_scale": 1.0, "upscaler": 0, "shadows": 2, "ssao": true, "mist": true, "msaa": 1, "taa": false, "gi": 1, "lod": 1},
	{"render_scale": 1.0, "upscaler": 0, "shadows": 2, "ssao": true, "mist": true, "msaa": 0, "taa": true, "gi": 2, "lod": 2},
]
const PRESET_KEYS := ["render_scale", "upscaler", "shadows", "ssao", "mist", "msaa", "taa", "gi", "lod"]


static func apply_preset(index: int) -> void:
	ensure_loaded()
	if index < 0 or index >= PRESETS.size():
		return
	for key: String in PRESETS[index]:
		_data["video"][key] = PRESETS[index][key]
	_data["video"]["preset"] = index
	save()
	bus.changed.emit("video", "preset")


static func metalfx_supported() -> bool:
	return OS.get_name() == "macOS" and RenderingServer.get_current_rendering_driver_name() == "metal"


static func fov() -> float:
	return clampf(float(get_value("video", "fov")), FOV_MIN, FOV_MAX)


static func text_scale() -> float:
	return clampf(float(get_value("accessibility", "text_scale")), 0.8, 1.6)


static func reduced_motion() -> bool:
	return bool(get_value("accessibility", "reduced_motion"))


static func reduced_flashes() -> bool:
	return bool(get_value("accessibility", "reduced_flashes"))
