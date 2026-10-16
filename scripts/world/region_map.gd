class_name RegionMap
extends RefCounted
## Authoritative layout data for the Shrouded Province greybox slice (ENVIRONMENT.md §1, §13 P0).
## Pure data and lookups, no nodes: the server derives each fighter's ZoneRule from this, the client
## reads the same table only for names, compass landmarks and footstep surfaces.
##
## Coordinates are metres in the XZ plane; -Z is north.
##   Lantern Village (sanctuary) .... south, z 13..80, pagoda landmark at the far end
##   Training Dojo (protected arena)  courtyard around the origin; the duel ring is at (0, 0)
##   Gate approach (sanctuary buffer) z -27..-13, ends at the vermilion boundary torii
##   Bamboo Road (frontier PvP) ..... north of the torii: grove, duel clearing, abandoned ruin

const BOUNDS := Rect2(-40, -100, 80, 182) ## Walkable extent; walls stand just outside.
const BOUNDARY_TORII_Z := -27.0
const WARNING_START_Z := -19.0 ## Pre-entry warning begins this far before the torii.

## First match wins. [rect (x, z, w, d), rule, name]
const ZONES := [
	[Rect2(-16, -13, 32, 26), ZoneRule.ARENA_PROTECTED, "Training Dojo"],
	[Rect2(-22, 13, 44, 69), ZoneRule.SAFE_SANCTUARY, "Lantern Village"],
	[Rect2(-12, -27, 24, 14), ZoneRule.SAFE_SANCTUARY, "Torii Approach"],
]
const DEFAULT_RULE := ZoneRule.FRONTIER_PVP

## Named frontier areas (names only; the rule stays FRONTIER_PVP). [rect, name]
const AREAS := [
	[Rect2(-10, -67, 20, 18), "Bamboo Clearing"],
	[Rect2(12, -94, 28, 28), "Abandoned Ruin"],
]
const DEFAULT_AREA := "Bamboo Road"

## Compass landmarks: [name, position].
const LANDMARKS := [
	["Training Dojo", Vector3(0, 0, 0)],
	["Lantern Village", Vector3(0, 0, 42)],
	["Pagoda", Vector3(0, 0, 74)],
	["Frontier Torii", Vector3(0, 0, -27)],
	["Bamboo Clearing", Vector3(0, 0, -58)],
	["Abandoned Ruin", Vector3(26, 0, -80)],
]

## Footstep surfaces: [rect, surface]; default "concrete" (packed earth and stone).
const SURFACES := [
	[Rect2(-15.5, -8, 6, 16), "wood"], # dojo veranda
	[Rect2(-40, -100, 80, 73), "grass"], # everything north of the torii
]


static func rule_at(position: Vector3) -> int:
	var p := Vector2(position.x, position.z)
	for zone: Array in ZONES:
		if (zone[0] as Rect2).has_point(p):
			return zone[1]
	return DEFAULT_RULE


static func region_name_at(position: Vector3) -> String:
	var p := Vector2(position.x, position.z)
	for zone: Array in ZONES:
		if (zone[0] as Rect2).has_point(p):
			return zone[2]
	for area: Array in AREAS:
		if (area[0] as Rect2).has_point(p):
			return area[1]
	return DEFAULT_AREA


static func surface_at(position: Vector3) -> String:
	var p := Vector2(position.x, position.z)
	for s: Array in SURFACES:
		if (s[0] as Rect2).has_point(p):
			return s[1]
	return "concrete"


## True on the safe side of the boundary torii, close enough that the danger warning should show.
static func approaching_frontier(position: Vector3) -> bool:
	return rule_at(position) == ZoneRule.SAFE_SANCTUARY and position.z < WARNING_START_Z \
			and position.z >= BOUNDARY_TORII_Z


## Metres to the nearest sanctuary edge (for "distance to safe return"); 0 when already safe.
static func distance_to_safety(position: Vector3) -> float:
	if rule_at(position) != DEFAULT_RULE:
		return 0.0
	var p := Vector2(position.x, position.z)
	var best := INF
	for zone: Array in ZONES:
		if zone[1] == ZoneRule.SAFE_SANCTUARY or zone[1] == ZoneRule.ARENA_PROTECTED:
			var r: Rect2 = zone[0]
			var closest := Vector2(clampf(p.x, r.position.x, r.end.x), clampf(p.y, r.position.y, r.end.y))
			best = minf(best, p.distance_to(closest))
	return best
