class_name EnchantFx
extends Node3D
## Cosmetic enchantment particles (3DMODELS.md FX catalogue): embers, frost, lightning, spirit,
## fire and petals, emitted from a box (a blade's length, a scarf's tip) into world space so they
## trail behind motion. GPU particles with a soft additive sprite and a colour ramp; enchanted
## blades also carry a small flickering light, which is what sells them at night.
##
## Never part of combat: no collision, no hit volumes, nothing replicated beyond the cosmetic ID.

const KINDS := ["embers", "frost", "lightning", "spirit", "fire", "petals"]

var extents := Vector3(0.012, 0.32, 0.006) ## Emission box half-size in local space.
var with_light := true
var intensity := 1.0 ## Scales particle counts (quality presets / attack bursts).

var _particles: GPUParticles3D
var _light: OmniLight3D
var _kind := ""
var _color := Color.WHITE
var _time := 0.0

static var _sprite: Texture2D
static var _petal: Texture2D


func set_effect(kind: String, color: Color) -> void:
	if kind == _kind and color == _color:
		return
	_kind = kind
	_color = color
	if _particles != null:
		_particles.queue_free()
		_particles = null
	if _light != null:
		_light.queue_free()
		_light = null
	if not KINDS.has(kind) or not AssetKit.visuals_enabled():
		return
	_particles = _build(kind, color)
	add_child(_particles)
	if with_light and kind != "petals":
		_light = OmniLight3D.new()
		_light.light_color = color
		_light.omni_range = 2.6
		_light.light_energy = 0.0
		_light.shadow_enabled = false
		add_child(_light)


## Bursts harder while the blade is swinging.
func set_boost(on: bool) -> void:
	if _particles != null:
		_particles.speed_scale = 1.6 if on else 1.0
		_particles.amount_ratio = 1.0 if on else 0.6


func _process(delta: float) -> void:
	if _light == null:
		return
	_time += delta
	var base := 0.6 if _kind == "fire" else 0.35
	var flicker := sin(_time * 23.0) * 0.12 + sin(_time * 7.3) * 0.18
	if _kind == "lightning":
		flicker = 1.6 if fmod(_time * 9.0, 1.0) < 0.12 else -0.35 # Discharges, not a glow.
	_light.light_energy = maxf(0.0, base + flicker) * intensity


