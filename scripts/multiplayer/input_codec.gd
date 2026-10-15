class_name InputCodec
extends RefCounted
## Quantized wire form of CombatIntent (MULTIPLAYER.md §3 "InputCommand"). One input is six ints:
##   [sequence, move_x, move_y, face_yaw, pressed, held]
## move_x/move_y are -127..127, face_yaw is 0..65535 or -1 for "no facing hint". A packet is a flat
## PackedInt32Array holding 1..MAX_INPUTS_PER_PACKET inputs with strictly increasing sequences.
##
## The client predicts with decode(encode(intent)), so prediction and the server see identical
## values. Decoding is strict: one bad field rejects the whole packet; nothing is "repaired".

const FIELDS := 6
const MAX_INPUTS_PER_PACKET := 8
const MOVE_SCALE := 127
const MAX_MOVE_LENGTH_Q := 128.0 ## 127 plus rounding slack; (127, 127) is a tampered diagonal.
const YAW_STEPS := 65536
const NO_FACING := -1
const KNOWN_BITS := CombatIntent.LIGHT | CombatIntent.HEAVY | CombatIntent.GUARD \
		| CombatIntent.DODGE | CombatIntent.SPRINT
const MAX_SEQUENCE := 0x7fffffff


static func encode_one(intent: CombatIntent) -> PackedInt32Array:
	var move := intent.move.limit_length(1.0)
	var yaw := NO_FACING
	var face := Vector2(intent.face_dir.x, intent.face_dir.z)
	if face.length_squared() > 0.0001:
		yaw = posmod(roundi(atan2(face.x, face.y) / TAU * YAW_STEPS), YAW_STEPS)
	return PackedInt32Array([
		intent.sequence,
		roundi(move.x * MOVE_SCALE),
		roundi(move.y * MOVE_SCALE),
		yaw,
		intent.pressed & KNOWN_BITS,
		intent.held & KNOWN_BITS,
	])


static func encode(intents: Array[CombatIntent]) -> PackedInt32Array:
	var out := PackedInt32Array()
	for intent in intents:
		out.append_array(encode_one(intent))
	return out


## Returns the decoded intents, or an empty array if the payload is malformed or tampered.
static func decode(payload: Variant) -> Array[CombatIntent]:
	var none: Array[CombatIntent] = []
	if typeof(payload) != TYPE_PACKED_INT32_ARRAY:
		return none
	var data: PackedInt32Array = payload
	if data.is_empty() or data.size() % FIELDS != 0 or data.size() / FIELDS > MAX_INPUTS_PER_PACKET:
		return none
	var out: Array[CombatIntent] = []
	var previous := 0
	for i in range(0, data.size(), FIELDS):
		var intent := _decode_record(data, i)
		if intent == null or intent.sequence <= previous:
			return none
		previous = intent.sequence
		out.append(intent)
	return out


## Round-trips an intent through the wire format (used by the client for prediction).
static func quantize(intent: CombatIntent) -> CombatIntent:
	var decoded := decode(encode_one(intent))
	return decoded[0] if not decoded.is_empty() else CombatIntent.new()


static func _decode_record(d: PackedInt32Array, i: int) -> CombatIntent:
	var seq := d[i]
	var mx := d[i + 1]
	var my := d[i + 2]
	var yaw := d[i + 3]
	var pressed := d[i + 4]
	var held := d[i + 5]
	if seq < 1 or seq > MAX_SEQUENCE:
		return null
	if absi(mx) > MOVE_SCALE or absi(my) > MOVE_SCALE or Vector2(mx, my).length() > MAX_MOVE_LENGTH_Q:
		return null
	if yaw < NO_FACING or yaw >= YAW_STEPS:
		return null
	if (pressed & ~KNOWN_BITS) != 0 or (held & ~KNOWN_BITS) != 0:
		return null
	var intent := CombatIntent.new()
	intent.sequence = seq
	intent.move = Vector2(mx, my) / float(MOVE_SCALE)
	if yaw != NO_FACING:
		var a := float(yaw) / YAW_STEPS * TAU
		intent.face_dir = Vector3(sin(a), 0.0, cos(a))
	intent.pressed = pressed
	intent.held = held
	return intent
