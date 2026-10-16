class_name CombatFx
extends RefCounted
## Contact feedback for *confirmed* events (3DMODELS.md FX-001..005): spark bursts, a parry fan,
## a posture-break shock ring, plus the matching sound. Purely cosmetic and never consulted by the
## rules. "Reduce flashes" keeps every cue's shape and sound but dims and thins it.

const SPARK_HIT := Color(1.0, 0.32, 0.22)
const SPARK_GUARD := Color(1.0, 0.78, 0.42)
const SPARK_PARRY := Color(0.88, 0.95, 1.0)
const SPARK_BREAK := Color(1.0, 0.85, 0.25)


## `attacker_pos` / `target_pos` are the presented positions (predicted or interpolated).
static func present_event(parent: Node, ev: Dictionary, attacker_pos: Vector3, target_pos: Vector3) -> void:
	var cue := Sfx.for_event(ev)
	var at := attacker_pos.lerp(target_pos, 0.62) + Vector3.UP * 1.25
	if not cue.is_empty():
		Sfx.play_at(parent, cue, at if ev.has("target") else attacker_pos + Vector3.UP * 1.2)
	match ev["type"]:
		&"hit":
			var crit: bool = ev.get("critical", false) or ev.get("killed", false)
			burst(parent, at, SPARK_HIT, 26 if crit else 14, 3.2)
			if crit:
				ring(parent, at, SPARK_HIT, 1.4)
		&"guarded":
			burst(parent, at, SPARK_GUARD, 12, 2.6)
		&"parried":
			burst(parent, at, SPARK_PARRY, 36, 4.5)
			ring(parent, at, SPARK_PARRY, 1.8)
		&"guard_broken":
			burst(parent, at, SPARK_BREAK, 30, 3.8)
			ring(parent, target_pos + Vector3.UP * 1.0, SPARK_BREAK, 2.4)
		&"dodged":
			burst(parent, target_pos + Vector3.UP * 0.2, Color(0.75, 0.7, 0.62, 0.6), 10, 1.2, false)


## Event without a target (attack start, dodge start, round reset): sound only.
static func present_solo(parent: Node, ev: Dictionary, at: Vector3) -> void:
	var cue := Sfx.for_event(ev)
	if not cue.is_empty():
		Sfx.play_at(parent, cue, at + Vector3.UP * 1.2)


static func burst(parent: Node, at: Vector3, color: Color, amount: int, speed: float, glow: bool = true) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var reduced := GameSettings.reduced_flashes()
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = false
	p.amount = maxi(4, amount / 2 if reduced else amount)
	p.lifetime = 0.35
	p.explosiveness = 0.95
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, -6.0, 0)
	p.damping_min = 2.0
	p.damping_max = 4.0
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.0
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0))
	p.scale_amount_curve = curve
	var mesh := SphereMesh.new()
	mesh.radius = 0.025
	mesh.height = 0.05
	mesh.radial_segments = 6
	mesh.rings = 3
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	if glow:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 1.5 if reduced else 4.0
	mesh.material = mat
	p.mesh = mesh
	p.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	parent.add_child(p)
	p.global_position = at
	p.emitting = true
	p.finished.connect(p.queue_free)


## Expanding flat ring: the shape of the cue matters more than its brightness.
static func ring(parent: Node, at: Vector3, color: Color, radius: float) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var reduced := GameSettings.reduced_flashes()
	var r := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.42
	torus.outer_radius = 0.5
	torus.rings = 24
	torus.ring_segments = 6
	r.mesh = torus
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(color, 0.5 if reduced else 0.9)
	r.material_override = mat
	r.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	r.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	parent.add_child(r)
	r.global_position = at
	r.scale = Vector3.ONE * 0.3
	var tw := r.create_tween().set_parallel()
	tw.tween_property(r, "scale", Vector3.ONE * radius, 0.22).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.22)
	tw.chain().tween_callback(r.queue_free)

