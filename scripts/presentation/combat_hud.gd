class_name CombatHud
extends CanvasLayer
## Placeholder HUD: the four combat resources for player and target, a confirmed-event feed and a
## centre banner for decisive moments. Reads state only; never changes it.

const FEED_LINES := 7
const BANNER_SECONDS := 0.9

var _player: FighterBody
var _target: FighterBody
var _names: Dictionary = {}
var _player_bars: Dictionary = {}
var _target_bars: Dictionary = {}
var _feed := Label.new()
var _feed_lines: Array[String] = []
var _banner := Label.new()
var _banner_time := 0.0
var _status := Label.new()
var _mode := Label.new()


func setup(player: FighterBody, target: FighterBody, names: Dictionary) -> void:
	_player = player
	_target = target
	_names = names


func _ready() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var left := _panel(root, Control.PRESET_TOP_LEFT, Vector2(20, 20))
	_player_bars = _bars(left, _names.get(_player.combatant.entity_id, "Player"))
	var right := _panel(root, Control.PRESET_TOP_RIGHT, Vector2(-300, 20))
	_target_bars = _bars(right, _names.get(_target.combatant.entity_id, "Target"))
	right.add_child(_mode)
	_mode.add_theme_font_size_override("font_size", 13)
	_mode.modulate = Color(1, 1, 1, 0.8)

	_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_banner.position = Vector2(-300, 140)
	_banner.size = Vector2(600, 60)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_theme_font_size_override("font_size", 40)
	_banner.add_theme_constant_override("outline_size", 8)
	_banner.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	root.add_child(_banner)

	_feed.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_feed.position = Vector2(-420, -190)
	_feed.size = Vector2(400, 170)
	_feed.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_feed.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_feed.add_theme_font_size_override("font_size", 14)
	_feed.add_theme_constant_override("outline_size", 4)
	_feed.add_theme_color_override("font_outline_color", Color.BLACK)
	root.add_child(_feed)

	var help := Label.new()
	help.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	help.position = Vector2(20, -150)
	help.text = "WASD move · Shift sprint · LMB light · E heavy\nRMB / Q guard (tap on impact = parry)\nE then RMB during windup = feint · Space dodge\nTab / MMB lock-on · F1 dummy mode · F5 reset · Esc free mouse"
	help.add_theme_font_size_override("font_size", 13)
	help.add_theme_constant_override("outline_size", 4)
	help.add_theme_color_override("font_outline_color", Color.BLACK)
	root.add_child(help)

	_status.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_status.position = Vector2(20, -40)
	_status.add_theme_font_size_override("font_size", 12)
	_status.modulate = Color(1, 1, 1, 0.6)
	root.add_child(_status)


func set_mode_text(text: String) -> void:
	_mode.text = "Dummy: " + text


func set_tick_stats(tick: int, sim_usec: int) -> void:
	_status.text = "sim tick %d @ %d Hz · tick cost %.2f ms · %d fps" % [
		tick, CombatSimulation.TICK_RATE, sim_usec / 1000.0, Engine.get_frames_per_second()]


func push_events(events: Array[Dictionary]) -> void:
	var player_id := _player.combatant.entity_id
	for ev in events:
		var line := _describe(ev)
		if line.is_empty():
			continue
		_feed_lines.append(line)
		var involves_player: bool = ev.get("attacker") == player_id or ev.get("target") == player_id
		match ev["type"]:
			&"parried":
				_show_banner("PARRY", Color(0.85, 0.95, 1.0))
			&"guard_broken":
				_show_banner("GUARD BROKEN", Color(1.0, 0.85, 0.2))
			&"hit":
				if ev.get("killed", false):
					_show_banner("DEFEATED" if ev["target"] == player_id else "VICTORY", Color(1, 0.35, 0.3))
				elif ev.get("critical", false):
					_show_banner("CRITICAL", Color(1, 0.5, 0.2))
				elif ev.get("posture_broken", false):
					_show_banner("POSTURE BROKEN", Color(1.0, 0.85, 0.2))
			&"dodged":
				if involves_player:
					_show_banner("EVADED", Color(0.6, 1.0, 0.7))
	while _feed_lines.size() > FEED_LINES:
		_feed_lines.pop_front()
	_feed.text = "\n".join(_feed_lines)


func _process(delta: float) -> void:
	if _player == null:
		return
	_fill(_player_bars, _player.combatant.stats)
	_fill(_target_bars, _target.combatant.stats)
	_banner_time = maxf(_banner_time - delta, 0.0)
	_banner.modulate.a = clampf(_banner_time / (BANNER_SECONDS * 0.5), 0.0, 1.0)


func _describe(ev: Dictionary) -> String:
	var attacker: String = _names.get(ev.get("attacker"), "?")
	var target: String = _names.get(ev.get("target"), "?")
	match ev["type"]:
		&"hit":
			var s := "%s hit %s for %d" % [attacker, target, ev["damage"]]
			if ev.get("critical", false):
				s += " (critical)"
			if ev.get("killed", false):
				s += " — defeated"
			return s
		&"guarded":
			return "%s guarded %s" % [target, attacker]
		&"parried":
			return "%s parried %s" % [target, attacker]
		&"guard_broken":
			return "%s broke %s's guard" % [attacker, target]
		&"dodged":
			return "%s evaded %s" % [target, attacker]
		&"feint":
			return "%s feinted" % attacker
	return ""


func _show_banner(text: String, color: Color) -> void:
	_banner.text = text
	_banner.add_theme_color_override("font_color", color)
	_banner_time = BANNER_SECONDS


func _panel(root: Control, preset: Control.LayoutPreset, offset: Vector2) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.set_anchors_preset(preset)
	box.position = offset
	box.custom_minimum_size = Vector2(280, 0)
	box.add_theme_constant_override("separation", 4)
	root.add_child(box)
	return box


func _bars(parent: VBoxContainer, title: String) -> Dictionary:
	var label := Label.new()
	label.text = title
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	parent.add_child(label)
	return {
		"health": _bar(parent, Color(0.85, 0.2, 0.2), 14),
		"posture": _bar(parent, Color(1.0, 0.8, 0.2), 8),
		"stamina": _bar(parent, Color(0.35, 0.8, 0.4), 8),
		"spirit": _bar(parent, Color(0.6, 0.4, 1.0), 6),
	}


func _bar(parent: VBoxContainer, color: Color, height: float) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(280, height)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.55)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)
	parent.add_child(bar)
	return bar


func _fill(bars: Dictionary, s: CombatStats) -> void:
	(bars["health"] as ProgressBar).value = 100.0 * s.health / s.max_health
	(bars["posture"] as ProgressBar).value = 100.0 * s.posture / s.max_posture
	(bars["stamina"] as ProgressBar).value = 100.0 * s.stamina / s.max_stamina
	(bars["spirit"] as ProgressBar).value = 100.0 * s.spirit / s.max_spirit
