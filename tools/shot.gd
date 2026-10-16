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
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED) # The game defaults to fullscreen.
	_want_size = Vector2i(int(size[0]), int(size[1]))
	root.size = _want_size
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
		if _args.has("app"): # --app=outfit_id,blade_id,scarf_id
			var ids := str(_args["app"]).split(",")
			_model.appearance = {"outfit": ids[0], "blade": ids[1], "scarf": ids[2]}
		stage.add_child(_model)
		if _args.has("night"):
			env.environment.background_color = Color(0.02, 0.025, 0.04)
			env.environment.ambient_light_color = Color(0.12, 0.14, 0.2)
			env.environment.glow_enabled = true
			sun.light_energy = 0.25
			sun.light_color = Color(0.6, 0.7, 1.0)
	if not _args.has("cam"):
		_args["cam"] = "1.6,1.5,-2.2"


var _gpu_ms: Array[float] = []
var _want_size := Vector2i(1280, 720)


func _process(_delta: float) -> bool:
	_frames += 1
	# The project opens fullscreen; macOS ignores mode changes mid-animation, so keep asking.
	if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED and _frames % 10 == 1:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	elif DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED and DisplayServer.window_get_size() != _want_size:
		DisplayServer.window_set_size(_want_size)
		root.size = _want_size
	if _frames == 1 and _args.has("level"):
		var world := Node3D.new()
		root.add_child(world)
		ProvinceLevel.build(world)
		GameSettings.apply_world(root)
		if not _args.has("raw"):
			root.add_child(PostFx.new())
	if _args.has("push") and _frames == int(_args.get("push_at", 120)) and UiShell.instance != null:
		UiShell.instance.push(load(str(_args["push"])).new())
	if _args.has("teleport") and _frames == int(_args.get("teleport_at", 100)):
		var bodies := root.find_children("*", "FighterBody", true, false)
		if not bodies.is_empty():
			(bodies[0] as FighterBody).global_position = _vec(str(_args["teleport"]))
	if _frames == 3 and _model != null and _args.has("clip"):
		_model.pose(StringName(str(_args["clip"])), float(_args.get("at", 0.0)))
	if _frames == 130 and _args.has("ab"): # Perf A/B: --ab=lights|particles|fog|ssil|glow hides one feature.
		var what := str(_args["ab"])
		for n in root.find_children("*", "OmniLight3D", true, false):
			if what == "lights": (n as Node3D).visible = false
		for n in root.find_children("*", "GPUParticles3D", true, false):
			if what == "particles": (n as Node3D).visible = false
		for n in root.find_children("*", "WorldEnvironment", true, false):
			var e := (n as WorldEnvironment).environment
			if what == "fog": e.volumetric_fog_enabled = false
			if what == "ssil": e.ssil_enabled = false
			if what == "glow": e.glow_enabled = false
			if what == "ssao": e.ssao_enabled = false
	if _args.has("stats") and _frames == 140:
		RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	if _args.has("stats") and _frames > 150 and _frames < _target - 1:
		var gpu := RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid())
		_gpu_ms.append(gpu if gpu > 0.0 else _delta * 1000.0) # Frame time where GPU timing is unavailable.
	if _frames == _target - 1 and _args.has("stats"):
		_gpu_ms.sort()
		var median: float = _gpu_ms[_gpu_ms.size() / 2] if not _gpu_ms.is_empty() else 0.0
		print("STATS frame_ms=%.2f draw_calls=%d objects=%d primitives=%d fps=%d" % [median,
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
			Engine.get_frames_per_second()])
	if _frames == _target:
		var img := root.get_texture().get_image()
		if _args.has("debug"):
			print("DEBUG mode=", DisplayServer.window_get_mode(), " win=", DisplayServer.window_get_size(), " root=", root.size, " img=", img.get_size(), " min=", DisplayServer.window_get_min_size())
		img.save_png(str(_args.get("out", "user://shot.png")))
		print("saved ", _args.get("out"))
		return true
	return false


static func _vec(s: String) -> Vector3:
	var p := s.split(",")
	return Vector3(float(p[0]), float(p[1]), float(p[2]))
