class_name MoveDefinition
extends Resource
## Authored data for one attack. Timings are simulation ticks (30 Hz baseline), never seconds,
## so client prediction and the authoritative server agree on frame data.

@export var move_id: StringName
@export_group("Timing (ticks)")
@export var windup_ticks := 9
@export var active_ticks := 3
@export var recovery_ticks := 12
@export_group("Effect")
@export var damage := 10
@export var posture_damage := 10
@export var stamina_cost := 10
@export var hitstun_ticks := 12
@export_group("Shape")
@export var reach := 2.0
@export var arc_degrees := 100.0
@export_group("Rules")
@export var guardable := true
@export var parryable := true
## Guard pressed before this many windup ticks cancels the attack (0 = cannot feint).
@export var feint_window_ticks := 0
@export var feint_stamina_cost := 10
## Light/heavy follow-ups may be buffered into this move's recovery.
@export var chainable := true
@export_group("Movement")
@export var lunge_distance := 0.5
## Maximum re-aim per tick during windup; active and recovery frames cannot turn at all.
@export var windup_tracking_deg := 6.0


func total_ticks() -> int:
	return windup_ticks + active_ticks + recovery_ticks


## Returns human-readable content errors; empty means valid.
func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if move_id == &"":
		errors.append("missing move_id")
	if windup_ticks < 1 or active_ticks < 1 or recovery_ticks < 0:
		errors.append("%s: windup/active must be >= 1 tick" % move_id)
	if damage < 0 or posture_damage < 0 or stamina_cost < 0:
		errors.append("%s: negative effect values" % move_id)
	if reach <= 0.0 or arc_degrees <= 0.0 or arc_degrees > 360.0:
		errors.append("%s: invalid shape" % move_id)
	if feint_window_ticks > windup_ticks:
		errors.append("%s: feint window longer than windup" % move_id)
	return errors
