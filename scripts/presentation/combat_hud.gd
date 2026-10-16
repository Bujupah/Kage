class_name CombatHud
extends CanvasLayer
## Gameplay HUD (GUI.md §4, GAME-01/02/03/06/34): vitals with a delayed-damage segment, target
## panel, compass with landmarks, region/risk pill, action bar, confirmed-event feed and banners,
## the danger-boundary warning, the defeat report and a controls card. It only reads state; it
## never changes it. The region rule shown is the server-replicated zone, not a local guess.

const FEED_LINES := 6
const BANNER_SECONDS := 1.1
const LAG_DELAY := 0.45 ## Seconds the damage segment holds before draining.
const COMPASS_WIDTH := 560.0
const COMPASS_FOV_DEG := 160.0
const RESPAWN_SECONDS := 3.0 ## Server and sandbox start a new round 90 ticks after a death.
const TITLE_CARD_SECONDS := 3.6
const ACTION_ICONS := {"attack_light": "katana", "attack_heavy": "sword-slice", "guard": "shield-reflect", "dodge": "dodge"}
const DANGER_TEXT := "Dangerous area: unsecured backpack items drop on defeat. Equipped gear and learned skills are protected."

var online := false

var _player: FighterBody
var _target: FighterBody
var _names: Dictionary = {}
var _root := Control.new()
var _vitals: Dictionary = {}
var _target_box := PanelContainer.new()
var _target_bars: Dictionary = {}
var _target_name := Label.new()
var _target_badge := Label.new()
var _pill := PanelContainer.new()
var _pill_title := Label.new()
var _pill_rule := Label.new()
var _latency := Label.new()
var _mode := Label.new()
var _compass := Control.new()
var _actions: Dictionary = {}
var _weapon := Label.new()
var _feed := Label.new()
var _feed_lines: Array[String] = []
var _banner := Label.new()
var _banner_time := 0.0
var _status := Label.new()
var _warning := PanelContainer.new()
var _death := PanelContainer.new()
var _death_title := Label.new()
var _death_body := Label.new()
var _death_timer := Label.new()
var _help := PanelContainer.new()
var _help_text := Label.new()
var _title_card := VBoxContainer.new() ## Cinematic area name shown on entering a region.
var _title_name := Label.new()
var _title_rule := Label.new()
var _title_time := 0.0
var _last_region := ""
var _death_kanji := Label.new()

var _lag_value := 1.0
var _lag_hold := 0.0
var _last_health := -1
var _last_zone := -1
var _warned := false
var _dead_since := -1.0
var _killer_line := ""


func setup(player: FighterBody, target: FighterBody, names: Dictionary) -> void:
	_player = player
	_target = target
	_names = names


func set_target(target: FighterBody, names: Dictionary) -> void:
	_target = target
	_names = names


func _ready() -> void:
	layer = 10
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = _hud_theme()
	add_child(_root)
	_build_scrims()
	_build_vitals()
	_build_target()
	_build_compass()
	_build_pill()
	_build_actions()
	_build_feed_and_banner()
	_build_warning()
	_build_death()
	_build_help()
	if bool(GameSettings.get_value("gameplay", "hints")):
		_help.visible = true
		get_tree().create_timer(8.0).timeout.connect(func() -> void: _help.visible = false)


## On-air HUD text gets a soft ink shadow so it holds up against a bright sky or sand.
static func _hud_theme() -> Theme:
	var t := Theme.new()
	t.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.75))
	t.set_constant("shadow_offset_x", "Label", 0)
	t.set_constant("shadow_offset_y", "Label", 1)
	t.set_constant("shadow_outline_size", "Label", 6)
	return t


