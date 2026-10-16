class_name ZoneRule
extends RefCounted
## World-state taxonomy (ENVIRONMENT.md §1.3). The authoritative server decides which rule applies to
## each fighter from its server-side position (RegionMap) and replicates it; visuals and signage
## only announce it. P0 implements the combat consequence (no hostile damage in sanctuaries); the
## carried-loot consequence arrives with inventory in P2.

const SAFE_SANCTUARY := 0
const ARENA_PROTECTED := 1
const FRONTIER_PVP := 2
const LAWLESS_PVP := 3
const COUNT := 4

const NAMES: Array[String] = ["Sanctuary", "Protected Arena", "Frontier", "Lawless"]


static func is_valid(rule: int) -> bool:
	return rule >= 0 and rule < COUNT


## Whether hostile hits resolve while either party stands in this zone.
static func allows_hostile_damage(rule: int) -> bool:
	return rule != SAFE_SANCTUARY


## Whether a defeat here drops unsecured carried items (GDD death rule; no inventory yet in P1).
static func drops_carried_loot(rule: int) -> bool:
	return rule == FRONTIER_PVP or rule == LAWLESS_PVP


static func is_dangerous(rule: int) -> bool:
	return drops_carried_loot(rule)
