class_name NpcDirector
extends RefCounted
## Server-side PvE (GDD PvPvE, ENVIRONMENT.md §5): spawns the bandit camps from ProvinceLevel,
## picks targets, drives each NPC with the same CombatIntent path a player uses (so they obey every
## rule the player does) and respawns them after a cooldown. NPCs never chase into sanctuaries and
## walk home when they lose their target or stray past their leash.

const FIRST_ENTITY_ID := 5000
const AGGRO_RADIUS := 13.0
const LEASH_RADIUS := 26.0
const RESPAWN_TICKS := CombatSimulation.TICK_RATE * 20
const HOME_TOLERANCE := 1.5

class Npc:
	var entity_id: int
	var display_name: String
	var home: Vector3
	var look: Dictionary
	var body: FighterBody
	var brain: DummyBrain
	var target_id := -1
	var dead_since := -1

var npcs: Array[Npc] = []


## Pure target choice: nearest living candidate inside the aggro radius that stands in a zone
## where hostile damage is legal, and only while the NPC is within its leash. Candidates are
## {id, position, zone, alive}. Returns -1 for "go home".
static func choose_target(home: Vector3, self_pos: Vector3, candidates: Array) -> int:
	if self_pos.distance_to(home) > LEASH_RADIUS:
		return -1
	var best := -1
	var best_d := AGGRO_RADIUS
	for c: Dictionary in candidates:
		if not c["alive"] or not ZoneRule.allows_hostile_damage(c["zone"]):
			continue
		var d := self_pos.distance_to(c["position"])
		if d < best_d and (c["position"] as Vector3).distance_to(home) <= LEASH_RADIUS:
			best_d = d
			best = c["id"]
	return best


## Creates every camp's NPC body. `make_body` builds and registers a FighterBody for
## (entity_id, team, spawn, facing, look) and returns it.
func spawn_all(make_body: Callable) -> void:
	var next_id := FIRST_ENTITY_ID
	for camp: Dictionary in ProvinceLevel.NPC_CAMPS:
		var n := Npc.new()
		n.entity_id = next_id
		next_id += 1
		n.display_name = camp["name"]
		n.home = camp["home"]
		n.look = CosmeticCatalog.sanitize(camp["look"])
		n.body = make_body.call(n.entity_id, NetProtocol.NPC_TEAM, n.home, Vector3.BACK, n.look)
		n.brain = DummyBrain.new(n.body, n.body)
		n.brain.mode = DummyBrain.Mode.DUELIST
		npcs.append(n)


## This tick's intents for every NPC, given the player bodies (entity_id -> FighterBody).
func intents(now: int, players: Dictionary) -> Dictionary:
	var out := {}
	var candidates := []
	for id: int in players:
		var b: FighterBody = players[id]
		candidates.append({"id": id, "position": b.global_position, "zone": b.combatant.zone, "alive": b.combatant.is_alive()})
	for n in npcs:
		if not n.body.combatant.is_alive():
			out[n.entity_id] = CombatIntent.new()
			continue
		var target := choose_target(n.home, n.body.global_position, candidates)
		if target != n.target_id:
			n.target_id = target
			if target >= 0:
				n.brain.target = players[target]
				n.brain.reset(now - 25) # Engage promptly instead of waiting a full decision cycle.
		if target >= 0:
			out[n.entity_id] = n.brain.sample_intent(now)
		else:
			out[n.entity_id] = _walk_home(n)
	return out


## Respawns NPCs that have been down long enough. Returns the respawned entity IDs.
func respawn_due(now: int) -> Array[int]:
	var back: Array[int] = []
	for n in npcs:
		var alive := n.body.combatant.is_alive()
		if alive:
			n.dead_since = -1
		elif n.dead_since < 0:
			n.dead_since = now
		elif now - n.dead_since >= RESPAWN_TICKS:
			n.dead_since = -1
			n.target_id = -1
			n.body.respawn(now)
			back.append(n.entity_id)
	return back


func _walk_home(n: Npc) -> CombatIntent:
	var intent := CombatIntent.new()
	var to := n.home - n.body.global_position
	to.y = 0.0
	if to.length() > HOME_TOLERANCE:
		intent.move = Vector2(to.x, to.z).normalized() * 0.6
	return intent