## Faint ink gradients along the top and bottom edges, where the HUD lives.
func _build_scrims() -> void:
	for top: bool in [true, false]:
		var grad := Gradient.new()
		grad.set_color(0, Color(0, 0, 0, 0.42))
		grad.set_color(1, Color(0, 0, 0, 0))
		var tex := GradientTexture2D.new()
		tex.gradient = grad
		tex.fill_from = Vector2(0.5, 0.0 if top else 1.0)
		tex.fill_to = Vector2(0.5, 1.0 if top else 0.0)
		var rect := TextureRect.new()
		rect.texture = tex
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_SCALE
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rect.set_anchors_preset(Control.PRESET_TOP_WIDE if top else Control.PRESET_BOTTOM_WIDE)
		if top:
			rect.offset_bottom = 170
		else:
			rect.offset_top = -190
		_root.add_child(rect)


# --- Public API (sandbox / net client) -----------------------------------------------------------

func set_mode_text(text: String) -> void:
	_mode.text = text


func set_help_text(_text: String) -> void:
	pass # Controls card is generated from live bindings.


func set_tick_stats(tick: int, sim_usec: int) -> void:
	_status.text = "sim tick %d · %d Hz · tick %.2f ms · %d fps" % [tick, CombatSimulation.TICK_RATE,
			sim_usec / 1000.0, Engine.get_frames_per_second()]


func set_status_text(text: String) -> void:
	_status.text = text


func set_latency(rtt_ms: int) -> void:
	if not bool(GameSettings.get_value("network", "show_latency")) or rtt_ms < 0:
		_latency.text = ""
		return
	var quality := "good" if rtt_ms < 80 else ("fair" if rtt_ms < 150 else "poor")
	_latency.text = "● %d ms · %s" % [rtt_ms, quality]
	_latency.add_theme_color_override("font_color", UiTokens.SAFE if rtt_ms < 80 else (UiTokens.GOLD if rtt_ms < 150 else UiTokens.VERMILION))


func push_events(events: Array[Dictionary]) -> void:
	var me := _player.combatant.entity_id if _player != null else -1
	for ev in events:
		var line := _describe(ev)
		if not line.is_empty():
			_feed_lines.append(line)
		var mine: bool = ev.get("attacker") == me or ev.get("target") == me
		match ev["type"]:
			&"parried":
				_show_banner("PARRY", UiTokens.TEXT_PRIMARY)
			&"guard_broken":
				_show_banner("GUARD BROKEN", UiTokens.GOLD)
			&"hit":
				if ev.get("killed", false):
					var won: bool = ev["attacker"] == me
					_show_banner("VICTORY" if won else "DEFEATED", UiTokens.SAFE if won else UiTokens.VERMILION)
					if ev["target"] == me:
						_killer_line = "Struck down by %s." % _names.get(ev["attacker"], "an opponent")
				elif ev.get("critical", false):
					_show_banner("CRITICAL", UiTokens.VERMILION.lightened(0.2))
				elif ev.get("posture_broken", false):
					_show_banner("POSTURE BROKEN", UiTokens.GOLD)
			&"dodged":
				if mine:
					_show_banner("EVADED", UiTokens.SAFE)
			&"round_reset":
				_show_banner("FIGHT", UiTokens.TEXT_PRIMARY)
	while _feed_lines.size() > FEED_LINES:
		_feed_lines.pop_front()
	_feed.text = "\n".join(_feed_lines)


# --- Frame update --------------------------------------------------------------------------------

func _process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var c := _player.combatant
	_fill_vitals(_vitals, c.stats, delta)
	_update_target()
	_update_zone(c)
	_update_actions(c)
	_update_death(c, delta)
	_compass.queue_redraw()
	_banner_time = maxf(_banner_time - delta, 0.0)
	_title_time = maxf(_title_time - delta, 0.0)
	var k := _title_time / TITLE_CARD_SECONDS
	_title_card.modulate.a = clampf(minf((1.0 - k) * 4.0, k * 2.5), 0.0, 1.0) if not GameSettings.reduced_motion() else (1.0 if _title_time > 0.0 else 0.0)
	_banner.modulate.a = clampf(_banner_time / (BANNER_SECONDS * 0.4), 0.0, 1.0)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_help") and not UiShell.gameplay_blocked():
		_help.visible = not _help.visible
		if _help.visible:
			_help_text.text = _controls_text()


