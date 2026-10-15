class_name CombatSimulation
extends RefCounted
## Fixed-tick authoritative combat loop. The headless region server will own one of these; the
## sandbox runs one locally. Movement happens between begin_tick() and end_tick() so physics bodies
## can move with Godot collision while every rule decision stays here.

const TICK_RATE := 30

var tick := 0
var combatants: Array[Combatant] = []
var _events: Array[Dictionary] = []


func add(c: Combatant) -> Combatant:
	combatants.append(c)
	return c


func find(entity_id: int) -> Combatant:
	for c in combatants:
		if c.entity_id == entity_id:
			return c
	return null


## Expires timed states, then applies this tick's intents (entity_id -> CombatIntent).
func begin_tick(intents: Dictionary) -> void:
	_events.clear()
	for c in combatants:
		c.update_timers(tick)
		var intent: CombatIntent = intents.get(c.entity_id)
		c.apply_intent(intent if intent != null else CombatIntent.new(), tick, _events)


## Resolves contacts, regenerates resources and returns the confirmed events for this tick.
func end_tick() -> Array[Dictionary]:
	_resolve_hits()
	for c in combatants:
		if c.is_alive():
			c.stats.regen(tick, c.is_guarding(), c.state != Combatant.State.POSTURE_BROKEN)
	var out: Array[Dictionary] = _events.duplicate()
	tick += 1
	return out


## Convenience for tests and headless scenarios without movement.
func step(intents: Dictionary = {}) -> Array[Dictionary]:
	begin_tick(intents)
	return end_tick()


func _resolve_hits() -> void:
	# Gather every contact from the same pre-resolution state first, so results never depend on
	# iteration order (two simultaneous swings trade instead of the first one cancelling the second).
	var contacts: Array[Array] = []
	for a in combatants:
		if not a.is_attack_active(tick):
			continue
		for t in combatants:
			if t == a or not t.is_alive() or t.team == a.team:
				continue
			if a.hit_targets.has(t.entity_id):
				continue
			if HitResolver.in_attack_volume(a, t, a.move):
				contacts.append([a, a.move, t])
	for contact in contacts:
		var a: Combatant = contact[0]
		var attack: MoveDefinition = contact[1]
		var t: Combatant = contact[2]
		if not t.is_alive():
			continue
		var ev := HitResolver.resolve(a, attack, t, tick)
		if ev["type"] == &"dodged":
			if a.dodged_targets.has(t.entity_id):
				continue
			a.dodged_targets[t.entity_id] = true
		else:
			a.hit_targets[t.entity_id] = true
		_events.append(ev)
