class_name AssassinModel
extends Node3D
## Animated samurai (3DMODELS.md §2): the CC0 Grab3D samurai (4K PBR lacquered armour, sheathed
## saya on the hip), the Poly Haven antique katana drawn in the right hand and a long procedural
## scarf. Appearance (armour lacquer, blade finish, scarf) comes from CosmeticCatalog IDs.
##
## Presentation only. drive() maps the replicated combat state (state, phase, start tick, attack
## chain) to clips and stretches each clip to the authored frame data, so a swing's strike lands
## on the move's active ticks. Nothing here feeds back into rules (3DMODELS.md §11.4).
##
## Animation: both Quaternius CC0 libraries and the samurai are retargeted at import onto Godot's
## SkeletonProfileHumanoid (BoneMaps in assets/retarget/, tools/make_bone_maps.gd), so every clip
## addresses %GeneralSkeleton:<ProfileBone> and plays on any humanoid body we swap in later.

# Loaded on demand (not preloaded) so the headless server, which references this script through
# FighterBody but never builds visuals, never loads character art.
const BODY_PATH := "res://assets/third_party/grab3d/samurai/samurai-rigged.glb"
const UAL2_PATH := "res://assets/third_party/quaternius_ual2/Unreal-Godot/UAL2_Standard.glb"
const UAL1_PATH := "res://assets/third_party/quaternius_ual1/Godot/AnimationLibrary_Godot_Standard.glb"
const KATANA_PATH := "res://assets/third_party/polyhaven/models/antique_katana_01/antique_katana_01.gltf"

const LIBRARY := &"kage"
const BLEND := 0.12
const BLEND_FAST := 0.06
const GUARD_HOLD := 0.32 ## Fraction of Sword_Block where the guard pose is held.
const WALK_SPEED_REF := 1.6 ## m/s at which the walk clip plays at 1x.
const JOG_SPEED_REF := 4.0
const SPRINT_SPEED_REF := 6.5
const TICK := 1.0 / CombatSimulation.TICK_RATE

## Katana grip in hand_r space (blade along +Y of the katana mesh, tsuba at its origin).
## Grip derived from the hand bones (RightHand space after retargeting): fingers run along +Y,
## index on -Z, thumb on +X (palm side). The handle lies across the palm and the blade leaves the
## fist on the index side (-Z); katana +X follows the fingers so the edge faces away from the wrist.
const GRIP_X := Vector3(0, 1, 0)
const GRIP_Y := Vector3(0, 0, -1)
const GRIP_Z := Vector3(-1, 0, 0)
const PALM := Vector3(0.03, 0.062, 0.012)
const GRIP_ON_HANDLE := -0.13 ## Katana-space Y the fist closes on (mid tsuka, below the tsuba).
## Blade root/tip in katana space, used for sword trails.
## Scarf ties on at the back of the cuirass, where ō-yoroi carry the agemaki cord (UpperChest
## space, -Z is behind), clear of the back plate.
const SCARF_ANCHOR := Vector3(0, 0.1, -0.24)
const BLADE_ROOT := Vector3(0, 0.06, 0)
const BLADE_TIP := Vector3(0, 0.69, 0)

const GLOW_LIGHT := Color(1.0, 0.65, 0.15)
const GLOW_HEAVY := Color(1.0, 0.15, 0.1)
const GLOW_PARRY := Color(0.9, 0.95, 1.0)

static var _shared_library: AnimationLibrary

var body_color := Color(0.16, 0.17, 0.2) ## Unused by the samurai body (kept for API compatibility).
var accent_color := Color(0.62, 0.1, 0.08) ## Trail tint.
var scarf_enabled := true
var appearance: Dictionary = CosmeticCatalog.DEFAULTS.duplicate()

var skeleton: Skeleton3D
var katana: Node3D
var trail: SwordTrail

