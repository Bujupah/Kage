extends TestCase

const KATANA_PATH := "res://data/weapons/katana_starter.tres"


func test_katana_loads_with_typed_chain() -> void:
	var katana: WeaponDefinition = load(KATANA_PATH)
	assert_true(katana != null, "katana resource loads")
	assert_eq(katana.weapon_id, &"weapon.katana.starter.v1", "weapon id")
	assert_eq(katana.light_chain.size(), 3, "light chain length")
	assert_eq(katana.heavy.move_id, &"move.katana.heavy.v1", "heavy id")


func test_all_content_validates() -> void:
	var katana: WeaponDefinition = load(KATANA_PATH)
	var errors := katana.validate()
	assert_true(errors.is_empty(), "content errors: %s" % ", ".join(errors))


func test_move_ids_are_unique() -> void:
	var katana: WeaponDefinition = load(KATANA_PATH)
	var seen := {}
	for m in katana.light_chain + [katana.heavy]:
		assert_false(seen.has(m.move_id), "duplicate move id %s" % m.move_id)
		seen[m.move_id] = true
