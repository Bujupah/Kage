class_name FighterBody
extends CharacterBody3D
## Physical + visual shell around a Combatant. Movement legality comes from the Combatant's state;
## collision comes from Godot physics. Visuals are placeholder geometry built in code, tuned for
## readable tells: amber blade = light windup, red = heavy windup, white = parry window.

const WALK_SPEED := 4.0
const SPRINT_SPEED := 6.5
const GUARD_SPEED := 1.8
const DODGE_SPEED := 8.5
const KNOCKBACK_SPEED := 2.5
const KNOCKBACK_TICKS := 5

const WORLD_LAYER := 1
const FIGHTER_LAYER := 2

# Sword pivot poses (Euler degrees). Positive X raises the tip; Y swings it across the body.
const POSE_REST := Vector3(-25, 15, 0)
const POSE_GUARD := Vector3(15, 75, 20)
const POSE_LIGHT_WINDUP := Vector3(70, -45, 0)
const POSE_HEAVY_WINDUP := Vector3(110, -20, 0)
const POSE_SWING_END := Vector3(-35, 80, 0)
const POSE_BROKEN := Vector3(-70, 10, 0)

const GLOW_LIGHT := Color(1.0, 0.65, 0.15)
const GLOW_HEAVY := Color(1.0, 0.15, 0.1)
const GLOW_PARRY := Color(0.9, 0.95, 1.0)
const CORRECTION_DECAY := 0.6 ## Share of a network correction still visible after each tick.

var combatant: Combatant
var spawn_point := Vector3.ZERO
var spawn_facing := Vector3.FORWARD

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _visual := Node3D.new()
var _sword_pivot := Node3D.new()
var _body_mat := StandardMaterial3D.new()
var _sword_mat := StandardMaterial3D.new()
var _correction_offset := Vector3.ZERO ## World-space visual lag behind the physics body.


func setup(c: Combatant, color: Color, spawn: Vector3, face: Vector3) -> void:
	combatant = c
	spawn_point = spawn
	spawn_facing = face.normalized()
	_body_mat.albedo_color = color
	_body_mat.roughness = 0.8


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
	add_child(_visual)
	_build_visuals()
	respawn(0)


func respawn(now: int) -> void:
	combatant.reset(now)
	global_position = spawn_point
	velocity = Vector3.ZERO
	combatant.facing = spawn_facing
	combatant.position = spawn_point
	rotation.y = atan2(-spawn_facing.x, -spawn_facing.z)
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


func update_presentation(now: int) -> void:
	var c := combatant
	var pose := POSE_REST
	var glow := Color.BLACK
	var glow_energy := 0.0
	var body_glow := Color.BLACK
	_visual.rotation = Vector3.ZERO
	_visual.position = Vector3.ZERO

	match c.state:
		Combatant.State.GUARD:
			pose = POSE_GUARD
			if c.is_parrying(now):
				glow = GLOW_PARRY
				glow_energy = 3.0
		Combatant.State.ATTACK:
			var m := c.move
			var heavy := c.chain_index < 0
			var mirror := Vector3(1, -1, -1) if c.chain_index == 1 else Vector3.ONE
			var windup_pose := (POSE_HEAVY_WINDUP if heavy else POSE_LIGHT_WINDUP) * mirror
			var t := float(c.elapsed(now))
			match c.attack_phase(now):
				Combatant.Phase.WINDUP:
					var k := t / m.windup_ticks
					pose = POSE_REST.lerp(windup_pose, ease(k, 0.4))
					glow = GLOW_HEAVY if heavy else GLOW_LIGHT
					glow_energy = lerpf(0.5, 4.0 if heavy else 2.5, k)
				Combatant.Phase.ACTIVE:
					var k := (t - m.windup_ticks + 1.0) / m.active_ticks
					pose = windup_pose.lerp(POSE_SWING_END * mirror, k)
					glow = GLOW_HEAVY
					glow_energy = 5.0
				Combatant.Phase.RECOVERY:
					var k := (t - m.windup_ticks - m.active_ticks) / maxf(m.recovery_ticks, 1.0)
					pose = (POSE_SWING_END * mirror).lerp(POSE_REST, ease(k, 2.0))
		Combatant.State.DODGE:
			_visual.position.y = -0.25
			_visual.scale = Vector3(1.0, 0.8, 1.0)
		Combatant.State.HITSTUN:
			if c.elapsed(now) < 3:
				body_glow = Color(1, 0.3, 0.3)
			_visual.rotation.x = deg_to_rad(10)
		Combatant.State.POSTURE_BROKEN:
			pose = POSE_BROKEN
			body_glow = Color(1, 0.85, 0.2) * (0.5 + 0.5 * sin(now * 0.6))
			_visual.rotation.x = deg_to_rad(18)
		Combatant.State.DEAD:
			pose = POSE_BROKEN
			_visual.rotation.x = deg_to_rad(-88)
			_visual.position.y = 0.35
	if c.state != Combatant.State.DODGE:
		_visual.scale = Vector3.ONE
	if _correction_offset.length_squared() > 0.0001:
		_visual.position += global_basis.inverse() * _correction_offset
		_correction_offset *= CORRECTION_DECAY
	else:
		_correction_offset = Vector3.ZERO

	_sword_pivot.rotation_degrees = pose
	_sword_mat.emission_enabled = glow_energy > 0.0
	_sword_mat.emission = glow
	_sword_mat.emission_energy_multiplier = glow_energy
	_body_mat.emission_enabled = body_glow != Color.BLACK
	_body_mat.emission = body_glow
	_body_mat.emission_energy_multiplier = 1.5


