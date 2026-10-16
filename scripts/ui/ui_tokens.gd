class_name UiTokens
extends RefCounted
## Design tokens from GUI.md §3. Every UI colour, size and font comes from here so screens stay
## consistent and accessibility options (text scale, high contrast) apply everywhere at once.

const SURFACE_BASE := Color("#111315")
const SURFACE_RAISED := Color("#1C2023")
const SURFACE_PAPER := Color("#D8CFBD")
const TEXT_PRIMARY := Color("#F2EEE6")
const TEXT_SECONDARY := Color("#B6B4AE")
const VERMILION := Color("#C94F43")
const GOLD := Color("#D7AE61")
const SPIRIT := Color("#9883CF")
const SAFE := Color("#6DA987")

const HEALTH := Color("#B8423A")
const HEALTH_LAG := Color("#E8D9B0") ## Delayed-damage segment.
const STAMINA := Color("#6DA987")
const POSTURE := GOLD

## Spacing scale (px at the 1600x900 reference).
const S1 := 4
const S2 := 8
const S3 := 12
const S4 := 16
const S5 := 24
const S6 := 32
const MIN_TARGET := 44 ## Minimum interactive height for controller-friendly menus.

const FONT_UI := "res://assets/third_party/fonts/inter/Inter.ttf"
const FONT_DISPLAY := "res://assets/third_party/fonts/cormorant/CormorantGaramond.ttf"
const FONT_BRUSH := "res://assets/third_party/fonts/yuji_boku/YujiBoku-Kage-subset.ttf" ## 影刀剣道武侍心静敗勝…
const UI_TEX := "res://assets/ui/%s.png"

const SIZE_BODY := 17
const SIZE_SMALL := 14
const SIZE_H2 := 26
const SIZE_H1 := 44
const SIZE_TITLE := 96


static func zone_color(rule: int) -> Color:
	match rule:
		ZoneRule.SAFE_SANCTUARY:
			return SAFE
		ZoneRule.ARENA_PROTECTED:
			return GOLD
	return VERMILION


static var _fonts: Dictionary = {}


## Display face: Cormorant Garamond at semibold with open tracking; body: Inter.
static func font(display: bool = false) -> Font:
	return display_font() if display else body_font()


static func display_font() -> Font:
	if not _fonts.has("display"):
		var f := FontVariation.new()
		f.base_font = load(FONT_DISPLAY)
		f.variation_opentype = {"wght": 600}
		f.spacing_glyph = 1
		_fonts["display"] = f
	return _fonts["display"]


static func body_font() -> Font:
	if not _fonts.has("body"):
		var f := FontVariation.new()
		f.base_font = load(FONT_UI)
		f.variation_opentype = {"wght": 420}
		_fonts["body"] = f
	return _fonts["body"]


## Small-caps style labels: Inter semibold, widely tracked.
static func overline_font() -> Font:
	if not _fonts.has("overline"):
		var f := FontVariation.new()
		f.base_font = load(FONT_UI)
		f.variation_opentype = {"wght": 600}
		f.spacing_glyph = 3
		_fonts["overline"] = f
	return _fonts["overline"]


static func brush_font() -> Font:
	return load(FONT_BRUSH)


static func tex(name: String) -> Texture2D:
	return load(UI_TEX % name)


static func scaled(px: int) -> int:
	return roundi(px * GameSettings.text_scale())
