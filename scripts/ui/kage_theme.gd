class_name KageTheme
extends RefCounted
## The shared Theme: ink-wash panels with gold hairlines and corner brackets, sumi brush strokes for
## hover/focus and bars, Cormorant display type with small-caps overlines (GUI.md §3). All painted
## textures come from assets/ui (tools/bake_ui_textures.gd). Rebuilt when text scale or contrast
## changes so the whole UI follows.
##
## Type variations: Title, H1, H2, Muted, Overline, Brush (labels); MenuItem, PrimaryButton,
## DangerButton, GhostButton (buttons); Pill (panel).


## Makes the Kage theme the global default. Controls under a CanvasLayer (every screen and the HUD)
## do not inherit a Window theme, so merging into the default theme is what reaches all of them.
static func install() -> void:
	var t := build()
	var global := ThemeDB.get_default_theme()
	global.merge_with(t)
	global.default_font = t.default_font
	global.default_font_size = t.default_font_size
	ThemeDB.fallback_font = t.default_font
	ThemeDB.fallback_font_size = t.default_font_size


static func build() -> Theme:
	var t := Theme.new()
	var contrast := bool(GameSettings.get_value("accessibility", "high_contrast"))
	var display := UiTokens.display_font()
	t.default_font = UiTokens.body_font()
	t.default_font_size = UiTokens.scaled(UiTokens.SIZE_BODY)

	# Panels.
	var panel := _tex_box("panel", 40, UiTokens.S6, UiTokens.S5)
	if contrast:
		panel.modulate_color = Color(1.25, 1.25, 1.25)
	t.set_stylebox("panel", "PanelContainer", panel)
	t.set_stylebox("panel", "Panel", panel)
	t.set_type_variation("Pill", "PanelContainer")
	t.set_stylebox("panel", "Pill", _tex_box("panel_soft", 38, UiTokens.S5, UiTokens.S3))
	t.set_stylebox("panel", "TooltipPanel", _tex_box("panel", 40, UiTokens.S3, UiTokens.S2))

	# Buttons: quiet underline at rest; a sumi swipe paints in behind on hover/focus.
	var swipe := _swipe(Color(0.62, 0.48, 0.25, 0.55))
	var swipe_strong := _swipe(Color(0.72, 0.55, 0.28, 0.8))
	for type in ["Button"]:
		t.set_stylebox("normal", type, _outline_box())
		t.set_stylebox("hover", type, swipe)
		t.set_stylebox("pressed", type, swipe_strong)
		t.set_stylebox("hover_pressed", type, swipe_strong)
		t.set_stylebox("focus", type, swipe)
		t.set_stylebox("disabled", type, _outline_box(0.2))
		t.set_color("font_color", type, Color(UiTokens.TEXT_PRIMARY, 0.92))
		t.set_color("font_hover_color", type, Color.WHITE)
		t.set_color("font_focus_color", type, Color.WHITE)
		t.set_color("font_pressed_color", type, UiTokens.GOLD.lightened(0.4))
		t.set_color("font_disabled_color", type, UiTokens.TEXT_SECONDARY.darkened(0.45))
		t.set_font("font", type, UiTokens.overline_font())
		t.set_font_size("font_size", type, UiTokens.scaled(14))
	# Dropdowns read as fields, not actions: a dark well with a gold underline that brightens.
	t.set_stylebox("normal", "OptionButton", _field_box(0.35))
	t.set_stylebox("hover", "OptionButton", _field_box(0.8, 0.5))
	t.set_stylebox("pressed", "OptionButton", _field_box(1.0, 0.55))
	t.set_stylebox("hover_pressed", "OptionButton", _field_box(1.0, 0.55))
	t.set_stylebox("focus", "OptionButton", _field_box(1.0, 0.0))
	t.set_stylebox("disabled", "OptionButton", _field_box(0.15))
	t.set_font("font", "OptionButton", UiTokens.body_font())
	t.set_font_size("font_size", "OptionButton", UiTokens.scaled(16))
	t.set_color("font_color", "OptionButton", UiTokens.TEXT_PRIMARY)
	t.set_color("font_hover_color", "OptionButton", Color.WHITE)
	t.set_color("font_focus_color", "OptionButton", Color.WHITE)
	t.set_color("font_pressed_color", "OptionButton", Color.WHITE)
	t.set_type_variation("PrimaryButton", "Button")
	t.set_stylebox("normal", "PrimaryButton", _swipe(Color(0.62, 0.17, 0.12, 0.85)))
	t.set_stylebox("hover", "PrimaryButton", _swipe(Color(0.78, 0.22, 0.15, 0.95)))
	t.set_stylebox("focus", "PrimaryButton", _swipe(Color(0.78, 0.22, 0.15, 0.95)))
	t.set_stylebox("pressed", "PrimaryButton", _swipe(Color(0.9, 0.3, 0.2, 1.0)))
	t.set_type_variation("DangerButton", "Button")
	t.set_stylebox("hover", "DangerButton", _swipe(Color(0.7, 0.18, 0.13, 0.75)))
	t.set_stylebox("focus", "DangerButton", _swipe(Color(0.7, 0.18, 0.13, 0.75)))
	t.set_color("font_color", "DangerButton", UiTokens.VERMILION.lightened(0.35))
	t.set_type_variation("GhostButton", "Button")
	t.set_stylebox("normal", "GhostButton", _empty(UiTokens.S5, UiTokens.S2))

	# Title-menu items: large serif, a gold-tinted ink swipe behind the hovered entry.
	t.set_type_variation("MenuItem", "Button")
	for state in ["normal", "disabled"]:
		t.set_stylebox(state, "MenuItem", _empty(UiTokens.S5, UiTokens.S1))
	for state in ["hover", "pressed", "focus", "hover_pressed"]:
		t.set_stylebox(state, "MenuItem", _swipe(Color(0.66, 0.5, 0.26, 0.42), UiTokens.S5, UiTokens.S1))
	t.set_font("font", "MenuItem", display)
	t.set_font_size("font_size", "MenuItem", UiTokens.scaled(30))
	t.set_color("font_color", "MenuItem", Color(UiTokens.TEXT_PRIMARY, 0.78))
	t.set_color("font_hover_color", "MenuItem", Color.WHITE)
	t.set_color("font_focus_color", "MenuItem", Color.WHITE)
	t.set_color("font_pressed_color", "MenuItem", UiTokens.GOLD.lightened(0.3))
	t.set_color("font_outline_color", "MenuItem", Color(0, 0, 0, 0.7))
	t.set_constant("outline_size", "MenuItem", 5)

	# Toggles.
	for state in ["normal", "hover", "pressed", "disabled", "hover_pressed"]:
		t.set_stylebox(state, "CheckButton", StyleBoxEmpty.new())
	t.set_stylebox("focus", "CheckButton", _swipe(Color(0.62, 0.48, 0.25, 0.4)))

	# Text fields and lists: a dark well with a gold underline.
	var field := StyleBoxFlat.new()
	field.bg_color = Color(0, 0, 0, 0.45)
	field.border_color = Color(UiTokens.GOLD, 0.55)
	field.border_width_bottom = 1
	field.content_margin_left = UiTokens.S3
	field.content_margin_right = UiTokens.S3
	field.content_margin_top = UiTokens.S2
	field.content_margin_bottom = UiTokens.S2
	var field_focus := field.duplicate() as StyleBoxFlat
	field_focus.border_color = UiTokens.GOLD
	field_focus.border_width_bottom = 2
	t.set_stylebox("normal", "LineEdit", field)
	t.set_stylebox("focus", "LineEdit", field_focus)
	t.set_stylebox("read_only", "LineEdit", field)
	t.set_color("caret_color", "LineEdit", UiTokens.GOLD)
	t.set_color("font_placeholder_color", "LineEdit", UiTokens.TEXT_SECONDARY.darkened(0.25))
	t.set_stylebox("panel", "ItemList", field)
	t.set_stylebox("focus", "ItemList", StyleBoxEmpty.new())
	t.set_stylebox("selected", "ItemList", _swipe(Color(0.62, 0.48, 0.25, 0.45)))
	t.set_stylebox("selected_focus", "ItemList", _swipe(Color(0.72, 0.55, 0.28, 0.6)))
	t.set_color("font_selected_color", "ItemList", Color.WHITE)

	# Labels.
	t.set_color("font_color", "Label", UiTokens.TEXT_PRIMARY)
	t.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.85))
	t.set_constant("outline_size", "Label", 3 if contrast else 0)
	t.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.55))
	t.set_constant("shadow_offset_y", "Label", 1)
	for v: Array in [["Title", display, UiTokens.SIZE_TITLE], ["H1", display, UiTokens.SIZE_H1],
			["H2", display, UiTokens.SIZE_H2], ["Muted", UiTokens.body_font(), UiTokens.SIZE_SMALL],
			["Overline", UiTokens.overline_font(), 12], ["Brush", UiTokens.brush_font(), 120]]:
		t.set_type_variation(v[0], "Label")
		t.set_font("font", v[0], v[1])
		t.set_font_size("font_size", v[0], UiTokens.scaled(v[2]))
	t.set_color("font_color", "Muted", UiTokens.TEXT_SECONDARY.lightened(0.25 if contrast else 0.08))
	t.set_color("font_color", "H2", UiTokens.GOLD.lightened(0.1))
	t.set_color("font_color", "Overline", UiTokens.GOLD)
	t.set_color("font_color", "Brush", Color(0.9, 0.86, 0.8, 0.9))

	# Sliders: hairline track, gold fill.
	var track := StyleBoxFlat.new()
	track.bg_color = Color(1, 1, 1, 0.14)
	track.content_margin_top = 1
	track.content_margin_bottom = 1
	var filled := track.duplicate() as StyleBoxFlat
	filled.bg_color = UiTokens.GOLD
	t.set_stylebox("slider", "HSlider", track)
	t.set_stylebox("grabber_area", "HSlider", filled)
	t.set_stylebox("grabber_area_highlight", "HSlider", filled)

	# Bars use the brush stroke; HUD widgets tint the fill per resource.
	var bar_bg := _tex_box("brush_bar", 18, 0, 0)
	bar_bg.modulate_color = Color(0, 0, 0, 0.7)
	t.set_stylebox("background", "ProgressBar", bar_bg)
	t.set_stylebox("fill", "ProgressBar", _tex_box("brush_bar", 18, 0, 0))

	# Tabs: overline type, a brush mark under the selected tab.
	t.set_stylebox("tab_selected", "TabBar", _swipe(Color(0.62, 0.48, 0.25, 0.5), UiTokens.S4, UiTokens.S2))
	t.set_stylebox("tab_unselected", "TabBar", _empty(UiTokens.S4, UiTokens.S2))
	t.set_stylebox("tab_hovered", "TabBar", _swipe(Color(0.62, 0.48, 0.25, 0.25), UiTokens.S4, UiTokens.S2))
	t.set_stylebox("tab_focus", "TabBar", StyleBoxEmpty.new())
	t.set_font("font", "TabBar", UiTokens.overline_font())
	t.set_font_size("font_size", "TabBar", UiTokens.scaled(13))
	t.set_color("font_selected_color", "TabBar", Color.WHITE)
	t.set_color("font_unselected_color", "TabBar", UiTokens.TEXT_SECONDARY)
	t.set_color("font_hovered_color", "TabBar", UiTokens.TEXT_PRIMARY)
	t.set_stylebox("panel", "TabContainer", StyleBoxEmpty.new())
	t.set_stylebox("tabbar_background", "TabContainer", StyleBoxEmpty.new())

	t.set_constant("separation", "VBoxContainer", UiTokens.S2)
	t.set_constant("separation", "HBoxContainer", UiTokens.S3)
	return t