static func _rotate_toward(from: Vector3, to: Vector3, max_rad: float) -> Vector3:
	var a := atan2(from.x, from.z)
	var b := atan2(to.x, to.z)
	var step := clampf(wrapf(b - a, -PI, PI), -max_rad, max_rad)
	return Vector3(sin(a + step), 0.0, cos(a + step))


func _build_visuals() -> void:
	var torso := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.36
	capsule.height = 1.7
	torso.mesh = capsule
	torso.material_override = _body_mat
	torso.position.y = 0.88
	_visual.add_child(torso)

	# Dark mask on the face so facing is readable from any angle.
	var mask := MeshInstance3D.new()
	var mask_mesh := BoxMesh.new()
	mask_mesh.size = Vector3(0.36, 0.16, 0.12)
	mask.mesh = mask_mesh
	var mask_mat := StandardMaterial3D.new()
	mask_mat.albedo_color = Color(0.08, 0.08, 0.1)
	mask.material_override = mask_mat
	mask.position = Vector3(0, 1.5, -0.3)
	_visual.add_child(mask)

	# Long scarf tail (identity feature from GDD §11) — cosmetic only, no collision.
	var scarf := MeshInstance3D.new()
	var scarf_mesh := BoxMesh.new()
	scarf_mesh.size = Vector3(0.14, 0.04, 0.9)
	scarf.mesh = scarf_mesh
	var scarf_mat := StandardMaterial3D.new()
	scarf_mat.albedo_color = _body_mat.albedo_color.lightened(0.35)
	scarf.material_override = scarf_mat
	scarf.position = Vector3(0.1, 1.3, 0.55)
	scarf.rotation_degrees = Vector3(-35, 8, 0)
	_visual.add_child(scarf)

	_sword_pivot.position = Vector3(0.38, 1.2, -0.15)
	_visual.add_child(_sword_pivot)
	var blade := MeshInstance3D.new()
	var blade_mesh := BoxMesh.new()
	blade_mesh.size = Vector3(0.04, 0.08, 1.05)
	blade.mesh = blade_mesh
	_sword_mat.albedo_color = Color(0.82, 0.84, 0.88)
	_sword_mat.metallic = 0.9
	_sword_mat.roughness = 0.25
	blade.material_override = _sword_mat
	blade.position.z = -0.62
	_sword_pivot.add_child(blade)
	var hilt := MeshInstance3D.new()
	var hilt_mesh := BoxMesh.new()
	hilt_mesh.size = Vector3(0.06, 0.06, 0.25)
	hilt.mesh = hilt_mesh
	var hilt_mat := StandardMaterial3D.new()
	hilt_mat.albedo_color = Color(0.15, 0.1, 0.08)
	hilt.material_override = hilt_mat
	_sword_pivot.add_child(hilt)
