class_name PlayerProfile
extends RefCounted
## Local player profile: display name, equipped appearance, owned cosmetics and wallet.
##
## Until the Go ledger exists (P2) this lives in user://profile.cfg and the wallet holds demo
## currency, which the Store labels plainly. The server never trusts this file: it only accepts
## catalogue IDs (CosmeticCatalog.sanitize), and real entitlement checks move server-side in P2.

const PATH := "user://profile.cfg"
const START_MON := 3000
const START_JADE := 1200

class Bus extends RefCounted:
	signal changed

static var bus := Bus.new()
static var _loaded := false
static var _equipped: Dictionary = {}
static var _owned: Array[String] = []
static var _wallet := {"mon": START_MON, "jade": START_JADE}
static var _title := "Shadow of the Shrouded Province"
static var _persist := true


static func ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	_equipped = CosmeticCatalog.DEFAULTS.duplicate()
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		_equipped = CosmeticCatalog.sanitize(cfg.get_value("profile", "equipped", {}))
		var owned: Variant = cfg.get_value("profile", "owned", [])
		if typeof(owned) == TYPE_ARRAY:
			for id: Variant in owned:
				if typeof(id) == TYPE_STRING:
					_owned.append(id)
		_wallet["mon"] = int(cfg.get_value("profile", "mon", START_MON))
		_wallet["jade"] = int(cfg.get_value("profile", "jade", START_JADE))
	for slot: String in CosmeticCatalog.SLOTS:
		for id: String in CosmeticCatalog.SLOTS[slot]:
			if CosmeticCatalog.is_free(slot, id) and not _owned.has(id):
				_owned.append(id)


static func save() -> void:
	if not _persist:
		return
	var cfg := ConfigFile.new()
	cfg.set_value("profile", "equipped", _equipped)
	cfg.set_value("profile", "owned", _owned)
	cfg.set_value("profile", "mon", _wallet["mon"])
	cfg.set_value("profile", "jade", _wallet["jade"])
	cfg.save(PATH)


static func appearance() -> Dictionary:
	ensure_loaded()
	return _equipped.duplicate()


static func title() -> String:
	return _title


static func display_name() -> String:
	var n := str(GameSettings.get_value("network", "player_name"))
	return n if not n.is_empty() else "Nameless Shadow"


static func owns(id: String) -> bool:
	ensure_loaded()
	return _owned.has(id)


static func balance(currency: String) -> int:
	ensure_loaded()
	return int(_wallet.get(currency, 0))


static func equip(slot: String, id: String) -> bool:
	ensure_loaded()
	if not CosmeticCatalog.is_valid(slot, id) or not owns(id):
		return false
	_equipped[slot] = id
	save()
	bus.changed.emit()
	return true


## Returns "" on success or a player-facing reason.
static func purchase(slot: String, id: String) -> String:
	ensure_loaded()
	var e := CosmeticCatalog.entry(slot, id)
	if e.is_empty():
		return "Unknown item."
	if owns(id):
		return "Already owned."
	var cur: String = e["currency"]
	var price: int = e["price"]
	if balance(cur) < price:
		return "Not enough %s." % ("Jade" if cur == "jade" else "Mon")
	_wallet[cur] = balance(cur) - price
	_owned.append(id)
	save()
	bus.changed.emit()
	return ""


## Test hook: forget everything (used by unit tests, never by the game).
static func reset_for_tests() -> void:
	_loaded = true
	_persist = false
	_equipped = CosmeticCatalog.DEFAULTS.duplicate()
	_owned.clear()
	_wallet = {"mon": START_MON, "jade": START_JADE}
	for slot: String in CosmeticCatalog.SLOTS:
		for id: String in CosmeticCatalog.SLOTS[slot]:
			if CosmeticCatalog.is_free(slot, id):
				_owned.append(id)
