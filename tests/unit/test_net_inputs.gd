extends TestCase
## Server-side input validation (MULTIPLAYER.md §11, §12 "Tampered input"): tampered or forged input
## packets are rejected whole and never reach the simulation.

const KATANA := preload("res://data/weapons/katana_starter.tres")
const PEER_A := 1001
const PEER_B := 1002


func _registry() -> PeerRegistry:
	var reg := PeerRegistry.new(42)
	assert_true(reg.try_join(PEER_A, NetProtocol.VERSION, "A").has("peer"), "A joins")
	assert_true(reg.try_join(PEER_B, NetProtocol.VERSION, "B").has("peer"), "B joins")
	return reg


func _input(seq: int, move := Vector2.ZERO, pressed := 0, held := 0) -> CombatIntent:
	var intent := CombatIntent.make(pressed, held, move)
	intent.sequence = seq
	return intent


func _packet(intents: Array[CombatIntent]) -> PackedInt32Array:
	return InputCodec.encode(intents)


## Raw record: [seq, move_x, move_y, face_yaw, pressed, held].
func _raw(fields: Array) -> PackedInt32Array:
	return PackedInt32Array(fields)


func test_valid_input_round_trips_and_is_applied() -> void:
	var reg := _registry()
	var a := reg.get_peer(PEER_A)
	var sent := _input(1, Vector2(0.6, -0.8), CombatIntent.LIGHT, CombatIntent.SPRINT)
	sent.face_dir = Vector3(1, 0, 0)
	assert_true(reg.submit_inputs(PEER_A, a.epoch, _packet([sent]), 0), "accepted")
	var intents := reg.collect_intents()
	var got: CombatIntent = intents[a.entity_id]
	assert_eq(got.sequence, 1, "sequence")
	assert_true(got.move.distance_to(Vector2(0.6, -0.8)) < 0.01, "move survives quantization")
	assert_true(got.face_dir.distance_to(Vector3(1, 0, 0)) < 0.001, "facing survives quantization")
	assert_eq(got.pressed, CombatIntent.LIGHT, "pressed")
	assert_eq(got.held, CombatIntent.SPRINT, "held")
	assert_eq(a.inputs.last_applied, 1, "ack advances once applied")


func test_unjoined_sender_is_rejected() -> void:
	var reg := _registry()
	var epoch := reg.get_peer(PEER_A).epoch
	assert_false(reg.submit_inputs(9999, epoch, _packet([_input(1)]), 0), "unknown peer")
	assert_eq(reg.rejected_inputs, 1, "counted")


func test_wrong_epoch_is_rejected() -> void:
	var reg := _registry()
	var a := reg.get_peer(PEER_A)
	assert_false(reg.submit_inputs(PEER_A, a.epoch + 1, _packet([_input(1)]), 0), "stale epoch")
	assert_false(reg.submit_inputs(PEER_A, "epoch", _packet([_input(1)]), 0), "non-int epoch")
	assert_eq(a.inputs.queued(), 0, "nothing queued")


func test_peer_cannot_drive_another_entity() -> void:
	var reg := _registry()
	var a := reg.get_peer(PEER_A)
	var b := reg.get_peer(PEER_B)
	# A only knows its own epoch; even a packet with B's epoch from A's connection is refused.
	assert_false(reg.submit_inputs(PEER_A, b.epoch, _packet([_input(1, Vector2.ZERO, CombatIntent.HEAVY)]), 0), "cross epoch")
	assert_true(reg.submit_inputs(PEER_A, a.epoch, _packet([_input(1, Vector2.ZERO, CombatIntent.HEAVY)]), 0), "own input")
	var intents := reg.collect_intents()
	assert_eq((intents[a.entity_id] as CombatIntent).pressed, CombatIntent.HEAVY, "A's fighter gets A's input")
	assert_eq((intents[b.entity_id] as CombatIntent).pressed, 0, "B's fighter untouched")


func test_speed_hack_move_vector_is_rejected() -> void:
	var q := PeerInputQueue.new()
	assert_eq(q.receive(_raw([1, 127, 127, -1, 0, 0]), 0), -1, "diagonal longer than 1")
	assert_eq(q.receive(_raw([1, 500, 0, -1, 0, 0]), 0), -1, "out of int8 range")
	assert_eq(q.queued(), 0, "no world mutation")


func test_unknown_action_bits_are_rejected() -> void:
	var q := PeerInputQueue.new()
	assert_eq(q.receive(_raw([1, 0, 0, -1, 64, 0]), 0), -1, "unknown pressed bit")
	assert_eq(q.receive(_raw([1, 0, 0, -1, 0, -1]), 0), -1, "all held bits set")
	assert_eq(q.receive(_raw([1, 0, 0, 70000, 0, 0]), 0), -1, "facing out of range")


func test_forged_payload_types_are_rejected() -> void:
	var q := PeerInputQueue.new()
	# A client trying to send results (a teleport position, a damage number) instead of intents.
	assert_eq(q.receive({"position": Vector3(50, 0, 50), "damage": 999}, 0), -1, "dictionary")
	assert_eq(q.receive([1, 0.5, 0.5, -1, 0, 0], 0), -1, "untyped array with floats")
	assert_eq(q.receive(PackedFloat32Array([1, 0, 0, -1, 0, 0]), 0), -1, "float array")
	assert_eq(q.receive(PackedInt32Array(), 0), -1, "empty")
	assert_eq(q.receive(_raw([1, 0, 0, -1, 0]), 0), -1, "truncated record")
	assert_eq(q.queued(), 0, "no world mutation")


