extends SceneTree
## Bakes the painted UI textures into assets/ui/ (GUI.md §3: ink, washi, lacquer, gold leaf).
##   godot --headless --path . -s res://tools/bake_ui_textures.gd
## Procedural so the look is reproducible; artists can overpaint the PNGs later without code changes.

const OUT := "res://assets/ui/%s.png"
const GOLD := Color("#D7AE61")
const INK := Color("#0B0C0D")

var _noise := FastNoiseLite.new()
var _fine := FastNoiseLite.new()


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/ui"))
	_noise.seed = 3
	_noise.frequency = 0.035
	_noise.fractal_octaves = 4
	_fine.seed = 9
	_fine.frequency = 0.35
	_save("panel", _panel(160, 160))
	_save("panel_soft", _panel_soft(160, 160))
	_save("brush_bar", _brush(512, 48, 0.0))
	_save("brush_swipe", _brush(512, 96, 0.35))
	_save("divider", _divider(768, 24))
	_save("ring", _ring(160))
	_save("grain", _grain(256))
	_save("ink_cloud", _ink_cloud(512))
	_save("corner", _corner(96))
	quit()


func _save(name: String, img: Image) -> void:
	img.save_png(ProjectSettings.globalize_path(OUT % name))
	print("baked ", name, " ", img.get_size())


## 9-slice panel (margins 40): lacquer-dark wash with paper grain, gold hairlines top and bottom
## that fade toward the sides, small gold corner brackets, faint inner shadow.
func _panel(w: int, h: int) -> Image:
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var n := _noise.get_noise_2d(x * 2.0, y * 2.0) * 0.5 + 0.5
			var g := _fine.get_noise_2d(x, y) * 0.5 + 0.5
			var edge := minf(minf(x, w - 1 - x), minf(y, h - 1 - y))
			var shade := lerpf(0.055, 0.085, n) + (g - 0.5) * 0.015
			var c := Color(shade * 1.05, shade, shade * 0.95, 0.9)
			c = c.darkened(clampf(1.0 - edge / 18.0, 0.0, 1.0) * 0.45) # inner shadow
			img.set_pixel(x, y, c)
	# Gold rules, inset 7 px, fading over the outer 40 px so 9-slice stretching keeps them crisp.
	for x in w:
		var fade := clampf(minf(x, w - 1 - x) / 40.0, 0.0, 1.0)
		for y in [7, h - 8]:
			img.set_pixel(x, y, img.get_pixel(x, y).lerp(GOLD, 0.85 * fade))
		for y in [8, h - 9]:
			img.set_pixel(x, y, img.get_pixel(x, y).lerp(GOLD.darkened(0.5), 0.35 * fade))
	# Corner brackets.
	for c: Vector2i in [Vector2i(3, 3), Vector2i(w - 4, 3), Vector2i(3, h - 4), Vector2i(w - 4, h - 4)]:
		var sx := 1 if c.x < w / 2 else -1
		var sy := 1 if c.y < h / 2 else -1
		for i in 14:
			img.set_pixel(c.x + sx * i, c.y, GOLD)
			img.set_pixel(c.x, c.y + sy * i, GOLD)
		for d in 3:
			img.set_pixel(c.x + sx * (3 + d), c.y + sy * 3, GOLD.darkened(0.2))
	return img


## Borderless soft panel: wash that fades to transparent at the edges (for overlays and pills).
func _panel_soft(w: int, h: int) -> Image:
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var n := _noise.get_noise_2d(x * 2.0, y * 2.0) * 0.5 + 0.5
			var edge := minf(minf(x, w - 1 - x), minf(y, h - 1 - y))
			var a := smoothstep(0.0, 38.0, edge) * 0.8
			var shade := lerpf(0.04, 0.07, n)
			img.set_pixel(x, y, Color(shade, shade, shade * 0.95, a))
	return img


