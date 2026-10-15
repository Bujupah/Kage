extends TestCase
## Client-side snapshot handling (MULTIPLAYER.md §12 "Late server packet"): late or reordered
## snapshots never overwrite newer state, and replication round-trips the combat state exactly.

const KATANA := preload("res://data/weapons/katana_starter.tres")


func _record(id: int, x: float, health: int = 100) -> Array:
	var c := Combatant.new(id, 1, KATANA)
	c.position = Vector3(x, 0, 0)
	c.stats.health = health
	return SnapshotCodec.encode_entity(c)


func test_newer_snapshot_is_accepted() -> void:
	var inbox := SnapshotInbox.new()
	assert_true(inbox.offer(10, 3, [_record(100, 1.0)]), "first snapshot")
	assert_true(inbox.offer(11, 4, [_record(100, 2.0)]), "newer snapshot")
	var snap := inbox.take()
	assert_eq(snap["tick"], 11, "newest wins")
	assert_eq(snap["ack"], 4, "ack carried")
	assert_true(inbox.take().is_empty(), "consumed once")


func test_late_snapshot_is_ignored() -> void:
	var inbox := SnapshotInbox.new()
	inbox.offer(20, 8, [_record(100, 5.0, 40)])
	assert_false(inbox.offer(19, 7, [_record(100, 4.0, 100)]), "older tick dropped")
	assert_false(inbox.offer(20, 8, [_record(100, 4.0, 100)]), "duplicate tick dropped")
	assert_eq(inbox.stale_dropped, 2, "counted")
	var snap := inbox.take()
	assert_eq(snap["tick"], 20, "pending snapshot is still the newest")
	assert_eq((snap["entities"][0] as Array)[SnapshotCodec.HEALTH], 40, "late packet did not resurrect health")


func test_late_snapshot_after_consumption_is_ignored() -> void:
	var inbox := SnapshotInbox.new()
	inbox.offer(30, 10, [])
	inbox.take()
	assert_false(inbox.offer(29, 9, []), "reordered packet arriving after the newer one was applied")
	assert_true(inbox.take().is_empty(), "nothing to apply")


func test_ack_never_moves_backwards() -> void:
	var inbox := SnapshotInbox.new()
	inbox.offer(40, 12, [])
	assert_false(inbox.offer(41, 11, []), "newer tick with an older ack is inconsistent")
	assert_eq(inbox.newest_ack, 12, "ack kept")


func test_malformed_snapshot_is_ignored() -> void:
	var inbox := SnapshotInbox.new()
	assert_false(inbox.offer("50", 1, []), "string tick")
	assert_false(inbox.offer(50, 1, "entities"), "non-array entities")
	var bad := _record(100, 0.0)
	bad[SnapshotCodec.HEALTH] = 1.5
	assert_false(inbox.offer(50, 1, [bad]), "wrong field type")
	assert_false(inbox.offer(50, 1, [[1, 2, 3]]), "short record")
	var nan := _record(100, 0.0)
	nan[SnapshotCodec.X] = NAN
	assert_false(inbox.offer(50, 1, [nan]), "non-finite position")
	assert_eq(inbox.newest_tick, -1, "nothing accepted")
	assert_true(inbox.offer(50, 1, [_record(100, 0.0)]), "a valid one still gets through")


func test_interpolation_buffer_ignores_out_of_order_samples() -> void:
	var buf := InterpolationBuffer.new()
	assert_true(buf.push(10, Vector3(0, 0, 0), 0.0, _record(100, 0.0)), "t10")
	assert_true(buf.push(12, Vector3(2, 0, 0), 0.0, _record(100, 2.0)), "t12")
	assert_false(buf.push(11, Vector3(99, 0, 0), 0.0, _record(100, 99.0)), "late t11 refused")
	assert_false(buf.push(12, Vector3(99, 0, 0), 0.0, _record(100, 99.0)), "duplicate t12 refused")
	var mid := buf.sample(11.0)
	assert_true((mid["position"] as Vector3).is_equal_approx(Vector3(1, 0, 0)), "blends t10..t12, not the late sample")


func test_interpolation_extrapolates_briefly_then_holds() -> void:
	var buf := InterpolationBuffer.new()
	buf.push(10, Vector3(0, 0, 0), 0.0, _record(100, 0.0))
	buf.push(11, Vector3(1, 0, 0), 0.0, _record(100, 1.0))
	assert_true((buf.sample(5.0)["position"] as Vector3).is_equal_approx(Vector3.ZERO), "before first: clamp")
	assert_true((buf.sample(12.0)["position"] as Vector3).is_equal_approx(Vector3(2, 0, 0)), "one tick ahead")
	var far := buf.sample(40.0)["position"] as Vector3
	assert_true(far.is_equal_approx(Vector3(1 + InterpolationBuffer.MAX_EXTRAPOLATION_TICKS, 0, 0)), "capped extrapolation")


func test_snapshot_round_trips_combat_state() -> void:
	var server := Combatant.new(100, 1, KATANA)
	var sim := CombatSimulation.new()
	sim.add(server)
	sim.step({100: CombatIntent.make(CombatIntent.HEAVY)})
	server.position = Vector3(1.5, 0, -2)
	server.facing = Vector3(1, 0, 0)
	var rec := SnapshotCodec.encode_entity(server)
	assert_true(SnapshotCodec.is_valid(rec), "valid record")
	var mirror := Combatant.new(100, 1, KATANA)
	SnapshotCodec.apply_combat_state(mirror, rec)
	assert_eq(mirror.state, Combatant.State.ATTACK, "state")
	assert_eq(mirror.move, KATANA.heavy, "heavy move resolved from chain index")
	assert_eq(mirror.state_start_tick, server.state_start_tick, "start tick")
	assert_eq(mirror.attack_phase(5), server.attack_phase(5), "same phase math")
	assert_eq(mirror.stats.stamina, server.stats.stamina, "stamina")
	assert_true(SnapshotCodec.facing_of(rec).is_equal_approx(Vector3(1, 0, 0)), "facing")
	assert_true(SnapshotCodec.position_of(rec).is_equal_approx(Vector3(1.5, 0, -2)), "position")


func test_event_codec_drops_unknown_content() -> void:
	var wire := NetProtocol.encode_event({"type": &"hit", "attacker": 1, "target": 2, "damage": 12,
			"killed": true, "move": &"move.katana.light_1.v1", "debug_blob": RefCounted.new()})
	assert_false(wire.has("debug_blob"), "only known keys are sent")
	var ev := NetProtocol.decode_event(wire)
	assert_eq(ev["type"], &"hit", "type restored as StringName")
	assert_eq(ev["damage"], 12, "damage")
	assert_true(NetProtocol.decode_event({"type": "grant_item"}).is_empty(), "unknown event type")
	assert_true(NetProtocol.decode_event({"type": "hit", "damage": "999"}).is_empty(), "wrong value type")
	assert_true(NetProtocol.decode_event(42).is_empty(), "not a dictionary")


func test_interpolation_never_blends_across_a_respawn() -> void:
	var buf := InterpolationBuffer.new()
	var corpse := Combatant.new(100, 1, KATANA)
	corpse.reset(0)
	buf.push(10, Vector3(1, 0, 0), 0.0, SnapshotCodec.encode_entity(corpse))
	corpse.reset(11) # respawn: new life
	buf.push(11, Vector3(0, 0, 3), 0.0, SnapshotCodec.encode_entity(corpse))
	assert_true((buf.sample(10.5)["position"] as Vector3).is_equal_approx(Vector3(0, 0, 3)), "no slide from corpse to spawn")
