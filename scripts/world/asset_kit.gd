class_name AssetKit
extends RefCounted
## Places authored models (CC-BY Sketchfab GLBs prepared by tools/optimize_models.gd) at real-world
## scale using the bounds manifest. Every placement gets a simple box collider on the WORLD layer
## and, for large buildings, an occluder. The headless server gets only the collider: it never
## loads art (ENVIRONMENT.md §10: server simulates collision, clients stream visuals).

const MODEL := "res://assets/third_party/sketchfab/%s/%s.glb"
const MANIFEST := "res://assets/third_party/sketchfab/manifest.json"

static var _manifest: Dictionary = {}
static var _scenes: Dictionary = {}


static func visuals_enabled() -> bool:
	return DisplayServer.get_name() != "headless"


static func bounds(key: String) -> Dictionary:
	if _manifest.is_empty():
		_manifest = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	return _manifest.get(key, {})


## Scale that makes `key` exactly `height` metres tall.
static func scale_for(key: String, height: float) -> float:
	var b := bounds(key)
	return height / float((b["size"] as Array)[1])


## Real-world footprint (x, height, z) of `key` at `height`.
static func footprint(key: String, height: float) -> Vector3:
	var b := bounds(key)
	var k := scale_for(key, height)
	var s: Array = b["size"]
	return Vector3(float(s[0]), float(s[1]), float(s[2])) * k


## Places `key` standing on `at` (bounds centred in XZ), `height` metres tall, turned `yaw_deg`.
## `solid` adds a footprint collider (shrunk by `collider_scale`) and an occluder for big pieces.
static func place(parent: Node3D, key: String, at: Vector3, height: float, yaw_deg: float = 0.0,
		solid: bool = true, collider_scale: Vector3 = Vector3(0.9, 1.0, 0.9)) -> Node3D:
	var b := bounds(key)
	var k := scale_for(key, height)
	var size: Array = b["size"]
	var mn: Array = b["min"]
	var root := Node3D.new()
	root.name = key.capitalize().replace(" ", "")
	root.position = at
	root.rotation_degrees.y = yaw_deg
	parent.add_child(root)
	if visuals_enabled():
		if not _scenes.has(key):
			_scenes[key] = load(MODEL % [key, key])
		var model: Node3D = (_scenes[key] as PackedScene).instantiate()
		model.scale = Vector3.ONE * k
		# Centre the bounds over `at` and put their bottom on the ground.
		model.position = -Vector3(float(mn[0]) + float(size[0]) * 0.5, float(mn[1]), float(mn[2]) + float(size[2]) * 0.5) * k
		root.add_child(model)
		for mi in model.find_children("*", "MeshInstance3D", true, false):
			(mi as GeometryInstance3D).visibility_range_end = 900.0
	if solid:
		var fp := Vector3(float(size[0]), float(size[1]), float(size[2])) * k * collider_scale
		var body := StaticBody3D.new()
		body.collision_layer = FighterBody.WORLD_LAYER
		body.collision_mask = 0
		body.position = Vector3(0, fp.y * 0.5, 0)
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = fp
		shape.shape = box
		body.add_child(shape)
		if fp.y > 3.0 and maxf(fp.x, fp.z) > 6.0 and visuals_enabled():
			var occ := OccluderInstance3D.new()
			var bo := BoxOccluder3D.new()
			bo.size = fp * Vector3(0.85, 0.8, 0.85)
			occ.occluder = bo
			body.add_child(occ)
		root.add_child(body)
	return root
