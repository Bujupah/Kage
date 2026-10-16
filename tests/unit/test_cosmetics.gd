extends TestCase
## Cosmetics pipeline (3DMODELS.md §10, GUI.md §5.6): stable IDs, server-side sanitising, purchase
## and equip rules, and replication through admission. Cosmetics never touch combat stats.


func test_catalog_ids_are_versioned_and_complete() -> void:
	for slot: String in CosmeticCatalog.SLOTS:
		assert_true(CosmeticCatalog.is_valid(slot, CosmeticCatalog.DEFAULTS[slot]), "default %s" % slot)
		assert_true(CosmeticCatalog.is_free(slot, CosmeticCatalog.DEFAULTS[slot]), "default %s is free" % slot)
		for id: String in CosmeticCatalog.SLOTS[slot]:
			var e: Dictionary = CosmeticCatalog.SLOTS[slot][id]
			assert_true(id.ends_with(".v1"), "versioned id %s" % id)
			assert_true(e.has("name") and e.has("rarity") and e.has("price") and e.has("currency"), "fields for %s" % id)
			assert_true(e["currency"] in ["mon", "jade"], "currency for %s" % id)


func test_sanitize_rejects_forged_appearance() -> void:
	var forged := {"outfit": "arm.does_not_exist.v9", "blade": 42, "scarf": "scf.moonlit_silk.v1", "hitbox": "huge"}
	var clean := CosmeticCatalog.sanitize(forged)
	assert_eq(clean["outfit"], CosmeticCatalog.DEFAULTS["outfit"], "unknown outfit falls back")
	assert_eq(clean["blade"], CosmeticCatalog.DEFAULTS["blade"], "non-string blade falls back")
	assert_eq(clean["scarf"], "scf.moonlit_silk.v1", "valid scarf kept")
	assert_false(clean.has("hitbox"), "unknown keys dropped")
	assert_eq(CosmeticCatalog.sanitize("nonsense"), CosmeticCatalog.DEFAULTS, "non-dictionary")


func test_purchase_spends_and_grants_once() -> void:
	PlayerProfile.reset_for_tests()
	var mon := PlayerProfile.balance("mon")
	assert_false(PlayerProfile.owns("arm.obsidian_vow.v1"), "not owned yet")
	assert_false(PlayerProfile.equip("outfit", "arm.obsidian_vow.v1"), "cannot equip unowned")
	assert_eq(PlayerProfile.purchase("outfit", "arm.obsidian_vow.v1"), "", "purchase ok")
	assert_eq(PlayerProfile.balance("mon"), mon - 1800, "price paid")
	assert_eq(PlayerProfile.purchase("outfit", "arm.obsidian_vow.v1"), "Already owned.", "no double purchase")
	assert_eq(PlayerProfile.balance("mon"), mon - 1800, "charged once")
	assert_true(PlayerProfile.equip("outfit", "arm.obsidian_vow.v1"), "equip after purchase")
	assert_eq(PlayerProfile.appearance()["outfit"], "arm.obsidian_vow.v1", "equipped")


func test_cannot_buy_without_funds() -> void:
	PlayerProfile.reset_for_tests()
	assert_eq(PlayerProfile.purchase("outfit", "arm.jade_serpent.v1"), "Not enough Jade.", "1400 > 1200 jade")
	assert_false(PlayerProfile.owns("arm.jade_serpent.v1"), "not granted")
	assert_eq(PlayerProfile.balance("jade"), PlayerProfile.START_JADE, "nothing spent")
	assert_eq(PlayerProfile.purchase("blade", "wpn.katana.nope.v1"), "Unknown item.", "unknown item")


func test_admission_stores_only_sanitised_appearance() -> void:
	var reg := PeerRegistry.new(3)
	var p: PeerRegistry.Peer = reg.try_join(10, NetProtocol.VERSION, "A", 0,
			{"outfit": "arm.indigo_tide.v1", "blade": "wpn.katana.fake.v1"})["peer"]
	assert_eq(p.appearance["outfit"], "arm.indigo_tide.v1", "valid outfit kept")
	assert_eq(p.appearance["blade"], CosmeticCatalog.DEFAULTS["blade"], "forged blade replaced")


func test_cosmetics_do_not_change_combat() -> void:
	var katana: WeaponDefinition = load("res://data/weapons/katana_starter.tres")
	var a := Combatant.new(1, 1, katana)
	var b := Combatant.new(2, 1, katana)
	# Appearance lives only on the presentation side: Combatant has no cosmetic fields at all.
	for prop in a.get_property_list():
		assert_false(String(prop["name"]).contains("appearance"), "no cosmetic state in rules")
	assert_eq(a.weapon.light_chain[0].reach, b.weapon.light_chain[0].reach, "same reach")
