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

## Armour lacquer sets: lacquer/trim recolour the 4K armour textures.
const OUTFITS := {
	"arm.crimson_oath.v1": {"name": "Crimson Oath", "rarity": 0, "price": 0, "currency": "mon",
		"blurb": "The red lacquer of a sworn retainer."},
	"arm.obsidian_vow.v1": {"name": "Obsidian Vow", "rarity": 1, "price": 1800, "currency": "mon",
		"lacquer": Color(0.05, 0.05, 0.06), "trim": Color(0.75, 0.75, 0.78), "gloss": 0.15,
		"blurb": "Black lacquer and silvered trim for those who walk unseen."},
	"arm.indigo_tide.v1": {"name": "Indigo Tide", "rarity": 2, "price": 650, "currency": "jade",
		"lacquer": Color(0.08, 0.14, 0.42), "trim": Color(0.85, 0.78, 0.6),
		"blurb": "Dyed in the colours of the river gate at night."},
	"arm.ivory_crane.v1": {"name": "Ivory Crane", "rarity": 2, "price": 650, "currency": "jade",
		"lacquer": Color(0.82, 0.78, 0.7), "trim": Color(0.55, 0.12, 0.08),
		"blurb": "Pale lacquer with vermilion cords, a ceremonial harness."},
	"arm.jade_serpent.v1": {"name": "Jade Serpent", "rarity": 3, "price": 1400, "currency": "jade",
		"lacquer": Color(0.06, 0.32, 0.22), "trim": Color(0.95, 0.82, 0.45), "gloss": 0.1,
		"blurb": "Legendary harness of the Mistwood wardens."},
}

## Blade finishes for the katana (steel tint, emission accent, wrap colour).
const BLADES := {
	"wpn.katana.tamahagane.v1": {"name": "Tamahagane", "rarity": 0, "price": 0, "currency": "mon",
		"blurb": "Folded steel with a quiet hamon."},
	"wpn.katana.sumi.v1": {"name": "Sumi-e", "rarity": 1, "price": 1200, "currency": "mon",
		"tint": Color(0.22, 0.22, 0.24), "blurb": "Blackened blade, as if painted in ink."},
	"wpn.katana.crimson_edge.v1": {"name": "Crimson Edge", "rarity": 2, "price": 500, "currency": "jade",
		"tint": Color(0.75, 0.62, 0.62), "glow": Color(1.0, 0.18, 0.12), "blurb": "A red line that never dries."},
	"wpn.katana.winter_bell.v1": {"name": "Winter Bell", "rarity": 3, "price": 1200, "currency": "jade",
		"tint": Color(0.75, 0.88, 1.0), "glow": Color(0.55, 0.85, 1.0), "blurb": "Frost blooms along the edge."},
}

## Long scarves (the signature silhouette).
const SCARVES := {
	"scf.ronin_wrap.v1": {"name": "Ronin Wrap", "rarity": 0, "price": 0, "currency": "mon",
		"color": Color(0.55, 0.08, 0.06), "length": 1.0, "blurb": "Worn and patched, still warm."},
	"scf.shadow_veil.v1": {"name": "Shadow Veil", "rarity": 1, "price": 900, "currency": "mon",
		"color": Color(0.06, 0.06, 0.08), "length": 1.15, "blurb": "Dark silk that drinks the lantern light."},
	"scf.moonlit_silk.v1": {"name": "Moonlit Silk", "rarity": 2, "price": 400, "currency": "jade",
		"color": Color(0.8, 0.85, 0.95), "length": 1.25, "blurb": "Pale silk threaded with spectral blue."},
	"scf.crimson_wanderer.v1": {"name": "Crimson Wanderer", "rarity": 3, "price": 900, "currency": "jade",
		"color": Color(0.75, 0.06, 0.05), "length": 1.5, "blurb": "Absurdly long. Gloriously so."},
}

const SLOTS := {"outfit": OUTFITS, "blade": BLADES, "scarf": SCARVES}
const SLOT_NAMES := {"outfit": "Armour", "blade": "Blade", "scarf": "Scarf"}
const DEFAULTS := {"outfit": "arm.crimson_oath.v1", "blade": "wpn.katana.tamahagane.v1", "scarf": "scf.ronin_wrap.v1"}


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