var _player: AnimationPlayer
var _armor_mat: ShaderMaterial
var _blade_mats: Array[StandardMaterial3D] = []
var _blade_glow := Color.BLACK ## Skin accent added to the telegraph glow.
var _clip_key := ""
var _hold_at := -1.0
var _scarf: ScarfChain


func _ready() -> void:
	var body: Node3D = (load(BODY_PATH) as PackedScene).instantiate()
	body.name = "Body"
	body.rotation.y = PI # The samurai faces +Z; fighters face -Z.
	add_child(body)
	skeleton = body.find_children("*", "Skeleton3D")[0]
	_player = body.find_children("*", "AnimationPlayer")[0]
	_player.add_animation_library(LIBRARY, shared_library())
	_player.playback_default_blend_time = BLEND

	for mi: MeshInstance3D in skeleton.find_children("*", "MeshInstance3D"):
		var src := mi.mesh.surface_get_material(0) as BaseMaterial3D
		if src != null:
			_armor_mat = ArmorMaterial.from_standard(src)
			mi.material_override = _armor_mat

	var grip_basis := Basis(GRIP_X, GRIP_Y, GRIP_Z)
	var grip := Transform3D(grip_basis, PALM - grip_basis * Vector3(0, GRIP_ON_HANDLE, 0))
	katana = _attach(&"RightHand", "weapon_hand_r", (load(KATANA_PATH) as PackedScene).instantiate(), grip)
	for mi: MeshInstance3D in katana.find_children("*", "MeshInstance3D"):
		for s in mi.mesh.get_surface_count():
			var mat := (mi.mesh.surface_get_material(s) as StandardMaterial3D).duplicate() as StandardMaterial3D
			# The scan is a patinated antique; game read needs polished steel that catches the sky.
			mat.metallic = 1.0
			mat.roughness = 0.42
			mat.metallic_specular = 0.6
			mi.set_surface_override_material(s, mat)
			_blade_mats.append(mat)

	trail = SwordTrail.new()
	trail.color = accent_color.lightened(0.35)
	add_child(trail)

	if scarf_enabled:
		_scarf = ScarfChain.new()
		_scarf.facing_source = self
		add_child(_scarf)
		_scarf.anchor = _attach(&"UpperChest", "scarf_upper_back", Node3D.new(), Transform3D(Basis.IDENTITY, SCARF_ANCHOR))
		_scarf.torso_top = _attach(&"UpperChest", "fx_chest", Node3D.new(), Transform3D.IDENTITY)
		_scarf.torso_bottom = _attach(&"Hips", "fx_root", Node3D.new(), Transform3D.IDENTITY)
	apply_appearance(appearance)
	play(&"Sword_Idle", 1.0)


## Applies catalogue IDs (outfit lacquer, blade finish, scarf). Unknown IDs fall back to defaults.
func apply_appearance(app: Dictionary) -> void:
	appearance = CosmeticCatalog.sanitize(app)
	if _armor_mat != null:
		ArmorMaterial.apply_outfit(_armor_mat, CosmeticCatalog.entry("outfit", appearance["outfit"]))
	var blade := CosmeticCatalog.entry("blade", appearance["blade"])
	for mat in _blade_mats:
		mat.albedo_color = (blade.get("tint", Color.WHITE) as Color) * 1.0
	_blade_glow = blade.get("glow", Color.BLACK)
	if trail != null:
		trail.color = (_blade_glow if _blade_glow != Color.BLACK else Color(1, 0.85, 0.75)).lightened(0.2)
	if _scarf != null:
		var scarf := CosmeticCatalog.entry("scarf", appearance["scarf"])
		_scarf.set_look(scarf.get("color", accent_color), float(scarf.get("length", 1.0)))


