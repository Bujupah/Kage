class_name PeerInputQueue
extends RefCounted
## Server-side input stream for one connected player. Clients send each input several times
## (unreliable + redundancy), so duplicates are expected and silently skipped; anything malformed,
## out of order, impossibly far ahead or too frequent rejects the whole packet without touching state.
##
## One input is consumed per server tick. `last_applied` is the ack echoed in snapshots: the client
## replays every input after it on top of the authoritative state.

const MAX_QUEUE := 8 ## Jitter buffer; older inputs are folded forward beyond this.
## Clients produce one input per tick, so a sequence can never run ahead of the ticks elapsed since
## the last accepted packet by more than this slack; faster jumps are forged, not lost.
const SEQUENCE_JUMP_SLACK := 16
const MAX_PACKETS_PER_WINDOW := 75 ## Client sends 30/s; leave room for bursts after a stall.
const RATE_WINDOW_TICKS := CombatSimulation.TICK_RATE

var last_received := 0 ## Highest sequence accepted into the queue.
var last_applied := 0 ## Highest sequence handed to the simulation (the ack).
var rejected_packets := 0
var last_received_tick := 0 ## Server tick of the last accepted packet; bounds sequence jumps.

var _queue: Array[CombatIntent] = []
var _last_intent := CombatIntent.new()
var _window := -1
var _packets_in_window := 0


## Returns how many new inputs were queued, or -1 if the packet was rejected.
func receive(payload: Variant, now: int) -> int:
	if not _within_rate(now):
		return _reject()
	var intents := InputCodec.decode(payload)
	if intents.is_empty():
		return _reject()
	var fresh: Array[CombatIntent] = []
	for intent in intents:
		if intent.sequence > last_received:
			fresh.append(intent)
	if fresh.is_empty():
		return 0 # Pure redundancy or a late duplicate.
	if fresh[-1].sequence - last_received > maxi(now - last_received_tick, 0) + SEQUENCE_JUMP_SLACK:
		return _reject()
	for intent in fresh:
		_queue.append(intent)
	last_received = fresh[-1].sequence
	last_received_tick = now
	while _queue.size() > MAX_QUEUE:
		var dropped: CombatIntent = _queue.pop_front()
		_queue[0].pressed |= dropped.pressed # Never lose a tap, only the stale movement sample.
		last_applied = dropped.sequence
	return fresh.size()


## The intent for this server tick. With nothing queued (loss or jitter) the last movement and held
## buttons continue, but presses never repeat.
func next_intent() -> CombatIntent:
	if not _queue.is_empty():
		_last_intent = _queue.pop_front()
		last_applied = _last_intent.sequence
		return _last_intent
	var repeat := CombatIntent.make(0, _last_intent.held, _last_intent.move)
	repeat.face_dir = _last_intent.face_dir
	repeat.sequence = last_applied
	return repeat


func queued() -> int:
	return _queue.size()


func _within_rate(now: int) -> bool:
	var window := now / RATE_WINDOW_TICKS
	if window != _window:
		_window = window
		_packets_in_window = 0
	_packets_in_window += 1
	return _packets_in_window <= MAX_PACKETS_PER_WINDOW


func _reject() -> int:
	rejected_packets += 1
	return -1
