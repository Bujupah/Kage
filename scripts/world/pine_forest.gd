class_name PineForest
extends RefCounted
## Hillside forest from the CC-BY "Pine trees pack (lowpoly, game ready, LODs)" by LOLIPOP.
## Hierarchical LOD per 96 m chunk: LOD1 meshes near, LOD2 mid-range, the pack's billboard far,
## each a MultiMeshInstance3D switched by visibility ranges with crossfade. Only the near and mid
## levels cast shadows. Thousands of trees cost a few hundred draws at most.

const PACK := "res://assets/third_party/sketchfab/pines/pines.glb"
const VARIANTS := ["Pine_big_1", "Pine_big_2", "Pine_big_3", "Pine_large_1", "Pine_large_2", "Pine_medium_1", "Pine_medium_2"]
const CHUNK := 96.0
## [part suffix(es), visibility begin, end, shadows]
const LEVELS := [
	[["LOD1_Bark", "LOD1_Clusters"], 0.0, 32.0, true],
	[["LOD2_Bark", "LOD2_Clusters"], 32.0, 115.0, false],
	[["Billboard"], 115.0, 900.0, false],
]

static var _meshes: Dictionary = {} ## "variant/level" -> ArrayMesh with the parts as surfaces


## `positions` are world positions on the terrain; each tree gets a random variant, yaw and scale.
static func build(parent: Node3D, positions: Array[Vector3], seed_value: int) -> void:
	if not AssetKit.visuals_enabled():
		return
	_ensure_meshes()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var buckets := {} ## Vector3i(cx, cz, variant) -> Array[Transform3D]
	for p in positions:
		var v := rng.randi_range(0, VARIANTS.size() - 1)
		var key := Vector3i(floori(p.x / CHUNK), floori(p.z / CHUNK), v)
		if not buckets.has(key):
			buckets[key] = []
		var s := rng.randf_range(0.7, 1.15)
		(buckets[key] as Array).append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s), p))
	for key: Vector3i in buckets:
		var xforms: Array = buckets[key]
		for li in LEVELS.size():
			var mesh: ArrayMesh = _meshes.get("%s/%d" % [VARIANTS[key.z], li])
			if mesh == null:
				continue
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = mesh
			mm.instance_count = xforms.size()
			for i in xforms.size():
				mm.set_instance_transform(i, xforms[i])
			var inst := MultiMeshInstance3D.new()
			inst.multimesh = mm
			var level: Array = LEVELS[li]
			inst.visibility_range_begin = level[1]
			inst.visibility_range_end = level[2]
			inst.visibility_range_begin_margin = 8.0
			inst.visibility_range_end_margin = 8.0
			inst.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DEPENDENCIES
			inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if level[3] else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			parent.add_child(inst)


## Pulls each variant's LOD parts out of the pack, re-centred on the trunk base, merged per level.
static func _ensure_meshes() -> void:
	if not _meshes.is_empty():
		return
	var pack: Node = (load(PACK) as PackedScene).instantiate()
	var parts := {} ## mesh-instance name -> [ArrayMesh, Transform3D in pack space]
	for mi: MeshInstance3D in pack.find_children("*", "MeshInstance3D", true, false):
		parts[String(mi.name)] = [mi.mesh, _relative(pack, mi)]
	for v: String in VARIANTS:
		# Trunk base from LOD1 bark: centre in XZ, bottom in Y.
		var base_xf := Transform3D()
		for n: String in parts:
			if n.begins_with(v + "_LOD1_Bark"):
				var aabb: AABB = (parts[n][1] as Transform3D) * (parts[n][0] as Mesh).get_aabb()
				base_xf = Transform3D(Basis.IDENTITY, -Vector3(aabb.get_center().x, aabb.position.y, aabb.get_center().z))
		for li in LEVELS.size():
			var merged := ArrayMesh.new()
			for suffix: String in LEVELS[li][0]:
				for n: String in parts:
					if n.begins_with(v + "_" + suffix) or (suffix == "Billboard" and n.begins_with(v + "_Billboard")):
						var src: Mesh = parts[n][0]
						var xf: Transform3D = base_xf * (parts[n][1] as Transform3D)
						for s in src.get_surface_count():
							var st := SurfaceTool.new()
							st.append_from(src, s, xf)
							st.commit(merged)
							merged.surface_set_material(merged.get_surface_count() - 1, src.surface_get_material(s))
			if merged.get_surface_count() > 0:
				_meshes["%s/%d" % [v, li]] = merged
	pack.free()


static func _relative(root: Node, node: Node3D) -> Transform3D:
	var xf := node.transform
	var p := node.get_parent()
	while p != null and p != root:
		if p is Node3D:
			xf = (p as Node3D).transform * xf
		p = p.get_parent()
	return xf
