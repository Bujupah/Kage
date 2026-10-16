class_name MenuStage
extends Node3D
## The 3D stage behind every menu (GUI.md §5.2, §5.3): a moonlit iaidō courtyard where the
## player's own assassin stands with their katana, wearing their equipped cosmetics. Screens ask for
## a framing (title, armory, store) and the camera glides there; dragging rotates the character.
## Cinematic but cheap: one character, a small set, baked-feeling light from three sources.

const FRAMES := {
	# [camera position, look-at, fov] — character is framed on the right third for menus.
	"title": [Vector3(-1.55, 1.42, 3.35), Vector3(-0.55, 1.15, 0.0), 42.0],
	"armory": [Vector3(-0.95, 1.3, 2.55), Vector3(-0.45, 1.05, 0.0), 40.0],
	"store": [Vector3(0.9, 1.25, 2.6), Vector3(0.4, 1.0, 0.0), 40.0],
	"blade": [Vector3(-0.85, 1.35, 2.0), Vector3(0.05, 1.05, 0.0), 36.0],
}
const DRAG_SPEED := 0.008
const FLOURISH_EVERY := 14.0

var model: AssassinModel
var _camera := Camera3D.new()
var _pivot := Node3D.new()
var _target_frame := "title"
## Fighters face -Z; the camera looks from +Z, so PI turns the assassin toward us, slightly toward
## the menu column on the left.
var _yaw := PI - 0.45
var _yaw_target := PI - 0.45
var _since_flourish := 0.0
var _cam_pos := Vector3.ZERO
var _cam_look := Vector3.ZERO
var _cam_fov := 42.0


func _ready() -> void:
	_build_set()
	_pivot.position.y = 0.12 # Stand on the hinoki dais, not in it.
	add_child(_pivot)
	model = AssassinModel.new()
	model.appearance = PlayerProfile.appearance()
	_pivot.add_child(model)
	_pivot.rotation.y = _yaw
	model.play(&"Idle", 1.0)
	PlayerProfile.bus.changed.connect(_on_profile_changed)
	add_child(_camera)
	var attrs := CameraAttributesPractical.new()
	attrs.dof_blur_far_enabled = true
	attrs.dof_blur_far_distance = 5.5
	attrs.dof_blur_far_transition = 4.0
	attrs.dof_blur_amount = 0.08
	_camera.attributes = attrs
	_camera.make_current()
	var f: Array = FRAMES["title"]
	_cam_pos = f[0]
	_cam_look = f[1]
	_cam_fov = f[2]
	_apply_camera()


func frame(frame_name: String) -> void:
	if FRAMES.has(frame_name):
		_target_frame = frame_name


func rotate_by(pixels: float) -> void:
	_yaw_target += pixels * DRAG_SPEED


## Plays a short sword flourish (after equipping something, or every so often while idle).
func flourish() -> void:
	_since_flourish = 0.0
	model.play(&"Sword_Regular_Combo", 1.0)
	var ap: AnimationPlayer = model.find_children("*", "AnimationPlayer", true, false)[0]
	ap.queue(AssassinModel.LIBRARY + "/Idle")


func _process(delta: float) -> void:
	var still := GameSettings.reduced_motion()
	var f: Array = FRAMES[_target_frame]
	var k := 1.0 if still else 1.0 - exp(-4.0 * delta)
	_cam_pos = _cam_pos.lerp(f[0], k)
	_cam_look = _cam_look.lerp(f[1], k)
	_cam_fov = lerpf(_cam_fov, f[2], k)
	_yaw = lerpf(_yaw, _yaw_target, 1.0 if still else 1.0 - exp(-8.0 * delta))
	_pivot.rotation.y = _yaw
	_apply_camera()
	_since_flourish += delta
	if _since_flourish > FLOURISH_EVERY and not still:
		flourish()


func _apply_camera() -> void:
	var breathe := 0.0 if GameSettings.reduced_motion() else sin(Time.get_ticks_msec() * 0.0004) * 0.015
	_camera.look_at_from_position(_cam_pos + Vector3(0, breathe, 0), _cam_look)
	_camera.fov = _cam_fov


func _on_profile_changed() -> void:
	model.apply_appearance(PlayerProfile.appearance())


# --- The set -------------------------------------------------------------------------------------

