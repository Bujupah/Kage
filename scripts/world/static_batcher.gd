class_name StaticBatcher
extends RefCounted
## Draw-call reduction for the environment kit (ENVIRONMENT.md §10). Static kit meshes tagged
## "batch" are merged per material inside fixed world cells: one draw per material per cell
## instead of one per block. Kit materials are world-space triplanar (or flat), so merging cannot
## break texturing, and cells keep frustum/occlusion culling effective. Colliders are untouched.

const CELL := 32.0


## Merges every tagged MeshInstance3D under `root`. Returns {"before": n, "after": m}.
static func merge(root: Node3D, cell: float = CELL) -> Dictionary:
	var groups := {} ## "material_id:cx:cz" -> {material, items: Array[MeshInstance3D]}
	var count := 0
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if not mi.has_meta("batch") or mi.mesh == null or mi.material_override == null:
			continue
		count += 1
		var xf := _relative(root, mi)
		var center := xf * mi.get_aabb().get_center()
		var key := "%d:%d:%d" % [mi.material_override.get_instance_id(), floori(center.x / cell), floori(center.z / cell)]
		if not groups.has(key):
			groups[key] = {"material": mi.material_override, "items": []}
		(groups[key]["items"] as Array).append(mi)
	var holder := Node3D.new()
	holder.name = "Batched"
	root.add_child(holder)
	for key: String in groups:
		var items: Array = groups[key]["items"]
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for mi: MeshInstance3D in items:
			for s in mi.mesh.get_surface_count():
				st.append_from(mi.mesh, s, _relative(root, mi))
		var merged := MeshInstance3D.new()
		merged.mesh = st.commit()
		merged.material_override = groups[key]["material"]
		merged.cast_shadow = items[0].cast_shadow
		holder.add_child(merged)
		for mi: MeshInstance3D in items:
			mi.queue_free()
	return {"before": count, "after": groups.size()}


## Transform of `node` in `root` space, without needing the tree (levels are built off-tree).
static func _relative(root: Node3D, node: Node3D) -> Transform3D:
	var xf := node.transform
	var p := node.get_parent()
	while p != null and p != root:
		if p is Node3D:
			xf = (p as Node3D).transform * xf
		p = p.get_parent()
	return xf
