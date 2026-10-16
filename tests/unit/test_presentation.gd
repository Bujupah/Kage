extends TestCase
## Pure helpers behind the art and UI layers: retargeted clip library, input binding persistence,
## server address parsing, credits parsing and sound cue resolution.


func test_merged_library_has_every_clip_the_model_drives() -> void:
	var lib := AssassinModel.shared_library()
	for clip in [&"Sword_Idle", &"Walk", &"Jog_Fwd", &"Sprint", &"Sword_Block", &"Sword_Regular_A",
			&"Sword_Regular_A_Rec", &"Sword_Regular_B", &"Sword_Regular_B_Rec", &"Sword_Regular_C",
			&"Sword_Attack", &"Roll", &"Hit_Chest", &"Hit_Knockback", &"Idle_Shield_Break", &"Death01"]:
		assert_true(lib.has_animation(clip), "clip %s" % clip)
	var roll := lib.get_animation(&"Roll")
	assert_true(roll.get_track_count() > 10, "roll keeps its bone tracks")
	for t in roll.get_track_count():
		assert_true(String(roll.track_get_path(t)).begins_with("%GeneralSkeleton:"), "retargeted track %s" % roll.track_get_path(t))
	assert_eq(lib.get_animation(&"Sword_Idle").loop_mode, Animation.LOOP_LINEAR, "idle loops")


func test_input_events_round_trip_through_settings() -> void:
	var key := InputEventKey.new()
	key.physical_keycode = KEY_F
	var back := GameSettings.event_from_dict(GameSettings.event_to_dict(key))
	assert_true(back is InputEventKey and (back as InputEventKey).physical_keycode == KEY_F, "key")
	var axis := InputEventJoypadMotion.new()
	axis.axis = JOY_AXIS_LEFT_Y
	axis.axis_value = -1.0
	var axis_back := GameSettings.event_from_dict(GameSettings.event_to_dict(axis)) as InputEventJoypadMotion
	assert_eq(axis_back.axis, JOY_AXIS_LEFT_Y, "axis")
	assert_eq(axis_back.axis_value, -1.0, "axis direction")
	assert_eq(GameSettings.event_from_dict({"type": "nonsense"}), null, "unknown entries ignored")


func test_default_bindings_cover_every_remappable_action() -> void:
	var defaults := InputBindings.defaults()
	for entry: Array in InputBindings.REMAPPABLE:
		assert_true(defaults.has(entry[0]), "default for %s" % entry[0])
	InputBindings.ensure_defaults()
	assert_eq(InputBindings.glyph("attack_light"), "LMB", "mouse glyph")
	assert_eq(InputBindings.glyph("dodge"), "Space", "key glyph")


func test_server_address_parsing() -> void:
	assert_eq(JoinScreen.parse_address("10.0.0.5:9000"), {"host": "10.0.0.5", "port": 9000}, "host:port")
	assert_eq(JoinScreen.parse_address("dojo.example"), {"host": "dojo.example", "port": NetProtocol.DEFAULT_PORT}, "default port")
	assert_true(JoinScreen.parse_address("host:99999").is_empty(), "port out of range")
	assert_true(JoinScreen.parse_address("host:abc").is_empty(), "port not a number")
	assert_true(JoinScreen.parse_address("  ").is_empty(), "blank")
	assert_true(JoinScreen.parse_address("two words").is_empty(), "spaces")


func test_credits_list_every_asset_with_a_source() -> void:
	var entries := CreditsScreen.parse_credits(FileAccess.get_file_as_string(CreditsScreen.CREDITS))
	assert_true(entries.size() >= 20, "credits listed (%d)" % entries.size())
	for e in entries:
		assert_true(String(e["source"]).begins_with("https://"), "source for %s" % e["asset"])


func test_combat_cues_resolve_to_real_sounds() -> void:
	for type in [&"attack_start", &"hit", &"guarded", &"parried", &"guard_broken", &"dodge_start", &"round_reset"]:
		var cue := Sfx.for_event({"type": type})
		assert_false(cue.is_empty(), "cue for %s" % type)
		assert_false(Sfx.streams(cue).is_empty(), "sounds for %s" % cue)
	for surface in ["concrete", "grass", "wood"]:
		assert_false(Sfx.streams("step_" + surface).is_empty(), "footsteps on %s" % surface)
	assert_false(Sfx.streams("ui_click").is_empty(), "ui click")