## Horizontal sumi brush stroke in white (tinted at runtime): ragged top/bottom edges, dry-brush
## streaks, tapered ends. `drift` lets the stroke wander vertically (for hover swipes).
func _brush(w: int, h: int, drift: float) -> Image:
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	var streaks := FastNoiseLite.new()
	streaks.seed = 17
	streaks.frequency = 0.08
	for x in w:
		var u := float(x) / (w - 1)
		var taper := smoothstep(0.0, 0.06, u) * (1.0 - smoothstep(0.9, 1.0, u))
		var center := h * 0.5 + _noise.get_noise_1d(x * 0.6) * h * drift
		var half := h * 0.42 * lerpf(0.55, 1.0, taper) * (0.92 + _noise.get_noise_1d(x * 3.0 + 50.0) * 0.12)
		for y in h:
			var d := absf(y - center)
			var ragged := half + _fine.get_noise_2d(x * 1.5, y * 4.0) * 2.5
			var a := clampf((ragged - d) / 1.6, 0.0, 1.0)
			var dry := smoothstep(-0.35, 0.25, streaks.get_noise_2d(x * 0.15, y * 3.5))
			a *= lerpf(0.55, 1.0, dry) * (0.35 + 0.65 * taper)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return img


func _divider(w: int, h: int) -> Image:
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var cy := h / 2
	for x in w:
		var u := absf(float(x) / (w - 1) - 0.5) * 2.0
		var a := (1.0 - smoothstep(0.1, 1.0, u)) * 0.9
		img.set_pixel(x, cy, Color(GOLD, a))
		img.set_pixel(x, cy + 1, Color(GOLD.darkened(0.5), a * 0.4))
	# Centre lozenge with a dot either side.
	var cx := w / 2
	for dy in range(-6, 7):
		var half := 6 - absi(dy)
		for dx in range(-half, half + 1):
			img.set_pixel(cx + dx, cy + dy, GOLD if absi(dx) + absi(dy) > 2 else Color(GOLD, 0.3))
	for s in [-1, 1]:
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				img.set_pixel(cx + s * 16 + dx, cy + dy, GOLD)
	return img


## Skill-slot ring: thin gold circle with four cardinal ticks and a soft dark disc.
func _ring(size: int) -> Image:
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var c := Vector2(size, size) * 0.5
	var r := size * 0.44
	for y in size:
		for x in size:
			var p := Vector2(x + 0.5, y + 0.5) - c
			var d := p.length()
			var disc := clampf((r - d) / 1.5, 0.0, 1.0) * 0.72
			var ring := clampf(1.0 - absf(d - r) / 1.3, 0.0, 1.0)
			var inner := clampf(1.0 - absf(d - (r - 6.0)) / 0.9, 0.0, 1.0) * 0.35
			var ang := atan2(p.y, p.x)
			var tick := 0.0
			for k in 4:
				var a0 := k * PI * 0.5 - PI * 0.5
				if absf(wrapf(ang - a0, -PI, PI)) < 0.03 and d > r - 1 and d < r + 9:
					tick = 1.0
			var col := Color(INK, disc).blend(Color(GOLD, maxf(maxf(ring, inner), tick)))
			img.set_pixel(x, y, col)
	return img


func _grain(size: int) -> Image:
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for y in size:
		for x in size:
			var v := rng.randf()
			img.set_pixel(x, y, Color(v, v, v, 1.0))
	return img


## Soft sumi cloud (alpha): sits behind titles and the menu column like ink bleeding into paper.
func _ink_cloud(size: int) -> Image:
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var c := Vector2(size, size) * 0.5
	for y in size:
		for x in size:
			var p := (Vector2(x, y) - c) / (size * 0.5)
			var n := _noise.get_noise_2d(x * 0.9, y * 0.9) * 0.5 + 0.5
			var a := clampf(1.0 - p.length() * (0.9 + n * 0.5), 0.0, 1.0)
			a = smoothstep(0.0, 0.8, a) * lerpf(0.6, 1.0, n)
			img.set_pixel(x, y, Color(0.02, 0.02, 0.025, a))
	return img


## Ornamental corner flourish (top-left; flipped in UI for the other corners).
func _corner(size: int) -> Image:
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for i in size:
		var a := 1.0 - float(i) / size
		img.set_pixel(i, 0, Color(GOLD, a))
		img.set_pixel(0, i, Color(GOLD, a))
		if i < size * 0.45:
			img.set_pixel(i, 5, Color(GOLD, a * 0.5))
			img.set_pixel(5, i, Color(GOLD, a * 0.5))
	for t in 64:
		var ang := t / 64.0 * PI * 0.5
		var p := Vector2(12, 12) + Vector2(cos(ang), sin(ang)) * 9.0
		img.set_pixel(int(p.x), int(p.y), GOLD)
	return img
