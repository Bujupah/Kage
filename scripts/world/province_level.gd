class_name ProvinceLevel
extends RefCounted
## The Shrouded Province greybox slice (ENVIRONMENT.md §13 P0): Lantern Village (sanctuary), the
## Training Dojo courtyard (protected duel arena at the origin), the torii approach, the vermilion
## boundary torii (danger crossing and return gate), Bamboo Road with a duel clearing, a small
## abandoned ruin and night ambience. Layout and rules come from RegionMap; this file only builds
## the scene. The same build runs on the headless server, so collision is identical everywhere.

## Arena duel slots (sandbox and `--spawn=arena` servers): [position, facing], inside the dojo ring.
const ARENA_SPAWNS := [
	[Vector3(0, 0, 3), Vector3.FORWARD],
	[Vector3(0, 0, -3), Vector3.BACK],
]
## Where players enter the world and respawn: the Lantern Village square, facing north to the dojo.
const SANCTUARY_SPAWNS := [
	[Vector3(-2.5, 0, 26), Vector3.FORWARD], [Vector3(2.5, 0, 26), Vector3.FORWARD],
	[Vector3(-2.5, 0, 36), Vector3.FORWARD], [Vector3(2.5, 0, 36), Vector3.FORWARD],
	[Vector3(-1.2, 0, 44), Vector3.FORWARD], [Vector3(1.2, 0, 44), Vector3.FORWARD],
	[Vector3(-2.0, 0, 52), Vector3.FORWARD], [Vector3(2.0, 0, 52), Vector3.FORWARD],
]
## Test spawns at the edge of the bamboo clearing (`--spawn=frontier`, used by the PvE smoke test).
const FRONTIER_SPAWNS := [
	[Vector3(-1.5, 0, -47), Vector3.FORWARD], [Vector3(1.5, 0, -47), Vector3.FORWARD],
]
## PvE: server-driven bandits guarding frontier sites. They never follow players into sanctuaries.
const NPC_CAMPS := [
	{"name": "Bandit Ronin", "home": Vector3(4.5, 0, -61), "look": {"outfit": "arm.obsidian_vow.v1", "blade": "wpn.katana.sumi.v1", "scarf": "scf.shadow_veil.v1"}},
	{"name": "Bandit Ronin", "home": Vector3(-4.5, 0, -55), "look": {"outfit": "arm.obsidian_vow.v1", "blade": "wpn.katana.sumi.v1", "scarf": "scf.shadow_veil.v1"}},
	{"name": "Ruin Warden", "home": Vector3(23, 0.6, -79), "look": {"outfit": "arm.jade_serpent.v1", "blade": "wpn.katana.winter_bell.v1", "scarf": "scf.moonlit_silk.v1"}},
	{"name": "Ruin Warden", "home": Vector3(29, 0.6, -77), "look": {"outfit": "arm.jade_serpent.v1", "blade": "wpn.katana.winter_bell.v1", "scarf": "scf.moonlit_silk.v1"}},
]
const AMBIENCE := "res://assets/third_party/oga_crickets/crickets.mp3"


const SKY_HDRI := "res://assets/third_party/polyhaven/hdris/belfast_sunset_puresky_2k.hdr"


static func build(parent: Node3D) -> void:
	_sky_and_light(parent)
	var terrain := ProvinceTerrain.build(parent)
	_ground(parent, terrain != null)
	_bounds(parent)
	_dojo(parent)
	_village(parent)
	_approach_and_torii(parent)
	_castle(parent)
	_bamboo_road(parent)
	_ruin(parent)
	_ambience(parent)
	if DisplayServer.get_name() != "headless":
		StaticBatcher.merge(parent) # The server needs colliders only; clients want few draws.


