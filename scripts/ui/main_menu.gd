class_name MainMenu
extends UiScreen
## HOME-01: title menu over the MenuStage, where the player's own assassin stands on the right
## third with their katana. A brush-calligraphy 影 mark heads a column of serif entries that a sumi
## swipe paints behind on hover. Drag the empty space to turn the character. Only features that
## exist are offered (GUI.md §5.2).

const ENTRIES := [
	["Enter the Province", "japan", "Explore the Shrouded Province with other players"],
	["Training Dojo", "ninja-heroic-stance", "Practise timing against the training shinobi"],
	["Armory", "ninja-mask", "Garb dyes, enchanted blades and silk scarves"],
	["Store", "shopping-bag", "Cosmetics with live try-on"],
	["Settings", "cog", "Video, audio, controls and accessibility"],
	["Credits", "scroll-unfurled", "The artists behind every asset"],
	["Quit", "exit-door", ""],
]

var _caption := Label.new()


func _init() -> void:
	super()
	closable = false
	dim_background = false


func _ready() -> void:
	if shell.stage != null:
		shell.stage.frame("title")
	_build_shade()
	var drag := StageDragArea.new()
	drag.shell = shell
	add_child(drag)

	var col := UiKit.vbox(0)
	col.position = Vector2(96, 70)
	col.custom_minimum_size = Vector2(440, 0)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(col)
	var mark_row := UiKit.hbox(UiTokens.S4)
	mark_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(mark_row)
	var kanji := UiKit.label("影", "Brush")
	kanji.add_theme_font_size_override("font_size", UiTokens.scaled(132))
	kanji.add_theme_color_override("font_color", Color(0.93, 0.9, 0.85))
	kanji.add_theme_constant_override("shadow_offset_x", 3)
	kanji.add_theme_constant_override("shadow_offset_y", 4)
	mark_row.add_child(kanji)
	var words := UiKit.vbox(0)
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	mark_row.add_child(words)
	var name_label := UiKit.label("KAGE", "H1")
	name_label.add_theme_font_size_override("font_size", UiTokens.scaled(54))
	words.add_child(name_label)
	words.add_child(UiKit.overline("The Shrouded Province"))
	col.add_child(UiKit.divider(400))
	col.add_child(UiKit.spacer(36))

	for e: Array in ENTRIES:
		var b := UiKit.button(e[0], _action(e[0]), "MenuItem")
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(420, 56)
		b.icon = load(UiKit.ICON_PATH % e[1])
		b.expand_icon = true
		b.add_theme_constant_override("icon_max_width", 24)
		b.add_theme_constant_override("h_separation", 18)
		b.add_theme_color_override("icon_normal_color", Color(UiTokens.GOLD, 0.55))
		b.add_theme_color_override("icon_hover_color", UiTokens.GOLD)
		b.add_theme_color_override("icon_focus_color", UiTokens.GOLD)
		var caption: String = e[2]
		b.mouse_entered.connect(func() -> void: _caption.text = caption)
		b.focus_entered.connect(func() -> void: _caption.text = caption)
		col.add_child(b)
	col.add_child(UiKit.spacer(18))
	_caption.theme_type_variation = "Muted"
	_caption.custom_minimum_size = Vector2(420, 24)
	_caption.text = ENTRIES[0][2]
	col.add_child(_caption)

	var build := UiKit.label("PRE-ALPHA  ·  PROTOCOL V%d  ·  GODOT %s" % [NetProtocol.VERSION, str(Engine.get_version_info()["string"]).to_upper()], "Overline")
	build.add_theme_color_override("font_color", Color(UiTokens.TEXT_SECONDARY, 0.55))
	build.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	build.position = Vector2(96, -48)
	add_child(build)
	add_child(PlayerCard.new())
	add_child(UiKit.hint_bar([["↑↓", "Navigate"], ["Enter", "Select"], ["Drag", "Turn character"]]))


func _action(entry: String) -> Callable:
	match entry:
		"Enter the Province":
			return func() -> void: shell.push(JoinScreen.new())
		"Training Dojo":
			return func() -> void: shell.start_sandbox()
		"Armory":
			return func() -> void: shell.push(ArmoryScreen.new())
		"Store":
			return func() -> void: shell.push(StoreScreen.new())
		"Settings":
			return func() -> void: shell.push(SettingsScreen.new())
		"Credits":
			return func() -> void: shell.push(CreditsScreen.new())
	return func() -> void: shell.quit()


## Ink bleeding in from the left so serif type reads over the scene without a box.
func _build_shade() -> void:
	var grad := Gradient.new()
	grad.set_color(0, Color(0.015, 0.015, 0.02, 0.92))
	grad.set_color(1, Color(0.015, 0.015, 0.02, 0.0))
	grad.add_point(0.32, Color(0.015, 0.015, 0.02, 0.7))
	grad.set_offset(grad.get_point_count() - 1, 0.62)
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill_from = Vector2(0, 0.5)
	tex.fill_to = Vector2(1, 0.5)
	var rect := TextureRect.new()
	rect.texture = tex
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	UiKit.full_rect(rect)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)
