class_name DummyBrain
extends RefCounted
## Scripted training partner. It emits the same CombatIntents a human would, so it exercises the
## exact rule path the player does (and can later run server-side as simple NPC input).

enum Mode { PASSIVE, GUARD, ATTACK, DUELIST }
const MODE_NAMES: Array[String] = [
	"Passive (punching bag)",
	"Always guards (posture pressure)",
	"Attacks on rhythm (parry practice)",
	"Duelist (combos, heavies, feints, reactive guard)",
]
const ENGAGE_RANGE := 2.0

var mode: Mode = Mode.ATTACK
var body: FighterBody
var target: FighterBody

var _rng := RandomNumberGenerator.new()
var _plan: Array[Dictionary] = [] ## {tick: int, pressed: int}
var _next_decision_tick := 45
var _guard_until := -1
var _reacted_serial := -1


func _init(own_body: FighterBody, opponent: FighterBody) -> void:
	body = own_body
	target = opponent
	_rng.seed = 1337


func mode_name() -> String:
	return MODE_NAMES[mode]


func cycle_mode(now: int) -> void:
	mode = ((mode + 1) % Mode.size()) as Mode
	reset(now)


func reset(now: int) -> void:
	_plan.clear()
	_guard_until = -1
	_next_decision_tick = now + 30


func sample_intent(now: int) -> CombatIntent:
	var intent := CombatIntent.new()
	var me := body.combatant
	if not me.is_alive():
		return intent
	var to := target.global_position - body.global_position
	to.y = 0.0
	var dist := to.length()
	if dist > 0.01:
		intent.face_dir = to / dist
	var foe := target.combatant

	match mode:
		Mode.GUARD:
			intent.held |= CombatIntent.GUARD
			if me.state == Combatant.State.NEUTRAL:
				intent.pressed |= CombatIntent.GUARD
		Mode.ATTACK:
			_approach(intent, to, dist)
			if now >= _next_decision_tick and me.state == Combatant.State.NEUTRAL and dist <= ENGAGE_RANGE + 0.3:
				_plan.append({"tick": now, "pressed": CombatIntent.LIGHT})
				_next_decision_tick = now + 50 + _rng.randi_range(0, 40)
		Mode.DUELIST:
			_approach(intent, to, dist)
			_react(now, foe)
			if now >= _next_decision_tick and me.state == Combatant.State.NEUTRAL \
					and dist <= ENGAGE_RANGE + 0.3 and foe.is_alive():
				_choose_offence(now)

	for step in _plan:
		if step["tick"] == now:
			intent.pressed |= step["pressed"]
	_plan = _plan.filter(func(s: Dictionary) -> bool: return s["tick"] > now)
	if now < _guard_until:
		intent.held |= CombatIntent.GUARD
	return intent


func _approach(intent: CombatIntent, to: Vector3, dist: float) -> void:
	if dist > ENGAGE_RANGE and body.combatant.state == Combatant.State.NEUTRAL:
		intent.move = Vector2(to.x, to.z).normalized() * 0.7


## Guards against roughly 70% of the player's attacks, sometimes on parry timing.
func _react(now: int, foe: Combatant) -> void:
	if foe.attack_phase(now) != Combatant.Phase.WINDUP or foe.attack_serial == _reacted_serial:
		return
	_reacted_serial = foe.attack_serial
	if _rng.randf() > 0.7:
		return
	var until_active := foe.move.windup_ticks - foe.elapsed(now)
	var lead := _rng.randi_range(1, 6) # 1-4 ticks early parries; later leads just guard
	var press_tick := now + maxi(until_active - lead, 0)
	_plan.append({"tick": press_tick, "pressed": CombatIntent.GUARD})
	_guard_until = press_tick + 18
	_next_decision_tick = maxi(_next_decision_tick, press_tick + 20)


func _choose_offence(now: int) -> void:
	var roll := _rng.randf()
	if roll < 0.45: # light string
		_plan.append({"tick": now, "pressed": CombatIntent.LIGHT})
		_plan.append({"tick": now + 10, "pressed": CombatIntent.LIGHT})
		if _rng.randf() < 0.5:
			_plan.append({"tick": now + 21, "pressed": CombatIntent.LIGHT})
	elif roll < 0.75: # heavy
		_plan.append({"tick": now, "pressed": CombatIntent.HEAVY})
	else: # heavy feint into a quick light
		_plan.append({"tick": now, "pressed": CombatIntent.HEAVY})
		_plan.append({"tick": now + 6, "pressed": CombatIntent.GUARD})
		_plan.append({"tick": now + 13, "pressed": CombatIntent.LIGHT})
	_next_decision_tick = now + 55 + _rng.randi_range(0, 35)
