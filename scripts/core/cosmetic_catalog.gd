class_name CosmeticCatalog
extends RefCounted
## Every cosmetic the game knows (3DMODELS.md §1, §10; GUI.md §5.6). Stable, versioned content IDs:
## clients send IDs, the server validates them, and appearance never changes combat stats or
## reach. Prices are in Mon (earned in play) or Jade (premium); there is no payment provider yet,
## so the store is a clearly labelled preview and entitlements are local (see Wardrobe).
##
## When bought or commissioned art arrives, an entry points at new meshes instead of recolour
## parameters; IDs and the pipeline stay the same.

const RARITY_NAMES: Array[String] = ["Common", "Uncommon", "Rare", "Legendary"]
const RARITY_COLORS: Array[Color] = [Color("#B6B4AE"), Color("#6DA987"), Color("#6F8FD6"), Color("#D7AE61")]

## Shinobi garb dyes: `dye` recolours the cloth, `accent` the sash and cuffs, `sheen` adds a silk rim.
const OUTFITS := {
	"gar.mistwood.v1": {"name": "Mistwood Shinobi", "rarity": 0, "price": 0, "currency": "mon",
		"blurb": "Forest-teal garb of the Mistwood cells."},
	"gar.night_heron.v1": {"name": "Night Heron", "rarity": 1, "price": 1800, "currency": "mon",
		"dye": Color(0.035, 0.035, 0.04), "accent": Color(0.55, 0.06, 0.05),
		"blurb": "Black as a moonless pond, with a crimson sash."},
	"gar.ash_walker.v1": {"name": "Ash Walker", "rarity": 2, "price": 650, "currency": "jade",
		"dye": Color(0.42, 0.41, 0.4), "accent": Color(0.85, 0.82, 0.74),
		"blurb": "Grey as burnt temples. Nobody looks twice."},
	"gar.indigo_tide.v1": {"name": "Indigo Tide", "rarity": 2, "price": 650, "currency": "jade",
		"dye": Color(0.07, 0.11, 0.38), "accent": Color(0.85, 0.7, 0.35), "sheen": 0.3,
		"blurb": "Dyed in the colours of the river gate at night."},
	"gar.blood_moon.v1": {"name": "Blood Moon", "rarity": 3, "price": 1400, "currency": "jade",
		"dye": Color(0.36, 0.03, 0.04), "accent": Color(0.05, 0.05, 0.05), "sheen": 0.6,
		"blurb": "Legendary garb of the Red Hand. Silk that drinks lantern light."},
}

## Blade finishes for the katana: steel `tint`, edge `glow`, and an enchantment `fx` (particles
## along the blade: embers, frost, lightning, spirit, fire). Purely visual; never changes reach.
const BLADES := {
	"wpn.katana.tamahagane.v1": {"name": "Tamahagane", "rarity": 0, "price": 0, "currency": "mon",
		"blurb": "Folded steel with a quiet hamon."},
	"wpn.katana.sumi.v1": {"name": "Sumi-e", "rarity": 1, "price": 1200, "currency": "mon",
		"tint": Color(0.22, 0.22, 0.24), "blurb": "Blackened blade, as if painted in ink."},
	"wpn.katana.crimson_edge.v1": {"name": "Crimson Edge", "rarity": 2, "price": 500, "currency": "jade",
		"tint": Color(0.75, 0.62, 0.62), "glow": Color(1.0, 0.18, 0.12), "fx": "embers",
		"blurb": "A red line that never dries. Sheds embers when drawn."},
	"wpn.katana.spirit_lotus.v1": {"name": "Spirit Lotus", "rarity": 2, "price": 600, "currency": "jade",
		"tint": Color(0.7, 0.9, 0.82), "glow": Color(0.25, 1.0, 0.6), "fx": "spirit",
		"blurb": "Jade wisps of the shrine's guardian drift from the steel."},
	"wpn.katana.winter_bell.v1": {"name": "Winter Bell", "rarity": 3, "price": 1200, "currency": "jade",
		"tint": Color(0.75, 0.88, 1.0), "glow": Color(0.55, 0.85, 1.0), "fx": "frost",
		"blurb": "Frost blooms along the edge and snow falls from it."},
	"wpn.katana.raijin_fang.v1": {"name": "Raijin's Fang", "rarity": 3, "price": 1500, "currency": "jade",
		"tint": Color(0.7, 0.72, 0.95), "glow": Color(0.55, 0.45, 1.0), "fx": "lightning",
		"blurb": "Forged in a thunderstorm. It still remembers."},
	"wpn.katana.kagutsuchi.v1": {"name": "Kagutsuchi", "rarity": 3, "price": 1500, "currency": "jade",
		"tint": Color(0.35, 0.2, 0.16), "glow": Color(1.0, 0.45, 0.08), "fx": "fire",
		"blurb": "Named for the fire god. The blade burns without fuel."},
}