func _update_target() -> void:
	var t := _target if _target != null and is_instance_valid(_target) else null
	_target_box.visible = t != null and _player.global_position.distance_to(t.global_position) < 30.0
	if not _target_box.visible:
		return
	_target_name.text = _names.get(t.combatant.entity_id, "Opponent")
	var rule := t.combatant.zone
	_target_badge.text = "ARENA DUEL" if rule == ZoneRule.ARENA_PROTECTED else ("PROTECTED" if rule == ZoneRule.SAFE_SANCTUARY else "HOSTILE")
	_target_badge.add_theme_color_override("font_color", UiTokens.zone_color(rule))
	var s := t.combatant.stats
	(_target_bars["health"] as ProgressBar).value = 100.0 * s.health / s.max_health
	(_target_bars["posture"] as ProgressBar).value = 100.0 * s.posture / s.max_posture


## Authoritative zone from the combatant (replicated online; set by the local sim offline).
func _update_zone(c: Combatant) -> void:
	var rule := c.zone
	var pos := _player.global_position
	var region := RegionMap.region_name_at(pos)
	_pill_title.text = region.to_upper()
	if region != _last_region:
		_last_region = region
		_show_title_card(region, rule)
	var rule_text := ZoneRule.NAMES[rule]
	match rule:
		ZoneRule.SAFE_SANCTUARY:
			rule_text += " · no combat"
		ZoneRule.ARENA_PROTECTED:
			rule_text += " · duels, nothing lost"
		_:
			rule_text += " · PvP · carried loot at risk · %d m to safety" % roundi(RegionMap.distance_to_safety(pos))
	_pill_rule.text = rule_text
	_pill_rule.add_theme_color_override("font_color", UiTokens.zone_color(rule))
	if _last_zone != -1 and rule != _last_zone:
		if ZoneRule.is_dangerous(rule):
			Sfx.play_ui(self, "ui_warning")
	_last_zone = rule
	# GAME-06: explicit loss rule before the first crossing of this session.
	var approaching := RegionMap.approaching_frontier(pos)
	_warning.visible = approaching and not _warned
	if ZoneRule.is_dangerous(rule):
		_warned = true


func _update_actions(c: Combatant) -> void:
	var w := c.weapon
	var costs := {
		"attack_light": w.light_chain[0].stamina_cost if not w.light_chain.is_empty() else 0,
		"attack_heavy": w.heavy.stamina_cost if w.heavy != null else 0,
		"guard": 0,
		"dodge": Combatant.DODGE_STAMINA_COST,
	}
	for action: String in _actions:
		var slot: Dictionary = _actions[action]
		var affordable: bool = c.stats.stamina >= int(costs[action]) and c.is_alive()
		(slot["panel"] as Control).modulate.a = 1.0 if affordable else 0.4
		(slot["glyph"] as Label).text = InputBindings.glyph(action)


func _update_death(c: Combatant, delta: float) -> void:
	if c.is_alive():
		_death.visible = false
		_dead_since = -1.0
		return
	if _dead_since < 0.0:
		_dead_since = 0.0
		_death_title.text = "DEFEATED"
		var lines := PackedStringArray()
		lines.append(_killer_line if not _killer_line.is_empty() else "You fell.")
		match c.zone:
			ZoneRule.ARENA_PROTECTED:
				lines.append("Protected arena: nothing is lost.")
			ZoneRule.SAFE_SANCTUARY:
				lines.append("Sanctuary: nothing is lost.")
			_:
				lines.append("Carried items dropped: none. (Inventory arrives in a later milestone.)")
				lines.append("Protected: equipped katana, learned techniques, cosmetics.")
		_death_body.text = "\n".join(lines)
		_killer_line = ""
	_dead_since += delta
	_death.visible = true
	var left := ceili(maxf(RESPAWN_SECONDS - _dead_since, 0.0))
	_death_timer.text = ("Respawning in %d s" if online else "New round in %d s") % left


