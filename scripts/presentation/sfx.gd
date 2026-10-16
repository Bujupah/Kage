class_name Sfx
extends RefCounted
## Sound cues (CC0 Kenney packs). Every combat cue plays from a *confirmed* event or a replicated
## state change, never from a local guess (3DMODELS.md §10 rule 3). Audio is the accessible backup
## for visual tells (FX-004: parry has its own unmistakable ring).

const IMPACT := "res://assets/third_party/kenney_impact_sounds/Audio/%s_%03d.ogg"
const RPG := "res://assets/third_party/kenney_rpg_audio/Audio/%s.ogg"
const UI := "res://assets/third_party/kenney_interface_sounds/Audio/%s_%03d.ogg"

## cue -> [bus, volume_db, files...]
const CUES := {
	"swing": ["Combat", -6.0, "rpg:knifeSlice", "rpg:knifeSlice2"],
	"hit": ["Combat", -2.0, "impact:impactPunch_medium:5"],
	"hit_heavy": ["Combat", 0.0, "impact:impactPunch_heavy:5"],
	"guard": ["Combat", -3.0, "impact:impactMetal_medium:5"],
	"parry": ["Combat", 0.0, "impact:impactBell_heavy:5"],
	"guard_break": ["Combat", 0.0, "impact:impactPlate_heavy:5"],
	"dodge": ["Combat", -8.0, "rpg:cloth1", "rpg:cloth2", "rpg:cloth3", "rpg:cloth4"],
	"draw": ["Combat", -6.0, "rpg:drawKnife1", "rpg:drawKnife2", "rpg:drawKnife3"],
	"step_concrete": ["Combat", -18.0, "impact:footstep_concrete:5"],
	"step_grass": ["Combat", -16.0, "impact:footstep_grass:5"],
	"step_wood": ["Combat", -16.0, "impact:footstep_wood:5"],
	"ui_move": ["UI", -14.0, "ui:tick:5"],
	"ui_click": ["UI", -8.0, "ui:click:5"],
	"ui_back": ["UI", -8.0, "ui:back:4"],
	"ui_confirm": ["UI", -6.0, "ui:confirmation:4"],
	"ui_error": ["UI", -6.0, "ui:error:8"],
	"ui_warning": ["UI", -4.0, "ui:question:4"],
}

static var _cache: Dictionary = {}


static func streams(cue: String) -> Array[AudioStream]:
	if _cache.has(cue):
		return _cache[cue]
	var out: Array[AudioStream] = []
	var def: Array = CUES.get(cue, [])
	for i in range(2, def.size()):
		var spec: PackedStringArray = String(def[i]).split(":")
		match spec[0]:
			"rpg":
				out.append(load(RPG % spec[1]))
			"impact", "ui":
				for n in int(spec[2]):
					var path := (IMPACT if spec[0] == "impact" else UI) % [spec[1], n + 1 if spec[0] == "ui" else n]
					if ResourceLoader.exists(path):
						out.append(load(path))
	_cache[cue] = out
	return out


## Positional one-shot at `at`; frees itself when done. No-op on a headless server.
static func play_at(parent: Node, cue: String, at: Vector3, pitch_jitter: float = 0.08) -> void:
	if DisplayServer.get_name() == "headless" or parent == null or not parent.is_inside_tree():
		return
	var choices := streams(cue)
	if choices.is_empty():
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = choices[randi() % choices.size()]
	p.bus = StringName(CUES[cue][0])
	p.volume_db = CUES[cue][1]
	p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	p.unit_size = 6.0
	parent.add_child(p)
	p.global_position = at
	p.finished.connect(p.queue_free)
	p.play()


## Non-positional (UI) one-shot.
static func play_ui(parent: Node, cue: String) -> void:
	if DisplayServer.get_name() == "headless" or parent == null or not parent.is_inside_tree():
		return
	var choices := streams(cue)
	if choices.is_empty():
		return
	var p := AudioStreamPlayer.new()
	p.stream = choices[randi() % choices.size()]
	p.bus = StringName(CUES[cue][0])
	p.volume_db = CUES[cue][1]
	p.process_mode = Node.PROCESS_MODE_ALWAYS
	parent.add_child(p)
	p.finished.connect(p.queue_free)
	p.play()


## Confirmed combat event -> cue.
static func for_event(ev: Dictionary) -> String:
	match ev["type"]:
		&"attack_start":
			return "swing"
		&"hit":
			return "hit_heavy" if ev.get("critical", false) or ev.get("killed", false) else "hit"
		&"guarded":
			return "guard"
		&"parried":
			return "parry"
		&"guard_broken":
			return "guard_break"
		&"dodge_start", &"feint":
			return "dodge"
		&"round_reset", &"respawned":
			return "draw"
	return ""