## Long scarves (the signature silhouette). Premium silks add a second colour, a pattern
## (0 plain, 1 gradient, 2 seigaiha waves, 3 starfield), a shimmer, glowing tips and tip particles.
const SCARVES := {
	"scf.ronin_wrap.v1": {"name": "Ronin Wrap", "rarity": 0, "price": 0, "currency": "mon",
		"color": Color(0.55, 0.08, 0.06), "length": 1.0, "blurb": "Worn and patched, still warm."},
	"scf.shadow_veil.v1": {"name": "Shadow Veil", "rarity": 1, "price": 900, "currency": "mon",
		"color": Color(0.06, 0.06, 0.08), "length": 1.15, "blurb": "Dark silk that drinks the lantern light."},
	"scf.moonlit_silk.v1": {"name": "Moonlit Silk", "rarity": 2, "price": 400, "currency": "jade",
		"color": Color(0.8, 0.85, 0.95), "color2": Color(0.45, 0.6, 0.95), "pattern": 1, "shimmer": 0.6,
		"length": 1.25, "blurb": "Pale silk threaded with spectral blue."},
	"scf.koi_river.v1": {"name": "Koi River", "rarity": 2, "price": 550, "currency": "jade",
		"color": Color(0.08, 0.14, 0.4), "color2": Color(0.9, 0.88, 0.8), "pattern": 2, "shimmer": 0.25,
		"length": 1.3, "blurb": "Seigaiha waves woven in indigo and bone."},
	"scf.crimson_wanderer.v1": {"name": "Crimson Wanderer", "rarity": 3, "price": 900, "currency": "jade",
		"color": Color(0.75, 0.06, 0.05), "length": 1.5, "blurb": "Absurdly long. Gloriously so."},
	"scf.phoenix_plume.v1": {"name": "Phoenix Plume", "rarity": 3, "price": 1600, "currency": "jade",
		"color": Color(0.7, 0.05, 0.03), "color2": Color(1.0, 0.7, 0.15), "pattern": 1, "shimmer": 0.5,
		"tip_glow": 3.0, "fx": "embers", "length": 1.45, "blurb": "Silk that ends in living flame."},
	"scf.void_silk.v1": {"name": "Void Silk", "rarity": 3, "price": 1600, "currency": "jade",
		"color": Color(0.02, 0.015, 0.04), "color2": Color(0.6, 0.4, 1.0), "pattern": 3, "shimmer": 0.8,
		"tip_glow": 1.5, "fx": "spirit", "length": 1.4, "blurb": "A strip of the night sky, stars still turning."},
	"scf.sakura_storm.v1": {"name": "Sakura Storm", "rarity": 3, "price": 1400, "currency": "jade",
		"color": Color(0.95, 0.62, 0.7), "color2": Color(0.98, 0.92, 0.94), "pattern": 1, "shimmer": 0.4,
		"fx": "petals", "length": 1.35, "blurb": "Every step scatters blossom."},
}

const SLOTS := {"outfit": OUTFITS, "blade": BLADES, "scarf": SCARVES}
const SLOT_NAMES := {"outfit": "Garb", "blade": "Blade", "scarf": "Scarf"}
const DEFAULTS := {"outfit": "gar.mistwood.v1", "blade": "wpn.katana.tamahagane.v1", "scarf": "scf.ronin_wrap.v1"}


const FX_NAMES := {"embers": "Ember sparks", "frost": "Falling frost", "lightning": "Lightning arcs",
	"spirit": "Spirit wisps", "fire": "Living flame", "petals": "Blossom trail"}


## Blurb plus the premium features a player is paying for (effects, pattern, glow), for detail panels.
static func describe(slot: String, id: String) -> String:
	var e := entry(slot, id)
	var lines: Array[String] = [str(e.get("blurb", ""))]
	if e.has("fx"):
		lines.append("✦ Effect: %s" % FX_NAMES.get(e["fx"], e["fx"]))
	if slot == "scarf" and int(e.get("pattern", 0)) > 0:
		lines.append("✦ Woven: %s" % ["", "gradient silk", "seigaiha waves", "starfield"][int(e["pattern"])])
	if slot == "outfit" and float(e.get("sheen", 0.0)) > 0.0:
		lines.append("✦ Silk sheen")
	return "\n".join(lines)


static func entry(slot: String, id: String) -> Dictionary:
	return (SLOTS.get(slot, {}) as Dictionary).get(id, {})


static func is_valid(slot: String, id: Variant) -> bool:
	return typeof(id) == TYPE_STRING and SLOTS.has(slot) and (SLOTS[slot] as Dictionary).has(id)


static func is_free(slot: String, id: String) -> bool:
	return int(entry(slot, id).get("price", 1)) == 0


## Server-side sanitising of a client's appearance (unknown IDs fall back to defaults). Entitlement
## checks need the Go ledger (P2); until then only catalogue membership is enforced.
static func sanitize(appearance: Variant) -> Dictionary:
	var out := DEFAULTS.duplicate()
	if typeof(appearance) != TYPE_DICTIONARY:
		return out
	for slot: String in SLOTS:
		var id: Variant = (appearance as Dictionary).get(slot)
		if is_valid(slot, id):
			out[slot] = id
	return out