# --- Builders ------------------------------------------------------------------------------------

func _build_vitals() -> void:
	var box := UiKit.vbox(3)
	box.position = Vector2(40, 34)
	box.custom_minimum_size = Vector2(360, 0)
	_root.add_child(box)
	var head := UiKit.hbox(UiTokens.S2)
	box.add_child(head)
	head.add_child(UiKit.overline(_names.get(_player.combatant.entity_id, "You") if _player != null else "You"))
	_vitals["health_text"] = UiKit.label("", "Muted")
	head.add_child(_vitals["health_text"])
	_vitals["health"] = _bar(box, UiTokens.HEALTH, 18, true, 360)
	_vitals["posture"] = _bar(box, UiTokens.POSTURE, 9, false, 300)
	_vitals["stamina"] = _bar(box, UiTokens.STAMINA, 9, false, 300)
	_vitals["spirit"] = _bar(box, UiTokens.SPIRIT, 7, false, 240)

func _build_target() -> void:
	_target_box.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	_target_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_target_box.position = Vector2(-200, 74)
	_target_box.custom_minimum_size = Vector2(400, 0)
	_root.add_child(_target_box)
	var v := UiKit.vbox(2)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	_target_box.add_child(v)
	_target_name.add_theme_font_override("font", UiTokens.display_font())
	_target_name.add_theme_font_size_override("font_size", UiTokens.scaled(24))
	_target_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_target_name)
	_target_badge.theme_type_variation = "Overline"
	_target_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_target_badge)
	_target_bars = {"health": _bar(v, UiTokens.HEALTH, 12, false, 400), "posture": _bar(v, UiTokens.POSTURE, 6, false, 320)}
	(_target_bars["posture"] as Control).get_parent().size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_target_box.visible = false

func _build_compass() -> void:
	_compass.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_compass.position = Vector2(-COMPASS_WIDTH * 0.5, 22)
	_compass.custom_minimum_size = Vector2(COMPASS_WIDTH, 36)
	_compass.size = Vector2(COMPASS_WIDTH, 36)
	_compass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_compass.draw.connect(_draw_compass)
	_root.add_child(_compass)


func _draw_compass() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null or _player == null:
		return
	var fwd := -cam.global_basis.z
	var heading := atan2(fwd.x, -fwd.z) # 0 = north (-Z), clockwise positive.
	var font := UiTokens.font(false)
	var w := COMPASS_WIDTH
	_compass.draw_rect(Rect2(0, 14, w, 2), Color(1, 1, 1, 0.18))
	var marks := [["N", 0.0], ["E", PI * 0.5], ["S", PI], ["W", -PI * 0.5]]
	for m: Array in marks:
		var x := _compass_x(heading, m[1])
		if x >= 0.0:
			_compass.draw_string(font, Vector2(x - 6, 12), m[0], HORIZONTAL_ALIGNMENT_LEFT, -1, UiTokens.scaled(14), UiTokens.TEXT_PRIMARY)
	# Dots for every landmark in view; a name only for the one closest to the heading, so labels
	# never pile up.
	var named := ""
	var named_x := -1.0
	var best := INF
	for lm: Array in RegionMap.LANDMARKS:
		var to: Vector3 = (lm[1] as Vector3) - _player.global_position
		if Vector2(to.x, to.z).length() < 4.0:
			continue
		var bearing := atan2(to.x, -to.z)
		var x := _compass_x(heading, bearing)
		if x >= 0.0:
			var col := UiTokens.zone_color(RegionMap.rule_at(lm[1]))
			_compass.draw_circle(Vector2(x, 15), 3.5, col)
			if absf(x - w * 0.5) < best and absf(x - w * 0.5) < w * 0.18:
				best = absf(x - w * 0.5)
				named = "%s · %d m" % [lm[0], roundi(Vector2(to.x, to.z).length())]
				named_x = x
	if not named.is_empty():
		_compass.draw_string(font, Vector2(named_x - 110, 33), named, HORIZONTAL_ALIGNMENT_CENTER, 220, UiTokens.scaled(12), UiTokens.TEXT_SECONDARY)
	_compass.draw_line(Vector2(w * 0.5, 8), Vector2(w * 0.5, 20), UiTokens.GOLD, 2.0)


