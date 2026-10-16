class_name SwordTrail
extends MeshInstance3D
## Fading ribbon between blade root and tip (3DMODELS.md FX-001). Purely cosmetic: it follows the
## animated blade, never the authoritative hit volume, and it is sampled at render rate so it stays
## smooth at any frame rate.

const MAX_SAMPLES := 14
const SAMPLE_SECONDS := 0.016
const FADE_SECONDS := 0.16

var color := Color(1, 0.85, 0.75)
var emitting := false
var source: AssassinModel

var _samples: Array[Dictionary] = [] ## {root, tip, age}
var _since_sample := 0.0
var _mesh := ImmediateMesh.new()


func _ready() -> void:
	top_level = true
	mesh = _mesh
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.vertex_color_use_as_albedo = true
	material_override = mat
	if source == null:
		source = get_parent() as AssassinModel


func _process(delta: float) -> void:
	global_transform = Transform3D.IDENTITY
	for s in _samples:
		s["age"] += delta
	while not _samples.is_empty() and _samples[0]["age"] > FADE_SECONDS:
		_samples.pop_front()
	_since_sample += delta
	if emitting and source != null and source.katana != null and _since_sample >= SAMPLE_SECONDS:
		_since_sample = 0.0
		var pts := source.blade_points()
		_samples.append({"root": pts[0], "tip": pts[1], "age": 0.0})
		while _samples.size() > MAX_SAMPLES:
			_samples.pop_front()
	_rebuild()


func _rebuild() -> void:
	_mesh.clear_surfaces()
	if _samples.size() < 2:
		return
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for s in _samples:
		var a := clampf(1.0 - s["age"] / FADE_SECONDS, 0.0, 1.0)
		_mesh.surface_set_color(Color(color, 0.0))
		_mesh.surface_add_vertex(s["root"])
		_mesh.surface_set_color(Color(color, 0.55 * a))
		_mesh.surface_add_vertex(s["tip"])
	_mesh.surface_end()
