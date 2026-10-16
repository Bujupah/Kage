extends Node
## Entry point. Picks a role from the user arguments (those after `--`):
##   (none)                          splash -> first-run settings -> title menu (GUI.md §2)
##   --server [--port=7777] [--max-players=16] [--spawn=arena|frontier] [--no-npcs]
##                                   headless authoritative region server (also the default when
##                                   the engine runs with --headless)
##   --client [--host=127.0.0.1] [--port=7777] [--name=Musashi]
##                                   join straight away (windowed, with the full UI shell)
##   --client ... --bot=passive|guard|attack|duelist
##                                   training AI drives the client (headless soak/smoke runs)
##   --sandbox                       skip menus and open the training dojo
##   --quit-after=SECONDS            exit after a while (automated smoke runs)
## Server and client both mount their match root at /root/Match so the shared RPC node lives at the
## same path (/root/Match/Session) on every peer.

const BOT_MODES: Array[String] = ["passive", "guard", "attack", "duelist"] ## DummyBrain.Mode order.


func _ready() -> void:
	var args := NetProtocol.parse_args(OS.get_cmdline_user_args())
	var port := int(args.get("port", NetProtocol.DEFAULT_PORT))
	if args.has("quit-after"):
		get_tree().create_timer(float(args["quit-after"])).timeout.connect(get_tree().quit)
	var headless := DisplayServer.get_name() == "headless"
	if args.has("server") or (headless and not args.has("client")):
		Engine.max_fps = 120 # Headless has no vsync; don't spin a core between physics ticks.
		var server := NetServer.new()
		server.port = port
		server.max_players = clampi(int(args.get("max-players", NetProtocol.MAX_PLAYERS)), 1, 64)
		var spawn := str(args.get("spawn", "sanctuary"))
		server.spawn_mode = spawn if spawn in ["arena", "frontier"] else "sanctuary"
		server.with_npcs = not args.has("no-npcs")
		_mount(server)
		return

	InputBindings.ensure_defaults()
	GameSettings.ensure_loaded()
	GameSettings.apply_bindings()
	GameSettings.apply_all(get_tree())
	var host := str(args.get("host", "127.0.0.1"))
	var player_name := str(args.get("name", ""))
	if args.has("client") and (args.has("bot") or headless):
		# Scripted clients skip the UI shell entirely (soak and smoke tests).
		var client := NetClient.new()
		client.host = host
		client.port = port
		client.player_name = player_name
		if args.has("bot"):
			client.bot_mode = maxi(BOT_MODES.find(str(args["bot"])), 0)
		_mount(client)
		return

	var shell := UiShell.new()
	shell.name = "Shell"
	get_tree().root.add_child.call_deferred(shell)
	if args.has("client") or args.has("host"):
		get_window().title = "Kage — %s" % (player_name if not player_name.is_empty() else "client")
		shell.ready.connect(func() -> void: shell.start_online(host, port, player_name), CONNECT_ONE_SHOT)
	elif args.has("sandbox"):
		shell.ready.connect(shell.start_sandbox, CONNECT_ONE_SHOT)
	else:
		shell.ready.connect(func() -> void: shell.push(SplashScreen.new()), CONNECT_ONE_SHOT)
	queue_free()


func _mount(match_root: Node) -> void:
	match_root.name = "Match"
	var tree := get_tree()
	tree.root.add_child.call_deferred(match_root)
	tree.set_deferred("current_scene", match_root)
	queue_free()