func _compass_x(heading: float, bearing: float) -> float:
	var d := wrapf(bearing - heading, -PI, PI)
	var half := deg_to_rad(COMPASS_FOV_DEG) * 0.5
	if absf(d) > half:
		return -1.0
	return COMPASS_WIDTH * 0.5 + d / half * COMPASS_WIDTH * 0.5


func _build_pill() -> void:
	# Quiet persistent region label (top right) on air, no box.
	var col := UiKit.vbox(0)
	col.anchor_left = 1.0
	col.anchor_right = 1.0
	col.offset_left = -480
	col.offset_right = -40
	col.offset_top = 34
	_root.add_child(col)
	_pill_title.theme_type_variation = "Overline"
	_pill_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_pill_title.add_theme_color_override("font_color", UiTokens.TEXT_PRIMARY)
	col.add_child(_pill_title)
	_pill_rule.theme_type_variation = "Muted"
	_pill_rule.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_pill_rule.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_pill_rule)
	for l: Label in [_latency, _mode]:
		l.theme_type_variation = "Muted"
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		col.add_child(l)
	# Cinematic area title card (centre top), shown when the region changes.
	_title_card.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_title_card.position = Vector2(-320, 150)
	_title_card.custom_minimum_size = Vector2(640, 0)
	_title_card.alignment = BoxContainer.ALIGNMENT_CENTER
	_title_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_title_card)
	_title_name.add_theme_font_override("font", UiTokens.display_font())
	_title_name.add_theme_font_size_override("font_size", UiTokens.scaled(52))
	_title_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_name.add_theme_constant_override("outline_size", 6)
	_title_name.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	_title_card.add_child(_title_name)
	var rule := UiKit.divider(520)
	rule.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_title_card.add_child(rule)
	_title_rule.theme_type_variation = "Overline"
	_title_rule.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_card.add_child(_title_rule)
	_title_card.modulate.a = 0.0

func _build_actions() -> void:
	var col := UiKit.vbox(UiTokens.S1)
	col.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	col.position = Vector2(-220, -150)
	col.custom_minimum_size = Vector2(440, 0)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(col)
	var row := UiKit.hbox(UiTokens.S5)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(row)
	for entry: Array in [["attack_light", "Light"], ["attack_heavy", "Heavy"], ["guard", "Guard"], ["dodge", "Dodge"]]:
		var slot := UiKit.vbox(2)
		slot.alignment = BoxContainer.ALIGNMENT_CENTER
		var ring := TextureRect.new()
		ring.texture = UiTokens.tex("ring")
		ring.custom_minimum_size = Vector2(70, 70)
		ring.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ring.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var ic := UiKit.icon(ACTION_ICONS[entry[0]], 34, Color(0.95, 0.92, 0.86))
		ic.set_anchors_preset(Control.PRESET_CENTER)
		ic.position = Vector2(-17, -17)
		ring.add_child(ic)
		slot.add_child(ring)
		var glyph := UiKit.label("", "Overline")
		glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		glyph.add_theme_color_override("font_color", UiTokens.TEXT_PRIMARY)
		slot.add_child(glyph)
		var name_label := UiKit.label(entry[1].to_upper(), "Overline")
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.add_theme_font_size_override("font_size", UiTokens.scaled(10))
		slot.add_child(name_label)
		row.add_child(slot)
		_actions[entry[0]] = {"panel": slot, "glyph": glyph}
	_weapon.text = "STARTER KATANA"
	_weapon.theme_type_variation = "Overline"
	_weapon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_weapon.add_theme_color_override("font_color", Color(UiTokens.GOLD, 0.7))
	col.add_child(_weapon)

