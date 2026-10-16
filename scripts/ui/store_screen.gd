class_name StoreScreen
extends UiScreen
## SHOP-01/02/03 cosmetic store with 3D try-on on your own assassin (GUI.md §5.6). Cosmetics only,
## no combat power. There is no payment provider yet: purchases spend the demo wallet, the banner
## says so, and real purchases will be server-verified receipts (never client-reported).

var _focus_slot := ""
var _focus_id := ""
var _slot := "outfit"
var _grid := GridContainer.new()
var _tabs := HBoxContainer.new()
var _name := Label.new()
var _blurb := Label.new()
var _price := Label.new()
var _buy := Button.new()
var _selected := ""
var _preview: Dictionary = {}


func _init(focus_slot: String = "", focus_id: String = "") -> void:
	super()
	_focus_slot = focus_slot
	_focus_id = focus_id


func _ready() -> void:
	_preview = PlayerProfile.appearance()
	if shell.stage != null:
		shell.stage.frame("store")
	var drag := StageDragArea.new()
	drag.shell = shell
	add_child(drag)
	add_child(_shade())

	var panel := VBoxContainer.new()
	panel.add_theme_constant_override("separation", UiTokens.S3)
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.offset_left = -640
	panel.offset_right = -60
	panel.offset_top = 150
	add_child(panel)
	panel.add_child(UiKit.label("Store", "H1"))
	var notice := UiKit.label("Preview store: demo currency, no real payments. Cosmetics never change combat stats.", "Muted", true)
	notice.add_theme_color_override("font_color", UiTokens.GOLD)
	panel.add_child(notice)
	_tabs.add_theme_constant_override("separation", UiTokens.S2)
	panel.add_child(_tabs)
	for slot: String in CosmeticCatalog.SLOTS:
		var b := UiKit.button(CosmeticCatalog.SLOT_NAMES[slot], func() -> void: _show_slot(slot))
		b.toggle_mode = true
		b.name = slot
		_tabs.add_child(b)
	_grid.columns = 2
	_grid.add_theme_constant_override("h_separation", UiTokens.S2)
	_grid.add_theme_constant_override("v_separation", UiTokens.S2)
	# Cards scroll inside a fixed band so long catalogues never push the detail panel off screen.
	var grid_scroll := ScrollContainer.new()
	grid_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	grid_scroll.custom_minimum_size.y = 312
	grid_scroll.follow_focus = true
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid_scroll.add_child(_grid)
	panel.add_child(grid_scroll)
	var detail := PanelContainer.new()
	detail.theme_type_variation = "Pill"
	panel.add_child(detail)
	var dv := UiKit.vbox(UiTokens.S1)
	detail.add_child(dv)
	_name.theme_type_variation = "H2"
	dv.add_child(_name)
	_blurb.theme_type_variation = "Muted"
	_blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dv.add_child(_blurb)
	dv.add_child(_price)
	var actions := UiKit.hbox()
	actions.add_child(UiKit.button("Back", func() -> void: shell.pop()))
	_buy = UiKit.button("Buy", _on_buy, "PrimaryButton")
	_buy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(_buy)
	panel.add_child(actions)
	add_child(PlayerCard.new())
	_show_slot(_focus_slot if CosmeticCatalog.SLOTS.has(_focus_slot) else "outfit")


func _exit_tree() -> void:
	if shell != null and shell.stage != null:
		shell.stage.model.apply_appearance(PlayerProfile.appearance())


func _show_slot(slot: String) -> void:
	_slot = slot
	for b: Button in _tabs.get_children():
		b.button_pressed = b.name == slot
	for c in _grid.get_children():
		c.queue_free()
	var first := ""
	for id: String in CosmeticCatalog.SLOTS[slot]:
		if CosmeticCatalog.is_free(slot, id):
			continue # Starter items are granted, not sold.
		var card := ItemCard.new().setup(slot, id, ItemCard.status_for(slot, id))
		card.pressed.connect(func() -> void: _select(id))
		_grid.add_child(card)
		if first.is_empty() or id == _focus_id:
			first = id
	_select(first)


func _select(id: String) -> void:
	_selected = id
	for c in _grid.get_children():
		if c is ItemCard:
			(c as ItemCard).button_pressed = (c as ItemCard).item_id == id
	var e := CosmeticCatalog.entry(_slot, id)
	_name.text = e.get("name", id)
	_blurb.text = CosmeticCatalog.describe(_slot, id)
	_preview = PlayerProfile.appearance()
	_preview[_slot] = id
	if shell.stage != null:
		shell.stage.model.apply_appearance(_preview)
		shell.stage.frame("blade" if _slot == "blade" else "store")
	var owned := PlayerProfile.owns(id)
	_price.text = "Owned" if owned else ItemCard.status_for(_slot, id)
	_buy.text = ("Owned · equip in Armory" if owned else "Buy").to_upper()
	_buy.disabled = owned


func _on_buy() -> void:
	var e := CosmeticCatalog.entry(_slot, _selected)
	var dialog := ConfirmationDialog.new()
	dialog.title = "Confirm purchase"
	dialog.dialog_text = "%s\n%s\n\nDemo currency: no real money is charged." % [e.get("name", ""), ItemCard.status_for(_slot, _selected)]
	dialog.ok_button_text = "Buy"
	add_child(dialog)
	dialog.confirmed.connect(func() -> void:
		var err := PlayerProfile.purchase(_slot, _selected)
		if err.is_empty():
			Sfx.play_ui(self, "ui_confirm")
			shell.toast("%s added to your Armory." % e.get("name", ""), UiTokens.SAFE)
			_show_slot(_slot)
		else:
			Sfx.play_ui(self, "ui_error")
			shell.toast(err, UiTokens.VERMILION)
		dialog.queue_free())
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered()


func _shade() -> Control:
	var grad := Gradient.new()
	grad.set_color(0, Color(0.02, 0.02, 0.03, 0.0))
	grad.set_color(1, Color(0.02, 0.02, 0.03, 0.9))
	grad.set_offset(0, 0.4)
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill_from = Vector2(0, 0.5)
	tex.fill_to = Vector2(1, 0.5)
	var rect := TextureRect.new()
	rect.texture = tex
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	UiKit.full_rect(rect)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect
