class_name UiShell
extends CanvasLayer
## Persistent UI root (GUI.md §8 "shell"): screen stack, modal/toast layers, menu backdrop and the
## game-session lifecycle (sandbox or online). It survives scene changes; game roots come and go
## underneath it. Presentation only: it starts and stops sessions but never touches game state.
##
## Layers, low to high: game HUD (owned by the game) < screens < toasts < modals.

const SANDBOX := "res://scenes/sandbox/combat_sandbox.tscn"

static var instance: UiShell

var in_game := false
var online := false

var _screen_host := Control.new()
var _toast_host := VBoxContainer.new()
var _dim := ColorRect.new() ## Frosted blur of the live game behind in-game menus.
var _grain := ColorRect.new() ## Film grain + vignette over menus (cinematic, subtle).

const BLUR_SHADER := """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float lod = 3.2;
void fragment() {
	vec3 c = textureLod(screen_tex, SCREEN_UV, lod).rgb;
	float v = smoothstep(1.1, 0.25, length(UV - 0.5));
	COLOR = vec4(c * 0.42 * mix(0.6, 1.0, v), 1.0);
}
"""
const GRAIN_SHADER := """
shader_type canvas_item;
uniform float vignette = 0.55;
void fragment() {
	float v = smoothstep(0.35, 1.05, length(UV - 0.5) * 1.35);
	COLOR = vec4(0.0, 0.0, 0.0, v * vignette);
}
"""
var _stack: Array[UiScreen] = []
var stage: MenuStage ## 3D menu stage with the player's samurai; only exists outside a game.
var _game: Node
var _last_join := {}


## True while a menu or overlay owns input; PlayerController then sends idle intents.
static func gameplay_blocked() -> bool:
	return instance != null and not instance._stack.is_empty()


func _ready() -> void:
	instance = self
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	KageTheme.install()
	GameSettings.bus.changed.connect(_on_setting_changed)
	var blur := ShaderMaterial.new()
	blur.shader = Shader.new()
	blur.shader.code = BLUR_SHADER
	_dim.material = blur
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.full_rect(_dim)
	_dim.visible = false
	add_child(_dim)
	UiKit.full_rect(_screen_host)
	_screen_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_screen_host)
	var grain := ShaderMaterial.new()
	grain.shader = Shader.new()
	grain.shader.code = GRAIN_SHADER
	_grain.material = grain
	_grain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.full_rect(_grain)
	add_child(_grain)
	_toast_host.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast_host.position = Vector2(-260, 90)
	_toast_host.custom_minimum_size = Vector2(520, 0)
	_toast_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_toast_host)


# --- Screen stack --------------------------------------------------------------------------------

func push(screen: UiScreen) -> UiScreen:
	screen.shell = self
	if not _stack.is_empty():
		_stack[-1].visible = false
	_stack.append(screen)
	_screen_host.add_child(screen)
	_animate_in(screen)
	screen.focus_first()
	_refresh()
	return screen


func pop() -> void:
	if _stack.is_empty():
		return
	var top: UiScreen = _stack.pop_back()
	top.queue_free()
	if not _stack.is_empty():
		_stack[-1].visible = true
		_animate_in(_stack[-1])
		_stack[-1].focus_first()
	Sfx.play_ui(self, "ui_back")
	_refresh()


## Replace the whole stack (e.g. main menu -> loading).
func replace(screen: UiScreen) -> UiScreen:
	clear()
	return push(screen)


func clear() -> void:
	for s in _stack:
		s.queue_free()
	_stack.clear()
	_refresh()


func top() -> UiScreen:
	return _stack[-1] if not _stack.is_empty() else null


## Screens fade and rise into place (GUI.md §2: 150–300 ms, never blocking input).
func _animate_in(screen: Control) -> void:
	if GameSettings.reduced_motion():
		return
	screen.modulate.a = 0.0
	screen.position.y = 14.0
	var tw := screen.create_tween().set_parallel().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(screen, "modulate:a", 1.0, 0.24)
	tw.tween_property(screen, "position:y", 0.0, 0.3)