func _build_feed_and_banner() -> void:
	_feed.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_feed.position = Vector2(-440, -190)
	_feed.size = Vector2(416, 160)
	_feed.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_feed.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_feed.theme_type_variation = "Muted"
	_feed.add_theme_constant_override("outline_size", 4)
	_root.add_child(_feed)
	_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_banner.position = Vector2(-400, 170)
	_banner.size = Vector2(800, 70)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.theme_type_variation = "H1"
	var swipe := StyleBoxTexture.new()
	swipe.texture = UiTokens.tex("brush_swipe")
	swipe.texture_margin_left = 60
	swipe.texture_margin_right = 60
	swipe.modulate_color = Color(0, 0, 0, 0.55)
	swipe.content_margin_top = 6
	swipe.content_margin_bottom = 6
	_banner.add_theme_stylebox_override("normal", swipe)
	_banner.add_theme_constant_override("outline_size", 10)
	_banner.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_root.add_child(_banner)
	_status.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_status.position = Vector2(24, -34)
	_status.theme_type_variation = "Muted"
	_status.modulate.a = 0.7
	_root.add_child(_status)


func _build_warning() -> void:
	_warning.set_anchors_preset(Control.PRESET_CENTER)
	_warning.position = Vector2(-300, 60)
	_warning.custom_minimum_size = Vector2(600, 0)
	_root.add_child(_warning)
	var v := UiKit.vbox(UiTokens.S2)
	_warning.add_child(v)
	var t := UiKit.label("Frontier ahead", "H2")
	t.add_theme_color_override("font_color", UiTokens.VERMILION.lightened(0.2))
	v.add_child(t)
	v.add_child(UiKit.label(DANGER_TEXT, "", true))
	v.add_child(UiKit.label("Other players may attack you past the torii. Turn back to stay in the sanctuary.", "Muted", true))
	_warning.visible = false


func _build_death() -> void:
	# Full-screen defeat report: ink darkness, a brush 敗, then the facts (GAME-34).
	_death.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	UiKit.full_rect(_death)
	_root.add_child(_death)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.0, 0.0, 0.62)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_death.add_child(shade)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_death.add_child(center)
	var v := UiKit.vbox(UiTokens.S2)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.custom_minimum_size = Vector2(620, 0)
	center.add_child(v)
	_death_kanji.text = "敗"
	_death_kanji.theme_type_variation = "Brush"
	_death_kanji.add_theme_font_size_override("font_size", UiTokens.scaled(150))
	_death_kanji.add_theme_color_override("font_color", Color(0.72, 0.12, 0.08, 0.92))
	_death_kanji.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_death_kanji)
	_death_title.theme_type_variation = "H1"
	_death_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_death_title)
	var rule := UiKit.divider(480)
	rule.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(rule)
	_death_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_death_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_death_body)
	_death_timer.theme_type_variation = "Overline"
	_death_timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_death_timer)
	_death.visible = false

func _build_help() -> void:
	_help.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	_help.position = Vector2(24, -130)
	_root.add_child(_help)
	var v := UiKit.vbox(UiTokens.S1)
	_help.add_child(v)
	v.add_child(UiKit.label("Controls", "H2"))
	_help_text.text = _controls_text()
	v.add_child(_help_text)
	v.add_child(UiKit.label("%s hides this card · Esc opens the menu" % InputBindings.glyph("toggle_help"), "Muted"))
	_help.visible = false


