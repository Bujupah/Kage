class_name CombatStats
extends RefCounted
## The four combat resources (GDD §5). Integers only, so client and server never drift on floats.

const STAMINA_REGEN_DELAY_TICKS := 20
const POSTURE_RECOVERY_DELAY_TICKS := 40

var max_health := 100
var max_stamina := 100
var max_posture := 100
var max_spirit := 100

var health := 100
var stamina := 100
## Accumulated pressure: 0 is fresh, reaching max_posture breaks the guard.
var posture := 0
var spirit := 0

var _last_stamina_spend_tick := -100000
var _last_posture_damage_tick := -100000


func reset() -> void:
	health = max_health
	stamina = max_stamina
	posture = 0
	spirit = 0
	_last_stamina_spend_tick = -100000
	_last_posture_damage_tick = -100000


## Spends only if the full amount is available.
func try_spend_stamina(amount: int, now: int) -> bool:
	if stamina < amount:
		return false
	stamina -= amount
	_last_stamina_spend_tick = now
	return true


## Spends what is available; returns false if the amount could not be fully covered.
func drain_stamina(amount: int, now: int) -> bool:
	var covered := stamina >= amount
	stamina = maxi(stamina - amount, 0)
	_last_stamina_spend_tick = now
	return covered


## Returns true when posture reaches the break threshold.
func add_posture(amount: int, now: int) -> bool:
	posture = mini(posture + amount, max_posture)
	_last_posture_damage_tick = now
	return posture >= max_posture


## Returns true when this damage is lethal.
func take_damage(amount: int) -> bool:
	health = maxi(health - amount, 0)
	return health == 0


func gain_spirit(amount: int) -> void:
	spirit = clampi(spirit + amount, 0, max_spirit)


func regen(now: int, guarding: bool, can_recover_posture: bool) -> void:
	if now - _last_stamina_spend_tick >= STAMINA_REGEN_DELAY_TICKS:
		# Guarding halves stamina recovery so turtling has a cost.
		if not guarding or now % 2 == 0:
			stamina = mini(stamina + 1, max_stamina)
	if can_recover_posture and now - _last_posture_damage_tick >= POSTURE_RECOVERY_DELAY_TICKS:
		posture = maxi(posture - 1, 0)
