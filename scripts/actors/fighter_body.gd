class_name FighterBody
extends CharacterBody3D
## Physical + visual shell around a Combatant. Movement legality comes from the Combatant's state;
## collision comes from Godot physics. The look is an AssassinModel (animated mannequin, katana,
## scarf) driven from the same state, keeping the readable tells: amber blade = light windup,
## red = heavy windup, white = parry window. The headless server builds no visuals at all.

const WALK_SPEED := 4.0
const SPRINT_SPEED := 6.5
const GUARD_SPEED := 1.8
const DODGE_SPEED := 8.5
const KNOCKBACK_SPEED := 2.5
const KNOCKBACK_TICKS := 5

const WORLD_LAYER := 1
const FIGHTER_LAYER := 2

const CORRECTION_DECAY := 0.6 ## Share of a network correction still visible after each tick.

var combatant: Combatant
var spawn_point := Vector3.ZERO
var spawn_facing := Vector3.FORWARD
var with_visuals := true ## False on the headless server: no meshes, animations or sounds.
var body_color := Color(0.16, 0.17, 0.2)
var accent_color := Color(0.62, 0.1, 0.08)
var appearance: Dictionary = {} ## Cosmetic IDs (CosmeticCatalog); empty = defaults.
var model: AssassinModel
var planar_speed := 0.0 ## m/s over the last presented tick (drives locomotion clips, footsteps).

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _correction_offset := Vector3.ZERO ## World-space visual lag behind the physics body.
var _last_presented_position := Vector3.ZERO
var _stride := 0.0
const STRIDE_METRES := 1.5 ## Distance between footstep sounds at a jog.


func setup(c: Combatant, color: Color, spawn: Vector3, face: Vector3, accent: Color = Color(0.62, 0.1, 0.08)) -> void:
	combatant = c
	spawn_point = spawn
	spawn_facing = face.normalized()
	body_color = color
	accent_color = accent


func _ready() -> void:
	collision_layer = FIGHTER_LAYER
	collision_mask = WORLD_LAYER | FIGHTER_LAYER
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.8
	shape.shape = capsule
	shape.position.y = 0.9
	add_child(shape)
	if with_visuals:
		model = AssassinModel.new()
		model.body_color = body_color
		model.accent_color = accent_color
		if not appearance.is_empty():
			model.appearance = CosmeticCatalog.sanitize(appearance)
		add_child(model)
	respawn(0)


func respawn(now: int) -> void:
	combatant.reset(now)
	global_position = spawn_point
	velocity = Vector3.ZERO
	combatant.facing = spawn_facing
	combatant.position = spawn_point
	rotation.y = atan2(-spawn_facing.x, -spawn_facing.z)
	_last_presented_position = spawn_point
	update_presentation(now)
	reset_physics_interpolation()


## Applies this tick's movement. Called between CombatSimulation.begin_tick() and end_tick().
func simulate_movement(intent: CombatIntent, now: int, delta: float) -> void:
	var c := combatant
	var wish := intent.move_world()
	var desired_velocity := Vector3.ZERO
	var desired_facing := intent.face_dir
	if desired_facing.length_squared() < 0.001 and wish.length() > 0.1:
		desired_facing = wish

	match c.state:
		Combatant.State.NEUTRAL:
			var sprinting := intent.is_held(CombatIntent.SPRINT) and wish.length() > 0.5
			desired_velocity = wish * (SPRINT_SPEED if sprinting else WALK_SPEED)
		Combatant.State.GUARD:
			desired_velocity = wish * GUARD_SPEED
		Combatant.State.ATTACK:
			if c.attack_phase(now) != Combatant.Phase.RECOVERY:
				var lunge_ticks := c.move.windup_ticks + c.move.active_ticks
				desired_velocity = c.facing * (c.move.lunge_distance / (lunge_ticks * delta))
		Combatant.State.DODGE:
			if c.elapsed(now) < Combatant.DODGE_MOVE_TICKS:
				desired_velocity = c.dodge_direction * DODGE_SPEED
			desired_facing = Vector3.ZERO
		Combatant.State.HITSTUN:
			if c.elapsed(now) < KNOCKBACK_TICKS:
				desired_velocity = c.knockback_direction * KNOCKBACK_SPEED

	if desired_facing.length_squared() > 0.001:
		c.facing = _rotate_toward(c.facing, desired_facing.normalized(), c.max_turn_rad_per_tick(now))

	velocity.x = desired_velocity.x
	velocity.z = desired_velocity.z
	velocity.y = 0.0 if is_on_floor() else velocity.y - _gravity * delta
	move_and_slide()
	c.position = global_position
	rotation.y = atan2(-c.facing.x, -c.facing.z)


## Keeps the visuals where they were drawn when reconciliation moves the body, then lets them catch
## up over a few ticks, so small prediction errors blend instead of popping. Cosmetic only.
func add_visual_correction(offset: Vector3) -> void:
	_correction_offset += offset


func clear_visual_correction() -> void:
	_correction_offset = Vector3.ZERO


## Once per simulation tick, after movement (or after a snapshot placed the body).
func update_presentation(now: int) -> void:
	var moved := global_position - _last_presented_position
	moved.y = 0.0
	_last_presented_position = global_position
	planar_speed = moved.length() * CombatSimulation.TICK_RATE if moved.length() < 2.0 else 0.0
	if model == null:
		return
	var c := combatant
	model.drive(c, now, planar_speed)
	if c.state == Combatant.State.NEUTRAL or c.state == Combatant.State.GUARD:
		_stride += planar_speed / CombatSimulation.TICK_RATE
		if _stride >= STRIDE_METRES:
			_stride = 0.0
			Sfx.play_at(self, "step_" + RegionMap.surface_at(global_position), global_position)
	match c.state:
		Combatant.State.HITSTUN:
			model.set_body_emission(Color(1, 0.3, 0.3), 1.2 if c.elapsed(now) < 3 else 0.0)
		Combatant.State.POSTURE_BROKEN:
			model.set_body_emission(Color(1, 0.85, 0.2), 0.4 + 0.4 * sin(now * 0.6))
		_:
			model.set_body_emission(Color.BLACK, 0.0)
	model.position = Vector3.ZERO
	if _correction_offset.length_squared() > 0.0001:
		model.position = global_basis.inverse() * _correction_offset
		_correction_offset *= CORRECTION_DECAY
	else:
		_correction_offset = Vector3.ZERO


static func _rotate_toward(from: Vector3, to: Vector3, max_rad: float) -> Vector3:
	var a := atan2(from.x, from.z)
	var b := atan2(to.x, to.z)
	var step := clampf(wrapf(b - a, -PI, PI), -max_rad, max_rad)
	return Vector3(sin(a + step), 0.0, cos(a + step))
