extends SceneTree
## Packs Poly Haven PBR sets into Terrain3D's layout (albedo RGB + height A, normal RGB +
## roughness A) so the terrain shader samples two textures per layer instead of four.
##   godot --headless --path . -s res://tools/pack_terrain_textures.gd
## Height comes from albedo luminance (Poly Haven displacement maps are not downloaded).

const LAYERS := ["leafy_grass", "forest_leaves_02", "mossy_rock", "raked_dirt"]
const SRC := "res://assets/third_party/polyhaven/textures/%s/%s_%s_1k.jpg"
const OUT := "res://assets/terrain/%s_%s.webp"


func _initialize() -> void:
	for id: String in LAYERS:
		var alb := Image.load_from_file(ProjectSettings.globalize_path(SRC % [id, id, "diff"]))
		var nrm := Image.load_from_file(ProjectSettings.globalize_path(SRC % [id, id, "nor_gl"]))
		var arm := Image.load_from_file(ProjectSettings.globalize_path(SRC % [id, id, "arm"]))
		for img in [alb, nrm, arm]:
			img.convert(Image.FORMAT_RGBA8)
		for y in alb.get_height():
			for x in alb.get_width():
				var a := alb.get_pixel(x, y)
				a.a = a.get_luminance()
				alb.set_pixel(x, y, a)
				var n := nrm.get_pixel(x, y)
				n.a = arm.get_pixel(x, y).g
				nrm.set_pixel(x, y, n)
		alb.save_webp(ProjectSettings.globalize_path(OUT % [id, "alb_h"]), true, 0.92)
		nrm.save_webp(ProjectSettings.globalize_path(OUT % [id, "nrm_r"]), true, 0.95)
		print("packed ", id)
	quit()