func _build(kind: String, color: Color) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.local_coords = false
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_aabb = AABB(Vector3(-2, -2, -2), Vector3(4, 4, 4))
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	m.emission_box_extents = extents
	m.direction = Vector3.UP
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = _soft_sprite()
	mat.disable_receive_shadows = true
	var quad := QuadMesh.new()
	var ramp := Gradient.new()
	match kind:
		"embers":
			p.amount = 48
			p.lifetime = 0.9
			m.spread = 35.0
			m.initial_velocity_min = 0.15
			m.initial_velocity_max = 0.5
			m.gravity = Vector3(0, 0.9, 0)
			m.turbulence_enabled = true
			m.turbulence_noise_strength = 1.4
			m.turbulence_noise_scale = 1.5
			m.scale_min = 0.5
			m.scale_max = 1.2
			quad.size = Vector2(0.018, 0.018)
			_ramp(ramp, [Color(1, 0.95, 0.7, 1), color, Color(color.r, color.g * 0.3, 0, 0)])
		"frost":
			p.amount = 34
			p.lifetime = 1.7
			m.spread = 180.0
			m.initial_velocity_min = 0.02
			m.initial_velocity_max = 0.12
			m.gravity = Vector3(0, -0.35, 0)
			m.angular_velocity_min = -90.0
			m.angular_velocity_max = 90.0
			m.scale_min = 0.4
			m.scale_max = 1.0
			quad.size = Vector2(0.022, 0.022)
			_ramp(ramp, [Color(1, 1, 1, 0), Color(0.9, 0.97, 1, 0.9), Color(color, 0)])
		"lightning":
			p.amount = 36
			p.lifetime = 0.14
			p.explosiveness = 0.25
			m.spread = 180.0
			m.initial_velocity_min = 1.2
			m.initial_velocity_max = 2.6
			m.gravity = Vector3.ZERO
			m.damping_min = 6.0
			m.damping_max = 10.0
			m.particle_flag_align_y = true # Velocity-stretched sparks read as arcs.
			mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
			quad.size = Vector2(0.008, 0.09)
			_ramp(ramp, [Color(1, 1, 1, 1), color.lightened(0.15), Color(color, 0)])
		"spirit":
			p.amount = 16
			p.lifetime = 2.0
			m.spread = 60.0
			m.initial_velocity_min = 0.05
			m.initial_velocity_max = 0.18
			m.gravity = Vector3(0, 0.12, 0)
			m.turbulence_enabled = true
			m.turbulence_noise_strength = 0.9
			m.turbulence_noise_scale = 2.2
			m.scale_min = 0.6
			m.scale_max = 1.4
			var curve := CurveTexture.new()
			curve.curve = Curve.new()
			curve.curve.add_point(Vector2(0, 0.2))
			curve.curve.add_point(Vector2(0.4, 1.0))
			curve.curve.add_point(Vector2(1, 0.0))
			m.scale_curve = curve
			quad.size = Vector2(0.06, 0.06)
			_ramp(ramp, [Color(color, 0), Color(color.lightened(0.4), 0.8), Color(color, 0)])
		"fire":
			p.amount = 110
			p.lifetime = 0.5
			m.spread = 18.0
			m.initial_velocity_min = 0.25
			m.initial_velocity_max = 0.6
			m.gravity = Vector3(0, 1.6, 0)
			m.angular_velocity_min = -60.0
			m.angular_velocity_max = 60.0
			m.turbulence_enabled = true
			m.turbulence_noise_strength = 0.6
			var flame := CurveTexture.new()
			flame.curve = Curve.new()
			flame.curve.add_point(Vector2(0, 0.6))
			flame.curve.add_point(Vector2(0.25, 1.0))
			flame.curve.add_point(Vector2(1, 0.1))
			m.scale_curve = flame
			quad.size = Vector2(0.05, 0.05)
			_ramp(ramp, [Color(1, 0.95, 0.75, 0.9), Color(color, 0.7), Color(0.6, 0.08, 0.02, 0.3), Color(0.1, 0.02, 0, 0)])
		"petals":
			p.amount = 14
			p.lifetime = 2.6
			m.spread = 90.0
			m.initial_velocity_min = 0.1
			m.initial_velocity_max = 0.35
			m.gravity = Vector3(0.15, -0.45, 0)
			m.angular_velocity_min = -160.0
			m.angular_velocity_max = 160.0
			m.turbulence_enabled = true
			m.turbulence_noise_strength = 0.5
			mat.blend_mode = BaseMaterial3D.BLEND_MODE_MIX # Unshaded so blossom reads at night.
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			mat.alpha_scissor_threshold = 0.4
			mat.albedo_texture = _petal_sprite()
			quad.size = Vector2(0.04, 0.03)
			_ramp(ramp, [color.lightened(0.2), color, Color(color, 0.0)])
	var ramp_tex := GradientTexture1D.new()
	ramp_tex.gradient = ramp
	m.color_ramp = ramp_tex
	quad.material = mat
	p.draw_pass_1 = quad
	p.process_material = m
	return p


static func _ramp(g: Gradient, colors: Array) -> void:
	var offsets := PackedFloat32Array()
	var cols := PackedColorArray()
	for i in colors.size():
		offsets.append(float(i) / (colors.size() - 1))
		cols.append(colors[i])
	g.offsets = offsets
	g.colors = cols


static func _soft_sprite() -> Texture2D:
	if _sprite == null:
		var t := GradientTexture2D.new()
		t.width = 64
		t.height = 64
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(0.5, 0.0)
		var g := Gradient.new()
		_ramp(g, [Color(1, 1, 1, 1), Color(1, 1, 1, 0.45), Color(1, 1, 1, 0)])
		t.gradient = g
		_sprite = t
	return _sprite


static func _petal_sprite() -> Texture2D:
	if _petal == null:
		var t := GradientTexture2D.new()
		t.width = 32
		t.height = 32
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(0.5, 0.05)
		var g := Gradient.new()
		_ramp(g, [Color(1, 1, 1, 1), Color(1, 1, 1, 0.9), Color(1, 1, 1, 0)])
		t.gradient = g
		_petal = t
	return _petal