static func _sky_and_light(parent: Node3D) -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	var sky := Sky.new()
	if DisplayServer.get_name() != "headless" and ResourceLoader.exists(SKY_HDRI):
		# Golden-hour HDRI: real sky gradient and image-based lighting for every PBR surface.
		var pano := PanoramaSkyMaterial.new()
		pano.panorama = load(SKY_HDRI)
		pano.energy_multiplier = 0.9
		sky.sky_material = pano
		sky.radiance_size = Sky.RADIANCE_SIZE_256
	else:
		var sky_mat := ProceduralSkyMaterial.new()
		sky_mat.sky_top_color = Color(0.1, 0.11, 0.24)
		sky_mat.sky_horizon_color = Color(0.62, 0.38, 0.36)
		sky.sky_material = sky_mat
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.ambient_light_energy = 0.75
	e.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	e.tonemap_mode = Environment.TONE_MAPPER_AGX
	e.tonemap_exposure = 1.0
	e.glow_enabled = true
	e.glow_intensity = 0.6
	e.glow_bloom = 0.04
	e.ssao_enabled = true
	e.ssao_intensity = 1.4
	e.ssil_enabled = true
	e.fog_enabled = true
	e.fog_mode = Environment.FOG_MODE_DEPTH
	e.fog_light_color = Color(0.78, 0.66, 0.6)
	e.fog_sky_affect = 0.25
	e.fog_density = 0.32 # Depth mode: the most the far horizon is hazed.
	e.fog_depth_begin = 60.0
	e.fog_depth_end = 520.0
	e.fog_depth_curve = 1.6
	e.fog_aerial_perspective = 0.35
	# Low volumetric haze catches the low sun: god rays through the bamboo (cosmetic, fair: the
	# density is the same everywhere and never hides a fighter more than depth fog does).
	e.volumetric_fog_enabled = true
	e.volumetric_fog_density = 0.0018
	e.volumetric_fog_albedo = Color(0.95, 0.85, 0.75)
	e.volumetric_fog_anisotropy = 0.7
	e.volumetric_fog_sky_affect = 0.1
	e.adjustment_enabled = true
	e.adjustment_contrast = 1.12
	e.adjustment_saturation = 1.04
	env.environment = e
	env.name = "WorldEnvironment"
	parent.add_child(env)

	var sun := DirectionalLight3D.new()
	sun.name = "Moon" # Settings look this light up for shadow quality.
	sun.light_color = Color(1.0, 0.78, 0.58)
	sun.light_energy = 1.6
	sun.light_volumetric_fog_energy = 1.4
	sun.shadow_enabled = true
	sun.shadow_blur = 1.4
	sun.directional_shadow_max_distance = 60.0
	sun.directional_shadow_blend_splits = true
	sun.rotation_degrees = Vector3(-16, -128, 0)
	parent.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.light_color = Color(0.55, 0.62, 0.85)
	fill.light_energy = 0.25
	fill.rotation_degrees = Vector3(-50, 40, 0)
	parent.add_child(fill)


static func _ground(parent: Node3D, has_terrain: bool) -> void:
	var b := RegionMap.BOUNDS
	# One collider for the whole floor; visual layers on top at tiny offsets to avoid z-fighting.
	# With terrain, the floor collider stays but its grass visual gives way to the terrain.
	var floor_body := WorldKit.box(parent, Vector3(b.get_center().x, -0.5, b.get_center().y), Vector3(b.size.x + 20, 1, b.size.y + 20),
			WorldKit.material("leafy_grass", 3.0))
	if has_terrain:
		for mi in floor_body.find_children("*", "MeshInstance3D", true, false):
			mi.queue_free()
	var dirt := WorldKit.material("raked_dirt", 3.0)
	var road := WorldKit.material("stone_pathway", 2.5)
	var grove_floor := WorldKit.material("forest_leaves_02", 2.5)
	WorldKit.box(parent, Vector3(0, 0.005, 46), Vector3(44, 0.01, 68), dirt, false) # village
	WorldKit.box(parent, Vector3(0, 0.012, 46), Vector3(7, 0.01, 68), road, false) # main street
	WorldKit.box(parent, Vector3(0, 0.005, 0), Vector3(32, 0.01, 26), dirt, false) # courtyard
	WorldKit.box(parent, Vector3(0, 0.012, 0), Vector3(10, 0.01, 10), WorldKit.material("playground_sand", 2.0), false) # duel ring
	WorldKit.box(parent, Vector3(0, 0.012, -20), Vector3(5, 0.01, 14), road, false) # approach
	if not has_terrain:
		WorldKit.box(parent, Vector3(0, 0.005, -63), Vector3(80, 0.01, 72), grove_floor, false) # grove floor
	# Bamboo Road: a dog-leg of stepping-stone path north to the clearing, then east to the ruin.
	WorldKit.box(parent, Vector3(0, 0.012, -42), Vector3(4, 0.01, 30), road, false)
	WorldKit.box(parent, Vector3(13, 0.012, -72), Vector3(26, 0.01, 4), road, false, -12.0)


