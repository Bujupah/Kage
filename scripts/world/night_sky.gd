class_name NightSky
extends RefCounted
## Procedural night sky (ENVIRONMENT.md §9 "night"): deep blue gradient, crisp hashed stars at any
## resolution, a Milky Way band, a moon disc with halo that follows the "Moon" light, and thin
## drifting clouds lit from the moon side. Radiance passes skip stars and clouds so image-based
## lighting stays a smooth cool fill. The shader never reads TIME: a time-dependent sky forces the
## radiance cubemap to re-render every frame, which cost ~25% of the frame at night.

const SHADER := """
shader_type sky;
render_mode use_half_res_pass;

uniform vec3 zenith : source_color = vec3(0.006, 0.010, 0.028);
uniform vec3 horizon : source_color = vec3(0.045, 0.065, 0.11);
uniform vec3 ground : source_color = vec3(0.01, 0.012, 0.016);
uniform vec3 moon_tint : source_color = vec3(0.85, 0.9, 1.0);
uniform float moon_size = 0.022;
uniform float star_density = 0.0;
uniform float cloud_cover = 0.42;
uniform vec2 cloud_offset = vec2(0.0);

float hash3(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise3(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash3(i), hash3(i + vec3(1, 0, 0)), f.x), mix(hash3(i + vec3(0, 1, 0)), hash3(i + vec3(1, 1, 0)), f.x), f.y),
			mix(mix(hash3(i + vec3(0, 0, 1)), hash3(i + vec3(1, 0, 1)), f.x), mix(hash3(i + vec3(0, 1, 1)), hash3(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

float fbm(vec3 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * noise3(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

vec3 stars(vec3 dir) {
	vec3 col = vec3(0.0);
	for (int layer = 0; layer < 2; layer++) {
		float scale = layer == 0 ? 260.0 : 520.0;
		vec3 p = dir * scale;
		vec3 cell = floor(p);
		float h = hash3(cell);
		float threshold = layer == 0 ? 0.992 : 0.994;
		if (h > threshold) {
			vec3 centre = cell + 0.5 + (vec3(hash3(cell + 11.0), hash3(cell + 23.0), hash3(cell + 37.0)) - 0.5) * 0.6;
			float d = length(p - centre);
			float b = smoothstep(0.32, 0.0, d) * (0.25 + 0.75 * (h - threshold) / (1.0 - threshold));
			float twinkle = 0.7 + 0.3 * hash3(cell + 71.0);
			vec3 tint = mix(vec3(0.75, 0.82, 1.0), vec3(1.0, 0.86, 0.7), hash3(cell + 5.0));
			col += tint * b * twinkle * (layer == 0 ? 1.1 : 0.55);
		}
	}
	return col;
}

void sky() {
	vec3 dir = EYEDIR;
	float up = dir.y;
	vec3 col = mix(horizon, zenith, pow(clamp(up, 0.0, 1.0), 0.45));
	if (up < 0.0) {
		col = mix(horizon, ground, smoothstep(0.0, 0.15, -up));
	}
	vec3 moon_dir = -LIGHT0_DIRECTION;
	float md = dot(dir, moon_dir);
	// Halo: wide cool glow plus a tight ring.
	col += moon_tint * (pow(max(md, 0.0), 64.0) * 0.12 + pow(max(md, 0.0), 900.0) * 0.6) * LIGHT0_ENERGY;
	if (!AT_CUBEMAP_PASS && up > -0.02) {
		float fade = smoothstep(-0.02, 0.18, up);
		// Milky Way: a band around a tilted great circle, broken up by dust lanes.
		vec3 band_axis = normalize(vec3(0.35, 0.55, 0.76));
		float band = exp(-pow(dot(dir, band_axis) / 0.16, 2.0));
		float dust = fbm(dir * 9.0);
		float glow = band * smoothstep(0.35, 0.75, fbm(dir * 4.0 + 3.0)) * (1.0 - 0.7 * smoothstep(0.55, 0.7, dust));
		col += vec3(0.16, 0.17, 0.24) * glow * 0.6 * fade;
		col += stars(dir) * (1.0 + band * 1.5) * fade * (1.0 - smoothstep(0.9995, 0.99995, md));
		// Moon disc with soft limb darkening and faint maria.
		float disc = smoothstep(cos(moon_size), cos(moon_size * 0.92), md);
		if (disc > 0.0) {
			float maria = fbm(dir * 180.0);
			col = mix(col, moon_tint * (2.6 - maria * 1.1) * LIGHT0_ENERGY * 2.0, disc);
		}
		// Thin clouds on a dome, lit on the moon side.
		vec2 uv = dir.xz / max(up + 0.12, 0.05);
		float c = fbm(vec3(uv * 0.55 + cloud_offset, 0.0));
		float cloud = smoothstep(1.0 - cloud_cover, 1.0 - cloud_cover + 0.32, c) * smoothstep(0.02, 0.25, up);
		vec3 lit = mix(vec3(0.03, 0.04, 0.06), moon_tint * 0.22, pow(max(md, 0.0), 6.0));
		col = mix(col, lit + horizon * 0.4, cloud * 0.85);
	}
	COLOR = col;
}
"""

static var _shader: Shader


static func material() -> ShaderMaterial:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	var m := ShaderMaterial.new()
	m.shader = _shader
	return m
