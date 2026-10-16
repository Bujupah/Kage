class_name ArmorMaterial
extends RefCounted
## Garb dye shader for the assassin (3DMODELS.md §2.3 "dyes use authored masks and fixed channels").
## Without authored masks yet, the dark-teal cloth and the green sash are isolated from the 4K base
## colour by hue, saturation and value, then re-dyed by luminance so folds, stitching and wear
## survive. Skin, leather, steel and the white headband are left untouched.

const SHADER := """
shader_type spatial;
render_mode depth_draw_opaque, cull_back;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D orm_tex : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 dye_color : source_color = vec3(0.1);
uniform float dye_strength : hint_range(0.0, 1.0) = 0.0;
uniform vec3 accent_color : source_color = vec3(1.0);
uniform float accent_strength : hint_range(0.0, 1.0) = 0.0;
uniform float sheen : hint_range(0.0, 1.0) = 0.0;
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
	// Cloth: dark teal-to-blue fabric. Sash/cuffs: saturated green.
	float teal = smoothstep(0.40, 0.45, hsv.x) * (1.0 - smoothstep(0.62, 0.68, hsv.x));
	float cloth = teal * smoothstep(0.08, 0.16, hsv.y) * (1.0 - smoothstep(0.42, 0.55, hsv.z));
	float green = smoothstep(0.27, 0.31, hsv.x) * (1.0 - smoothstep(0.44, 0.48, hsv.x));
	float accent = green * smoothstep(0.35, 0.5, hsv.y) * smoothstep(0.12, 0.2, hsv.z);
	float lum = dot(base.rgb, vec3(0.299, 0.587, 0.114));
	vec3 dyed = dye_color * clamp(lum / 0.12, 0.0, 2.6);
	vec3 acc = accent_color * clamp(lum / 0.3, 0.0, 2.0);
	vec3 col = mix(base.rgb, dyed, cloth * dye_strength);
	col = mix(col, acc, accent * accent_strength);
	vec4 orm = texture(orm_tex, UV);
	ALBEDO = col;
	ROUGHNESS = clamp(orm.g - cloth * sheen * 0.35, 0.04, 1.0);
	METALLIC = orm.b;
	NORMAL_MAP = texture(normal_tex, UV).rgb;
	// Silk sheen: a soft rim that only premium dyes switch on.
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION = flash_color * flash_energy + dye_color * fres * sheen * cloth * 0.6;
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
	m.set_shader_parameter("dye_color", outfit.get("dye", Color(0.1, 0.1, 0.1)))
	m.set_shader_parameter("dye_strength", 1.0 if outfit.has("dye") else 0.0)
	m.set_shader_parameter("accent_color", outfit.get("accent", Color.WHITE))
	m.set_shader_parameter("accent_strength", 1.0 if outfit.has("accent") else 0.0)
	m.set_shader_parameter("sheen", float(outfit.get("sheen", 0.0)))
