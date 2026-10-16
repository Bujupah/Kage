class_name ArmorMaterial
extends RefCounted
## Skin shader for the samurai armour (3DMODELS.md §2.3 "dyes use authored masks and fixed
## channels"). Without authored masks yet, the lacquer and gold-trim channels are isolated from the
## 4K base colour by hue/saturation, so recolours keep every bit of the original shading detail.
## Skin tones (low saturation, orange hue) and black cloth are left untouched.

const SHADER := """
shader_type spatial;
render_mode depth_draw_opaque, cull_back;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D orm_tex : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 lacquer_color : source_color = vec3(0.55, 0.04, 0.03);
uniform float lacquer_strength : hint_range(0.0, 1.0) = 0.0;
uniform vec3 trim_color : source_color = vec3(1.0);
uniform float trim_strength : hint_range(0.0, 1.0) = 0.0;
uniform float lacquer_gloss : hint_range(-0.5, 0.5) = 0.0;
uniform vec3 flash_color : source_color = vec3(0.0);
uniform float flash_energy = 0.0;

vec3 rgb2hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + 1e-10)), d / (q.x + 1e-10), q.x);
}

void fragment() {
	vec4 base = texture(albedo_tex, UV);
	vec3 hsv = rgb2hsv(base.rgb);
	float red_hue = 1.0 - smoothstep(0.02, 0.06, min(hsv.x, 1.0 - hsv.x));
	float lacquer = red_hue * smoothstep(0.55, 0.75, hsv.y) * smoothstep(0.06, 0.18, hsv.z);
	float gold = (1.0 - smoothstep(0.03, 0.06, abs(hsv.x - 0.12))) * smoothstep(0.35, 0.55, hsv.y) * smoothstep(0.25, 0.45, hsv.z);
	// Recolour by luminance so lacquer highlights, chips and seams survive.
	float lum = dot(base.rgb, vec3(0.299, 0.587, 0.114));
	vec3 lacquer_rgb = lacquer_color * clamp(lum / 0.22, 0.0, 2.5);
	vec3 trim_rgb = trim_color * clamp(lum / 0.5, 0.0, 1.8);
	vec3 col = mix(base.rgb, lacquer_rgb, lacquer * lacquer_strength);
	col = mix(col, trim_rgb, gold * trim_strength);
	vec4 orm = texture(orm_tex, UV);
	ALBEDO = col;
	ROUGHNESS = clamp(orm.g - lacquer * lacquer_gloss, 0.04, 1.0);
	METALLIC = orm.b;
	NORMAL_MAP = texture(normal_tex, UV).rgb;
	EMISSION = flash_color * flash_energy;
}
"""

static var _shader: Shader


## Shader material reusing the textures of the imported StandardMaterial3D.
static func from_standard(src: BaseMaterial3D) -> ShaderMaterial:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	var m := ShaderMaterial.new()
	m.shader = _shader
	m.set_shader_parameter("albedo_tex", src.albedo_texture)
	m.set_shader_parameter("normal_tex", src.normal_texture)
	m.set_shader_parameter("orm_tex", src.roughness_texture if src.roughness_texture != null else src.metallic_texture)
	return m


static func apply_outfit(m: ShaderMaterial, outfit: Dictionary) -> void:
	m.set_shader_parameter("lacquer_color", outfit.get("lacquer", Color(0.55, 0.04, 0.03)))
	m.set_shader_parameter("lacquer_strength", 1.0 if outfit.has("lacquer") else 0.0)
	m.set_shader_parameter("trim_color", outfit.get("trim", Color.WHITE))
	m.set_shader_parameter("trim_strength", 1.0 if outfit.has("trim") else 0.0)
	m.set_shader_parameter("lacquer_gloss", float(outfit.get("gloss", 0.0)))
