extends SceneTree
## Writes the BoneMap resources that retarget every humanoid source onto Godot's
## SkeletonProfileHumanoid at import (3DMODELS.md §2.2: canonical rig, explicit adapters).
##   godot --headless --path . -s res://tools/make_bone_maps.gd

const FINGERS := ["Thumb", "Index", "Middle", "Ring", "Little"]
const SEGMENTS := {"Thumb": ["Metacarpal", "Proximal", "Distal"], "Index": ["Proximal", "Intermediate", "Distal"],
	"Middle": ["Proximal", "Intermediate", "Distal"], "Ring": ["Proximal", "Intermediate", "Distal"],
	"Little": ["Proximal", "Intermediate", "Distal"]}


func _initialize() -> void:
	_save("res://assets/retarget/ual2_bone_map.tres", _ual2())
	_save("res://assets/retarget/ual1_bone_map.tres", _ual1())
	_save("res://assets/retarget/ninja_bone_map.tres", _mixamo("res://assets/third_party/sketchfab/ninja/ninja.glb"))
	quit()


func _save(path: String, map: Dictionary) -> void:
	var bm := BoneMap.new()
	bm.profile = SkeletonProfileHumanoid.new()
	for profile_bone: String in map:
		bm.set_skeleton_bone_name(profile_bone, map[profile_bone])
	print(path, " ", ResourceSaver.save(bm, path), " (", map.size(), " bones)")


func _limbs(m: Dictionary, f: Callable) -> void:
	for side in ["Left", "Right"]:
		for part in ["Shoulder", "UpperArm", "LowerArm", "Hand", "UpperLeg", "LowerLeg", "Foot", "Toes"]:
			m[side + part] = f.call(side, part, "", 0)
		for finger: String in FINGERS:
			for i in 3:
				m[side + finger + SEGMENTS[finger][i]] = f.call(side, "finger", finger, i + 1)


func _ual2() -> Dictionary:
	var m := {"Root": "root", "Hips": "pelvis", "Spine": "spine_01", "Chest": "spine_02", "UpperChest": "spine_03", "Neck": "neck_01", "Head": "Head"}
	_limbs(m, func(side: String, part: String, finger: String, n: int) -> String:
		const PARTS := {"Shoulder": "clavicle", "UpperArm": "upperarm", "LowerArm": "lowerarm", "Hand": "hand",
			"UpperLeg": "thigh", "LowerLeg": "calf", "Foot": "foot", "Toes": "ball"}
		var s := "l" if side == "Left" else "r"
		if part == "finger":
			return "%s_%02d_%s" % ["pinky" if finger == "Little" else finger.to_lower(), n, s]
		return "%s_%s" % [PARTS[part], s])
	return m


func _ual1() -> Dictionary:
	var m := {"Root": "root", "Hips": "DEF-hips", "Spine": "DEF-spine.001", "Chest": "DEF-spine.002", "UpperChest": "DEF-spine.003", "Neck": "DEF-neck", "Head": "DEF-head"}
	_limbs(m, func(side: String, part: String, finger: String, n: int) -> String:
		const PARTS := {"Shoulder": "shoulder", "UpperArm": "upper_arm", "LowerArm": "forearm", "Hand": "hand",
			"UpperLeg": "thigh", "LowerLeg": "shin", "Foot": "foot", "Toes": "toe"}
		var s := "L" if side == "Left" else "R"
		if part == "finger":
			var f := "thumb" if finger == "Thumb" else "f_" + ("pinky" if finger == "Little" else finger.to_lower())
			return "DEF-%s.%02d.%s" % [f, n, s]
		return "DEF-%s.%s" % [PARTS[part], s])
	return m


## Mixamo rigs exported through Sketchfab carry "mixamorig_<Bone>_<index>" names; resolve each
## profile bone by stripping the prefix and index from the names actually in the file.
func _mixamo(path: String) -> Dictionary:
	var scene: Node = (load(path) as PackedScene).instantiate()
	var sk: Skeleton3D = scene.find_children("*", "Skeleton3D", true, false)[0]
	var by_base := {}
	var re := RegEx.create_from_string("^mixamorig_(.+?)_\\d+$")
	for i in sk.get_bone_count():
		var full := sk.get_bone_name(i)
		var hit := re.search(full)
		by_base[hit.get_string(1) if hit != null else full] = full
	scene.free()
	var m := {"Hips": by_base["Hips"], "Spine": by_base["Spine"], "Chest": by_base["Spine1"],
		"UpperChest": by_base["Spine2"], "Neck": by_base["Neck"], "Head": by_base["Head"]}
	_limbs(m, func(side: String, part: String, finger: String, n: int) -> String:
		const PARTS := {"Shoulder": "Shoulder", "UpperArm": "Arm", "LowerArm": "ForeArm", "Hand": "Hand",
			"UpperLeg": "UpLeg", "LowerLeg": "Leg", "Foot": "Foot", "Toes": "ToeBase"}
		var base: String = "%sHand%s%d" % [side, "Pinky" if finger == "Little" else finger, n] if part == "finger" else side + PARTS[part]
		return by_base.get(base, ""))
	return m
