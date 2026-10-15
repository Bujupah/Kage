extends TestCase
## Rule tests for the authoritative combat core. Frame data comes from the real katana content:
## light_1 = windup 9, active 3 (ticks 9..11 when started on tick 0), recovery 12.

const KATANA := preload("res://data/weapons/katana_starter.tres")
const A := 1
const B := 2

const LIGHT := CombatIntent.LIGHT
const HEAVY := CombatIntent.HEAVY
const GUARD := CombatIntent.GUARD
const DODGE := CombatIntent.DODGE


## A at the origin facing -Z; B 1.5 m in front of A, facing back towards A.
func _duel(b_team: int = 2) -> CombatSimulation:
	var sim := CombatSimulation.new()
	var a := sim.add(Combatant.new(A, 1, KATANA))
	a.position = Vector3.ZERO
	a.facing = Vector3(0, 0, -1)
	var b := sim.add(Combatant.new(B, b_team, KATANA))
	b.position = Vector3(0, 0, -1.5)
	b.facing = Vector3(0, 0, 1)
	return sim


## Runs until sim.tick == until. `script` maps tick -> {entity_id: CombatIntent};
## `held` maps entity_id -> bits held on every tick.
func _run(sim: CombatSimulation, until: int, script: Dictionary = {}, held: Dictionary = {}) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	while sim.tick < until:
		var intents := {}
		for id in held:
			intents[id] = CombatIntent.make(0, held[id])
		var scripted: Dictionary = script.get(sim.tick, {})
		for id in scripted:
			var intent: CombatIntent = scripted[id]
			if held.has(id):
				intent.held |= held[id]
			intents[id] = intent
		events.append_array(sim.step(intents))
	return events


func _count(events: Array[Dictionary], type: StringName) -> int:
	return events.filter(func(e: Dictionary) -> bool: return e["type"] == type).size()


func _press(bits: int) -> CombatIntent:
	return CombatIntent.make(bits)


func test_attack_phases_follow_frame_data() -> void:
	var sim := _duel()
	var a := sim.find(A)
	sim.step({A: _press(LIGHT)})
	assert_eq(a.state, Combatant.State.ATTACK, "attack started")
	assert_eq(a.stats.stamina, 100 - KATANA.light_chain[0].stamina_cost, "stamina spent")
	assert_eq(a.attack_phase(8), Combatant.Phase.WINDUP, "tick 8 windup")
	assert_eq(a.attack_phase(9), Combatant.Phase.ACTIVE, "tick 9 active")
	assert_eq(a.attack_phase(11), Combatant.Phase.ACTIVE, "tick 11 active")
	assert_eq(a.attack_phase(12), Combatant.Phase.RECOVERY, "tick 12 recovery")
	_run(sim, 25)
	assert_eq(a.state, Combatant.State.NEUTRAL, "back to neutral after 24 ticks")


func test_hit_lands_once_across_active_frames() -> void:
	var sim := _duel()
	var b := sim.find(B)
	var events := _run(sim, 13, {0: {A: _press(LIGHT)}})
	assert_eq(_count(events, &"hit"), 1, "one hit event despite 3 active ticks")
	assert_eq(b.stats.health, 88, "light damage applied once")
	assert_eq(b.stats.posture, 7, "half posture on clean hit")
	assert_eq(b.state, Combatant.State.HITSTUN, "defender staggered")


func test_out_of_reach_misses() -> void:
	var sim := _duel()
	sim.find(B).position = Vector3(0, 0, -4.0)
	var events := _run(sim, 13, {0: {A: _press(LIGHT)}})
	assert_eq(_count(events, &"hit"), 0, "no hit beyond reach")
	assert_eq(sim.find(B).stats.health, 100, "health untouched")


func test_outside_arc_misses() -> void:
	var sim := _duel()
	sim.find(B).position = Vector3(1.8, 0, 0.3) # beside and slightly behind A
	_run(sim, 13, {0: {A: _press(LIGHT)}})
	assert_eq(sim.find(B).stats.health, 100, "sector check rejects targets beside/behind")


func test_held_guard_blocks_after_parry_window() -> void:
	var sim := _duel()
	var b := sim.find(B)
	# Guard pressed on tick 0 -> parry window 0..4, expired well before the tick-9 hit.
	var events := _run(sim, 10, {0: {A: _press(LIGHT), B: _press(GUARD)}}, {B: GUARD})
	assert_eq(_count(events, &"guarded"), 1, "guarded event")
	assert_eq(b.stats.health, 100, "no chip damage")
	assert_eq(b.stats.posture, 15, "full posture damage on guard")
	assert_eq(b.stats.stamina, 93, "guard costs stamina")


