class_name SnapshotCodec
extends RefCounted
## Per-entity snapshot record (MULTIPLAYER.md §3 "WorldSnapshot"). Plain arrays of ints and floats;
## no objects or resources ever cross the wire.
##   [entity_id, x, y, z, facing_yaw, state, state_start_tick, state_duration, chain_index,
##    parry_until_tick, health, posture, stamina, spirit, attack_serial, life, zone]

enum { ID, X, Y, Z, YAW, STATE, STATE_START, STATE_DURATION, CHAIN, PARRY_UNTIL, HEALTH, POSTURE, STAMINA, SPIRIT, SERIAL, LIFE, ZONE, SIZE }

const FLOAT_FIELDS := [X, Y, Z, YAW]


static func encode_entity(c: Combatant) -> Array:
	var rec := []
	rec.resize(SIZE)
	rec[ID] = c.entity_id
	rec[X] = c.position.x
	rec[Y] = c.position.y
	rec[Z] = c.position.z
	rec[YAW] = atan2(c.facing.x, c.facing.z)
	rec[STATE] = c.state
	rec[STATE_START] = c.state_start_tick
	rec[STATE_DURATION] = c.state_duration
	rec[CHAIN] = c.chain_index
	rec[PARRY_UNTIL] = c.parry_until_tick()
	rec[HEALTH] = c.stats.health
	rec[POSTURE] = c.stats.posture
	rec[STAMINA] = c.stats.stamina
	rec[SPIRIT] = c.stats.spirit
	rec[SERIAL] = c.attack_serial
	rec[LIFE] = c.life
	rec[ZONE] = c.zone
	return rec


## Structural check for records arriving from the network; never index an unchecked array.
static func is_valid(rec: Variant) -> bool:
	if typeof(rec) != TYPE_ARRAY or (rec as Array).size() != SIZE:
		return false
	for i in SIZE:
		var v: Variant = rec[i]
		if i in FLOAT_FIELDS:
			if typeof(v) != TYPE_FLOAT or not is_finite(v):
				return false
		elif typeof(v) != TYPE_INT:
			return false
	return rec[STATE] >= 0 and rec[STATE] < Combatant.State.size() and ZoneRule.is_valid(rec[ZONE])


static func position_of(rec: Array) -> Vector3:
	return Vector3(rec[X], rec[Y], rec[Z])


static func facing_of(rec: Array) -> Vector3:
	return Vector3(sin(rec[YAW]), 0.0, cos(rec[YAW]))


## Mirrors combat state and resources onto a client-side Combatant. Position is left to the caller
## (reconciliation for the local fighter, interpolation for remote ones).
static func apply_combat_state(c: Combatant, rec: Array) -> void:
	c.apply_replicated_state(rec[STATE], rec[STATE_START], rec[STATE_DURATION], rec[CHAIN], rec[PARRY_UNTIL])
	c.stats.health = rec[HEALTH]
	c.stats.posture = rec[POSTURE]
	c.stats.stamina = rec[STAMINA]
	c.stats.spirit = rec[SPIRIT]
	c.attack_serial = rec[SERIAL]
	c.life = rec[LIFE]
	c.zone = rec[ZONE]
