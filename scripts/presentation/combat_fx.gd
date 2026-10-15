class_name CombatFx
extends RefCounted
## Placeholder contact sparks for confirmed events. Shared by the sandbox and network clients;
## purely cosmetic, never consulted by the rules.


static func present_event(parent: Node, ev: Dictionary, attacker_pos: Vector3, target_pos: Vector3) -> void:
	var at := attacker_pos.lerp(target_pos, 0.7) + Vector3.UP * 1.2
	match ev["type"]:
		&"hit":
			spark(parent, at, Color(1, 0.25, 0.2), 0.35 if ev.get("critical", false) else 0.22)
		&"guarded":
			spark(parent, at, Color(1, 0.8, 0.4), 0.18)
		&"parried":
			spark(parent, at, Color(0.9, 0.95, 1), 0.5)
		&"guard_broken":
			spark(parent, at, Color(1, 0.85, 0.2), 0.45)


static func spark(parent: Node, at: Vector3, color: Color, size: float) -> void:
	var spark_mesh := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = size
	mesh.height = size * 2.0
	spark_mesh.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = color
	spark_mesh.material_override = mat
	spark_mesh.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	parent.add_child(spark_mesh)
	spark_mesh.global_position = at
	var tween := spark_mesh.create_tween().set_parallel()
	tween.tween_property(spark_mesh, "scale", Vector3.ONE * 2.2, 0.18)
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.18)
	tween.chain().tween_callback(spark_mesh.queue_free)
