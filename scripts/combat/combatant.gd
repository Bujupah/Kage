class_name Combatant
extends RefCounted
## Authoritative combat state for one fighter.
##
## Pure rules: no nodes, no rendering, no wall clock. Every timer is a simulation tick, so the same
## code runs in local prediction and on the headless region server (MULTIPLAYER.md §4).
## Movement is applied by the owning body; this class only says what movement is legal.

enum State { NEUTRAL, ATTACK, GUARD, DODGE, HITSTUN, POSTURE_BROKEN, DEAD }
enum Phase { NONE, WINDUP, ACTIVE, RECOVERY }

const PARRY_WINDOW_TICKS := 5 ## ~167 ms at 30 Hz, opened by a fresh guard press.
const PARRY_REARM_TICKS := 15 ## Guard presses closer together than this open no window (anti-mash).
const DODGE_TICKS := 15
const DODGE_IFRAME_FROM := 1
const DODGE_IFRAME_TO := 8 ## Exclusive: i-frames are bounded, the tail of a dodge is punishable.
const DODGE_MOVE_TICKS := 10
const DODGE_STAMINA_COST := 25
const INPUT_BUFFER_TICKS := 6
const POSTURE_BREAK_TICKS := 45 ## Punish window after a guard/posture break.
const PARRIED_STAGGER_TICKS := 20
const FREE_TURN_RAD_PER_TICK := 0.6

var entity_id: int
var team: int
var weapon: WeaponDefinition
var stats := CombatStats.new()

var state: State = State.NEUTRAL
var state_start_tick := 0
var state_duration := 0
var move: MoveDefinition ## Current attack; null outside State.ATTACK.
var chain_index := 0 ## Index into weapon.light_chain; -1 for the heavy attack.
var attack_serial := 0 ## Increments per attack instance; scopes hit de-duplication.
var life := 0 ## Increments on every reset/respawn, so observers can tell a respawn from movement.
var zone := ZoneRule.FRONTIER_PVP ## Set by the owner of the world map from the server position.
var hit_targets: Dictionary = {} ## entity_id -> true for the current attack instance.
var dodged_targets: Dictionary = {}

var position := Vector3.ZERO
var facing := Vector3.FORWARD
var radius := 0.4
var dodge_direction := Vector3.ZERO
var knockback_direction := Vector3.ZERO

var _move_input := Vector3.ZERO
var _last_guard_press_tick := -100000
var _parry_until_tick := -1
var _buffered_action := 0
var _buffered_tick := -100000


func _init(id: int, team_id: int, weapon_def: WeaponDefinition) -> void:
	entity_id = id
	team = team_id
	weapon = weapon_def


func reset(now: int) -> void:
	life += 1
	stats.reset()
	move = null
	chain_index = 0
	hit_targets.clear()
	dodged_targets.clear()
	_parry_until_tick = -1
	_buffered_action = 0
	_last_guard_press_tick = -100000
	_enter(State.NEUTRAL, now)


# --- Queries -------------------------------------------------------------------------------------

func elapsed(now: int) -> int:
	return now - state_start_tick


func is_alive() -> bool:
	return state != State.DEAD


func attack_phase(now: int) -> Phase:
	if state != State.ATTACK or move == null:
		return Phase.NONE
	var t := elapsed(now)
	if t < move.windup_ticks:
		return Phase.WINDUP
	if t < move.windup_ticks + move.active_ticks:
		return Phase.ACTIVE
	return Phase.RECOVERY


func is_attack_active(now: int) -> bool:
	return attack_phase(now) == Phase.ACTIVE


func is_guarding() -> bool:
	return state == State.GUARD


func is_parrying(now: int) -> bool:
	return state == State.GUARD and now < _parry_until_tick


func is_invulnerable(now: int) -> bool:
	if state != State.DODGE:
		return false
	var t := elapsed(now)
	return t >= DODGE_IFRAME_FROM and t < DODGE_IFRAME_TO


## Turn-rate limit: attacks commit to a direction, which is what makes them dodgeable.
func max_turn_rad_per_tick(now: int) -> float:
	match state:
		State.NEUTRAL, State.GUARD:
			return FREE_TURN_RAD_PER_TICK
		State.ATTACK:
			if attack_phase(now) == Phase.WINDUP:
				return deg_to_rad(move.windup_tracking_deg)
	return 0.0


func parry_until_tick() -> int:
	return _parry_until_tick


# --- Replication (clients mirror server state; they never derive outcomes) -----------------------

## Overwrites the observable state with values from a server snapshot. `chain` picks the attack
## (-1 = heavy) and is ignored outside State.ATTACK.
func apply_replicated_state(next: State, start_tick: int, duration: int, chain: int, parry_until: int) -> void:
	state = next
	state_start_tick = start_tick
	state_duration = duration
	_parry_until_tick = parry_until
	chain_index = chain
	move = null
	if next == State.ATTACK:
		if chain < 0:
			move = weapon.heavy
		elif chain < weapon.light_chain.size():
			move = weapon.light_chain[chain]
		if move == null:
			state = State.NEUTRAL


# --- Tick entry points (called by CombatSimulation) ----------------------------------------------