static func _bounds(parent: Node3D) -> void:
	# Boundary colliders (§4). With terrain, the forested hillside rising right at the edge is the
	# visible boundary, so the colliders carry no mesh; stone walls are drawn only as a fallback.
	var b := RegionMap.BOUNDS
	var h := 7.0
	var walls := [
		[Vector3(b.position.x - 1, h * 0.5, b.get_center().y), Vector3(2, h, b.size.y + 4)],
		[Vector3(b.end.x + 1, h * 0.5, b.get_center().y), Vector3(2, h, b.size.y + 4)],
		[Vector3(b.get_center().x, h * 0.5, b.position.y - 1), Vector3(b.size.x + 4, h, 2)],
		[Vector3(b.get_center().x, h * 0.5, b.end.y + 1), Vector3(b.size.x + 4, h, 2)],
	]
	var draw := not ProvinceTerrain.available()
	var rock := WorldKit.material("mossy_rock", 3.0, Color(0.7, 0.72, 0.68))
	for w: Array in walls:
		if draw:
			WorldKit.box(parent, w[0], w[1], rock)
			continue
		var body := StaticBody3D.new()
		body.collision_layer = FighterBody.WORLD_LAYER
		body.collision_mask = 0
		body.position = w[0]
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = w[1]
		shape.shape = box
		body.add_child(shape)
		parent.add_child(body)


static func _dojo(parent: Node3D) -> void:
	# Courtyard walls with gates north (to the frontier) and south (to the village).
	for side in [-1, 1]:
		WorldKit.compound_wall(parent, Vector3(-16, 0, side * 13), Vector3(-3, 0, side * 13))
		WorldKit.compound_wall(parent, Vector3(3, 0, side * 13), Vector3(16, 0, side * 13))
	WorldKit.compound_wall(parent, Vector3(16, 0, -13), Vector3(16, 0, 13))
	# Dojo hall: the open-sided shrine corridor (CC-BY "Japanese shrine" by GreenG) on the west edge.
	AssetKit.place(parent, "shrine_hall", Vector3(-23.5, 0, 0), 7.0, 90.0)
	WorldKit.prop(parent, "katana_stand_01", Vector3(-15.2, 0.0, -6.0), 90.0, 1.0)
	for p in [Vector3(-7, 0, -9), Vector3(7, 0, -9), Vector3(-7, 0, 9), Vector3(7, 0, 9)]:
		_lantern(parent, p)
	for p in [Vector3(-13, 0, -10.5), Vector3(13, 0, 10.5)]:
		_tree(parent, "maple", p, 5.0, p.x * 17.0)


static func _village(parent: Node3D) -> void:
	# Mountain-village street: Shirakawa-go gassho farmhouses (CC-BY "Shirakawago Village Set House 1"
	# by Lokomotto), gables to the street, varied in yaw and scale so repetition does not read.
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for side in [-1, 1]:
		var row := 0
		for z in [22.0, 37.0, 52.0, 66.0]:
			var height := rng.randf_range(9.6, 11.2)
			var yaw := (90.0 if side < 0 else -90.0) + rng.randf_range(-7.0, 7.0)
			AssetKit.place(parent, "farmhouse", Vector3(side * 11.2, 0, z + rng.randf_range(-1.0, 1.0)), height, yaw)
			_lantern(parent, Vector3(side * 4.6, 0, z + 7.0))
			if (row + (1 if side > 0 else 0)) % 2 == 0: # Blossom between alternate houses.
				_tree(parent, "cherry" if rng.randf() < 0.6 else "maple", Vector3(side * 17.5, 0, z + 7.2), rng.randf_range(6.0, 7.5), rng.randf() * 360.0)
			row += 1
	# Village fence and the far landmark: a five-storey pagoda (CC-BY "Japanese Temple" by Jainesh Pathak).
	for side in [-1, 1]:
		WorldKit.compound_wall(parent, Vector3(side * 22, 0, 13), Vector3(side * 22, 0, 80), 2.4)
		WorldKit.compound_wall(parent, Vector3(side * 16, 0, 13), Vector3(side * 22, 0, 13), 2.4)
	AssetKit.place(parent, "pagoda", Vector3(0, 0, 73.5), 17.0, 180.0)
	# Square by the well: benches, buckets; the sanctuary's social space, framed by blossom.
	WorldKit.cylinder(parent, Vector3(0, 0, 32), 1.1, 0.8, WorldKit.material("japanese_stone_wall", 1.0), true, 1.1, 10)
	WorldKit.prop(parent, "wooden_bucket_01", Vector3(1.3, 0, 31.2), 20.0)
	WorldKit.prop(parent, "painted_wooden_bench", Vector3(-2.6, 0, 30.5), 90.0, 1.0, Vector3(0.5, 0.5, 1.6))
	WorldKit.prop(parent, "painted_wooden_bench", Vector3(2.6, 0, 33.5), -90.0, 1.0, Vector3(0.5, 0.5, 1.6))
	WorldKit.prop(parent, "wooden_crate_02", Vector3(-2.8, 0, 52), 10.0, 1.0, Vector3(0.8, 0.8, 0.8))
	_tree(parent, "cherry", Vector3(-4.5, 0, 28.0), 7.0, 40.0)
	_tree(parent, "cherry", Vector3(4.8, 0, 36.5), 6.5, 200.0)
	_lantern(parent, Vector3(-2.8, 0, 64.5))
	_lantern(parent, Vector3(2.8, 0, 64.5))