static func _tex_box(name: String, margin: int, pad_h: int, pad_v: int) -> StyleBoxTexture:
	var s := StyleBoxTexture.new()
	s.texture = UiTokens.tex(name)
	s.set_texture_margin_all(margin)
	s.content_margin_left = pad_h
	s.content_margin_right = pad_h
	s.content_margin_top = pad_v
	s.content_margin_bottom = pad_v
	return s


## Sumi brush swipe tinted `color`, stretched behind a control (tapered ends stay intact).
static func _swipe(color: Color, pad_h: int = UiTokens.S5, pad_v: int = UiTokens.S2) -> StyleBoxTexture:
	var s := StyleBoxTexture.new()
	s.texture = UiTokens.tex("brush_swipe")
	s.texture_margin_left = 60
	s.texture_margin_right = 60
	s.texture_margin_top = 8
	s.texture_margin_bottom = 8
	s.modulate_color = color
	s.content_margin_left = pad_h
	s.content_margin_right = pad_h
	s.content_margin_top = pad_v
	s.content_margin_bottom = pad_v
	return s


## Resting button: faint gold underline only, so stacks of buttons read as a quiet list.
static func _outline_box(alpha: float = 0.45) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0, 0, 0, 0.25)
	s.border_color = Color(UiTokens.GOLD, alpha)
	s.border_width_bottom = 1
	s.content_margin_left = UiTokens.S5
	s.content_margin_right = UiTokens.S5
	s.content_margin_top = UiTokens.S2
	s.content_margin_bottom = UiTokens.S2
	return s


static func _field_box(line_alpha: float, fill_alpha: float = 0.42) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.02, 0.02, 0.025, fill_alpha)
	s.border_color = Color(UiTokens.GOLD, line_alpha)
	s.border_width_bottom = 1
	s.content_margin_left = UiTokens.S3
	s.content_margin_right = UiTokens.S3
	s.content_margin_top = UiTokens.S1
	s.content_margin_bottom = UiTokens.S1
	return s


static func _empty(pad_h: int, pad_v: int) -> StyleBoxEmpty:
	var s := StyleBoxEmpty.new()
	s.content_margin_left = pad_h
	s.content_margin_right = pad_h
	s.content_margin_top = pad_v
	s.content_margin_bottom = pad_v
	return s
