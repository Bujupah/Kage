extends SceneTree
## Renders a scene or a model pose to PNG for visual review (needs a display, not --headless):
##   godot --path . -s res://tools/shot.gd -- --out=/tmp/x.png [--scene=res://...] [--frames=40]
##     [--cam=x,y,z] [--look=x,y,z] [--clip=Sword_Regular_A] [--at=0.3] [--size=1280x720]
## --level builds the province slice; without --scene/--level it builds a model turntable.

var _args := {}
var _frames := 0
var _target := 40
var _model: AssassinModel


func _initialize() -> void:
	_args = NetProtocol.parse_args(OS.get_cmdline_user_args())
	_target = int(_args.get("frames", 40))
	var size := str(_args.get("size", "1280x720")).split("x")
	root.size = Vector2i(int(size[0]), int(size[1]))
	DisplayServer.window_set_size(root.size)
	if _args.has("level"):
		pass # Built on the first frame, once the root is in the tree (Terrain3D needs that).
	elif _args.has("scene"):
		root.add_child((load(str(_args["scene"])) as PackedScene).instantiate())
	else:
		_turntable()
	if _args.has("cam"):
		var cam := Camera3D.new()
		root.add_child(cam)
		cam.look_at_from_position(_vec(str(_args["cam"])), _vec(str(_args.get("look", "0,1,0"))))
		cam.fov = float(_args.get("fov", 50))
		cam.make_current()


func _turntable() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.12, 0.13, 0.15)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.5, 0.5, 0.55)
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	stage.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, -30, 0)
	sun.shadow_enabled = true
	stage.add_child(sun)
	var floor_mesh := MeshInstance3D.new()
	floor_mesh.mesh = PlaneMesh.new()
	(floor_mesh.mesh as PlaneMesh).size = Vector2(6, 6)
	stage.add_child(floor_mesh)
	if _args.has("model"):
		var m: Node3D = (load(str(_args["model"])) as PackedScene).instantiate()
		m.rotation_degrees.y = float(_args.get("yaw", 0))
		stage.add_child(m)
		var ap := m.find_children("*", "AnimationPlayer", true, false)
		if not ap.is_empty() and _args.has("anim"):
			(ap[0] as AnimationPlayer).play(str(_args["anim"]))
	else:
		_model = AssassinModel.new()
		stage.add_child(_model)
	if not _args.has("cam"):
		_args["cam"] = "1.6,1.5,-2.2"


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 1 and _args.has("level"):
		var world := Node3D.new()
		root.add_child(world)
		ProvinceLevel.build(world)
		GameSettings.apply_world(root)
	if _args.has("push") and _frames == int(_args.get("push_at", 120)) and UiShell.instance != null:
		UiShell.instance.push(load(str(_args["push"])).new())
	if _args.has("teleport") and _frames == int(_args.get("teleport_at", 100)):
		var bodies := root.find_children("*", "FighterBody", true, false)
		if not bodies.is_empty():
			(bodies[0] as FighterBody).global_position = _vec(str(_args["teleport"]))
	if _frames == 3 and _model != null and _args.has("clip"):
		_model.pose(StringName(str(_args["clip"])), float(_args.get("at", 0.0)))
	if _frames == _target - 1 and _args.has("stats"):
		print("STATS draw_calls=%d objects=%d primitives=%d fps=%d" % [
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
			Engine.get_frames_per_second()])
	if _frames == _target:
		var img := root.get_texture().get_image()
		img.save_png(str(_args.get("out", "user://shot.png")))
		print("saved ", _args.get("out"))
		return true
	return false


static func _vec(s: String) -> Vector3:
	var p := s.split(",")
	return Vector3(float(p[0]), float(p[1]), float(p[2]))
