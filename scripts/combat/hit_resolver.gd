class_name HitResolver
extends RefCounted
## The single rule path for melee contact (ARCHITECTURE.md §6.4). Every weapon or ability hit goes
## through resolve(), so no move can bypass dodge, parry, guard, posture or death checks.

const HEIGHT_TOLERANCE := 1.8
const GUARD_COS_HALF_ANGLE := 0.2588 ## cos(75°): guard and parry only cover the front.

const PARRY_REFLECT_POSTURE := 1.0 ## Share of posture damage reflected onto a parried attacker.
const PARRY_DEFENDER_POSTURE := 0.25
const GUARD_STAMINA_PER_POSTURE := 0.5
const HIT_POSTURE := 0.5
const BROKEN_DAMAGE_MULT := 1.5

const SPIRIT_ON_PARRY := 15
const SPIRIT_ON_BREAK := 20
const SPIRIT_ON_HIT := 5


## Authoritative hit volume: a flat sector from the attacker's server-side position and facing.
static func in_attack_volume(attacker: Combatant, target: Combatant, attack: MoveDefinition) -> bool:
	var to := target.position - attacker.position
	if absf(to.y) > HEIGHT_TOLERANCE:
		return false
	to.y = 0.0
	var dist := to.length()
	if dist > attack.reach + target.radius:
		return false
	if dist < 0.001:
		return true
	var fwd := Vector3(attacker.facing.x, 0.0, attacker.facing.z)
	if fwd.length_squared() < 0.0001:
		return false
	var allowance := atan(target.radius / dist)
	return fwd.angle_to(to) <= deg_to_rad(attack.arc_degrees) * 0.5 + allowance


static func is_facing(defender: Combatant, attacker: Combatant) -> bool:
	var to := attacker.position - defender.position
	to.y = 0.0
	if to.length_squared() < 0.0001:
		return true
	var fwd := Vector3(defender.facing.x, 0.0, defender.facing.z).normalized()
	return fwd.dot(to.normalized()) >= GUARD_COS_HALF_ANGLE


## Resolves one contact and applies its effects to both combatants. Returns the confirmed event.
## `attack` is passed explicitly so simultaneous trades resolve even if the attacker was just
## interrupted by an earlier contact in the same tick.
static func resolve(attacker: Combatant, attack: MoveDefinition, defender: Combatant, now: int) -> Dictionary:
	var ev := {
		"tick": now,
		"attacker": attacker.entity_id,
		"target": defender.entity_id,
		"move": attack.move_id,
		"attack_serial": attacker.attack_serial,
	}
	var push := defender.position - attacker.position
	push.y = 0.0
	push = push.normalized() if push.length_squared() > 0.0001 else -defender.facing

	if defender.is_invulnerable(now):
		ev["type"] = &"dodged"
		return ev

	var front := is_facing(defender, attacker)

	if front and attack.parryable and defender.is_parrying(now):
		defender.stats.add_posture(int(attack.posture_damage * PARRY_DEFENDER_POSTURE), now)
		defender.stats.gain_spirit(SPIRIT_ON_PARRY)
		if attacker.stats.add_posture(int(attack.posture_damage * PARRY_REFLECT_POSTURE), now):
			attacker.apply_posture_break(now)
			ev["attacker_broken"] = true
		else:
			attacker.apply_hitstun(Combatant.PARRIED_STAGGER_TICKS, now, -push)
		ev["type"] = &"parried"
		return ev

	if front and attack.guardable and defender.is_guarding():
		var covered := defender.stats.drain_stamina(int(attack.posture_damage * GUARD_STAMINA_PER_POSTURE), now)
		var broke := defender.stats.add_posture(attack.posture_damage, now)
		if broke or not covered:
			defender.apply_posture_break(now)
			attacker.stats.gain_spirit(SPIRIT_ON_BREAK)
			ev["type"] = &"guard_broken"
		else:
			ev["type"] = &"guarded"
		return ev

	var was_broken := defender.state == Combatant.State.POSTURE_BROKEN
	var damage := attack.damage
	if was_broken:
		damage = int(round(damage * BROKEN_DAMAGE_MULT))
		ev["critical"] = true
	attacker.stats.gain_spirit(SPIRIT_ON_HIT)
	ev["type"] = &"hit"
	ev["damage"] = damage

	if defender.stats.take_damage(damage):
		defender.die(now)
		ev["killed"] = true
		return ev

	if was_broken:
		# The punish consumes the break: posture resets and the defender is merely staggered.
		defender.stats.posture = 0
		defender.apply_hitstun(attack.hitstun_ticks, now, push)
	elif defender.stats.add_posture(int(attack.posture_damage * HIT_POSTURE), now):
		defender.apply_posture_break(now)
		attacker.stats.gain_spirit(SPIRIT_ON_BREAK)
		ev["posture_broken"] = true
	else:
		defender.apply_hitstun(attack.hitstun_ticks, now, push)
	return ev