func _controls_text() -> String:
	var g := InputBindings.glyph
	var lines := [
		"%s%s%s%s  move   ·   %s  sprint" % [g.call("move_forward"), g.call("move_left"), g.call("move_back"), g.call("move_right"), g.call("sprint")],
		"%s  light (3-hit chain)   ·   %s  heavy" % [g.call("attack_light"), g.call("attack_heavy")],
		"%s  guard — tap just before impact to parry" % g.call("guard"),
		"%s during a heavy windup  feint" % g.call("guard"),
		"%s  dodge (i-frames at the start only)" % g.call("dodge"),
		"%s  lock on" % g.call("lock_on"),
	]
	if not online:
		lines.append("F1  dummy behaviour   ·   F5  reset")
	return "\n".join(lines)


func _bar(parent: Container, color: Color, height: float, with_lag: bool = false, width: float = 300.0) -> ProgressBar:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(width, height)
	parent.add_child(holder)
	var lag: ProgressBar
	if with_lag:
		lag = _make_bar(UiTokens.HEALTH_LAG, height, width)
		holder.add_child(lag)
	var bar := _make_bar(color, height, width)
	if with_lag:
		bar.add_theme_stylebox_override("background", StyleBoxEmpty.new())
		bar.set_meta("lag", lag)
	holder.add_child(bar)
	return bar

## Sumi brush-stroke bar: dark stroke underneath, tinted stroke as the fill.
func _make_bar(color: Color, height: float, width: float) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	bar.custom_minimum_size = Vector2(width, height)
	var bg := StyleBoxTexture.new()
	bg.texture = UiTokens.tex("brush_bar")
	bg.texture_margin_left = 18
	bg.texture_margin_right = 18
	bg.modulate_color = Color(0, 0, 0, 0.62)
	var fill := bg.duplicate() as StyleBoxTexture
	fill.modulate_color = color
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)
	bar.value = 100
	return bar

func _fill_vitals(bars: Dictionary, s: CombatStats, delta: float) -> void:
	var health := 100.0 * s.health / s.max_health
	(bars["health"] as ProgressBar).value = health
	(bars["posture"] as ProgressBar).value = 100.0 * s.posture / s.max_posture
	(bars["stamina"] as ProgressBar).value = 100.0 * s.stamina / s.max_stamina
	(bars["spirit"] as ProgressBar).value = 100.0 * s.spirit / s.max_spirit
	(bars["health_text"] as Label).text = "%d / %d" % [s.health, s.max_health]
	# Delayed-damage segment: holds the old value briefly, then drains to the new one.
	var lag: ProgressBar = (bars["health"] as ProgressBar).get_meta("lag")
	if s.health != _last_health:
		if s.health > _last_health:
			_lag_value = health
		_lag_hold = LAG_DELAY
		_last_health = s.health
	if _lag_hold > 0.0:
		_lag_hold -= delta
	else:
		_lag_value = move_toward(_lag_value, health, delta * 60.0)
	_lag_value = maxf(_lag_value, health)
	lag.value = _lag_value


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
		&"round_reset":
			return "— new round —"
	return ""


## Area discovery card: the region name in large serif over a gold rule, then the rule in small caps.
func _show_title_card(region: String, rule: int) -> void:
	_title_name.text = region
	var rule_text := ZoneRule.NAMES[rule].to_upper()
	match rule:
		ZoneRule.SAFE_SANCTUARY:
			rule_text += "  ·  NO COMBAT"
		ZoneRule.ARENA_PROTECTED:
			rule_text += "  ·  DUELS, NOTHING LOST"
		_:
			rule_text += "  ·  PVP  ·  CARRIED LOOT AT RISK"
	_title_rule.text = rule_text
	_title_rule.add_theme_color_override("font_color", UiTokens.zone_color(rule))
	_title_time = TITLE_CARD_SECONDS


func _show_banner(text: String, color: Color) -> void:
	_banner.text = text
	_banner.add_theme_color_override("font_color", color)
	_banner_time = BANNER_SECONDS