func test_oversized_and_unordered_packets_are_rejected() -> void:
	var q := PeerInputQueue.new()
	var many: Array[CombatIntent] = []
	for i in InputCodec.MAX_INPUTS_PER_PACKET + 1:
		many.append(_input(i + 1))
	assert_eq(q.receive(_packet(many), 100), -1, "too many inputs in one packet")
	assert_eq(q.receive(_packet([_input(2), _input(1)]), 0), -1, "descending sequences")
	assert_eq(q.receive(_packet([_input(1), _input(1)]), 0), -1, "repeated sequence")
	assert_eq(q.receive(_raw([0, 0, 0, -1, 0, 0]), 0), -1, "sequence zero")
	assert_eq(q.queued(), 0, "no world mutation")


func test_sequence_cannot_outrun_server_time() -> void:
	var q := PeerInputQueue.new()
	assert_eq(q.receive(_packet([_input(1)]), 0), 1, "first input")
	assert_eq(q.receive(_packet([_input(10_000)]), 1), -1, "jump far beyond elapsed ticks")
	assert_eq(q.last_received, 1, "high-water mark untouched by the forged jump")
	# After a real 3 s outage, a matching sequence gap is legitimate.
	assert_eq(q.receive(_packet([_input(95)]), 90), 1, "gap matching elapsed time")


func test_duplicates_and_replays_apply_once() -> void:
	var q := PeerInputQueue.new()
	assert_eq(q.receive(_packet([_input(1, Vector2.ZERO, CombatIntent.LIGHT)]), 0), 1, "first")
	assert_eq(q.receive(_packet([_input(1, Vector2.ZERO, CombatIntent.LIGHT), _input(2)]), 1), 1, "redundant copy skipped")
	assert_eq(q.receive(_packet([_input(1, Vector2.ZERO, CombatIntent.LIGHT)]), 2), 0, "replay ignored")
	assert_eq(q.next_intent().pressed, CombatIntent.LIGHT, "press applied")
	assert_eq(q.next_intent().pressed, 0, "seq 2")
	var idle := q.next_intent()
	assert_eq(idle.pressed, 0, "starved tick never repeats a press")
	assert_eq(idle.sequence, 2, "ack stays at the last real input")


func test_input_flood_is_rate_limited() -> void:
	var q := PeerInputQueue.new()
	var accepted := 0
	for i in PeerInputQueue.MAX_PACKETS_PER_WINDOW + 20:
		if q.receive(_packet([_input(i + 1)]), 0) >= 0:
			accepted += 1
	assert_eq(accepted, PeerInputQueue.MAX_PACKETS_PER_WINDOW, "packets beyond the window budget dropped")
	assert_true(q.rejected_packets >= 20, "flood counted")


func test_queue_overflow_keeps_presses() -> void:
	var q := PeerInputQueue.new()
	var burst: Array[CombatIntent] = []
	for i in InputCodec.MAX_INPUTS_PER_PACKET:
		burst.append(_input(i + 1, Vector2.ZERO, CombatIntent.DODGE if i == 0 else 0))
	q.receive(_packet(burst), 0)
	var more: Array[CombatIntent] = []
	for i in 4:
		more.append(_input(InputCodec.MAX_INPUTS_PER_PACKET + i + 1))
	q.receive(_packet(more), 4)
	assert_eq(q.queued(), PeerInputQueue.MAX_QUEUE, "trimmed to the jitter buffer")
	assert_eq(q.next_intent().pressed & CombatIntent.DODGE, CombatIntent.DODGE, "dropped tap folded forward")


func test_tampered_input_never_changes_simulation() -> void:
	var reg := _registry()
	var a := reg.get_peer(PEER_A)
	var sim := CombatSimulation.new()
	var fighter := sim.add(Combatant.new(a.entity_id, 1, KATANA))
	reg.submit_inputs(PEER_A, a.epoch, _raw([1, 0, 0, -1, CombatIntent.LIGHT | 256, 0]), 0)
	sim.step(reg.collect_intents())
	assert_eq(fighter.state, Combatant.State.NEUTRAL, "no attack from a rejected packet")
	assert_eq(fighter.stats.stamina, 100, "no stamina spent")


func test_join_validation() -> void:
	var reg := PeerRegistry.new(7, 2) # two seats
	assert_true(reg.try_join(1, NetProtocol.VERSION + 1, "x").has("reason"), "wrong version")
	assert_true(reg.try_join(1, "1", "x").has("reason"), "non-int version")
	var first: PeerRegistry.Peer = reg.try_join(1, NetProtocol.VERSION, "x")["peer"]
	assert_true(reg.try_join(1, NetProtocol.VERSION, "x").has("reason"), "double join")
	reg.try_join(2, NetProtocol.VERSION, "y")
	assert_true(reg.try_join(3, NetProtocol.VERSION, "z").has("reason"), "full")
	assert_true(first.entity_id != 1, "entity id is server-assigned, not the peer id")
	assert_eq(PeerRegistry.sanitize_name("  Musashi\n\t of the very long name  ", "f"), "Musashi of the v", "names stripped and capped")
	assert_eq(PeerRegistry.sanitize_name(123, "fallback"), "fallback", "non-string name")