## All clips in one library. Both sources were retargeted at import, so tracks already address
## %GeneralSkeleton:<ProfileBone>; tracks for bones the body lacks (Root) are dropped.
static func shared_library() -> AnimationLibrary:
	if _shared_library != null:
		return _shared_library
	var body: Node = (load(BODY_PATH) as PackedScene).instantiate()
	var sk: Skeleton3D = body.find_children("*", "Skeleton3D")[0]
	var lib := AnimationLibrary.new()
	for scene: PackedScene in [load(UAL2_PATH), load(UAL1_PATH)]:
		var root: Node = scene.instantiate()
		var src: AnimationPlayer = root.find_children("*", "AnimationPlayer")[0]
		for clip in src.get_animation_list():
			if lib.has_animation(clip):
				continue
			var anim := src.get_animation(clip).duplicate(true) as Animation
			for t in range(anim.get_track_count() - 1, -1, -1):
				var bone := String(anim.track_get_path(t)).get_slice(":", 1)
				if bone.is_empty() or sk.find_bone(bone) < 0:
					anim.remove_track(t)
			lib.add_animation(clip, anim)
		root.free()
	body.free()
	for clip: StringName in [&"Sword_Idle", &"Idle", &"Walk", &"Jog_Fwd", &"Sprint"]:
		if lib.has_animation(clip):
			lib.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	_shared_library = lib
	return lib


# --- State to animation --------------------------------------------------------------------------

## Called once per simulation tick with the fighter's (predicted, interpolated or local) state.
func drive(c: Combatant, now: int, planar_speed: float) -> void:
	var phase := c.attack_phase(now)
	match c.state:
		Combatant.State.NEUTRAL:
			if planar_speed > 5.0:
				_loop(&"Sprint", planar_speed / SPRINT_SPEED_REF)
			elif planar_speed > 2.4:
				_loop(&"Jog_Fwd", planar_speed / JOG_SPEED_REF)
			elif planar_speed > 0.3:
				_loop(&"Walk", planar_speed / WALK_SPEED_REF)
			else:
				_loop(&"Sword_Idle", 1.0)
		Combatant.State.GUARD:
			_once("guard", &"Sword_Block", 2.2, BLEND_FAST, GUARD_HOLD)
		Combatant.State.ATTACK:
			_drive_attack(c, now, phase)
		Combatant.State.DODGE:
			_once("dodge%d" % c.state_start_tick, &"Roll", _fit(&"Roll", Combatant.DODGE_TICKS + 4), BLEND_FAST)
		Combatant.State.HITSTUN:
			var stagger := c.state_duration >= Combatant.PARRIED_STAGGER_TICKS
			var clip := &"Hit_Knockback" if stagger else &"Hit_Chest"
			_once("hit%d" % c.state_start_tick, clip, _fit(clip, maxi(c.state_duration, 6)), BLEND_FAST)
		Combatant.State.POSTURE_BROKEN:
			_once("broken%d" % c.state_start_tick, &"Idle_Shield_Break", _fit(&"Idle_Shield_Break", Combatant.POSTURE_BREAK_TICKS), BLEND_FAST)
		Combatant.State.DEAD:
			_once("dead%d" % c.state_start_tick, &"Death01", 1.4, BLEND_FAST, 0.98)
	_update_blade(c, now, phase)


func _drive_attack(c: Combatant, now: int, phase: Combatant.Phase) -> void:
	var m := c.move
	var strike_ticks := m.windup_ticks + m.active_ticks
	var key := "atk%d" % c.attack_serial
	match c.chain_index:
		0, 1:
			var hit := &"Sword_Regular_A" if c.chain_index == 0 else &"Sword_Regular_B"
			if phase == Combatant.Phase.RECOVERY:
				var rec := StringName(String(hit) + "_Rec")
				_once(key + "r", rec, _fit(rec, m.recovery_ticks), BLEND_FAST)
			else:
				_once(key, hit, _fit(hit, strike_ticks), BLEND_FAST)
		2:
			_once(key, &"Sword_Regular_C", _fit(&"Sword_Regular_C", m.total_ticks()), BLEND_FAST)
		_:
			_once(key, &"Sword_Attack", _fit(&"Sword_Attack", m.total_ticks()), BLEND_FAST)