func _build_set() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.05, 0.06, 0.13)
	sky_mat.sky_horizon_color = Color(0.32, 0.22, 0.3)
	sky_mat.ground_horizon_color = Color(0.12, 0.1, 0.12)
	sky_mat.ground_bottom_color = Color(0.03, 0.03, 0.04)
	sky.sky_material = sky_mat
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.ambient_light_energy = 0.55
	e.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	e.tonemap_mode = Environment.TONE_MAPPER_ACES
	e.tonemap_exposure = 0.95
	e.glow_enabled = true
	e.glow_intensity = 0.7
	e.glow_bloom = 0.08
	e.glow_hdr_threshold = 0.9
	e.ssao_enabled = true
	e.ssao_intensity = 1.6
	e.ssil_enabled = true
	e.volumetric_fog_enabled = true
	e.volumetric_fog_density = 0.035
	e.volumetric_fog_albedo = Color(0.55, 0.6, 0.75)
	e.volumetric_fog_emission = Color(0.02, 0.02, 0.04)
	e.volumetric_fog_anisotropy = 0.6
	e.adjustment_enabled = true
	e.adjustment_contrast = 1.08
	e.adjustment_saturation = 0.95
	env.environment = e
	add_child(env)

	# Key: warm lantern light from the front-left. Rim: cold moonlight from behind. Fill: faint sky.
	var key := SpotLight3D.new()
	key.light_color = Color(1.0, 0.72, 0.5)
	key.light_energy = 5.0
	key.spot_range = 12.0
	key.spot_angle = 28.0
	key.shadow_enabled = true
	key.look_at_from_position.call_deferred(Vector3(-2.6, 3.2, 3.0), Vector3(0, 1.0, 0))
	add_child(key)
	var rim := SpotLight3D.new()
	rim.light_color = Color(0.62, 0.72, 1.0)
	rim.light_energy = 6.0
	rim.spot_range = 12.0
	rim.spot_angle = 30.0
	rim.light_volumetric_fog_energy = 0.8
	rim.look_at_from_position.call_deferred(Vector3(1.8, 3.6, -3.4), Vector3(0, 1.2, 0))
	add_child(rim)
	var moon := DirectionalLight3D.new()
	moon.name = "Moon"
	moon.light_color = Color(0.55, 0.62, 0.95)
	moon.light_energy = 0.35
	moon.shadow_enabled = true
	moon.rotation_degrees = Vector3(-35, 150, 0)
	add_child(moon)

	var planks := WorldKit.material("hinoki_planks", 1.2, Color(0.75, 0.7, 0.65))
	var sand := WorldKit.material("raked_dirt", 2.0, Color(0.8, 0.78, 0.75))
	WorldKit.box(self, Vector3(0, -0.5, -4), Vector3(40, 1, 40), sand)
	WorldKit.box(self, Vector3(0, 0.06, 0), Vector3(4.2, 0.12, 3.2), planks)
	WorldKit.box(self, Vector3(0, 0.02, 0), Vector3(4.6, 0.04, 3.6), WorldKit.material("japanese_stone_wall", 1.0), false)
	AssetKit.place(self, "torii", Vector3(1.2, 0, -6.5), 5.2, -12.0, false)
	for p in [Vector3(2.9, 0, -2.6)]:
		AssetKit.place(self, "stone_lantern", p, 1.9, p.x * 20.0, false)
		WorldKit.light(self, p + Vector3(0, 1.25, 0), WorldKit.LANTERN_LIGHT, 1.4, 5.0)
	AssetKit.place(self, "maple", Vector3(-4.6, 0, -4.8), 5.5, 40.0, false)
	AssetKit.place(self, "cherry", Vector3(5.8, 0, -6.0), 6.0, 160.0, false)
	WorldKit.paper_lantern(self, Vector3(-2.1, 2.6, 1.2))
	WorldKit.compound_wall(self, Vector3(-8, 0, -9), Vector3(8, 0, -9), 2.2)
	WorldKit.bamboo_grove(self, Rect2(-14, -16, 28, 7), 70, [], 11)
	WorldKit.bamboo_grove(self, Rect2(-14, -9, 6, 12), 18, [], 12)
	WorldKit.bamboo_grove(self, Rect2(7, -9, 7, 12), 18, [], 13)
	WorldKit.prop(self, "katana_stand_01", Vector3(1.55, 0.12, -0.9), -30.0)
	_petals()
	_fireflies()


func _petals() -> void:
	var p := CPUParticles3D.new()
	p.amount = 90
	p.lifetime = 9.0
	p.preprocess = 9.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(6, 0.5, 2.5)
	p.position = Vector3(0, 5.5, -3.0) # Behind the character, never drifting into the lens.
	p.direction = Vector3(0.4, -1, 0.1)
	p.spread = 25.0
	p.gravity = Vector3(0.25, -0.35, 0.05)
	p.initial_velocity_min = 0.2
	p.initial_velocity_max = 0.5
	p.angular_velocity_min = -120.0
	p.angular_velocity_max = 120.0
	p.particle_flag_rotate_y = true
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.2
	var quad := QuadMesh.new()
	quad.size = Vector2(0.045, 0.035)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.96, 0.72, 0.78)
	var shape := GradientTexture2D.new() # Soft oval petal instead of a hard square.
	shape.fill = GradientTexture2D.FILL_RADIAL
	shape.fill_from = Vector2(0.5, 0.5)
	shape.fill_to = Vector2(0.5, 0.0)
	var g := Gradient.new()
	g.set_color(0, Color.WHITE)
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.75, Color(1, 1, 1, 0.9))
	shape.gradient = g
	mat.albedo_texture = shape
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mat.alpha_scissor_threshold = 0.5
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = 0.6
	mat.backlight_enabled = true
	mat.backlight = Color(0.9, 0.5, 0.55)
	quad.material = mat
	p.mesh = quad
	add_child(p)


func _fireflies() -> void:
	var p := CPUParticles3D.new()
	p.amount = 24
	p.lifetime = 6.0
	p.preprocess = 6.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(5, 0.8, 3)
	p.position = Vector3(0, 1.0, -3.0)
	p.gravity = Vector3.ZERO
	p.initial_velocity_min = 0.05
	p.initial_velocity_max = 0.15
	p.spread = 180.0
	var m := SphereMesh.new()
	m.radius = 0.012
	m.height = 0.024
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.85, 0.45)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.8, 0.4)
	mat.emission_energy_multiplier = 6.0
	m.material = mat
	p.mesh = m
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0))
	curve.add_point(Vector2(0.5, 1))
	curve.add_point(Vector2(1, 0))
	p.scale_amount_curve = curve
	add_child(p)
