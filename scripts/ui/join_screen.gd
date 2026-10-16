class_name JoinScreen
extends UiScreen
## HOME-07 + AUTH-01 (stub): saved province servers and a display name. There is no real sign-in
## until the Go login service lands in P2, and the screen says so instead of pretending.

var _name := LineEdit.new()
var _address := LineEdit.new()
var _list := ItemList.new()
var _error := UiKit.label("", "Muted", true)


func _ready() -> void:
	var col := UiKit.centered_panel(self, 620)
	col.add_child(UiKit.label("Enter the Province", "H1"))
	col.add_child(UiKit.label("Local sign-in (development): other players see this name. Accounts arrive with the login service.", "Muted", true))
	_name.placeholder_text = "Display name"
	_name.max_length = PeerRegistry.MAX_NAME_LENGTH
	_name.text = str(GameSettings.get_value("network", "player_name"))
	col.add_child(UiKit.row("Name", _name))
	col.add_child(UiKit.spacer(4))
	col.add_child(UiKit.label("Province servers", "H2"))
	_list.custom_minimum_size.y = 150
	_list.item_activated.connect(func(_i: int) -> void: _join())
	col.add_child(_list)
	_address.placeholder_text = "host:port"
	var add_row := UiKit.hbox()
	_address.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_row.add_child(_address)
	add_row.add_child(UiKit.button("Add", _add))
	add_row.add_child(UiKit.button("Remove", _remove))
	col.add_child(add_row)
	_error.add_theme_color_override("font_color", UiTokens.VERMILION)
	col.add_child(_error)
	var actions := UiKit.hbox()
	actions.add_child(UiKit.button("Back", func() -> void: shell.pop()))
	var join := UiKit.button("Join", _join)
	join.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(join)
	col.add_child(actions)
	col.add_child(UiKit.label("Population and ping are not shown yet: the server directory is a P4 service.", "Muted", true))
	_reload()


func _reload() -> void:
	_list.clear()
	for s: String in GameSettings.get_value("network", "servers"):
		_list.add_item(s)
	if _list.item_count > 0:
		_list.select(0)


func _add() -> void:
	var parsed := parse_address(_address.text)
	if parsed.is_empty():
		_error.text = "Enter an address like 127.0.0.1:%d" % NetProtocol.DEFAULT_PORT
		Sfx.play_ui(self, "ui_error")
		return
	var servers: Array = (GameSettings.get_value("network", "servers") as Array).duplicate()
	var entry := "%s:%d" % [parsed["host"], parsed["port"]]
	if not servers.has(entry):
		servers.append(entry)
	GameSettings.set_value("network", "servers", servers)
	_address.text = ""
	_error.text = ""
	_reload()


func _remove() -> void:
	var sel := _list.get_selected_items()
	if sel.is_empty():
		return
	var servers: Array = (GameSettings.get_value("network", "servers") as Array).duplicate()
	servers.erase(_list.get_item_text(sel[0]))
	GameSettings.set_value("network", "servers", servers)
	_reload()


func _join() -> void:
	var sel := _list.get_selected_items()
	if sel.is_empty():
		_error.text = "Pick or add a server first."
		Sfx.play_ui(self, "ui_error")
		return
	var parsed := parse_address(_list.get_item_text(sel[0]))
	var display := PeerRegistry.sanitize_name(_name.text, "")
	GameSettings.set_value("network", "player_name", display)
	shell.start_online(parsed["host"], parsed["port"], display)


## "host" or "host:port" -> {host, port}; {} when unusable.
static func parse_address(text: String) -> Dictionary:
	var t := text.strip_edges()
	if t.is_empty() or t.contains(" "):
		return {}
	var host := t
	var port := NetProtocol.DEFAULT_PORT
	var colon := t.rfind(":")
	if colon > 0:
		host = t.substr(0, colon)
		var p := t.substr(colon + 1)
		if not p.is_valid_int() or int(p) < 1 or int(p) > 65535:
			return {}
		port = int(p)
	return {"host": host, "port": port}