func _refresh() -> void:
	var menu_open := not _stack.is_empty()
	_dim.visible = menu_open and in_game and _stack[-1].dim_background
	_grain.visible = menu_open
	if in_game:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if menu_open else Input.MOUSE_MODE_CAPTURED
		if not online:
			get_tree().paused = menu_open # Local sandbox pauses; online never does (GUI.md §2).
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	if not _stack.is_empty():
		if _stack[-1].on_back():
			pop()
	elif in_game:
		push(PauseMenu.new())


# --- Sessions ------------------------------------------------------------------------------------

func show_main_menu() -> void:
	_end_game()
	_ensure_backdrop()
	replace(MainMenu.new())


func start_sandbox() -> void:
	clear()
	_free_backdrop()
	_end_game()
	_game = (load(SANDBOX) as PackedScene).instantiate()
	_begin_game(_game, false)


func start_online(host: String, port: int, player_name: String) -> void:
	_last_join = {"host": host, "port": port, "name": player_name}
	clear()
	_free_backdrop()
	_end_game()
	var client := NetClient.new()
	client.host = host
	client.port = port
	client.player_name = player_name
	client.phase_changed.connect(_on_net_phase)
	client.ready_to_play.connect(_on_net_ready)
	client.failed.connect(_on_net_failed)
	_game = client
	client.name = "Match" # The shared RPC node must live at /root/Match/Session on every peer.
	push(LoadingScreen.new())
	_begin_game(client, true)


func retry_online() -> void:
	if not _last_join.is_empty():
		start_online(_last_join["host"], _last_join["port"], _last_join["name"])


func _begin_game(root_node: Node, is_online: bool) -> void:
	online = is_online
	in_game = true
	get_tree().root.add_child(root_node)
	get_tree().current_scene = root_node
	GameSettings.apply_world(get_tree().root)
	_refresh()


func _end_game() -> void:
	get_tree().paused = false
	in_game = false
	online = false
	if _game != null and is_instance_valid(_game):
		_game.queue_free()
	_game = null
	if multiplayer.multiplayer_peer != null and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null


func quit() -> void:
	_end_game()
	get_tree().quit()


func _on_net_phase(text: String, step: int) -> void:
	var s := top()
	if s is LoadingScreen:
		(s as LoadingScreen).set_phase(text, step)


func _on_net_ready() -> void:
	if top() is LoadingScreen:
		pop()


func _on_net_failed(title: String, reason: String) -> void:
	var was_playing := not (top() is LoadingScreen)
	clear()
	push(ErrorScreen.new(title, reason, was_playing))
	Sfx.play_ui(self, "ui_error")


# --- Backdrop, toasts ----------------------------------------------------------------------------

## The menu stage (GUI.md §5.2): the player's own samurai on a lit set behind every menu.
func _ensure_backdrop() -> void:
	if stage != null:
		return
	stage = MenuStage.new()
	stage.name = "MenuStage"
	get_tree().root.add_child(stage)
	GameSettings.apply_world(get_tree().root)


func _free_backdrop() -> void:
	if stage != null:
		stage.queue_free()
		stage = null


func toast(text: String, color: Color = UiTokens.TEXT_PRIMARY, seconds: float = 3.0) -> void:
	var p := PanelContainer.new()
	p.theme_type_variation = "Pill"
	var l := UiKit.label(text)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	p.add_child(l)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_host.add_child(p)
	var tw := p.create_tween()
	tw.tween_interval(seconds)
	tw.tween_property(p, "modulate:a", 0.0, 0.0 if GameSettings.reduced_motion() else 0.4)
	tw.tween_callback(p.queue_free)


func _on_setting_changed(section: String, key: String) -> void:
	if section == "accessibility" and key in ["text_scale", "high_contrast"]:
		KageTheme.install()
		get_tree().root.propagate_notification(Control.NOTIFICATION_THEME_CHANGED)
	elif section == "audio":
		GameSettings.apply_audio()
	elif section == "video":
		if key in ["window_mode", "vsync", "max_fps"]:
			GameSettings.apply_window()
		else:
			GameSettings.apply_world(get_tree().root)
