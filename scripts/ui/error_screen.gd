class_name ErrorScreen
extends UiScreen
## LOAD-04 / BOOT-06: why the session ended and what the player can do. Reconnecting starts a new
## join; P1 has no session resume, so it never promises the old fighter state is kept.

var _title: String
var _reason: String
var _was_playing: bool


func _init(title: String = "Connection problem", reason: String = "", was_playing: bool = false) -> void:
	super()
	_title = title
	_reason = reason
	_was_playing = was_playing
	closable = false


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.03, 0.035, 0.92)
	UiKit.full_rect(bg)
	add_child(bg)
	var col := UiKit.centered_panel(self, 560)
	var t := UiKit.label(_title, "H1")
	t.add_theme_color_override("font_color", UiTokens.VERMILION.lightened(0.15))
	col.add_child(t)
	col.add_child(UiKit.label(_reason, "", true))
	if _was_playing:
		col.add_child(UiKit.label("Reconnecting starts a new session; your previous position and state are not resumed yet.", "Muted", true))
	var actions := UiKit.hbox()
	actions.add_child(UiKit.button("Main Menu", func() -> void: shell.show_main_menu()))
	var retry := UiKit.button("Reconnect" if _was_playing else "Retry", func() -> void: shell.retry_online())
	retry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(retry)
	col.add_child(actions)