## Speed that makes `clip` last exactly `ticks` simulation ticks.
func _fit(clip: StringName, ticks: int) -> float:
	var anim := shared_library().get_animation(clip)
	return anim.length / maxf(ticks * TICK, 0.05)


func _loop(clip: StringName, speed: float) -> void:
	if _clip_key != String(clip):
		_clip_key = String(clip)
		_hold_at = -1.0
		_player.play(LIBRARY + "/" + clip, BLEND)
	_player.speed_scale = clampf(speed, 0.6, 1.8)


func _once(key: String, clip: StringName, speed: float, blend: float, hold_fraction: float = -1.0) -> void:
	if _clip_key == key:
		return
	_clip_key = key
	_player.play(LIBRARY + "/" + clip, blend)
	_player.speed_scale = speed
	_hold_at = shared_library().get_animation(clip).length * hold_fraction if hold_fraction > 0.0 else -1.0


## Freezes on `fraction` of `clip` (turntables, previews).
func pose(clip: StringName, fraction: float) -> void:
	_clip_key = String(clip)
	_player.play(LIBRARY + "/" + clip, 0.0)
	_player.seek(shared_library().get_animation(clip).length * fraction, true)
	_player.pause()


func play(clip: StringName, speed: float) -> void:
	_clip_key = String(clip)
	_player.play(LIBRARY + "/" + clip)
	_player.speed_scale = speed


func _process(_delta: float) -> void:
	if _hold_at >= 0.0 and _player.is_playing() and _player.current_animation_position >= _hold_at:
		_player.pause()
		_player.seek(_hold_at, true)


# --- Telegraphs ----------------------------------------------------------------------------------

## Blade glow keeps the M0 readability contract: amber = light windup, red = heavy, white = parry.
func _update_blade(c: Combatant, now: int, phase: Combatant.Phase) -> void:
	var glow := Color.BLACK
	var energy := 0.0
	if c.state == Combatant.State.GUARD and c.is_parrying(now):
		glow = GLOW_PARRY
		energy = 2.5
	elif c.state == Combatant.State.ATTACK:
		var heavy := c.chain_index < 0
		match phase:
			Combatant.Phase.WINDUP:
				var k := float(c.elapsed(now)) / c.move.windup_ticks
				glow = GLOW_HEAVY if heavy else GLOW_LIGHT
				energy = lerpf(0.4, 3.5 if heavy else 2.2, k)
			Combatant.Phase.ACTIVE:
				glow = GLOW_HEAVY
				energy = 4.0
	if energy <= 0.0 and _blade_glow != Color.BLACK:
		glow = _blade_glow # Skin accent at rest; telegraphs always override it.
		energy = 0.6
	for mat in _blade_mats:
		mat.emission_enabled = energy > 0.0
		mat.emission = glow
		mat.emission_energy_multiplier = energy
	trail.emitting = phase == Combatant.Phase.ACTIVE or (phase == Combatant.Phase.WINDUP
			and c.move != null and c.elapsed(now) >= c.move.windup_ticks - 2)


func blade_points() -> PackedVector3Array:
	return PackedVector3Array([katana.global_transform * BLADE_ROOT, katana.global_transform * BLADE_TIP])


func set_body_emission(color: Color, energy: float) -> void:
	if _armor_mat != null:
		_armor_mat.set_shader_parameter("flash_color", color)
		_armor_mat.set_shader_parameter("flash_energy", energy * 0.35)


# --- Built parts ---------------------------------------------------------------------------------

func _attach(bone: StringName, marker: String, child: Node3D, offset: Transform3D) -> Node3D:
	var att := BoneAttachment3D.new()
	att.name = marker
	att.bone_name = bone
	skeleton.add_child(att)
	child.transform = offset
	att.add_child(child)
	return child
