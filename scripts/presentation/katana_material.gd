class_name KatanaMaterial
extends RefCounted
## Katana shader: the Poly Haven scan is one mesh and one material, so the blade is found by its
## position along the sword (katana-space Y past the tsuba). Only the blade becomes polished steel
## with the finish tint and the enchantment / telegraph glow; tsuka wrap, tsuba and habaki keep
## the scan's own patina. The glow ripples slowly along the edge so enchanted steel looks alive.

const SHADER := """
shader_type spatial;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic;
uniform sampler2D rough_tex : hint_default_white, filter_linear_mipmap_anisotropic;
uniform sampler2D metal_tex : hint_default_black, filter_linear_mipmap_anisotropic;
uniform vec3 yrow = vec3(0.0, 1.0, 0.0); // katana-space Y = dot(yrow, VERTEX) + yoff
uniform float yoff = 0.0;
uniform float blade_from = 0.055;
uniform vec3 tint : source_color = vec3(1.0);
uniform vec3 glow_color : source_color = vec3(0.0);
uniform float glow_energy = 0.0;
uniform float ripple = 0.0;

varying float ky;

void vertex() {
	ky = dot(yrow, VERTEX) + yoff;
}

void fragment() {
	float blade = smoothstep(blade_from, blade_from + 0.015, ky);
	vec3 base = texture(albedo_tex, UV).rgb;
	ALBEDO = mix(base, base * tint, blade);
	METALLIC = mix(texture(metal_tex, UV).b, 1.0, blade);
	ROUGHNESS = mix(texture(rough_tex, UV).g, 0.38, blade);
	SPECULAR = mix(0.5, 0.65, blade);
	NORMAL_MAP = texture(normal_tex, UV).rgb;
	float wave = 1.0 + ripple * (0.35 * sin(ky * 38.0 - TIME * 5.0) + 0.15 * sin(ky * 91.0 + TIME * 3.1));
	EMISSION = glow_color * glow_energy * blade * wave;
}
"""

static var _shader: Shader


## `to_katana` maps the mesh's local space into katana space (blade along +Y from the tsuba).
static func from_standard(src: BaseMaterial3D, to_katana: Transform3D) -> ShaderMaterial:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	var m := ShaderMaterial.new()
	m.shader = _shader
	m.set_shader_parameter("albedo_tex", src.albedo_texture)
	m.set_shader_parameter("normal_tex", src.normal_texture)
	m.set_shader_parameter("rough_tex", src.roughness_texture)
	m.set_shader_parameter("metal_tex", src.metallic_texture if src.metallic_texture != null else src.roughness_texture)
	var b := to_katana.basis
	m.set_shader_parameter("yrow", Vector3(b.x.y, b.y.y, b.z.y))
	m.set_shader_parameter("yoff", to_katana.origin.y)
	return m


static func set_glow(m: ShaderMaterial, color: Color, energy: float, ripple: float = 0.0) -> void:
	m.set_shader_parameter("glow_color", color)
	m.set_shader_parameter("glow_energy", energy)
	m.set_shader_parameter("ripple", ripple)
