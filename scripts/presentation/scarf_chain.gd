class_name ScarfChain
extends MeshInstance3D
## The signature long scarf (3DMODELS.md §5): a verlet point chain hung from the neck marker and
## drawn as a two-sided ribbon. Cheap enough for every fighter (no soft-body physics), kept off the
## sword arm and out of the body by a simple capsule push, and never part of hit detection.

const SEGMENTS := 12
const SEGMENT_LENGTH := 0.115 ## ~1.4 m: the "Crimson Wanderer" hero length.
const WIDTH := 0.1
const GRAVITY := Vector3(0, -9.8, 0)
const DRAG := 0.06
const STEP := 1.0 / 90.0
const BODY_RADIUS := 0.2
const TORSO_FORWARD := 0.08
const MAX_STEP_MOVE := 0.09 ## Cap per-step travel (8 m/s) so sudden moves can't whip the scarf skyward.

var color := Color(0.62, 0.1, 0.08)
var anchor: Node3D
var facing_source: Node3D ## The fighter; its +Z is "behind", where the scarf streams.
var torso_top: Node3D ## Chest marker; with torso_bottom it bounds the capsule the scarf rests on.
var torso_bottom: Node3D
const TRAIL_FORCE := 3.5 ## Constant push behind the wearer, so the scarf reads as a trailing tail.
var wind := Vector3(0.6, 0.0, 0.25)

var _points: PackedVector3Array = []
var _previous: PackedVector3Array = []
var _accumulator := 0.0
var _time := 0.0
var _mesh := ImmediateMesh.new()


## Silk shader: UV.x runs across the ribbon, UV.y from the knot (0) to the tip (1).
const SHADER := """
shader_type spatial;
render_mode cull_disabled;
uniform vec3 color1 : source_color = vec3(0.6, 0.1, 0.08);
uniform vec3 color2 : source_color = vec3(1.0);
uniform int pattern = 0;
uniform float shimmer = 0.0;
uniform float tip_glow = 0.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }

void fragment() {
	float u = UV.x;
	float v = UV.y;
	vec3 c = color1;
	vec3 glow = vec3(0.0);
	if (pattern == 1) {
		c = mix(color1, color2, smoothstep(0.15, 1.0, v));
	} else if (pattern == 2) {
		// Seigaiha: offset rows of concentric wave arcs.
		vec2 g = vec2(u * 2.0, v * 16.0);
		float row = floor(g.y);
		g.x += mod(row, 2.0) * 0.5;
		vec2 f = vec2(fract(g.x) - 0.5, fract(g.y));
		float r = length(f);
		float ring = step(0.5, fract(r * 3.5));
		c = mix(color1, color2, ring * (1.0 - step(0.62, r)) * 0.85);
	} else if (pattern == 3) {
		// Starfield drifting toward the tip, each star on its own twinkle.
		vec2 g = vec2(u * 5.0, v * 34.0 - TIME * 0.35);
		vec2 id = floor(g);
		float h = hash(id);
		float star = step(0.82, h) * smoothstep(0.28, 0.0, length(fract(g) - 0.5));
		star *= 0.55 + 0.45 * sin(TIME * 3.0 + h * 40.0);
		c = mix(color1, color2 * 0.25, smoothstep(0.0, 1.0, v) * 0.5);
		glow += color2 * star * 2.2;
	}
	float band = pow(0.5 + 0.5 * sin(v * 7.0 - TIME * 1.6 + u * 2.0), 10.0);
	float fres = pow(1.0 - abs(dot(NORMAL, VIEW)), 2.0);
	ALBEDO = c;
	ROUGHNESS = 0.75 - shimmer * 0.4;
	SPECULAR = 0.4 + shimmer * 0.4;
	BACKLIGHT = c * 0.45;
	glow += color2 * (fres * 0.35 + band * 0.3) * shimmer;
	glow += mix(color1, color2, 0.6) * tip_glow * smoothstep(0.8, 1.0, v);
	EMISSION = glow;
}
"""

static var _shader: Shader

var _mat := ShaderMaterial.new()
var _segment_length := SEGMENT_LENGTH
var _tip_fx: EnchantFx


func _ready() -> void:
	top_level = true
	mesh = _mesh
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	_mat.shader = _shader
	_mat.set_shader_parameter("color1", color)
	material_override = _mat


## Colour and length multiplier (Crimson Wanderer is 1.5x).
func set_look(new_color: Color, length_scale: float) -> void:
	set_style({"color": new_color, "length": length_scale})