## Stone toro (CC-BY "Japanese Stone Lantern" by Sahir Virmani) with a warm light in its firebox.
static func _lantern(parent: Node3D, at: Vector3) -> void:
	AssetKit.place(parent, "stone_lantern", at, 1.9, 0.0, true, Vector3(0.7, 1.0, 0.7))
	if AssetKit.visuals_enabled():
		WorldKit.light(parent, at + Vector3(0, 1.25, 0), WorldKit.LANTERN_LIGHT, 1.1, 5.5)


## Ornamental tree (CC-BY maple by endlessvoidmc / cherry by Sereib); trunk-sized collider only.
static func _tree(parent: Node3D, key: String, at: Vector3, height: float, yaw: float) -> void:
	AssetKit.place(parent, key, at, height, yaw, true, Vector3(0.08, 0.5, 0.08))


## Torii model with colliders on its two pillars only, so the gateway stays walkable.
static func _torii(parent: Node3D, at: Vector3, height: float, yaw: float) -> void:
	AssetKit.place(parent, "torii", at, height, yaw, false)
	var span := AssetKit.footprint("torii", height).x
	for sx in [-1, 1]:
		var body := StaticBody3D.new()
		body.collision_layer = FighterBody.WORLD_LAYER
		body.collision_mask = 0
		body.position = at + Basis(Vector3.UP, deg_to_rad(yaw)) * Vector3(sx * span * 0.37, height * 0.5, 0)
		var shape := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = 0.32
		cyl.height = height
		shape.shape = cyl
		body.add_child(shape)
		parent.add_child(body)


## Distant skyline landmark (CC-BY "Japanese Castle" by Zorodroger) on the northern ridge.
static func _castle(parent: Node3D) -> void:
	if not AssetKit.visuals_enabled():
		return
	var at := Vector3(58, 0, -178)
	var noise := FastNoiseLite.new()
	noise.seed = 7
	noise.frequency = 0.012
	noise.fractal_octaves = 4
	var ridges := FastNoiseLite.new()
	ridges.seed = 21
	ridges.noise_type = FastNoiseLite.TYPE_CELLULAR
	ridges.frequency = 0.006
	at.y = ProvinceTerrain.height_at(Vector2(at.x, at.z), RegionMap.BOUNDS.grow(ProvinceTerrain.FLAT_MARGIN), noise, ridges) - 1.0
	AssetKit.place(parent, "castle", at, 34.0, 200.0, false)


static func _approach_and_torii(parent: Node3D) -> void:
	# The approach is the sanctuary buffer; the torii is where the rules change (§1.3, §4).
	_torii(parent, Vector3(0, 0, RegionMap.BOUNDARY_TORII_Z), 6.0, 0.0)
	for side in [-1, 1]:
		WorldKit.compound_wall(parent, Vector3(side * 3.6, 0, -13.5), Vector3(side * 3.6, 0, -25.5), 1.4)
		_lantern(parent, Vector3(side * 2.4, 0, -24.0))
	# Return waystone on the frontier side, lit so the way back is readable at night (§9).
	WorldKit.cylinder(parent, Vector3(-3.8, 0, -30.5), 0.45, 1.6, WorldKit.material("japanese_stone_wall", 0.8), true, 0.35, 6)
	WorldKit.light(parent, Vector3(-3.8, 2.0, -30.5), Color(0.5, 0.9, 0.65), 1.4, 6.0)


