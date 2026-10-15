class_name DojoLevel
extends RefCounted
## Placeholder dojo courtyard shared by the sandbox, the headless server and network clients, so
## the server collides against exactly the walls the client predicts against.

## Duel spawn slots for networked matches: [position, facing].
const SPAWNS := [
	[Vector3(0, 0, 3), Vector3.FORWARD],
	[Vector3(0, 0, -3), Vector3.BACK],
]


static func build(parent: Node) -> void:
	var env := WorldEnvironment.new()
	var environment := Environment.new()
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.22, 0.2, 0.38)
	sky_mat.sky_horizon_color = Color(0.95, 0.55, 0.38)
	sky_mat.ground_horizon_color = Color(0.4, 0.28, 0.25)
	sky_mat.ground_bottom_color = Color(0.1, 0.08, 0.1)
	sky.sky_material = sky_mat
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.glow_enabled = true
	environment.fog_enabled = true
	environment.fog_density = 0.008
	environment.fog_light_color = Color(0.75, 0.5, 0.45)
	env.environment = environment
	parent.add_child(env)

	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.8, 0.6)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-35, -40, 0)
	parent.add_child(sun)

	_block(parent, Vector3(0, -0.5, 0), Vector3(40, 1, 40), Color(0.42, 0.36, 0.3)) # courtyard
	_block(parent, Vector3(0, 0.01, 0), Vector3(10, 0.02, 10), Color(0.62, 0.55, 0.42), false) # sand duel ring
	# Torii gate as a landmark for orientation.
	var red := Color(0.7, 0.12, 0.08)
	_block(parent, Vector3(-2.5, 2.25, -9), Vector3(0.45, 4.5, 0.45), red)
	_block(parent, Vector3(2.5, 2.25, -9), Vector3(0.45, 4.5, 0.45), red)
	_block(parent, Vector3(0, 4.6, -9), Vector3(7.2, 0.4, 0.6), red)
	_block(parent, Vector3(0, 3.8, -9), Vector3(6.0, 0.25, 0.35), red)
	# Low walls and stone lanterns give sight lines and something for the camera spring to hit.
	var stone := Color(0.5, 0.48, 0.45)
	_block(parent, Vector3(-12, 0.6, 0), Vector3(0.6, 1.2, 18), stone)
	_block(parent, Vector3(12, 0.6, 0), Vector3(0.6, 1.2, 18), stone)
	for p: Vector3 in [Vector3(-6, 0, 6), Vector3(6, 0, 6), Vector3(-6, 0, -6), Vector3(6, 0, -6)]:
		_block(parent, p + Vector3(0, 0.6, 0), Vector3(0.5, 1.2, 0.5), stone)
		var lamp := OmniLight3D.new()
		lamp.light_color = Color(1.0, 0.6, 0.3)
		lamp.light_energy = 1.5
		lamp.omni_range = 5.0
		lamp.position = p + Vector3(0, 1.45, 0)
		parent.add_child(lamp)


static func _block(parent: Node, center: Vector3, size: Vector3, color: Color, solid: bool = true) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.95
	mesh.material_override = mat
	if not solid:
		mesh.position = center
		parent.add_child(mesh)
		return
	var body := StaticBody3D.new()
	body.collision_layer = FighterBody.WORLD_LAYER
	body.position = center
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	shape.shape = box_shape
	body.add_child(shape)
	body.add_child(mesh)
	parent.add_child(body)