## Full scarf cosmetic: colours, pattern, shimmer, glowing tip and tip particles (CosmeticCatalog).
func set_style(style: Dictionary) -> void:
	color = style.get("color", color)
	_segment_length = SEGMENT_LENGTH * clampf(float(style.get("length", 1.0)), 0.5, 2.0)
	_mat.set_shader_parameter("color1", color)
	_mat.set_shader_parameter("color2", style.get("color2", color.lightened(0.3)))
	_mat.set_shader_parameter("pattern", int(style.get("pattern", 0)))
	_mat.set_shader_parameter("shimmer", float(style.get("shimmer", 0.0)))
	_mat.set_shader_parameter("tip_glow", float(style.get("tip_glow", 0.0)))
	var fx := str(style.get("fx", ""))
	if fx.is_empty():
		if _tip_fx != null:
			_tip_fx.queue_free()
			_tip_fx = null
		return
	if _tip_fx == null:
		_tip_fx = EnchantFx.new()
		_tip_fx.extents = Vector3(0.05, 0.05, 0.05)
		_tip_fx.with_light = false
		_tip_fx.top_level = true
		add_child(_tip_fx)
	_tip_fx.set_effect(fx, style.get("color2", color))


func _process(delta: float) -> void:
	if anchor == null or not anchor.is_inside_tree():
		return
	global_transform = Transform3D.IDENTITY
	var origin := anchor.global_position
	if _points.is_empty() or _points[0].distance_to(origin) > 3.0:
		_reset(origin)
	_accumulator = minf(_accumulator + delta, STEP * 6.0)
	_time += delta
	while _accumulator >= STEP:
		_accumulator -= STEP
		_simulate(origin)
	_rebuild()
	if _tip_fx != null and _points.size() > 3:
		_tip_fx.global_position = _points[_points.size() - 2]


func _reset(origin: Vector3) -> void:
	_points.resize(SEGMENTS + 1)
	_previous.resize(SEGMENTS + 1)
	var back := facing_source.global_basis.z.normalized() if facing_source != null else Vector3.BACK
	for i in SEGMENTS + 1:
		_points[i] = origin + (back * 0.3 + Vector3.DOWN).normalized() * _segment_length * i
		_previous[i] = _points[i]


func _simulate(origin: Vector3) -> void:
	var gust := wind * (0.6 + 0.4 * sin(_time * 1.7) + 0.25 * sin(_time * 4.3))
	if facing_source != null:
		var behind := facing_source.global_basis.z
		behind.y = 0.0
		gust += behind.normalized() * TRAIL_FORCE
	# Torso capsule along the animated spine (the neck marker itself sits on the back).
	var body_axis_top := torso_top.global_position if torso_top != null else origin + Vector3.DOWN * 0.15
	var body_axis_bottom := torso_bottom.global_position if torso_bottom != null else origin + Vector3.DOWN * 0.6
	if facing_source != null:
		# Spine bones sit near the back; centre the torso capsule inside the chest instead.
		var forward := -facing_source.global_basis.z
		forward.y = 0.0
		forward = forward.normalized() * TORSO_FORWARD
		body_axis_top += forward
		body_axis_bottom += forward
	_points[0] = origin
	_previous[0] = origin
	for i in range(1, SEGMENTS + 1):
		var p := _points[i]
		var v := ((p - _previous[i]) * (1.0 - DRAG)).limit_length(MAX_STEP_MOVE)
		_previous[i] = p
		_points[i] = p + v + (GRAVITY + gust * (float(i) / SEGMENTS)) * STEP * STEP
	for _iteration in 3:
		for i in range(1, SEGMENTS + 1):
			var a := _points[i - 1]
			var b := _points[i]
			var d := b - a
			var len := d.length()
			if len > 0.0001:
				_points[i] = a + d * (_segment_length / len)
			_points[i] = _push_out(_points[i], body_axis_top, body_axis_bottom)


static func _push_out(p: Vector3, top: Vector3, bottom: Vector3) -> Vector3:
	var axis := bottom - top
	var t := clampf((p - top).dot(axis) / axis.length_squared(), 0.0, 1.0)
	var closest := top + axis * t
	var off := p - closest
	var dist := off.length()
	if dist < BODY_RADIUS and dist > 0.0001:
		return closest + off / dist * BODY_RADIUS
	return p


func _rebuild() -> void:
	_mesh.clear_surfaces()
	if _points.size() < 2:
		return
	var side := anchor.global_basis.x.normalized()
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in _points.size():
		var w := WIDTH * lerpf(1.0, 0.75, float(i) / SEGMENTS) * 0.5
		var along := (_points[mini(i + 1, SEGMENTS)] - _points[maxi(i - 1, 0)]).normalized()
		var across := (side - along * side.dot(along)).normalized()
		var normal := along.cross(across).normalized()
		var v := float(i) / SEGMENTS
		_mesh.surface_set_normal(normal)
		_mesh.surface_set_uv(Vector2(0.0, v))
		_mesh.surface_add_vertex(_points[i] - across * w)
		_mesh.surface_set_normal(normal)
		_mesh.surface_set_uv(Vector2(1.0, v))
		_mesh.surface_add_vertex(_points[i] + across * w)
	_mesh.surface_end()
