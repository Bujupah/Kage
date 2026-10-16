class_name ProvinceTerrain
extends RefCounted
## Terrain for the Shrouded Province (Terrain3D, MIT GDExtension). Client-side and visual only:
## the playable slice stays perfectly flat (fair sword combat, ENVIRONMENT.md §4) and keeps its
## simple floor collider, so the headless server never needs the extension. Beyond the boundary
## walls the land rises into forested hills and mountains for a real horizon.
##
## Layers (packed by tools/pack_terrain_textures.gd): 0 grass, 1 forest floor, 2 mossy rock
## (auto-applied on slopes), 3 raked earth. Grass cards come from the Terrain3D instancer, which
## culls and LODs them per cell.

const TEX := "res://assets/terrain/%s_%s.webp"
const LAYERS := ["leafy_grass", "forest_leaves_02", "mossy_rock", "raked_dirt"]
const UV_SCALES := [0.18, 0.22, 0.08, 0.2]
const SIZE := 512 ## Metres per side (1 m vertex spacing).
const ORIGIN := Vector3(-256, 0, -256) ## Must sit on the 256 m region grid; covers the slice plus ~170 m of hills.
const FLAT_MARGIN := 1.0 ## Metres past the boundary before the land starts to rise.
const GRASS_SPACING := 0.9


static func available() -> bool:
	return ClassDB.class_exists("Terrain3D") and DisplayServer.get_name() != "headless"


static func build(parent: Node3D) -> Node3D:
	if not available():
		return null
	var terrain: Node3D = ClassDB.instantiate("Terrain3D")
	terrain.name = "Terrain3D"
	parent.add_child(terrain)
	terrain.set("region_size", 256)
	terrain.set("vertex_spacing", 1.0)
	terrain.call("set_collision_mode", 0) # Visual only; the slice has its own flat collider.

	var assets: Resource = ClassDB.instantiate("Terrain3DAssets")
	for i in LAYERS.size():
		var ta: Resource = ClassDB.instantiate("Terrain3DTextureAsset")
		ta.set("name", LAYERS[i])
		ta.set("albedo_texture", load(TEX % [LAYERS[i], "alb_h"]))
		ta.set("normal_texture", load(TEX % [LAYERS[i], "nrm_r"]))
		ta.set("uv_scale", UV_SCALES[i])
		ta.set("detiling_rotation", 0.15)
		assets.call("set_texture", i, ta)
	assets.call("set_mesh_asset", 0, _grass_asset())
	terrain.set("assets", assets)

	var mat: Resource = terrain.get("material")
	mat.set("world_background", 0) # NONE: no infinite checkered plane beyond the regions.
	mat.set("auto_shader", true)
	mat.call("set_shader_param", "auto_base_texture", 0)
	mat.call("set_shader_param", "auto_overlay_texture", 2)
	mat.call("set_shader_param", "auto_slope", 4.0) # Rock only where it is genuinely steep.
	mat.call("set_shader_param", "blend_sharpness", 0.9)

	var data: Object = terrain.get("data")
	data.call("import_images", [heightmap(), null, null], ORIGIN, 0.0, 1.0)
	_paint(data)
	_scatter_grass(terrain, data)
	_cedar_forest(parent, data)
	return terrain


## Height field: 0 inside the walls (+ margin), rising with distance into noisy hills.
static func heightmap() -> Image:
	var img := Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RF)
	var noise := FastNoiseLite.new()
	noise.seed = 7
	noise.frequency = 0.012
	noise.fractal_octaves = 4
	var ridges := FastNoiseLite.new()
	ridges.seed = 21
	ridges.noise_type = FastNoiseLite.TYPE_CELLULAR
	ridges.frequency = 0.006
	var flat := RegionMap.BOUNDS.grow(FLAT_MARGIN)
	for y in SIZE:
		for x in SIZE:
			img.set_pixel(x, y, Color(height_at(Vector2(ORIGIN.x + x, ORIGIN.z + y), flat, noise, ridges), 0, 0))
	return img


static func height_at(p: Vector2, flat: Rect2, noise: FastNoiseLite, ridges: FastNoiseLite) -> float:
	var closest := Vector2(clampf(p.x, flat.position.x, flat.end.x), clampf(p.y, flat.position.y, flat.end.y))
	var d := p.distance_to(closest)
	if d <= 0.0:
		return -0.02 # Just under the kit's ground layers.
	var rise := smoothstep(0.0, 22.0, d) # Hillsides start right at the boundary: the land is the wall.
	var hills := (noise.get_noise_2d(p.x, p.y) * 0.5 + 0.5) * 18.0
	var peaks := (1.0 - absf(ridges.get_noise_2d(p.x, p.y))) * smoothstep(60.0, 180.0, d) * 55.0
	return rise * (4.0 + hills) + peaks + d * 0.06