func update_timers(now: int) -> void:
	match state:
		State.ATTACK:
			if elapsed(now) >= move.total_ticks():
				move = null
				chain_index = 0
				_enter(State.NEUTRAL, now)
		State.DODGE:
			if elapsed(now) >= DODGE_TICKS:
				_enter(State.NEUTRAL, now)
		State.HITSTUN:
			if elapsed(now) >= state_duration:
				_enter(State.NEUTRAL, now)
		State.POSTURE_BROKEN:
			if elapsed(now) >= state_duration:
				stats.posture = 0
				_enter(State.NEUTRAL, now)


func apply_intent(intent: CombatIntent, now: int, events: Array[Dictionary]) -> void:
	if state == State.DEAD:
		return
	_move_input = intent.move_world()

	var guard_pressed := intent.is_pressed(CombatIntent.GUARD)
	var guard_held := guard_pressed or intent.is_held(CombatIntent.GUARD)
	var rearmed := now - _last_guard_press_tick >= PARRY_REARM_TICKS
	if guard_pressed:
		_last_guard_press_tick = now
		_buffered_action = 0 # A fresh defensive press overrides stale buffered offence.
	_buffer(intent, now)

	match state:
		State.NEUTRAL:
			if not _consume_buffer(now, events) and guard_held:
				_enter_guard(now, guard_pressed and rearmed)
		State.GUARD:
			if guard_pressed and rearmed:
				_parry_until_tick = now + PARRY_WINDOW_TICKS
			# A parry attempt commits for its whole window, even if the button was only tapped.
			if now >= _parry_until_tick:
				if not guard_held:
					_enter(State.NEUTRAL, now)
				_consume_buffer(now, events)
		State.ATTACK:
			match attack_phase(now):
				Phase.WINDUP:
					if guard_pressed and elapsed(now) < move.feint_window_ticks \
							and stats.try_spend_stamina(move.feint_stamina_cost, now):
						events.append({"type": &"feint", "tick": now, "attacker": entity_id, "move": move.move_id})
						move = null
						chain_index = 0
						_enter_guard(now, rearmed)
				Phase.RECOVERY:
					_try_chain(now, events)


# --- Effects applied by HitResolver --------------------------------------------------------------

func apply_hitstun(ticks: int, now: int, from_direction: Vector3) -> void:
	if state == State.DEAD:
		return
	move = null
	chain_index = 0
	knockback_direction = from_direction
	_enter(State.HITSTUN, now)
	state_duration = ticks


func apply_posture_break(now: int) -> void:
	if state == State.DEAD:
		return
	move = null
	chain_index = 0
	stats.posture = stats.max_posture
	_enter(State.POSTURE_BROKEN, now)
	state_duration = POSTURE_BREAK_TICKS


func die(now: int) -> void:
	move = null
	chain_index = 0
	_buffered_action = 0
	_enter(State.DEAD, now)


# --- Internals -----------------------------------------------------------------------------------

func _enter(next: State, now: int) -> void:
	state = next
	state_start_tick = now
	state_duration = 0


func _enter_guard(now: int, with_parry_window: bool) -> void:
	_enter(State.GUARD, now)
	_parry_until_tick = now + PARRY_WINDOW_TICKS if with_parry_window else -1


func _buffer(intent: CombatIntent, now: int) -> void:
	var action := 0
	if intent.is_pressed(CombatIntent.DODGE):
		action = CombatIntent.DODGE
	elif intent.is_pressed(CombatIntent.HEAVY):
		action = CombatIntent.HEAVY
	elif intent.is_pressed(CombatIntent.LIGHT):
		action = CombatIntent.LIGHT
	if action != 0:
		_buffered_action = action
		_buffered_tick = now


func _buffer_live(now: int) -> bool:
	return _buffered_action != 0 and now - _buffered_tick <= INPUT_BUFFER_TICKS


func _consume_buffer(now: int, events: Array[Dictionary]) -> bool:
	if not _buffer_live(now):
		_buffered_action = 0
		return false
	match _buffered_action:
		CombatIntent.DODGE:
			if stats.try_spend_stamina(DODGE_STAMINA_COST, now):
				_buffered_action = 0
				dodge_direction = _move_input.normalized() if _move_input.length() > 0.2 else -facing
				_enter(State.DODGE, now)
				events.append({"type": &"dodge_start", "tick": now, "attacker": entity_id})
				return true
		CombatIntent.LIGHT:
			if not weapon.light_chain.is_empty():
				return _start_attack(weapon.light_chain[0], 0, now, events)
		CombatIntent.HEAVY:
			if weapon.heavy != null:
				return _start_attack(weapon.heavy, -1, now, events)
	return false


func _try_chain(now: int, events: Array[Dictionary]) -> void:
	if not _buffer_live(now) or not move.chainable:
		return
	if _buffered_action == CombatIntent.LIGHT and chain_index >= 0 \
			and chain_index + 1 < weapon.light_chain.size():
		_start_attack(weapon.light_chain[chain_index + 1], chain_index + 1, now, events)
	elif _buffered_action == CombatIntent.HEAVY and weapon.heavy != null:
		_start_attack(weapon.heavy, -1, now, events)


func _start_attack(def: MoveDefinition, index: int, now: int, events: Array[Dictionary]) -> bool:
	if not stats.try_spend_stamina(def.stamina_cost, now):
		return false
	_buffered_action = 0
	move = def
	chain_index = index
	attack_serial += 1
	hit_targets.clear()
	dodged_targets.clear()
	_enter(State.ATTACK, now)
	events.append({"type": &"attack_start", "tick": now, "attacker": entity_id, "move": def.move_id})
	return true
