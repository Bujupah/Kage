class_name ItemCard
extends Button
## Reusable cosmetic card (GUI.md §7 "item card", "rarity badge"). Rarity is shown by text, border
## and symbol, never colour alone (GUI.md §3).

const SYMBOLS: Array[String] = ["◇", "◈", "❖", "✦"]

var slot := ""
var item_id := ""

var _name := Label.new()
var _rarity := Label.new()
var _status := Label.new()


func setup(slot_name: String, id: String, status: String) -> ItemCard:
	slot = slot_name
	item_id = id
	var e := CosmeticCatalog.entry(slot, id)
	var r := int(e.get("rarity", 0))
	toggle_mode = true
	custom_minimum_size = Vector2(250, 84)
	focus_mode = Control.FOCUS_ALL
	var color: Color = CosmeticCatalog.RARITY_COLORS[r]
	# Lacquer-black card, hairline border in the rarity colour, a rarity strip along the top; the
	# selected card gains a gold frame and a soft glow.
	for state in ["normal", "hover", "pressed", "focus", "hover_pressed"]:
		var lit: bool = state != "normal"
		var picked: bool = state in ["pressed", "hover_pressed"]
		var box := StyleBoxFlat.new()
		box.bg_color = Color(0.035, 0.035, 0.045, 0.86) if not lit else Color(0.07, 0.065, 0.06, 0.92)
		box.border_color = UiTokens.GOLD if picked else Color(color, 0.85 if lit else 0.35)
		box.set_border_width_all(1)
		box.border_width_top = 3
		if picked:
			box.border_color = UiTokens.GOLD
			box.shadow_color = Color(UiTokens.GOLD, 0.22)
			box.shadow_size = 10
		box.set_corner_radius_all(2)
		box.content_margin_left = UiTokens.S4
		box.content_margin_right = UiTokens.S3
		box.content_margin_top = UiTokens.S2
		box.content_margin_bottom = UiTokens.S2
		add_theme_stylebox_override(state, box)
	var v := UiKit.vbox(0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = UiTokens.S4
	v.offset_top = UiTokens.S2
	v.offset_right = -UiTokens.S3
	add_child(v)
	_rarity.text = "%s %s" % [SYMBOLS[r], CosmeticCatalog.RARITY_NAMES[r].to_upper()]
	_rarity.theme_type_variation = "Overline"
	_rarity.add_theme_color_override("font_color", color)
	_name.text = e.get("name", id)
	_name.add_theme_font_override("font", UiTokens.display_font())
	_name.add_theme_font_size_override("font_size", UiTokens.scaled(20))
	_status.theme_type_variation = "Muted"
	for l: Label in [_rarity, _name, _status]:
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(l)
	set_status(status)
	pressed.connect(func() -> void: Sfx.play_ui(self, "ui_click"))
	focus_entered.connect(func() -> void: Sfx.play_ui(self, "ui_move"))
	return self


func set_status(text: String) -> void:
	_status.text = text


## "Owned", "Equipped" or the price, for store and armory cards.
static func status_for(slot_name: String, id: String) -> String:
	if PlayerProfile.appearance().get(slot_name) == id:
		return "Equipped"
	if PlayerProfile.owns(id):
		return "Owned"
	var e := CosmeticCatalog.entry(slot_name, id)
	return "%s %s" % ["◆" if e["currency"] == "jade" else "◎", PlayerCard._thousands(int(e["price"]))] + \
			(" Jade" if e["currency"] == "jade" else " Mon")
