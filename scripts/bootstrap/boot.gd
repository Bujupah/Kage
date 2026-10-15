extends Node
## Entry point. Picks a role from the user arguments (those after `--`):
##   (none)                          single-player combat sandbox (M0)
##   --server [--port=7777]          headless authoritative duel server (also the default when the
##                                   engine runs with --headless)
##   --client [--host=127.0.0.1] [--port=7777] [--name=Musashi] [--bot=passive|guard|attack|duelist]
##                                   windowed duel client; --bot drives it with the training AI
##   --quit-after=SECONDS            exit after a while (automated smoke runs)
## Server and client both mount their match root at /root/Match so the shared RPC node lives at the
## same path (/root/Match/Session) on every peer.

const SANDBOX := "res://scenes/sandbox/combat_sandbox.tscn"
const BOT_MODES: Array[String] = ["passive", "guard", "attack", "duelist"] ## DummyBrain.Mode order.


func _ready() -> void:
	var args := NetProtocol.parse_args(OS.get_cmdline_user_args())
	var port := int(args.get("port", NetProtocol.DEFAULT_PORT))
	if args.has("quit-after"):
		get_tree().create_timer(float(args["quit-after"])).timeout.connect(get_tree().quit)
	if args.has("server") or (DisplayServer.get_name() == "headless" and not args.has("client")):
		Engine.max_fps = 120 # Headless has no vsync; don't spin a core between physics ticks.
		var server := NetServer.new()
		server.port = port
		_mount(server)
	elif args.has("client") or args.has("host"):
		var client := NetClient.new()
		client.host = str(args.get("host", "127.0.0.1"))
		client.port = port
		client.player_name = str(args.get("name", ""))
		if args.has("bot"):
			client.bot_mode = maxi(BOT_MODES.find(str(args["bot"])), 0)
		get_window().title = "Kage — %s" % (client.player_name if not client.player_name.is_empty() else "client")
		_mount(client)
	else:
		get_tree().change_scene_to_file.call_deferred(SANDBOX)


func _mount(match_root: Node) -> void:
	match_root.name = "Match"
	var tree := get_tree()
	tree.root.add_child.call_deferred(match_root)
	tree.set_deferred("current_scene", match_root)
	queue_free()