## Forest floor under the bamboo road; grass everywhere else (slopes go rocky automatically).
static func _paint(data: Object) -> void:
	for z in range(-100, -26):
		for x in range(-40, 41):
			data.call("set_control_base_id", Vector3(x, 0, z), 1)
	data.call("update_maps", 0, true, false)


static func _scatter_grass(terrain: Node3D, data: Object) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var xforms: Array[Transform3D] = []
	# Verges along the village fence and the approach, and the open frontier floor.
	var areas := [Rect2(-21.5, 14, 4.0, 66), Rect2(17.5, 14, 4.0, 66), Rect2(-11, -26.5, 6.5, 13),
		Rect2(4.5, -26.5, 6.5, 13), Rect2(-39, -99, 78, 70)]
	for a: Rect2 in areas:
		var count := int(a.get_area() / (GRASS_SPACING * GRASS_SPACING) * (0.35 if a.size.y > 60 and a.size.x > 60 else 1.0))
		for i in count:
			var p := Vector3(rng.randf_range(a.position.x, a.end.x), 0, rng.randf_range(a.position.y, a.end.y))
			if _on_path(p):
				continue
			var s := rng.randf_range(0.7, 1.25)
			xforms.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s, s)), p))
	terrain.get("instancer").call("add_transforms", 0, xforms)


static func _on_path(p: Vector3) -> bool:
	var q := Vector2(p.x, p.z)
	for r: Rect2 in [Rect2(-3.5, -60, 7, 33), Rect2(-1, -78, 28, 12), Rect2(12, -94, 28, 28)]:
		if r.has_point(q):
			return true
	return Vector2(0, -58).distance_to(q) < 9.0


static func _grass_asset() -> Resource:
	var ma: Resource = ClassDB.instantiate("Terrain3DMeshAsset")
	ma.set("name", "Grass")
	ma.set("generated_type", 1) # TYPE_TEXTURE_CARD
	ma.set("height_offset", 0.0)
	ma.set("visibility_range", 55.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = _grass_texture()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mat.alpha_scissor_threshold = 0.5
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.backlight_enabled = true
	mat.backlight = Color(0.35, 0.45, 0.15)
	mat.roughness = 0.85
	ma.set("material_override", mat)
	return ma


## Procedural tuft of blades (alpha) so the cards read as grass, not coloured quads.
static func _grass_texture() -> ImageTexture:
	var img := Image.create_empty(128, 128, true, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for b in 26:
		var base_x := rng.randf_range(10, 118)
		var lean := rng.randf_range(-0.45, 0.45)
		var height := rng.randf_range(55, 125)
		var width := rng.randf_range(2.0, 4.0)
		var col := Color.from_hsv(rng.randf_range(0.19, 0.27), rng.randf_range(0.45, 0.7), rng.randf_range(0.28, 0.5))
		for t in int(height):
			var k := float(t) / height
			var cx := base_x + lean * t * (0.3 + k)
			var w := width * (1.0 - k)
			for dx in range(int(cx - w), int(cx + w) + 1):
				if dx >= 0 and dx < 128:
					img.set_pixel(dx, 127 - t, col.lightened(k * 0.35))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


## Hillside pine forest (CC-BY pack by LOLIPOP via PineForest: LOD1 → LOD2 → billboard per chunk).
static func _cedar_forest(parent: Node3D, data: Object) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var flat := RegionMap.BOUNDS.grow(FLAT_MARGIN + 4.0)
	var positions: Array[Vector3] = []
	var tries := 0
	while positions.size() < 1900 and tries < 20000:
		tries += 1
		var p := Vector2(rng.randf_range(ORIGIN.x + 4, ORIGIN.x + SIZE - 4), rng.randf_range(ORIGIN.z + 4, ORIGIN.z + SIZE - 4))
		var closest := Vector2(clampf(p.x, flat.position.x, flat.end.x), clampf(p.y, flat.position.y, flat.end.y))
		var d := p.distance_to(closest)
		if d < 5.0 or d > 210.0:
			continue
		var h: float = data.call("get_height", Vector3(p.x, 0, p.y))
		if is_nan(h) or h > 52.0:
			continue # Bare ridgelines above the tree line.
		positions.append(Vector3(p.x, h - 0.4, p.y))
	PineForest.build(parent, positions, 5)
