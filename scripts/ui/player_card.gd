class_name PlayerCard
extends VBoxContainer
## Top-right identity block on menu screens: name, title and wallet with currency marks, set on air
## (no box) with a gold rule, like a title card. The wallet is demo currency until the Go ledger
## lands, and says so on hover.

var _name := Label.new()
var _title := Label.new()
var _mon := Label.new()
var _jade := Label.new()


func _ready() -> void:
	anchor_left = 1.0
	anchor_right = 1.0
	offset_left = -440
	offset_right = -56
	offset_top = 44
	alignment = BoxContainer.ALIGNMENT_END
	add_theme_constant_override("separation", 2)
	mouse_filter = Control.MOUSE_FILTER_PASS
	_name.theme_type_variation = "H2"
	_name.add_theme_color_override("font_color", UiTokens.TEXT_PRIMARY)
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_name)
	_title.theme_type_variation = "Overline"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_title)
	var rule := UiKit.divider(380)
	rule.size_flags_horizontal = Control.SIZE_SHRINK_END
	add_child(rule)
	var wallet := UiKit.hbox(UiTokens.S2)
	wallet.alignment = BoxContainer.ALIGNMENT_END
	add_child(wallet)
	wallet.add_child(UiKit.icon("coins", 18, UiTokens.GOLD))
	wallet.add_child(_mon)
	wallet.add_child(UiKit.spacer(0))
	wallet.add_child(UiKit.icon("emerald", 18, Color("#7FC8A9")))
	wallet.add_child(_jade)
	for l: Label in [_mon, _jade]:
		l.add_theme_font_override("font", UiTokens.display_font())
		l.add_theme_font_size_override("font_size", UiTokens.scaled(20))
	tooltip_text = "Demo wallet: there are no real payments yet."
	PlayerProfile.bus.changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	_name.text = PlayerProfile.display_name()
	_title.text = PlayerProfile.title().to_upper()
	_mon.text = "%s Mon" % _thousands(PlayerProfile.balance("mon"))
	_jade.text = "%s Jade" % _thousands(PlayerProfile.balance("jade"))


static func _thousands(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.right(3) + out
		s = s.left(s.length() - 3)
	return ("-" if n < 0 else "") + s + out
