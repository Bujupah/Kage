class_name CreditsScreen
extends UiScreen
## MENU-07: contributors and every third-party asset with its license, read from the generated
## assets/third_party/CREDITS.md so the screen never drifts from what ships.

const CREDITS := "res://assets/third_party/CREDITS.md"


func _ready() -> void:
	var center := CenterContainer.new()
	UiKit.full_rect(center)
	add_child(center)
	var p := UiKit.panel(860)
	p.custom_minimum_size.y = 600
	center.add_child(p)
	var col := UiKit.vbox(UiTokens.S3)
	p.add_child(col)
	col.add_child(UiKit.label("Credits", "H1"))
	col.add_child(UiKit.label("Built with Godot Engine (MIT license, godotengine.org/license).", "Muted", true))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	var list := UiKit.vbox(UiTokens.S1)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	for entry in parse_credits(FileAccess.get_file_as_string(CREDITS)):
		var line := UiKit.label("%s — %s" % [entry["asset"], entry["use"]], "", true)
		list.add_child(line)
		var src := UiKit.label(entry["source"], "Muted", true)
		list.add_child(src)
	col.add_child(UiKit.label("Art, audio and animation: CC0 1.0 unless marked. Sketchfab models: CC BY 4.0. Icons: CC BY 3.0 (game-icons.net). Fonts (Inter, Cormorant Garamond, Yuji Boku): SIL Open Font License 1.1.", "Muted", true))
	col.add_child(UiKit.button("Back", func() -> void: shell.pop()))


## Rows of the markdown table in CREDITS.md -> [{asset, source, use}].
static func parse_credits(text: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for line in text.split("\n"):
		if not line.begins_with("| ") or line.begins_with("| Folder") or line.begins_with("|---"):
			continue
		var cells := line.split("|")
		if cells.size() >= 5:
			out.append({"asset": cells[2].strip_edges(), "source": cells[3].strip_edges(), "use": cells[4].strip_edges()})
	return out