func test_timed_parry_staggers_attacker() -> void:
	var sim := _duel()
	var a := sim.find(A)
	var b := sim.find(B)
	var events := _run(sim, 10, {0: {A: _press(LIGHT)}, 7: {B: _press(GUARD)}}, {})
	assert_eq(_count(events, &"parried"), 1, "parried event")
	assert_eq(a.state, Combatant.State.HITSTUN, "attacker staggered")
	assert_eq(a.stats.posture, 15, "posture reflected onto attacker")
	assert_eq(b.stats.health, 100, "defender unharmed")
	assert_eq(b.stats.spirit, HitResolver.SPIRIT_ON_PARRY, "parry builds Spirit")


func test_tap_parry_commits_for_whole_window() -> void:
	var sim := _duel()
	var b := sim.find(B)
	# Tap (press without hold) on tick 6: window 6..10 must survive the release to catch tick 9.
	var events := _run(sim, 10, {0: {A: _press(LIGHT)}, 6: {B: _press(GUARD)}})
	assert_eq(_count(events, &"parried"), 1, "tapped parry still parries")
	_run(sim, 12)
	assert_eq(b.state, Combatant.State.NEUTRAL, "guard drops once window ends and button is up")


func test_parry_mashing_gets_no_window() -> void:
	var sim := _duel()
	# Tap on tick 0, press-and-hold again on tick 7: within PARRY_REARM_TICKS, so no fresh window.
	var events := _run(sim, 10, {
		0: {A: _press(LIGHT), B: _press(GUARD)},
		7: {B: CombatIntent.make(GUARD, GUARD)},
		8: {B: CombatIntent.make(0, GUARD)},
		9: {B: CombatIntent.make(0, GUARD)},
	})
	assert_eq(_count(events, &"parried"), 0, "mashed press does not parry")
	assert_eq(_count(events, &"guarded"), 1, "but still guards")


func test_attack_from_behind_ignores_guard() -> void:
	var sim := _duel()
	var b := sim.find(B)
	b.facing = Vector3(0, 0, -1) # back turned to A
	_run(sim, 10, {0: {A: _press(LIGHT), B: _press(GUARD)}}, {B: GUARD})
	assert_eq(b.stats.health, 88, "guard only covers the front")


func test_dodge_iframes_avoid_hit() -> void:
	var sim := _duel()
	var b := sim.find(B)
	var events := _run(sim, 13, {0: {A: _press(LIGHT)}, 8: {B: _press(DODGE)}})
	assert_eq(b.stats.health, 100, "i-frames cover the active window")
	assert_eq(_count(events, &"dodged"), 1, "dodge reported once per attack")


func test_late_dodge_is_hit() -> void:
	var sim := _duel()
	var b := sim.find(B)
	_run(sim, 13, {0: {A: _press(LIGHT)}, 9: {B: _press(DODGE)}})
	assert_eq(b.stats.health, 88, "dodge start frame is vulnerable")
	assert_eq(b.state, Combatant.State.HITSTUN, "dodge interrupted")


func test_guard_break_opens_critical_punish() -> void:
	var sim := _duel()
	var b := sim.find(B)
	b.stats.add_posture(90, 0)
	var events := _run(sim, 10, {0: {A: _press(LIGHT), B: _press(GUARD)}}, {B: GUARD})
	assert_eq(_count(events, &"guard_broken"), 1, "guard broken")
	assert_eq(b.state, Combatant.State.POSTURE_BROKEN, "defender broken")
	# A recovers on tick 24 and attacks again; active on tick 33, inside the 45-tick break.
	events = _run(sim, 34, {24: {A: _press(LIGHT)}}, {B: GUARD})
	var hits := events.filter(func(e: Dictionary) -> bool: return e["type"] == &"hit")
	assert_eq(hits.size(), 1, "punish lands")
	assert_true(hits[0].get("critical", false), "punish is critical")
	assert_eq(b.stats.health, 100 - 18, "critical damage x1.5")
	assert_eq(b.stats.posture, 0, "punish consumes the break")


func test_posture_recovers_after_break_window() -> void:
	var sim := _duel()
	var b := sim.find(B)
	b.stats.add_posture(90, 0)
	_run(sim, 10, {0: {A: _press(LIGHT), B: _press(GUARD)}}, {B: GUARD})
	_run(sim, 9 + Combatant.POSTURE_BREAK_TICKS + 1)
	assert_eq(b.state, Combatant.State.NEUTRAL, "break expires")
	assert_eq(b.stats.posture, 0, "posture resets after break")


func test_feint_cancels_windup_for_stamina() -> void:
	var sim := _duel()
	var a := sim.find(A)
	var events := _run(sim, 6, {0: {A: _press(HEAVY)}, 5: {A: _press(GUARD)}})
	assert_eq(_count(events, &"feint"), 1, "feint event")
	assert_eq(a.state, Combatant.State.GUARD, "feint drops into guard")
	assert_eq(a.stats.stamina, 100 - 28 - 12, "heavy cost + feint cost")
	_run(sim, 30)
	assert_eq(sim.find(B).stats.health, 100, "feinted attack never lands")


