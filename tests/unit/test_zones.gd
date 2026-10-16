extends TestCase
## Risk zones (ENVIRONMENT.md §1.3): the server-side map decides the rule, the simulation enforces
## it, snapshots carry it.

const KATANA := preload("res://data/weapons/katana_starter.tres")


func _duel(zone_a: int, zone_b: int) -> CombatSimulation:
	var sim := CombatSimulation.new()
	var a := sim.add(Combatant.new(1, 1, KATANA))
	a.facing = Vector3(0, 0, -1)
	a.zone = zone_a
	var b := sim.add(Combatant.new(2, 2, KATANA))
	b.position = Vector3(0, 0, -1.5)
	b.facing = Vector3(0, 0, 1)
	b.zone = zone_b
	return sim


func _swing(sim: CombatSimulation) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	events.append_array(sim.step({1: CombatIntent.make(CombatIntent.LIGHT)}))
	while sim.tick < 14:
		events.append_array(sim.step())
	return events


func _hits(events: Array[Dictionary]) -> int:
	return events.filter(func(e: Dictionary) -> bool: return e["type"] == &"hit").size()


func test_region_map_layout() -> void:
	assert_eq(RegionMap.rule_at(Vector3(0, 0, 0)), ZoneRule.ARENA_PROTECTED, "duel ring is the protected arena")
	assert_eq(RegionMap.rule_at(Vector3(0, 0, 40)), ZoneRule.SAFE_SANCTUARY, "village street")
	assert_eq(RegionMap.rule_at(Vector3(0, 0, -20)), ZoneRule.SAFE_SANCTUARY, "torii approach is a safe buffer")
	assert_eq(RegionMap.rule_at(Vector3(0, 0, -28)), ZoneRule.FRONTIER_PVP, "past the torii")
	assert_eq(RegionMap.region_name_at(Vector3(26, 0, -80)), "Abandoned Ruin", "ruin name")
	assert_eq(RegionMap.region_name_at(Vector3(0, 0, -58)), "Bamboo Clearing", "clearing name")
	for spawn: Array in ProvinceLevel.ARENA_SPAWNS:
		assert_eq(RegionMap.rule_at(spawn[0]), ZoneRule.ARENA_PROTECTED, "duel spawns stand in the arena")
	for spawn: Array in ProvinceLevel.SANCTUARY_SPAWNS:
		assert_eq(RegionMap.rule_at(spawn[0]), ZoneRule.SAFE_SANCTUARY, "players enter the world in the sanctuary")
	for camp: Dictionary in ProvinceLevel.NPC_CAMPS:
		assert_eq(RegionMap.rule_at(camp["home"]), ZoneRule.FRONTIER_PVP, "NPC camps are in the frontier")


func test_frontier_warning_and_safety_distance() -> void:
	assert_true(RegionMap.approaching_frontier(Vector3(0, 0, -24)), "warn just before the torii")
	assert_false(RegionMap.approaching_frontier(Vector3(0, 0, -15)), "no warning deeper in the buffer")
	assert_false(RegionMap.approaching_frontier(Vector3(0, 0, -30)), "already across")
	assert_eq(RegionMap.distance_to_safety(Vector3(0, 0, 40)), 0.0, "safe already")
	assert_true(absf(RegionMap.distance_to_safety(Vector3(0, 0, -37)) - 10.0) < 0.01, "10 m back to the torii")


func test_no_hostile_damage_in_sanctuary() -> void:
	var sim := _duel(ZoneRule.SAFE_SANCTUARY, ZoneRule.SAFE_SANCTUARY)
	var events := _swing(sim)
	assert_eq(_hits(events), 0, "no hit in the sanctuary")
	assert_eq(sim.find(2).stats.health, 100, "health untouched")
	assert_eq(sim.find(1).stats.stamina < 100, true, "the swing itself still happened")


func test_attack_into_or_out_of_sanctuary_is_blocked() -> void:
	assert_eq(_hits(_swing(_duel(ZoneRule.FRONTIER_PVP, ZoneRule.SAFE_SANCTUARY))), 0, "frontier attacker, safe target")
	assert_eq(_hits(_swing(_duel(ZoneRule.SAFE_SANCTUARY, ZoneRule.FRONTIER_PVP))), 0, "safe attacker, frontier target")


func test_arena_and_frontier_allow_duels() -> void:
	assert_eq(_hits(_swing(_duel(ZoneRule.ARENA_PROTECTED, ZoneRule.ARENA_PROTECTED))), 1, "arena duel")
	assert_eq(_hits(_swing(_duel(ZoneRule.FRONTIER_PVP, ZoneRule.FRONTIER_PVP))), 1, "frontier fight")
	assert_false(ZoneRule.drops_carried_loot(ZoneRule.ARENA_PROTECTED), "arena never drops loot")
	assert_true(ZoneRule.drops_carried_loot(ZoneRule.FRONTIER_PVP), "frontier rule drops carried loot")


func test_zone_is_replicated_and_validated() -> void:
	var c := Combatant.new(7, 1, KATANA)
	c.zone = ZoneRule.FRONTIER_PVP
	var rec := SnapshotCodec.encode_entity(c)
	var mirror := Combatant.new(7, 1, KATANA)
	mirror.zone = ZoneRule.SAFE_SANCTUARY
	SnapshotCodec.apply_combat_state(mirror, rec)
	assert_eq(mirror.zone, ZoneRule.FRONTIER_PVP, "client learns the authoritative zone")
	rec[SnapshotCodec.ZONE] = 99
	assert_false(SnapshotCodec.is_valid(rec), "unknown zone rejected")


func test_npcs_pick_targets_only_where_combat_is_legal() -> void:
	var home := Vector3(0, 0, -60)
	var near_frontier := {"id": 1, "position": Vector3(0, 0, -55), "zone": ZoneRule.FRONTIER_PVP, "alive": true}
	var near_safe := {"id": 2, "position": Vector3(0, 0, -57), "zone": ZoneRule.SAFE_SANCTUARY, "alive": true}
	var dead := {"id": 3, "position": Vector3(0, 0, -59), "zone": ZoneRule.FRONTIER_PVP, "alive": false}
	var far := {"id": 4, "position": Vector3(0, 0, -30), "zone": ZoneRule.FRONTIER_PVP, "alive": true}
	assert_eq(NpcDirector.choose_target(home, home, [near_safe, dead, near_frontier, far]), 1, "nearest legal target")
	assert_eq(NpcDirector.choose_target(home, home, [near_safe]), -1, "never chases into a sanctuary")
	assert_eq(NpcDirector.choose_target(home, home, [far]), -1, "outside aggro radius")
	assert_eq(NpcDirector.choose_target(home, home + Vector3(0, 0, 30), [near_frontier]), -1, "past the leash: go home")