static func _bamboo_road(parent: Node3D) -> void:
	var keep_clear := [
		[Rect2(-3.5, -60, 7, 33)], # road north
		[Vector2(0, -58), 10.5], # duel clearing
		[Rect2(-1, -78, 28, 12)], # road east to the ruin
		[Rect2(12, -94, 28, 28)], # ruin site
		[Vector2(-3.8, -30.5), 2.5], # return waystone
	]
	WorldKit.bamboo_grove(parent, Rect2(-39, -99, 78, 70), 300, keep_clear, 42)
	# Duel clearing: open ellipse with known exits, a little cover at its rim (§5 pattern 1).
	WorldKit.prop(parent, "stone_fire_pit", Vector3(6.5, 0, -63), 0.0, 1.0, Vector3(1.4, 0.5, 1.4))
	WorldKit.prop(parent, "tree_stump_01", Vector3(-7.5, 0, -54), 30.0, 1.0, Vector3(1.0, 0.6, 1.0))
	WorldKit.prop(parent, "rock_07", Vector3(-6.5, 0, -63.5), 60.0, 1.0, Vector3(1.6, 1.0, 1.4))
	WorldKit.prop(parent, "rock_09", Vector3(8, 0, -52), 200.0, 1.0, Vector3(1.4, 0.9, 1.4))
	for p in [Vector3(-4, 0, -40), Vector3(4.5, 0, -46), Vector3(-3, 0, -66), Vector3(9, 0, -70)]:
		WorldKit.prop(parent, "fern_02", p, p.x * 40.0)
		WorldKit.prop(parent, "shrub_03", p + Vector3(1.2, 0, 0.8), p.z * 13.0)
	# Mist pools in the grove (cosmetic, quality-scaled; never hides fighters more than fog does).
	var fog := FogVolume.new()
	fog.size = Vector3(70, 3, 60)
	fog.position = Vector3(0, 1.0, -65)
	var fog_mat := FogMaterial.new()
	fog_mat.density = 0.02
	fog_mat.albedo = Color(0.7, 0.75, 0.8)
	fog.material = fog_mat
	parent.add_child(fog)


static func _ruin(parent: Node3D) -> void:
	# Small ruin: broken compound walls, a fallen torii and rubble (§13 P0 "small ruin").
	var stone := WorldKit.material("japanese_stone_wall", 1.6, Color(0.8, 0.8, 0.78))
	var c := Vector3(26, 0, -80)
	WorldKit.box(parent, c + Vector3(0, 0.3, 0), Vector3(16, 0.6, 14), stone)
	WorldKit.box(parent, c + Vector3(-7.5, 1.6, -2), Vector3(1.0, 2.6, 9), stone)
	WorldKit.box(parent, c + Vector3(7.5, 1.0, 1), Vector3(1.0, 1.4, 8), stone)
	WorldKit.box(parent, c + Vector3(-2, 2.2, -6.5), Vector3(8, 3.8, 1.0), stone)
	WorldKit.box(parent, c + Vector3(4.5, 1.1, -6.5), Vector3(3, 1.6, 1.0), stone)
	for p in [Vector3(-4, 0.6, 3), Vector3(3, 0.6, 3), Vector3(-4, 0.6, -3), Vector3(3, 0.6, -3)]:
		WorldKit.cylinder(parent, c + p, 0.3, 1.0 + abs(p.x) * 0.45, WorldKit.material("japanese_cedar_bark", 1.0, Color(0.35, 0.3, 0.28)), true)
	WorldKit.torii(parent, c + Vector3(0, 0.6, 6.2), 4.6, 4.2, 0.0, true)
	WorldKit.prop(parent, "rock_moss_set_01", c + Vector3(5, 0.6, -3), 40.0, 1.0)
	WorldKit.prop(parent, "wooden_crate_02", c + Vector3(-5, 0.6, 1.5), 70.0, 1.0, Vector3(0.8, 0.8, 0.8))
	WorldKit.stone_lantern(parent, c + Vector3(0, 0.6, -4.5), true)
	WorldKit.light(parent, c + Vector3(0, 2.5, 0), Color(0.55, 0.75, 1.0), 1.0, 10.0) # cyan ghost residue


static func _ambience(parent: Node3D) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var stream: AudioStream = load(AMBIENCE)
	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	for p in [Vector3(0, 2, 40), Vector3(0, 2, -55), Vector3(0, 2, 0)]:
		var player := AudioStreamPlayer3D.new()
		player.stream = stream
		player.bus = &"Ambience"
		player.unit_size = 18.0
		player.max_db = -6.0
		player.position = p
		player.autoplay = true
		parent.add_child(player)
