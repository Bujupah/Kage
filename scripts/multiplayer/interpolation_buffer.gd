class_name InterpolationBuffer
extends RefCounted
## Recent authoritative samples for one remote fighter, rendered a short delay behind the newest
## server tick (MULTIPLAYER.md §5 "Remote players"). Positions blend between the two snapshots that
## bracket the render tick; discrete combat state comes from the older one. Past the newest sample
## the fighter is extrapolated for a few ticks at most, then held. A new life (respawn) restarts the
## buffer so a fighter never slides from its corpse to the spawn point.

const CAPACITY := 32
const MAX_EXTRAPOLATION_TICKS := 3

var _samples: Array[Dictionary] = [] ## {tick, position, yaw, record}, oldest first.


## Rejects samples that are not strictly newer than the newest one stored.
func push(tick: int, position: Vector3, yaw: float, record: Array) -> bool:
	if not _samples.is_empty() and not NetProtocol.is_newer(tick, _samples[-1]["tick"]):
		return false
	if not _samples.is_empty() and record[SnapshotCodec.LIFE] != _samples[-1]["record"][SnapshotCodec.LIFE]:
		_samples.clear()
	_samples.append({"tick": tick, "position": position, "yaw": yaw, "record": record})
	while _samples.size() > CAPACITY:
		_samples.pop_front()
	return true


func is_empty() -> bool:
	return _samples.is_empty()


func newest_tick() -> int:
	return _samples[-1]["tick"] if not _samples.is_empty() else -1


func clear() -> void:
	_samples.clear()


## Returns {position, yaw, record} at `render_tick`, or {} with no samples yet.
func sample(render_tick: float) -> Dictionary:
	if _samples.is_empty():
		return {}
	var first: Dictionary = _samples[0]
	if render_tick <= first["tick"]:
		return _at(first)
	for i in range(_samples.size() - 1, 0, -1):
		var a: Dictionary = _samples[i - 1]
		var b: Dictionary = _samples[i]
		if render_tick >= a["tick"] and render_tick <= b["tick"]:
			var k: float = (render_tick - a["tick"]) / float(b["tick"] - a["tick"])
			return {
				"position": (a["position"] as Vector3).lerp(b["position"], k),
				"yaw": lerp_angle(a["yaw"], b["yaw"], k),
				"record": a["record"] if k < 1.0 else b["record"],
			}
	# Beyond the newest sample: limited extrapolation from the last two, then hold.
	var last: Dictionary = _samples[-1]
	if _samples.size() < 2:
		return _at(last)
	var prev: Dictionary = _samples[-2]
	var span := float(last["tick"] - prev["tick"])
	var ahead := minf(render_tick - last["tick"], MAX_EXTRAPOLATION_TICKS)
	var velocity: Vector3 = ((last["position"] as Vector3) - prev["position"]) / span
	return {"position": last["position"] + velocity * ahead, "yaw": last["yaw"], "record": last["record"]}


static func _at(s: Dictionary) -> Dictionary:
	return {"position": s["position"], "yaw": s["yaw"], "record": s["record"]}
