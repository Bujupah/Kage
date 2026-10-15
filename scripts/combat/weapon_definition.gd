class_name WeaponDefinition
extends Resource
## A weapon family's universal moveset. Abilities and gems will attach to this later (GDD §6–7).

@export var weapon_id: StringName
@export var display_name := ""
@export var light_chain: Array[MoveDefinition] = []
@export var heavy: MoveDefinition


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if weapon_id == &"":
		errors.append("missing weapon_id")
	if light_chain.is_empty():
		errors.append("%s: empty light chain" % weapon_id)
	for m in light_chain:
		if m == null:
			errors.append("%s: null light move" % weapon_id)
		else:
			errors.append_array(m.validate())
	if heavy == null:
		errors.append("%s: missing heavy" % weapon_id)
	else:
		errors.append_array(heavy.validate())
	return errors
