class_name WorldKit
extends RefCounted
## Greybox-plus environment kit (ENVIRONMENT.md §3): Edo-inspired modules assembled from primitives
## with CC0 Poly Haven PBR materials. Collision is always a simple box/cylinder separate from the
## visual mesh (§10), on the WORLD layer the camera spring arm and fighters collide with.
##
## Materials use world-space triplanar mapping, so a block of any size tiles at a real-world scale
## without per-module UVs.

const TEX_DIR := "res://assets/third_party/polyhaven/textures/%s/%s_%s_1k.jpg"
const PROPS_DIR := "res://assets/third_party/polyhaven/models/%s/%s.gltf"

const VERMILION := Color(0.72, 0.16, 0.09)
const LACQUER := Color(0.06, 0.05, 0.05)
const PAPER := Color(0.93, 0.88, 0.76)
const LANTERN_LIGHT := Color(1.0, 0.62, 0.32)

const OCCLUDER_MIN_HEIGHT := 1.6
const OCCLUDER_MIN_WIDTH := 4.0
const BAMBOO_CELL := 16.0 ## Grove instancing chunk: culls and fades per cell, not per grove.

static var _materials: Dictionary = {}
static var _props: Dictionary = {}


## PBR material from a Poly Haven texture set; `metres` is the size one texture repeat covers.
static func material(tex_id: String, metres: float = 2.0, tint: Color = Color.WHITE) -> StandardMaterial3D:
	var key := "%s@%s@%s" % [tex_id, metres, tint.to_html()]
	if _materials.has(key):
		return _materials[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint
	if not AssetKit.visuals_enabled():
		_materials[key] = mat # Headless server: geometry and colliders only, never texture loads.
		return mat
	mat.albedo_texture = load(TEX_DIR % [tex_id, tex_id, "diff"])
	var arm_path := TEX_DIR % [tex_id, tex_id, "arm"]
	if ResourceLoader.exists(arm_path):
		var arm: Texture2D = load(arm_path)
		mat.roughness_texture = arm
		mat.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
		mat.ao_enabled = true
		mat.ao_texture = arm
		mat.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	var nor_path := TEX_DIR % [tex_id, tex_id, "nor_gl"]
	if ResourceLoader.exists(nor_path):
		mat.normal_enabled = true
		mat.normal_texture = load(nor_path)
	mat.uv1_triplanar = true
	mat.uv1_world_triplanar = true
	mat.uv1_scale = Vector3.ONE / metres
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_materials[key] = mat
	return mat


static func flat(color: Color, roughness: float = 0.8, emission: float = 0.0) -> StandardMaterial3D:
	var key := "flat@%s@%s@%s" % [color.to_html(), roughness, emission]
	if _materials.has(key):
		return _materials[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	if emission > 0.0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = emission
	_materials[key] = mat
	return mat


# --- Primitives ----------------------------------------------------------------------------------

## Visual box; with `solid` it also gets a matching static collider on the WORLD layer.
static func box(parent: Node3D, center: Vector3, size: Vector3, mat: Material, solid: bool = true,
		yaw_deg: float = 0.0) -> Node3D:
	var mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mesh.mesh = bm
	mesh.material_override = mat
	mesh.set_meta("batch", true)
	if not solid:
		mesh.position = center
		mesh.rotation_degrees.y = yaw_deg
		parent.add_child(mesh)
		return mesh
	var body := StaticBody3D.new()
	body.collision_layer = FighterBody.WORLD_LAYER
	body.collision_mask = 0
	body.position = center
	body.rotation_degrees.y = yaw_deg
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	shape.shape = bs
	body.add_child(shape)
	body.add_child(mesh)
	if size.y >= OCCLUDER_MIN_HEIGHT and maxf(size.x, size.z) >= OCCLUDER_MIN_WIDTH:
		# Big solid blocks hide what is behind them (houses, walls): skip drawing it.
		var occ := OccluderInstance3D.new()
		var bo := BoxOccluder3D.new()
		bo.size = size * 0.92
		occ.occluder = bo
		body.add_child(occ)
	parent.add_child(body)
	return body


static func cylinder(parent: Node3D, base: Vector3, radius: float, height: float, mat: Material,
		solid: bool = true, top_radius: float = -1.0, sides: int = 12) -> Node3D:
	var mesh := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.bottom_radius = radius
	cm.top_radius = radius if top_radius < 0.0 else top_radius
	cm.height = height
	cm.radial_segments = sides
	cm.rings = 1
	mesh.mesh = cm
	mesh.material_override = mat
	mesh.set_meta("batch", true)
	var center := base + Vector3.UP * height * 0.5
	if not solid:
		mesh.position = center
		parent.add_child(mesh)
		return mesh
	var body := StaticBody3D.new()
	body.collision_layer = FighterBody.WORLD_LAYER
	body.collision_mask = 0
	body.position = center
	var shape := CollisionShape3D.new()
	var cs := CylinderShape3D.new()
	cs.radius = maxf(radius, cm.top_radius)
	cs.height = height
	shape.shape = cs
	body.add_child(shape)
	body.add_child(mesh)
	parent.add_child(body)
	return body


## A Poly Haven prop instance (cached scene); `collider` adds a box of that size at its base.
static func prop(parent: Node3D, id: String, at: Vector3, yaw_deg: float = 0.0, scale: float = 1.0,
		collider: Vector3 = Vector3.ZERO) -> Node3D:
	var node: Node3D
	if AssetKit.visuals_enabled():
		if not _props.has(id):
			_props[id] = load(PROPS_DIR % [id, id])
		node = (_props[id] as PackedScene).instantiate()
	else:
		node = Node3D.new() # Headless server: the collider below is all that matters.
	node.position = at
	node.rotation_degrees.y = yaw_deg
	node.scale = Vector3.ONE * scale
	parent.add_child(node)
	if collider != Vector3.ZERO:
		var body := StaticBody3D.new()
		body.collision_layer = FighterBody.WORLD_LAYER
		body.collision_mask = 0
		body.position = at + Vector3.UP * collider.y * 0.5
		body.rotation_degrees.y = yaw_deg
		var shape := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = collider
		shape.shape = bs
		body.add_child(shape)
		parent.add_child(body)
	return node


static func light(parent: Node3D, at: Vector3, color: Color = LANTERN_LIGHT, energy: float = 1.6,
		reach: float = 7.0) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = color
	l.light_energy = energy
	l.omni_range = reach
	l.omni_attenuation = 1.4
	l.position = at
	l.distance_fade_enabled = true
	l.distance_fade_begin = 28.0
	l.distance_fade_length = 10.0
	parent.add_child(l)
	return l


# --- Modules -------------------------------------------------------------------------------------

## Timber-and-plaster house (village kit): stone footing, cedar posts, plaster infill, shutter band,
## overhanging gable roof of grey tiles. `size` is the footprint (x, height-to-eaves, z); the gable
## ridge runs along local X. Returns the module root (for hanging lanterns).
static func house(parent: Node3D, center: Vector3, size: Vector3, yaw_deg: float = 0.0,
		thatched: bool = false) -> Node3D:
	var root := Node3D.new()
	root.position = center
	root.rotation_degrees.y = yaw_deg
	parent.add_child(root)
	var w := size.x
	var h := size.y
	var d := size.z
	var stone := material("japanese_stone_wall", 1.6)
	var plaster := material("white_plaster_rough_01", 2.5, Color(0.92, 0.89, 0.82))
	var timber := material("japanese_cedar_planks", 1.5, Color(0.55, 0.45, 0.38))
	var post_mat := material("japanese_cedar_bark", 1.2, Color(0.45, 0.36, 0.3))
	var roof := material("thatch_roof_angled", 2.0) if thatched else material("grey_roof_tiles", 1.5)
	box(root, Vector3(0, 0.2, 0), Vector3(w + 0.3, 0.4, d + 0.3), stone)
	box(root, Vector3(0, 0.4 + h * 0.5, 0), Vector3(w, h, d), plaster)
	# Lower timber skirt and the shutter band read as Edo machiya street fronts.
	box(root, Vector3(0, 0.4 + h * 0.18, 0), Vector3(w + 0.04, h * 0.36, d + 0.04), timber, false)
	box(root, Vector3(0, 0.4 + h * 0.62, 0), Vector3(w + 0.06, 0.18, d + 0.06), timber, false)
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			box(root, Vector3(sx * w * 0.5, 0.4 + h * 0.5, sz * d * 0.5), Vector3(0.26, h, 0.26), post_mat, false)
	# Gable roof: two slabs pitched along local X, overhanging all round.
	var pitch := deg_to_rad(28.0)
	var half_span := d * 0.5 + 0.7
	var slab_len := half_span / cos(pitch)
	var rise := half_span * tan(pitch)
	var eave_y := 0.4 + h
	for side in [-1, 1]:
		var slab := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(w + 1.4, 0.22, slab_len)
		slab.mesh = bm
		slab.material_override = roof
		slab.set_meta("batch", true)
		slab.position = Vector3(0, eave_y + rise * 0.5, side * half_span * 0.5)
		slab.rotation.x = side * pitch
		root.add_child(slab)
	box(root, Vector3(0, eave_y + rise + 0.08, 0), Vector3(w + 1.5, 0.22, 0.32), material("grey_roof_tiles", 1.0, Color(0.6, 0.6, 0.62)), false)
	# Gable end triangles filled with dark timber.
	for sx in [-1, 1]:
		var tri := MeshInstance3D.new()
		var pm := PrismMesh.new()
		pm.size = Vector3(d, rise, 0.2)
		tri.mesh = pm
		tri.material_override = timber
		tri.set_meta("batch", true)
		tri.position = Vector3(sx * w * 0.5, eave_y + rise * 0.5, 0)
		tri.rotation_degrees.y = 90
		root.add_child(tri)
	return root


## Red paper lantern (chōchin) hanging at `at`, with a warm light.
static func paper_lantern(parent: Node3D, at: Vector3, with_light: bool = true) -> void:
	var body := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.22
	sm.height = 0.5
	body.mesh = sm
	body.material_override = flat(Color(0.85, 0.22, 0.12), 0.9, 1.4)
	body.set_meta("batch", true)
	body.position = at
	parent.add_child(body)
	for dy in [-0.25, 0.25]:
		var cap := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.1
		cm.bottom_radius = 0.1
		cm.height = 0.05
		cap.mesh = cm
		cap.material_override = flat(LACQUER, 0.4)
		cap.set_meta("batch", true)
		cap.position = at + Vector3(0, dy, 0)
		parent.add_child(cap)
	if with_light:
		light(parent, at + Vector3(0, -0.3, 0), LANTERN_LIGHT, 1.3, 6.0)


## Stone lantern (tōrō): base, shaft, lit firebox, pyramidal cap and finial.
static func stone_lantern(parent: Node3D, at: Vector3, lit: bool = true) -> void:
	var stone := material("mossy_rock", 0.8, Color(0.75, 0.75, 0.72))
	cylinder(parent, at, 0.32, 0.25, stone, true, 0.28, 8)
	cylinder(parent, at + Vector3(0, 0.25, 0), 0.12, 0.7, stone, false, 0.12, 8)
	box(parent, at + Vector3(0, 1.02, 0), Vector3(0.42, 0.14, 0.42), stone, false)
	box(parent, at + Vector3(0, 1.24, 0), Vector3(0.32, 0.3, 0.32), flat(Color(1.0, 0.7, 0.4), 0.9, 2.2 if lit else 0.0), false)
	cylinder(parent, at + Vector3(0, 1.39, 0), 0.42, 0.22, stone, false, 0.05, 4)
	cylinder(parent, at + Vector3(0, 1.6, 0), 0.06, 0.12, stone, false, 0.02, 6)
	if lit:
		light(parent, at + Vector3(0, 1.25, 0), LANTERN_LIGHT, 1.2, 5.0)


## Torii gate across local X; `span` between posts. Vermilion lacquer, black kasagi.
static func torii(parent: Node3D, center: Vector3, span: float = 5.0, height: float = 4.6,
		yaw_deg: float = 0.0, broken: bool = false) -> Node3D:
	var root := Node3D.new()
	root.position = center
	root.rotation_degrees.y = yaw_deg
	parent.add_child(root)
	var red := flat(VERMILION, 0.55)
	var black := flat(LACQUER, 0.4)
	cylinder(root, Vector3(-span * 0.5, 0, 0), 0.24, height, red, true, 0.21)
	var right_h := height * 0.55 if broken else height
	cylinder(root, Vector3(span * 0.5, 0, 0), 0.24, right_h, red, true, 0.21)
	for sx in [-1, 1]:
		cylinder(root, Vector3(sx * span * 0.5, 0, 0), 0.34, 0.4, black, false, 0.3)
	if broken:
		# Fallen kasagi resting against the stump, a sign of the danger beyond.
		var beam := box(root, Vector3(span * 0.15, 0.9, 0.6), Vector3(span + 1.6, 0.36, 0.5), red, true)
		beam.rotation_degrees.z = 14.0
		return root
	box(root, Vector3(0, height * 0.78, 0), Vector3(span + 0.9, 0.3, 0.32), red, false) # nuki
	box(root, Vector3(0, height + 0.12, 0), Vector3(span + 2.0, 0.36, 0.55), red, false) # shimaki
	box(root, Vector3(0, height + 0.38, 0), Vector3(span + 2.6, 0.2, 0.75), black, false) # kasagi
	box(root, Vector3(0, height * 0.9, 0), Vector3(0.5, height * 0.2 - 0.2, 0.24), black, false) # gakuzuka
	return root


## Low compound wall with a tiled cap (dojo and village perimeters).
static func compound_wall(parent: Node3D, from: Vector3, to: Vector3, height: float = 1.9) -> void:
	# Tsuiji-bei: dressed-stone footing, whitewashed plaster between dark cedar posts, a timber
	# band under the eaves and a gabled tile cap that overhangs both faces. One collider for it all.
	var mid := (from + to) * 0.5
	var length := from.distance_to(to)
	var yaw := rad_to_deg(atan2(to.x - from.x, to.z - from.z)) + 90.0
	box(parent, mid + Vector3(0, 0.25, 0), Vector3(length, 0.5, 0.75), material("japanese_stone_wall", 1.0), true, yaw)
	var body := box(parent, mid + Vector3(0, 0.5 + height * 0.5, 0), Vector3(length, height, 0.42),
			material("white_plaster_rough_01", 2.0, Color(0.97, 0.95, 0.9)), true, yaw)
	if not AssetKit.visuals_enabled():
		return
	var timber := material("japanese_cedar_planks", 1.0, Color(0.32, 0.24, 0.2))
	var tiles := material("grey_roof_tiles", 0.8, Color(0.62, 0.64, 0.68))
	var top := height * 0.5
	# Posts every ~2.4 m, standing proud of both faces.
	var bays := maxi(1, roundi(length / 2.4))
	for k in bays + 1:
		var x := -length * 0.5 + length * float(k) / float(bays)
		_local_box(body, Vector3(clampf(x, -length * 0.5 + 0.11, length * 0.5 - 0.11), 0, 0), Vector3(0.22, height, 0.5), timber)
	_local_box(body, Vector3(0, top - 0.14, 0), Vector3(length, 0.18, 0.5), timber)
	# Gabled cap: two pitched tile slabs meeting at a ridge beam.
	for side in [-1, 1]:
		var slab := _local_box(body, Vector3(0, top + 0.16, side * 0.34), Vector3(length + 0.3, 0.1, 0.78), tiles)
		slab.rotation_degrees.x = side * 24.0
	_local_box(body, Vector3(0, top + 0.34, 0), Vector3(length + 0.36, 0.16, 0.2), tiles)


## Non-colliding box parented to `parent` at a local offset (batched with the level's statics).
static func _local_box(parent: Node3D, offset: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mesh.mesh = bm
	mesh.material_override = mat
	mesh.set_meta("batch", true)
	mesh.position = offset
	parent.add_child(mesh)
	return mesh


## Dense bamboo: stalks and canopy leaf cards as chunked MultiMeshes, and one capsule collider per
## clump so groves are real cover (no invisible gaps, §3).
static func bamboo_grove(parent: Node3D, area: Rect2, clumps: int, keep_clear: Array, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var positions: Array[Vector3] = []
	var tries := 0
	while positions.size() < clumps and tries < clumps * 20:
		tries += 1
		var p := Vector3(rng.randf_range(area.position.x, area.end.x), 0, rng.randf_range(area.position.y, area.end.y))
		var blocked := false
		for c: Array in keep_clear: # [Vector2 center, radius] or [Rect2]
			if c[0] is Rect2:
				blocked = (c[0] as Rect2).grow(0.6).has_point(Vector2(p.x, p.z))
			else:
				blocked = Vector2(p.x, p.z).distance_to(c[0]) < float(c[1])
			if blocked:
				break
		if not blocked:
			positions.append(p)

	var stalk_mesh := CylinderMesh.new()
	stalk_mesh.top_radius = 0.045
	stalk_mesh.bottom_radius = 0.065
	stalk_mesh.height = 1.0
	stalk_mesh.radial_segments = 7
	stalk_mesh.rings = 1
	stalk_mesh.material = _bamboo_material()
	var leaf_mesh := QuadMesh.new()
	leaf_mesh.size = Vector2(2.6, 2.6)
	leaf_mesh.material = _leaf_material()

	var stalk_xforms: Array[Transform3D] = []
	var leaf_xforms: Array[Transform3D] = []
	var collider := StaticBody3D.new()
	collider.collision_layer = FighterBody.WORLD_LAYER
	collider.collision_mask = 0
	parent.add_child(collider)
	for p in positions:
		var count := rng.randi_range(4, 8)
		for i in count:
			var off := Vector3(rng.randf_range(-0.45, 0.45), 0, rng.randf_range(-0.45, 0.45))
			var height := rng.randf_range(6.5, 10.5)
			var lean := Basis.from_euler(Vector3(rng.randf_range(-0.07, 0.07), 0, rng.randf_range(-0.07, 0.07)))
			stalk_xforms.append(Transform3D(lean.scaled(Vector3(1, height, 1)), p + off + lean * Vector3.UP * height * 0.5))
			for k in 1:
				var top := p + off + lean * Vector3.UP * height * rng.randf_range(0.7, 0.92)
				var b := Basis.from_euler(Vector3(rng.randf_range(-0.5, 0.5), rng.randf_range(0, TAU), rng.randf_range(-0.3, 0.3)))
				leaf_xforms.append(Transform3D(b, top))
		var shape := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = 0.55
		cyl.height = 4.0
		shape.shape = cyl
		shape.position = p + Vector3.UP * 2.0
		collider.add_child(shape)
	if not AssetKit.visuals_enabled():
		return # The server needs the clump colliders only.
	_emit_chunked(parent, stalk_mesh, stalk_xforms, rng, 130.0, true)
	# Canopy: real leaf clusters from the CC-BY "Free Bamboo Set" (JonhGillessen), one MultiMesh per
	# variant per cell; flat procedural cards only if the pack is missing.
	var clusters := _bamboo_leaf_meshes()
	if clusters.is_empty():
		_emit_chunked(parent, leaf_mesh, leaf_xforms, rng, 95.0, true)
		return
	var by_variant: Array = []
	for _v in clusters.size():
		by_variant.append([] as Array[Transform3D])
	for x in leaf_xforms:
		var k := rng.randf_range(2.4, 3.4)
		(by_variant[rng.randi_range(0, clusters.size() - 1)] as Array[Transform3D]).append(
				Transform3D(x.basis.orthonormalized().scaled(Vector3.ONE * k), x.origin))
	for v in clusters.size():
		_emit_chunked(parent, clusters[v], by_variant[v], rng, 80.0, true)


## One MultiMeshInstance3D per BAMBOO_CELL, so frustum culling, shadow cascades and distance
## fades work per chunk instead of loading the whole grove into every pass.
static func _emit_chunked(parent: Node3D, mesh: Mesh, xforms: Array[Transform3D], rng: RandomNumberGenerator,
		fade_end: float, shadows: bool) -> void:
	var cells := {}
	for x in xforms:
		var key := Vector2i(floori(x.origin.x / BAMBOO_CELL), floori(x.origin.z / BAMBOO_CELL))
		if not cells.has(key):
			cells[key] = []
		(cells[key] as Array).append(x)
	for key: Vector2i in cells:
		var list: Array = cells[key]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.mesh = mesh
		mm.instance_count = list.size()
		for i in list.size():
			mm.set_instance_transform(i, list[i])
			mm.set_instance_custom_data(i, Color(rng.randf(), rng.randf(), 0, 0))
		var inst := MultiMeshInstance3D.new()
		inst.multimesh = mm
		inst.visibility_range_end = fade_end
		inst.visibility_range_end_margin = 12.0
		inst.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(inst)


const BAMBOO_PACK := "res://assets/third_party/sketchfab/bamboo/bamboo.glb"
const BAMBOO_CLUSTERS := ["Object_5", "Object_8", "Object_11", "Object_16"] ## Alpha leaf sprays in the pack.
static var _leaf_clusters: Array[Mesh] = []


## Leaf sprays re-centred on their stem and normalised to ~1 m, so instance scale is metres.
static func _bamboo_leaf_meshes() -> Array[Mesh]:
	if not _leaf_clusters.is_empty() or not ResourceLoader.exists(BAMBOO_PACK):
		return _leaf_clusters
	var pack: Node = (load(BAMBOO_PACK) as PackedScene).instantiate()
	for mi: MeshInstance3D in pack.find_children("*", "MeshInstance3D", true, false):
		if not BAMBOO_CLUSTERS.has(String(mi.name)):
			continue
		var xf := mi.transform
		var p := mi.get_parent()
		while p != null and p != pack:
			if p is Node3D:
				xf = (p as Node3D).transform * xf
			p = p.get_parent()
		var aabb: AABB = xf * mi.mesh.get_aabb()
		var k := 1.0 / maxf(aabb.size.x, maxf(aabb.size.y, aabb.size.z))
		var norm := Transform3D(Basis.from_scale(Vector3.ONE * k), -aabb.get_center() * k) * xf
		var out := ArrayMesh.new()
		for si in mi.mesh.get_surface_count():
			var st := SurfaceTool.new()
			st.append_from(mi.mesh, si, norm)
			st.commit(out)
			var src := mi.mesh.surface_get_material(si) as BaseMaterial3D
			var mat := src.duplicate() as BaseMaterial3D
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			mat.alpha_scissor_threshold = 0.45
			mat.cull_mode = BaseMaterial3D.CULL_DISABLED
			mat.backlight_enabled = true # Moon- and lantern-light through the leaves.
			mat.backlight = Color(0.25, 0.32, 0.12)
			mat.albedo_color = Color(0.82, 0.9, 0.78)
			out.surface_set_material(out.get_surface_count() - 1, mat)
		_leaf_clusters.append(out)
	pack.free()
	return _leaf_clusters


static func _bamboo_material() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
// Bamboo culm: green gradient, darker nodes every ~35 cm, gentle sway. Cosmetic only.
varying float v_height;
varying vec4 v_custom;
void vertex() {
	v_custom = INSTANCE_CUSTOM;
	v_height = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
	float sway = sin(TIME * 0.9 + INSTANCE_CUSTOM.r * 6.28) * 0.04 * max(VERTEX.y + 0.5, 0.0);
	VERTEX.x += sway;
}
void fragment() {
	float node = smoothstep(0.035, 0.0, abs(fract(v_height / 0.38 + v_custom.g) - 0.5) - 0.465);
	vec3 young = vec3(0.32, 0.46, 0.2);
	vec3 old = vec3(0.45, 0.47, 0.26);
	vec3 col = mix(young, old, v_custom.r);
	ALBEDO = mix(col, col * 0.55, node);
	ROUGHNESS = 0.55;
	SPECULAR = 0.35;
}
"""
	mat.shader = sh
	return mat


static func _leaf_material() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode cull_disabled;
// Procedural spray of lanceolate bamboo leaves on a card (alpha scissor), swaying in the wind.
varying vec4 v_custom;
void vertex() {
	v_custom = INSTANCE_CUSTOM;
	VERTEX.x += sin(TIME * 1.3 + INSTANCE_CUSTOM.r * 6.28 + VERTEX.y) * 0.06;
}
float leaf(vec2 uv, vec2 base, float ang, float len) {
	vec2 d = uv - base;
	vec2 r = vec2(cos(ang) * d.x + sin(ang) * d.y, -sin(ang) * d.x + cos(ang) * d.y);
	float t = clamp(r.x / len, 0.0, 1.0);
	float w = 0.045 * sin(3.14159 * pow(t, 0.7));
	return step(0.0, r.x) * step(r.x, len) * step(abs(r.y), w);
}
void fragment() {
	float a = 0.0;
	for (int i = 0; i < 9; i++) {
		float fi = float(i);
		vec2 base = vec2(0.5 + 0.18 * sin(fi * 2.1 + v_custom.g * 5.0), 0.5 + 0.18 * cos(fi * 1.7));
		a = max(a, leaf(UV, base, fi * 0.7 + v_custom.r * 3.0, 0.32));
	}
	if (a < 0.5) discard;
	ALBEDO = mix(vec3(0.12, 0.24, 0.07), vec3(0.22, 0.33, 0.1), v_custom.g);
	ROUGHNESS = 0.7;
	BACKLIGHT = vec3(0.25, 0.35, 0.1);
}
"""
	mat.shader = sh
	return mat
