class_name ArmoryScreen
extends UiScreen
## META-02 wardrobe: change armour lacquer, blade finish and scarf on your own samurai with live
## preview. Previews are labelled until equipped (GUI.md §10 rule 7); locked items link to the Store.
## Cosmetics carry no stats (3DMODELS.md §0).

var _slot := "outfit"
var _preview: Dictionary = {}
var _grid := GridContainer.new()
var _detail_name := Label.new()
var _detail_blurb := Label.new()
var _detail_state := Label.new()
var _equip := Button.new()
var _selected := ""
var _tabs := HBoxContainer.new()


func _ready() -> void:
	_preview = PlayerProfile.appearance()
	if shell.stage != null:
		shell.stage.frame("armory")
	var drag := StageDragArea.new()
	drag.shell = shell
	add_child(drag)
	add_child(_side_shade())

	var panel := VBoxContainer.new()
	panel.add_theme_constant_override("separation", UiTokens.S3)
	panel.position = Vector2(72, 64)
	panel.custom_minimum_size = Vector2(560, 0)
	add_child(panel)
	panel.add_child(UiKit.label("Armory", "H1"))
	panel.add_child(UiKit.label("Cosmetic only: appearance never changes reach, damage or defence.", "Muted"))
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
	panel.add_child(_grid)
	var detail := PanelContainer.new()
	detail.theme_type_variation = "Pill"
	panel.add_child(detail)
	var dv := UiKit.vbox(UiTokens.S1)
	detail.add_child(dv)
	_detail_name.theme_type_variation = "H2"
	dv.add_child(_detail_name)
	_detail_blurb.theme_type_variation = "Muted"
	_detail_blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dv.add_child(_detail_blurb)
	dv.add_child(_detail_state)
	var actions := UiKit.hbox()
	actions.add_child(UiKit.button("Back", func() -> void: shell.pop()))
	_equip = UiKit.button("Equip", _on_equip, "PrimaryButton")
	_equip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(_equip)
	panel.add_child(actions)
	add_child(PlayerCard.new())
	_show_slot("outfit")


func _exit_tree() -> void:
	# Leaving without equipping drops the preview (only committed looks persist).
	if shell != null and shell.stage != null:
		shell.stage.model.apply_appearance(PlayerProfile.appearance())


func _show_slot(slot: String) -> void:
	_slot = slot
	for b: Button in _tabs.get_children():
		b.button_pressed = b.name == slot
	if shell.stage != null:
		shell.stage.frame("blade" if slot == "blade" else "armory")
	for c in _grid.get_children():
		c.queue_free()
	var first := ""
	for id: String in CosmeticCatalog.SLOTS[slot]:
		var card := ItemCard.new().setup(slot, id, ItemCard.status_for(slot, id) if PlayerProfile.owns(id) else "Locked · in Store")
		card.pressed.connect(func() -> void: _select(id))
		_grid.add_child(card)
		if first.is_empty() or PlayerProfile.appearance()[slot] == id:
			first = id
	_select(first)


func _select(id: String) -> void:
	_selected = id
	for c in _grid.get_children():
		if c is ItemCard:
			(c as ItemCard).button_pressed = (c as ItemCard).item_id == id
	var e := CosmeticCatalog.entry(_slot, id)
	_detail_name.text = e.get("name", id)
	_detail_blurb.text = e.get("blurb", "")
	var owned := PlayerProfile.owns(id)
	var equipped: bool = PlayerProfile.appearance()[_slot] == id
	_preview[_slot] = id
	if shell.stage != null:
		shell.stage.model.apply_appearance(_preview)
	if equipped:
		_detail_state.text = "Equipped"
	elif owned:
		_detail_state.text = "Previewing: not equipped yet"
	else:
		_detail_state.text = "Previewing a Store item: not owned"
	_detail_state.add_theme_color_override("font_color", UiTokens.SAFE if equipped else UiTokens.GOLD)
	_equip.text = ("Equipped" if equipped else ("Equip" if owned else "View in Store")).to_upper()
	_equip.disabled = equipped


func _on_equip() -> void:
	if not PlayerProfile.owns(_selected):
		shell.push(StoreScreen.new(_slot, _selected))
		return
	if PlayerProfile.equip(_slot, _selected):
		Sfx.play_ui(self, "ui_confirm")
		if shell.stage != null:
			shell.stage.flourish()
		_show_slot(_slot)


func _side_shade() -> Control:
	var grad := Gradient.new()
	grad.set_color(0, Color(0.02, 0.02, 0.03, 0.9))
	grad.set_color(1, Color(0.02, 0.02, 0.03, 0.0))
	grad.set_offset(1, 0.6)
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
