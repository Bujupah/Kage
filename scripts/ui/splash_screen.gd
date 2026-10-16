class_name SplashScreen
extends UiScreen
## BOOT-01/02: game mark rising out of ink. Short, skippable with any input, static under reduced
## motion. Never blocks anything: it only hands over to first-run or the title menu.

const SECONDS := 2.4

var _elapsed := 0.0
var _done := false
var _mark := UiKit.label("KAGE", "Title")
var _sub := UiKit.label("The Shrouded Province", "Muted")


func _init() -> void:
	super()
	closable = false


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.03, 0.035)
	UiKit.full_rect(bg)
	add_child(bg)
	var col := UiKit.vbox(UiTokens.S3)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	UiKit.full_rect(col)
	add_child(col)
	for l: Label in [_mark, _sub]:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(l)
	_mark.add_theme_constant_override("outline_size", 0)
	var hint := UiKit.label("Press any key", "Muted")
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.modulate.a = 0.5
	col.add_child(UiKit.spacer(40))
	col.add_child(hint)
	if GameSettings.reduced_motion():
		_mark.modulate.a = 1.0
	else:
		_mark.modulate.a = 0.0
		_sub.modulate.a = 0.0
		var tw := create_tween()
		tw.tween_property(_mark, "modulate:a", 1.0, 0.9).set_ease(Tween.EASE_OUT)
		tw.tween_property(_sub, "modulate:a", 1.0, 0.5)


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= SECONDS:
		_finish()


func _input(event: InputEvent) -> void:
	if _elapsed > 0.25 and (event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton) and event.is_pressed():
		get_viewport().set_input_as_handled()
		_finish()


func _finish() -> void:
	if _done:
		return
	_done = true
	if bool(GameSettings.get_value("meta", "first_run_done")):
		shell.show_main_menu()
	else:
		shell.replace(FirstRunScreen.new())
