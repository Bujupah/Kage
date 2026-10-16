class_name LoadingScreen
extends UiScreen
## LOAD-01 / HOME-10: honest join phases reported by NetClient, no fake percentage
## (GUI.md §5.1 step 5). Back cancels the attempt.

const PHASES: Array[String] = ["Connecting", "Authorizing", "Synchronizing world", "Ready"]

var _rows: Array[Label] = []
var _detail := UiKit.label("", "Muted", true)
var _tip := UiKit.label("", "Muted", true)

const TIPS: Array[String] = [
	"Tap guard just before a blow lands to parry; holding guard only blocks and wears your posture.",
	"A broken posture leaves a fighter open to a critical strike. Watch the gold bar.",
	"Dodges are invulnerable only at the start. The tail of a roll can be punished.",
	"The vermilion torii marks the frontier: beyond it, other players may attack you.",
	"Feint a heavy attack by guarding early in its windup. It costs stamina.",
]


func _ready() -> void:
	var col := UiKit.centered_panel(self, 560)
	col.add_child(UiKit.label("Entering the province", "H1"))
	for p in PHASES:
		var l := UiKit.label("·  " + p)
		l.modulate.a = 0.35
		_rows.append(l)
		col.add_child(l)
	col.add_child(_detail)
	col.add_child(UiKit.spacer(8))
	_tip.text = TIPS[randi() % TIPS.size()]
	col.add_child(_tip)
	col.add_child(UiKit.button("Cancel", func() -> void: shell.show_main_menu()))
	set_phase("Connecting", 0)


func set_phase(detail: String, step: int) -> void:
	for i in _rows.size():
		_rows[i].modulate.a = 1.0 if i <= step else 0.35
		_rows[i].text = ("✓  " if i < step else ("›  " if i == step else "·  ")) + PHASES[i]
	_detail.text = detail


func on_back() -> bool:
	shell.show_main_menu()
	return false
