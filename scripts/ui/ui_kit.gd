class_name UiKit
extends RefCounted
## Small builders for the reusable components in GUI.md §7, so screens read as layout, not
## boilerplate. Everything is a standard Control styled by KageTheme, so focus and controller
## navigation come from Godot for free.


static func full_rect(c: Control) -> Control:
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	return c


static func label(text: String, variation: String = "", wrap: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	if not variation.is_empty():
		l.theme_type_variation = variation
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


static func button(text: String, on_press: Callable, variation: String = "") -> Button:
	var b := Button.new()
	# Action buttons set in spaced small caps; menu entries keep their serif title case.
	b.text = text if variation == "MenuItem" else text.to_upper()
	b.custom_minimum_size.y = UiTokens.MIN_TARGET
	if not variation.is_empty():
		b.theme_type_variation = variation
	b.pressed.connect(func() -> void:
		Sfx.play_ui(b, "ui_click")
		on_press.call())
	b.focus_entered.connect(func() -> void: Sfx.play_ui(b, "ui_move"))
	return b


static func vbox(sep: int = UiTokens.S2) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


static func hbox(sep: int = UiTokens.S3) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


static func panel(min_width: float = 0.0) -> PanelContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size.x = min_width
	return p


## Centered column panel used by most menu screens.
static func centered_panel(parent: Control, width: float) -> VBoxContainer:
	var center := CenterContainer.new()
	full_rect(center)
	parent.add_child(center)
	var p := panel(width)
	center.add_child(p)
	var v := vbox(UiTokens.S3)
	p.add_child(v)
	return v


static func spacer(height: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size.y = height
	return c


## Label on the left, control on the right; returns the row.
static func row(text: String, control: Control, hint: String = "") -> HBoxContainer:
	var h := hbox()
	var l := label(text)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.custom_minimum_size.x = 260
	if not hint.is_empty():
		l.tooltip_text = hint
		l.mouse_filter = Control.MOUSE_FILTER_PASS
	h.add_child(l)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	control.custom_minimum_size.y = UiTokens.MIN_TARGET - 8
	h.add_child(control)
	return h


static func slider_row(text: String, min_v: float, max_v: float, step: float, value: float,
		on_change: Callable, fmt: String = "%d%%", scale: float = 100.0) -> HBoxContainer:
	var s := HSlider.new()
	s.min_value = min_v
	s.max_value = max_v
	s.step = step
	s.value = value
	s.custom_minimum_size.x = 220
	var readout := label(fmt % (value * scale), "Muted")
	readout.custom_minimum_size.x = 64
	s.value_changed.connect(func(v: float) -> void:
		readout.text = fmt % (v * scale)
		on_change.call(v))
	var box := hbox(UiTokens.S2)
	box.add_child(s)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(readout)
	return row(text, box)


static func check_row(text: String, value: bool, on_change: Callable, hint: String = "") -> HBoxContainer:
	var c := CheckButton.new()
	c.button_pressed = value
	c.toggled.connect(func(v: bool) -> void:
		Sfx.play_ui(c, "ui_click")
		on_change.call(v))
	return row(text, c, hint)


static func option_row(text: String, items: Array, selected: int, on_change: Callable) -> HBoxContainer:
	var o := OptionButton.new()
	for item: String in items:
		o.add_item(item)
	o.selected = selected
	o.item_selected.connect(func(i: int) -> void: on_change.call(i))
	return row(text, o)


# --- Ornament & iconography ---------------------------------------------------------------------

const ICON_PATH := "res://assets/third_party/game_icons/%s.svg"


## Gold ornamental rule (lozenge centre, fading ends).
static func divider(width: float = 360.0) -> TextureRect:
	var t := TextureRect.new()
	t.texture = UiTokens.tex("divider")
	t.custom_minimum_size = Vector2(width, 12)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


## game-icons.net glyph (CC BY 3.0) tinted `color`.
static func icon(name: String, size: float = 28.0, color: Color = UiTokens.GOLD) -> TextureRect:
	var t := TextureRect.new()
	t.texture = load(ICON_PATH % name)
	t.custom_minimum_size = Vector2(size, size)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.modulate = color
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


static func overline(text: String) -> Label:
	return label(text.to_upper(), "Overline")


## Screen title block: overline, serif title, ornamental rule.
static func title_block(kicker: String, title: String, width: float = 420.0) -> VBoxContainer:
	var v := vbox(UiTokens.S1)
	v.add_child(overline(kicker))
	v.add_child(label(title, "H1"))
	v.add_child(divider(width))
	return v


## Console-style hint bar: [glyph] action pairs along the bottom edge (GUI.md §7 keybind glyph).
static func hint_bar(pairs: Array) -> HBoxContainer:
	var h := hbox(UiTokens.S5)
	h.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	h.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	h.grow_vertical = Control.GROW_DIRECTION_BEGIN
	h.offset_right = -48
	h.offset_bottom = -32
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for p: Array in pairs:
		var item := hbox(UiTokens.S2)
		var key := PanelContainer.new()
		var box := StyleBoxFlat.new()
		box.bg_color = Color(0, 0, 0, 0.35)
		box.border_color = Color(UiTokens.GOLD, 0.7)
		box.set_border_width_all(1)
		box.set_corner_radius_all(3)
		box.content_margin_left = 7
		box.content_margin_right = 7
		box.content_margin_top = 1
		box.content_margin_bottom = 1
		key.add_theme_stylebox_override("panel", box)
		var k := label(p[0], "Overline")
		k.add_theme_color_override("font_color", UiTokens.TEXT_PRIMARY)
		key.add_child(k)
		item.add_child(key)
		item.add_child(label(p[1], "Muted"))
		h.add_child(item)
	return h
