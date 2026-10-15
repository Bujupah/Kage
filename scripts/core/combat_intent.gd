class_name CombatIntent
extends RefCounted
## One tick of player (or NPC) intent. Clients send intents, never results (MULTIPLAYER.md §2).
##
## `pressed` holds edge-triggered actions since the last tick; `held` holds continuous ones.
## `move` is the desired world-space XZ direction (length <= 1). `face_dir` is an optional
## facing hint (e.g. towards a lock-on target); the simulation applies its own turn-rate limits.

const LIGHT := 1
const HEAVY := 2
const GUARD := 4
const DODGE := 8
const SPRINT := 16

var sequence := 0
var move := Vector2.ZERO
var face_dir := Vector3.ZERO
var pressed := 0
var held := 0


static func make(pressed_bits: int = 0, held_bits: int = 0, move_dir: Vector2 = Vector2.ZERO) -> CombatIntent:
	var intent := CombatIntent.new()
	intent.pressed = pressed_bits
	intent.held = held_bits
	intent.move = move_dir
	return intent


func is_pressed(bit: int) -> bool:
	return (pressed & bit) != 0


func is_held(bit: int) -> bool:
	return (held & bit) != 0


## World-space movement direction, clamped so a tampered intent cannot request extra speed.
func move_world() -> Vector3:
	return Vector3(move.x, 0.0, move.y).limit_length(1.0)
