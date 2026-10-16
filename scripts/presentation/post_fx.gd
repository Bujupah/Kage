class_name PostFx
extends CanvasLayer
## Final image pass over the 3D view, under the HUD and menus (layer 5):
##   * contrast-adaptive sharpening (AMD CAS-style), which restores texture detail that TAA,
##     FSR 2 and MetalFX soften, without haloing edges that are already sharp;
##   * a filmic night grade: cool lifted shadows, warm highlights (lantern light stays gold),
##     gentle highlight roll-off and a touch of local contrast;
##   * lens character: faint chromatic fringe and vignette toward the corners.
## Settings: video/post_fx (on/off) and video/sharpen (0..1). Cosmetic only; never brightens
## darkness enough to change what a player can see compared with the post_fx-off image.

const SHADER := """
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen : hint_screen_texture, filter_linear;
uniform float sharpen : hint_range(0.0, 1.0) = 0.5;
uniform float grade : hint_range(0.0, 1.0) = 1.0;
uniform float fringe : hint_range(0.0, 1.0) = 0.35;
uniform float vignette : hint_range(0.0, 1.0) = 0.3;
uniform vec3 shadow_tint : source_color = vec3(0.6, 0.66, 0.78);
uniform vec3 highlight_tint : source_color = vec3(1.0, 0.86, 0.68);

vec3 tap(vec2 uv) { return texture(screen, uv).rgb; }

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 px = SCREEN_PIXEL_SIZE;
	// Chromatic fringe grows toward the corners only.
	vec2 from_centre = uv - 0.5;
	float edge = dot(from_centre, from_centre);
	vec2 shift = from_centre * edge * fringe * 0.012;
	vec3 c = vec3(tap(uv - shift).r, tap(uv).g, tap(uv + shift).b);
	// CAS: sharpening amount from local contrast in a 3x3 cross.
	vec3 n = tap(uv + vec2(0.0, -px.y));
	vec3 s = tap(uv + vec2(0.0, px.y));
	vec3 e = tap(uv + vec2(px.x, 0.0));
	vec3 w = tap(uv + vec2(-px.x, 0.0));
	vec3 mn = min(c, min(min(n, s), min(e, w)));
	vec3 mx = max(c, max(max(n, s), max(e, w)));
	vec3 amp = sqrt(clamp(min(mn, 1.0 - mx) / max(mx, vec3(1e-4)), 0.0, 1.0));
	float peak = -1.0 / mix(8.0, 5.0, sharpen);
	vec3 wgt = amp * peak;
	vec3 sharp = (c + (n + s + e + w) * wgt) / (1.0 + 4.0 * wgt);
	c = mix(c, clamp(sharp, 0.0, 1.0), step(0.001, sharpen));
	// Night grade: split-tone by luminance, then a soft S-curve.
	float l = dot(c, vec3(0.2126, 0.7152, 0.0722));
	vec3 toned = c * mix(shadow_tint * 1.3, vec3(1.0), smoothstep(0.0, 0.3, l));
	toned = mix(toned, toned * highlight_tint * 1.12, smoothstep(0.45, 1.0, l));
	toned = mix(toned, toned * toned * (3.0 - 2.0 * toned), 0.25);
	c = mix(c, toned, grade);
	c *= 1.0 - vignette * smoothstep(0.18, 0.75, edge * 2.2);
	COLOR = vec4(c, 1.0);
}
"""

var _rect := ColorRect.new()
var _mat := ShaderMaterial.new()


func _ready() -> void:
	layer = 5
	process_mode = Node.PROCESS_MODE_ALWAYS
	_mat.shader = Shader.new()
	_mat.shader.code = SHADER
	_rect.material = _mat
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_rect)
	GameSettings.bus.changed.connect(func(section: String, _key: String) -> void:
		if section == "video" or section == "accessibility":
			_apply())
	_apply()


func _apply() -> void:
	var on := bool(GameSettings.get_value("video", "post_fx"))
	_rect.visible = on
	_mat.set_shader_parameter("sharpen", float(GameSettings.get_value("video", "sharpen")))
	# Accessibility: no lens effects for players who asked for reduced flashes/motion.
	var calm := GameSettings.reduced_flashes() or bool(GameSettings.get_value("accessibility", "reduced_motion"))
	_mat.set_shader_parameter("fringe", 0.0 if calm else 0.35)