func test_feint_after_window_is_ignored() -> void:
	var sim := _duel()
	var a := sim.find(A)
	_run(sim, 13, {0: {A: _press(HEAVY)}, 12: {A: _press(GUARD)}})
	assert_eq(a.state, Combatant.State.ATTACK, "committed past the feint window")


func test_light_chain_buffers_into_next_move() -> void:
	var sim := _duel()
	var a := sim.find(A)
	sim.find(B).position = Vector3(0, 0, -10) # keep the target out of the way
	_run(sim, 13, {0: {A: _press(LIGHT)}, 10: {A: _press(LIGHT)}})
	assert_eq(a.move, KATANA.light_chain[1], "buffered press chains on first recovery tick")
	assert_eq(a.chain_index, 1, "chain index")
	assert_eq(a.state_start_tick, 12, "chain starts when recovery begins")


func test_stale_buffer_expires() -> void:
	var sim := _duel()
	var a := sim.find(A)
	sim.find(B).position = Vector3(0, 0, -10)
	# Pressed on tick 3, more than INPUT_BUFFER_TICKS before recovery starts on tick 12.
	_run(sim, 25, {0: {A: _press(LIGHT)}, 3: {A: _press(LIGHT)}})
	assert_eq(a.state, Combatant.State.NEUTRAL, "early press did not chain")


func test_insufficient_stamina_blocks_actions() -> void:
	var sim := _duel()
	var a := sim.find(A)
	a.stats.stamina = 5
	sim.step({A: _press(LIGHT)})
	assert_eq(a.state, Combatant.State.NEUTRAL, "no attack without stamina")
	sim.step({A: _press(DODGE)})
	assert_eq(a.state, Combatant.State.NEUTRAL, "no dodge without stamina")


func test_lethal_hit_kills_and_freezes() -> void:
	var sim := _duel()
	var b := sim.find(B)
	b.stats.health = 5
	var events := _run(sim, 10, {0: {A: _press(LIGHT)}})
	assert_eq(b.state, Combatant.State.DEAD, "defender dead")
	assert_true(events.any(func(e: Dictionary) -> bool: return e.get("killed", false)), "kill flagged")
	sim.step({B: _press(LIGHT)})
	assert_eq(b.state, Combatant.State.DEAD, "dead combatants ignore input")


func test_same_team_cannot_damage() -> void:
	var sim := _duel(1)
	_run(sim, 13, {0: {A: _press(LIGHT)}})
	assert_eq(sim.find(B).stats.health, 100, "party friendly fire off")


func test_simultaneous_swings_trade() -> void:
	var sim := _duel()
	_run(sim, 10, {0: {A: _press(LIGHT), B: _press(LIGHT)}})
	assert_eq(sim.find(A).stats.health, 88, "A hit")
	assert_eq(sim.find(B).stats.health, 88, "B hit: order-independent resolution")


func test_tampered_move_vector_is_clamped() -> void:
	var intent := CombatIntent.make(0, 0, Vector2(50, 0))
	assert_true(is_equal_approx(intent.move_world().length(), 1.0), "move intent clamped to unit length")


func test_windup_tracking_is_limited() -> void:
	var sim := _duel()
	var a := sim.find(A)
	sim.step({A: _press(LIGHT)})
	assert_eq(a.max_turn_rad_per_tick(5), deg_to_rad(KATANA.light_chain[0].windup_tracking_deg), "windup tracking")
	assert_eq(a.max_turn_rad_per_tick(10), 0.0, "active frames cannot turn")


func test_simulation_is_deterministic() -> void:
	var script := {
		0: {A: _press(LIGHT)}, 7: {B: _press(GUARD)}, 30: {B: _press(HEAVY)},
		40: {A: _press(DODGE)}, 60: {A: _press(LIGHT)}, 70: {A: _press(LIGHT)}, 75: {B: _press(DODGE)},
	}
	var results: Array[String] = []
	for i in 2:
		var sim := _duel()
		var events := _run(sim, 120, script.duplicate(true))
		var a := sim.find(A)
		var b := sim.find(B)
		results.append("%s|%d,%d,%d|%d,%d,%d" % [
			str(events.map(func(e: Dictionary) -> String: return "%d:%s" % [e["tick"], e["type"]])),
			a.stats.health, a.stats.stamina, a.stats.posture,
			b.stats.health, b.stats.stamina, b.stats.posture,
		])
	assert_eq(results[0], results[1], "same inputs -> same outcome")
