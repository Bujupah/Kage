# Samurai Assassin — 3D Models, Characters, Animation & VFX Bible

> **Status:** Proposed specification; **P0 items 1–4 have first implementations**: see "Implementation status".  
> **Engine:** Godot 4.x, GDScript gameplay/presentation, Go backend services. **Source DCC:** Blender recommended. **Interchange:** glTF 2.0 / `.glb` where supported.  
> **Related:** [GDD.md](GDD.md), [GUI.md](GUI.md), [ENVIRONMENT.md](ENVIRONMENT.md), [ARCHITECTURE.md](ARCHITECTURE.md).

## Implementation status (P0 vertical slice)

| P0 item (§14) | State | Where |
|---|---|---|
| 1. Canonical rig, base body, outfit, long scarf | Grab3D CC0 samurai (4K PBR armour, rigged); canonical rig = Godot `SkeletonProfileHumanoid` via import BoneMaps; verlet scarf tied at the cuirass (`scarf_upper_back`); markers `weapon_hand_r`, `fx_chest`, `fx_root` | `scripts/presentation/assassin_model.gd`, `scarf_chain.gd`, `assets/retarget/` |
| 2. Gameplay katana with sheath and markers | Poly Haven CC0 antique katana with a grip derived from the hand bones; the saya is part of the armour mesh (a drawn katana and the sheathed hilt both show for now) | same |
| 3. Idle/run/dodge/guard/parry/combo/hit/defeat animations | UAL1 + UAL2 retargeted at import (rest fixer + silhouette fix), stretched to authored frame data so strikes land on active ticks | same |
| Skins (§2.3, §4) | `CosmeticCatalog`: armour lacquer recolours (shader on the 4K textures), blade finishes, scarves; replicated as sanitised IDs, zero stats | `cosmetic_catalog.gd`, `armor_material.gd` |
| 4. Trails, parry sparks, posture break, hit/death FX | Sword trail ribbon, spark bursts, parry fan, posture-break ring, matching CC0 sounds; "Reduce flashes" dims without removing cues | `sword_trail.gd`, `combat_fx.gd`, `sfx.gd` |
| 5. Training dummy, bandit NPC, village/dojo kit | Dummy uses the same model; village/dojo kit exists (ENVIRONMENT.md); bandit NPC not yet | — |
| 6. Cosmetic suppression test with 2+ clients | Not yet | — |

Presentation never feeds back into rules: the headless server builds `FighterBody` with `with_visuals = false`.

## 0. Art identity and foundational rules

**Art target:** Third-person 3D dark-fantasy Edo-inspired action. Grounded anatomy, excellent sword silhouettes and material quality, with selectively exaggerated supernatural sword auras and **very long flowing scarf** animations. Style should look cohesive on modest hardware, not like a collection of unrelated purchased assets.

**Technical truth:** These are proposed content, rigging and VFX guidelines; exact triangle counts, draw-call/texture budgets, number of NPCs, shader passes and platform profiles require real Godot benchmarks. No claim that high-fidelity cloth sim or large-scale crowds are automatically performant.

**Gameplay invariants:**
- Equipped weapon, socketed gems and worn cosmetics are protected from PvP loot loss under current GDD; only **unsecured backpack contents** are lootable on dangerous-zone defeat.
- Gems are freely removable at safe equipment locations; removing gems does not destroy them. Gems in weapon sockets influence authoritative properties only through server-approved build state.
- Six equipped technique slots plus core combat actions; character model/VFX must telegraph their states clearly.
- Cosmetic items have **zero combat-stat value**; competitive visibility and performance limits apply to scarves, auras, masks, skins and trails.
- Rare spirit weapons are distinguished via custom model, VFX, sound, animations and staged awakening; most weapons have no spirit.
- Distinguish **server gameplay state** from cosmetic/client-only presentation: particles/cloth trails are not authoritative hitboxes.

## 1. The master asset taxonomy

| ID family | Required assets | Stage | Variations |
|---|---|---|---|
| CHR | Playable assassin body models | P0 | Base rig, multiple body/face/skin/hair options P1 |
| RIG | Shared humanoid skeleton, attachments | P0 | IK points, weapons, scarf, mask, hair, back/sheath sockets |
| ANI | Locomotion, combat, hits, emotes | P0/P1 | Stances, weapon families, crowd NPC variants |
| WPN | Katana, Wakizashi, Nodachi | P0/P1 | Handles, guards, sheaths, rarity/style variants |
| WPN2 | Optional future: tanto, twin short blades, yari | P2+ | Only after combat style acceptance |
| ARM | Clothing, layered armor, masks, boots, gloves | P1 | Dye channels, ragged/ceremonial variants |
| SCF | Long scarves, capes, ribbon cloth | P0/P1 | Cloth LOD, long spectral variants, trails |
| GEM | Stat/passive/cursed gem models/icons | P1 | Cut, affinity, tier, sockets, workbench display |
| SCR | Buff scrolls, technique scrolls, seals | P1 | Readability for on-ground and inventory |
| FX | Weapon trails, strikes, defense, statuses, spirit | P0/P1/P2 | Scalable quality and accessible equivalents |
| NPC | Villagers, traders, trainers, guards | P1 | Outfit/prop variants and shared rigs |
| ENM | Humanoid enemies, bandits, rogue assassins | P0/P1 | Weapon families and posture readability |
| BOS | Bosses, Oni, legendary swordmasters | P1/P2 | Large unique silhouettes, phase swaps |
| ENT | Chests, death remains, dropped equipment, pickup markers | P0 | Rarity glints, owner/risk status visuals |
| ENV | Buildings, ruins, foliage, rocks, roads, shrines | P0/P1 | Described extensively in ENVIRONMENT.md |
| PROP | Workbenches, forge, banners, furniture, market props | P1 | Interactive/noninteractive variants |
| VEH | Caravans/carts, optional mounts later | P1/P3 | Carefully selected physics/navigation |
| UI3D | Turntable stages, item preview rigs, 3D menu backgrounds | P0/P2 | Controlled lighting and pose presets |

## 2. Playable assassin character model

### 2.1 Physical appearance
- Adult humanoid anatomy with deliberately varied faces, hairstyles, body builds, skin tones and facial markings. Clothing silhouettes must be readable in PvP; avoid body morphology that changes competitive collision dimensions.
- Neutral base undersuit and layered modular clothes; shirts/robes, shoulder panels, belts, wrappings, trousers, boots, gauntlets, masks and ornamental talismans.
- Edo-inspired references: kimono/hakama, haori, travel coats, tabi/waraji-inspired footwear, partial samurai armor, ronin and shinobi-inspired clothing. Clearly fictionalized fantasy costumes; avoid false claims of historical accuracy.
- Character model has protected equipment sockets, cosmetic appearance slots and visual-only dyes. Separate source authoring from runtime appearance descriptors.
- Default visual motif: restrained dark lacquer/leather cloth layers, long red or black scarf, weapon on hip/back, minimalist eye-catching highlight rather than glowing every surface.

### 2.2 Canonical skeletal rig (recommended naming contract)

A consistent humanoid skeleton is essential for shared animations, modular outfits, camera and hit feedback. Establish a canonical rig first; retarget only through explicit adapters.

```text
AssassinRoot
└── Skeleton3D
    ├── Hips
    │   ├── Spine -> Chest -> UpperChest -> Neck -> Head
    │   ├── UpperLeg_L -> LowerLeg_L -> Foot_L -> Toes_L
    │   └── UpperLeg_R -> LowerLeg_R -> Foot_R -> Toes_R
    ├── Clavicle_L -> UpperArm_L -> Forearm_L -> Hand_L -> finger chains
    └── Clavicle_R -> UpperArm_R -> Forearm_R -> Hand_R -> finger chains
```

Required attachment markers/bones: `weapon_hand_r`, `weapon_hand_l`, `sheath_hip_l`, `sheath_hip_r`, `sheath_back`, `offhand`, `scarf_neck`, `scarf_upper_back`, `mask_face`, `fx_chest`, `fx_root`, `foot_l`, `foot_r`, `eyes`, `camera_focus`. Markers may be `BoneAttachment3D` nodes or explicitly bound sockets; names are *proposed* and must be frozen in a content schema.

Rig requirements: root-motion policy defined per combat move; in-place locomotion for ordinary network movement unless authoritatively mapped root-motion is proven safe; sword tip markers; IK targets for hand-to-sheath and two-handed Nodachi grip; separate viewmodel not required for third person. Avoid cloth/weapon collisions generating authoritative impulses.

### 2.3 Model modularity, skinning and assembly
- Base skinned mesh split into stable body regions; hide covered segments to prevent clipping and reduce overdraw. Ensure face/hair/mask compatibility.
- Outfit pieces share the same bind skeleton, or use well-defined attachments for rigid items.
- Standard accessory sockets for blade, sheath, charms, shoulder ornaments, scarf, emblems, lantern.
- Geometry variants: body skin, sleeves, chest armor, forearm plates, belts, hakama/skirt panels, boots, head and hair, scarf; budget number of material surfaces and draw calls.
- Dyes use authored masks and fixed channels. Player colors cannot imitate dangerous technique windups or safe/hostile team colors.
- Data-driven appearance schema (`base_body_id`, `hair_id`, `mask_id`, `outfit_piece_ids`, `dye_palette_ids`, `scarf_id`, `weapon_skin_id`, `vfx_preset_id`); the game confirms entitlements before applying cosmetics.

### 2.4 Character states / animation requirements

| Group | Minimum clips | Additional design notes |
|---|---|---|
| Locomotion | idle, walk, run, sprint, start/stop, turn-in-place, jump/fall/land | Eight-direction blend optional; responsive start/stop |
| Defensive | guard enter/hold/release, parry success/fail, posture stagger/break, dodge 4+ directions | Timing synchronized with authoritative move windows |
| Offensive | light chain, heavy windup/swing/recovery, charged attacks, feint, clashes | Distinct Katana/Wakizashi/Nodachi timing |
| Stances | sheathe/unsheathe, Stone/Storm/Moon idle + transitions | Stance reads clearly before first hit |
| Hit reactions | hit light/medium/heavy, stagger, launch if applicable, knockdown, get-up | Preserve lock-on readability |
| Interactions | pickup, chest open, inspect, forge, gem socket, scroll learn, meditate | Fast cancel rules; server confirmation timing |
| Social | bow, sit, kneel, wave, point, respectful duel salute, limited emotes | Optional social gestures, no animation exploits |
| Defeat | hit-to-defeat, fall, grounded remains, respawn | No dismemberment assumption; rating considerations |
| Unique | Shadow Step, Crimson Moon, Phantom Clone, Eclipse, spirit awakening | Specific telegraph start/end for each |
| Boss/NPC | idle, patrol, alert, chase, attack telegraphs, posture reaction, phase transition | Separate boss rigs as necessary |

Provide animation events for footsteps, sword draw, anticipation, strike onset, parry sound, cloak/scarf override, contact feedback and VFX triggers. **Animation event timing on the client is presentation; the authoritative server validates the actual move state.**

## 3. Primary weapons: silhouettes, physical rules and attachment

| Family | Model silhouette | Attack identity | Required animations / components | Proposed variants |
|---|---|---|---|---|
| **Katana** | Curved single-edged blade, mid-length handle, hip sheath | Balanced precision and counters | Sheathed draw, light/heavy chains, parry, 3 stances | Steel, black lacquer, engraved, frost, crimson, spirit |
| **Wakizashi** | Shorter curved blade, compact handle | Fast close-range, assassinations, tight spaces | Quick draw, rapid dual/one-hand sets (dual optional), short parry | Polished, blackened, wrapped, venom, spectral |
| **Nodachi / Ōdachi** | Long two-handed blade with wide attack arc | Reach, high posture pressure, commitment | Two-hand grip, charged slash, broad guard, recovery | Rusted giant, ceremonial, cursed, thunder |
| Tanto (future) | Small straight/curved dagger | Utility/stealth, not necessarily full standalone family | Sneak executions, quick stab | Concealed, shadow, ritual |
| Yari (future) | Long spear | Space control | Thrust string, butt-end, guard | Military, ceremonial, spirit |

**Every weapon model includes:** blade, guard/tsuba, handle/tsuka, pommel, scabbard/saya (where appropriate), optional wrap/charm, grip attachment, tip marker, impact points, a style/material set, world pickup model, hero preview model, and lower LOD. Mesh ornamentation must not make actual reach impossible to read.

**Weapon geometry semantics:** visual length and hit reach are related but controlled by authored move data; blade collider shown for debugging must never be inferred from a cosmetic extension/aura. Client swing trails interpolate blade root/tip motion but damage is computed by server-authoritative move/hit checks.

### 3.1 Model tiers and variation
- **Common:** utilitarian, accurate silhouette, minor wear.
- **Uncommon:** distinctive handle/guard or engraving; restrained FX.
- **Rare:** recognizable blade treatment, mild glow or rune geometry.
- **Legendary:** hero mesh, bespoke sheath, signature guard, texture work, unique passive preview.
- **Spirit weapon:** additionally custom spirit silhouette, bond phases, special VFX and sound; not every legendary sword is spiritual.

Rarity must not directly set attack reach, hidden hitbox geometry or unreadable glow. Cosmetics must preserve silhouettes of Katana/Wakizashi/Nodachi.

## 4. Model/VFX manifestation from items, gems, buffs and skills

This matrix is the central contract between gameplay properties and visible character representation. VFX should explain state without exposing unrevealed hidden build details or misleading PvP opponents.

| Trigger | In-world model/presentation change | Visible to whom | Gameplay rule |
|---|---|---|---|
| Equip Katana/Wakizashi/Nodachi | Swap blade + sheath, combat stance pose, grip IK | All players in AOI | Base weapon family drives authoritative moveset |
| Equip cosmetic sword skin | Swap permitted weapon appearance/material | Nearby players | No stat or reach changes |
| Equip outfit/armor | Swap meshes/material, hair occlusion, mask | Nearby players | Gear stats if item is functional; skin visuals alone cosmetic |
| Equip scarf | Cloth mesh, neck attachment, wind flow, optional subtle particles | Nearby players | Cosmetic only |
| Socket Blood Gem | Small weapon socket glow; stronger tint only during applicable proc | Nearby, with effect budgets | Passive procs determined server-side; no visual stat claim |
| Socket Shadow Gem | Dim purple engraving, subtle short-lived phantom trail on proc | Nearby | Only when authorized effect triggers |
| Socket Wind Gem | Fine cyan wisps at blade/tip or during relevant movement | Nearby | No mobility bonus unless server-authorized stats |
| Socket Thunder Gem | Restrained sparks on charged/parry interaction | Nearby | Effects represent actual authoritative activation |
| Socket Frost Gem | Frost edge shader/particles on qualified strike | Nearby | Slow/chill proc must match gameplay state |
| Socket Poison/Venom Gem | Green-violet droplets/smoky subtle film on procs | Nearby | Do not confuse with health/blood visuals |
| Socket Cursed Gem | Ominous rune pulse, heartbeat/low-frequency sound on activation | Nearby with sound falloff | Trade-off effects documented in tooltip |
| Resonance active | Small hilt motif, rare burst/secondary trail on proc | Nearby | Reveal only public combat evidence when triggered |
| Offensive buff scroll | Short casting seal, warm blade sigil, buff icon over self only when relevant | Caster; combat impact readable | Duration and category server-owned |
| Defensive buff scroll | Faint armor etching/deflect shimmer | Combatants | Show reduction/guard only when active |
| Utility buff scroll | Footprints/feather particles, subtle breath effect | Local or relevant nearby | No visual stealth exploit |
| Perfect parry | Spark fan, brief impact light, posture snap | Combatants | Only on validated perfect parry |
| Posture break | Distinct body recoil, ring/burst cue, audible strike | Combatants | Break validated by authority |
| Shadow Step | Short shadow streak and afterimage | Nearby (visibility rules apply) | Teleport endpoint/server state authoritative |
| Crimson Moon | Directed red arc matching validated hit volume | Nearby | Visual arc must not imply a bigger damage zone |
| Phantom Clone | Readable ghost clone with tell/tint, limited lifespan | Nearby as allowed | Clone's targeting/damage defined by server |
| Technique Weaving | Brief combined interaction motif | Nearby + player HUD | Only after server confirms combo/proc |
| Spirit awakening | Weapon morph/material layer, spectral entity/halo limited by state | Nearby | Hero FX, not automatically huge raw buff |
| Low health | Subtle breathing, vignette local, optional cloth/body stress | Mainly local | Must not flash aggressively |
| PvP notoriety | Title/emblem, selective banner/aura with privacy | Authorized nearby | No universal precise location reveal |
| Defeat & carried loot drop | Body/remains, unsecured loot container, dropped bag | Nearby | Protected equipped weapon/gems remain with player |

### 4.1 Socket visuals and gem attachment

Provide gem cut variations (faceted, teardrop, rough crystal, engraved stone, cursed shard), three-tier small world models and a high-detail workbench representation. Socket locations near hilt/guard are most readable; do not place large gems along blade edge that obstruct sword collision silhouette. Gems should be visible in equipment UI even when in-world gem visibility is downgraded at distance.

**Free gem swaps at safe station:** socket mesh attaches/removes instantly after successful server-confirmed loadout update. Removing gem never destroys it. Outside authorized stations, show current gems but disable editing; if a client visually previews a new gem, label it unsaved/not active.

## 5. Scarves, hair, cloth and ornaments — signature feature

### 5.1 Scarf families
- **Ronin Wrap:** medium cloth length, simple physics/secondary motion.
- **Crimson Wanderer:** exaggerated long scarf (hero look), dynamic flutter in wind/sprint.
- **Shadow Veil:** dark flowing scarf with restrained intermittent ghost-fray trail.
- **Moonlit Silk:** pale material with soft spectral blue thread.
- **Ashen Banner:** battle-damaged fabric, jagged silhouette.
- **Spirit Ribbon:** rare cosmetic with layered translucent ribbons; capped for opponents.

### 5.2 Scarf simulation tiers

| Distance/state | Suggested technique | Requirement |
|---|---|---|
| Local player, high quality | Limited bone-chain procedural animation, optional carefully budgeted cloth solution | Collision guard near head and sword; stable camera |
| Nearby players | Preauthored animations + bone spring/wind blend | Visually convincing under combat |
| Mid-distance | Reduced-bone preauthored motion; simplify material and trail | No simulation spikes with group count |
| Far distance | Static or simple shader flutter / low LOD | Preserve silhouette and optimize |
| Reduced effects/accessibility | Short/no trails and simplified cloth | Equally readable combat tells |

**Do not** run expensive unconstrained soft-body physics for every scarf on every player. Prevent fabric penetration through bodies, sheath or blade, and ensure scarves are not part of authoritative hit detection. Prevent misleading team coloration and do not let scarves fully cover a sword's windup.

### 5.3 Hair and apparel
- 2–4 base cuts initially (short tied, long ponytail, topknot, loose, shaved optional), expanding as pipeline allows.
- Hair ties react to wind/turn/attacks with inexpensive secondary animation and LOD.
- Hakama, sleeves and coats receive cloth bones/vertex tricks where needed; armor plates attach rigidly. No gameplay-affecting physics push from fabric.
- Faction clothing must never obscure client-visible hostility/PvP intent cues. Include occlusion culling/hair-hiding under masks/helmets.

## 6. Ability and status VFX asset library

| VFX ID | Trigger | Required layers | Safety/readability |
|---|---|---|---|
| FX-001 | Standard Katana slash | blade streak, impact spark, sound | Trail obeys weapon swing |
| FX-002 | Wakizashi quick slash | small fast streak/air cut | No invisible hits |
| FX-003 | Nodachi heavy slash | broad directional arc, dust, impact | Clearly slower windup |
| FX-004 | Guard/parry | contact spark, radial impulse, tiny shake | Colorblind-safe audio cue |
| FX-005 | Posture break | sharp body glow, shock ring, stagger | No full-screen strobe |
| FX-006 | Dodge | small dust/cloth acceleration | No fake invulnerability cue |
| FX-007 | Shadow Step | restrained shadow afterimage and arrival | Unambiguous start/end |
| FX-008 | Crimson Moon | crimson crescent + lingering fading embers | Accurate authoritative threat shape |
| FX-009 | Smoke Veil | localized smoke with consistent visibility policy | Low preset still respects occlusion rules |
| FX-010 | Phantom Clone | translucent model/afterimage, dissolve | Visually distinguishable decoy, rules TBD |
| FX-011 | Spirit Guard | translucent sigil around blade/arms | Guard active window visible |
| FX-012 | Eclipse | elite dark red moon slash + optional sky tint local | Camera effects limited and skippable |
| FX-013 | Blood proc | tiny red edge/sigil burst, target status | Distinct from generic blood gore |
| FX-014 | Poison proc | small mist/needle burst | Status icon provides accessible backup |
| FX-015 | Frost proc | crystalline glint and chilled breath | No excessive fogging of target |
| FX-016 | Thunder proc | fast branched spark | Respect photosensitivity toggles |
| FX-017 | Scroll cast | hand gesture, paper ink seal, colored ring | Not confused with incoming attack |
| FX-018 | Gem resonance | socket pulse, fused color accent | Short and rare, no constant clutter |
| FX-019 | Rare loot beam | rarity-specific subtle glint/ground marker | Doesn't reveal hidden drops through walls |
| FX-020 | Spirit weapon manifestation | silhouette/entity apparition near wielder | Budgeted for dense player gatherings |
| FX-021 | World event arrival | sky particle/local landmark beacon | No global visibility cheats |
| FX-022 | Boss telegraph | floor shape + animation + audio indicator | Readable at every quality preset |
| FX-023 | Lootable remains | low-glow pouch marker | Only actual unsecured loot shown |
| FX-024 | Assassin Echo | monochrome stylized spectral duel replay | Never leak unrevealed stealth positions |

**VFX specification per effect:** event ID, owner, affected players, socket, start/duration/end, authoritative or purely decorative source, pooling/LOD, deterministic seed if important, max screen-space coverage, accessibility fallback, sound reference, status stack visuals, cancellation behavior, network interest filter, QA test cases.

**Rendering proposals for Godot:** `GPUParticles3D` for scalable ornamental particles, `ShaderMaterial` for dissolve/edge/frost/blood; procedural mesh or `RibbonTrail`-style authored geometry for sword trails, decals for temporary floor signals, `AnimationPlayer`/`AnimationTree` and material parameters. Exact project renderer support/limits must be tested; no dependence on unverified built-in components.

## 7. Rare spirit weapons — full content contract

Only special legendary weapon templates may be marked spirit-bearing. They gain personalized lore and appearance without dominating PvP statistically.

**Asset package for one spirit weapon:** base mesh+sheath; dormant/awakened/ascended skins or material states; spirit silhouette (fox/oni/dragon/ancestor, inspired but fictionalized); 3–5 sound cues; idle breath VFX; active signature proc; stage transition/awakening cinematic (short and skippable); 3D inspection pose; icon and banner art; world pickup depiction; biography/lineage UI portrait; LOD/culling behavior.

**Example weapon — Murasame's Grief (fictional):**
- **Dormant:** blackened Katana with pale engraved crack.
- **Awakened:** a low-intensity blue-white foxlike spectral stream appears after precision counters.
- **Ascended:** the spirit briefly emerges on a validated special attack, with controlled crescents and a distinct sheath ornament.
- **Temperament:** parry-oriented trials; record of notable historical wielders without real personal IDs.
- **Rules:** equipped sword remains protected on dangerous-zone defeat. If moved voluntarily to unsecured backpack before expedition, carried-item risk follows the inventory classification; transitions disallowed in danger to prevent exploit.

**Other candidates:** Oni's Debt (heavy Nodachi/poise trade-offs), Winter Bell (frost counter Katana), Nameless Ash (mobility Wakizashi), Thunder Pilgrim (posture-focused sword). Keep each mechanically different with counterplay and optional cosmetic de-intensification.

## 8. Enemy/NPC/boss model library

### 8.1 Civilian and friendly NPCs
- Village trader (merchant robe + ledger, vendor prop), blacksmith (apron, tongs, forge), gem artisan (precision bench, tools), scroll scribe (ink/scroll), dojo master (wooden sword), quest giver, healer/medic, guards, caravan escort, civilians with schedules.
- Shared skeleton and interchangeable costumes for efficient crowds. Avoid facial animation scope explosion at launch; prioritize clear silhouettes and useful gestures.
- Noncombat NPC LOD/animation budgets; conversations via facial focus and idle gestures rather than full cinematic lipsync unless planned.

### 8.2 Combat enemies
- **Bandit Ronin:** similar humanoid rig; readable basic slash/parry; starter combat training.
- **Shadow Scout:** ambush, short sword, smoke; telegraph stealth reveal.
- **Cursed Soldier:** armored castle defender, deliberate strong posture, slow swings.
- **Shrine Wraith:** spectral animation, attack hitbox still readable, no misleading transparency.
- **Oni Minion:** distinct shoulders/claws, larger collision volume, melee AOE cues.
- **Rogue Master:** advanced stance transitions and feints, fair learnable patterns.

### 8.3 Boss example content packs

| Boss | Model/rig uniqueness | Arena/VFX requirements | Fight identity |
|---|---|---|---|
| Bell Keeper | Heavy humanoid armor, tall Nodachi, dangling temple bells | Bell pulses, posture resonance, floor marks | Rhythm, guard and counter windows |
| Crimson Oni | Non-humanoid large rig, horns, chained weapon | Fire/curse arcs, massive readable tells | Team positioning, posture break |
| Forgotten Swordmaster | Refined humanoid rig, scarf, special sheath | Few sharp precise effects, no clutter | Pure duel mastery and stance reads |
| Shrine Widow | Spectral layered drape, multiple arms illusion | Trap zones, ink sigils, clones | Spatial awareness and skill timing |
| Spirit of the Valley | Distinct silhouette/possible multiple phases | Varying spirit projections; capped quality | High-tier event and spirit trials |

Every boss package needs: silhouette sheets, turntable, skeleton spec, locomotion, every telegraphed move with frame timings authored, posture/hit reactions, phase transition, reset/death, audio, hitbox/hurtbox QA and low-effects equivalent. Gameplay frame data resides in authored content/authority, not inferred from impressive-looking mesh animation.

## 9. Item and world-drop model requirements

**Gems:** gemstone mesh for at least blood, shadow, wind, thunder, frost, venom, cursed; raw/crude/refined visual tiers; 3D high-detail preview, lightweight ground pickup and matching 2D UI icon. Do not render excessive tiny gem meshes on other players at range.

**Scrolls:** offensive/defensive/utility buff scrolls; consumable technique-learning scroll; legendary/legacy sealed scroll; worn parchment, ribbon/wax seal, distinct motif. Inventory labels must communicate permanent learned versus unsecured physical item.

**Loot:** pouch, chest (wood/iron/spirit), crate, weapon pickup, collectible ingredient, crafting station output, corpse/remains marker, major boss reward cache. Each displays `untouched/opening/open/empty/locked` or authoritative equivalent states. The visible body is not proof that gear on the body is lootable; represented drops are only unsecured carried inventory.

**Crafting and equipment displays:** anvil, bellows, whetstone, gem socket bench, polishing rack, scroll archive, weapon rack, armor mannequin, costume wardrobe, spirit altar and skill dojo boards. Interactive affordance must be visible from a third-person camera.

## 10. Character effects based on items: deterministic presentation mapping

**Data model (conceptual):**
```text
AppearanceState
  body_variant, head_variant, hair_variant, skin_material
  wardrobe_slots[]: cosmetic_id + dye_palette
  equipped_primary_weapon_template + allowed cosmetic_skin
  weapon_stage: normal | dormant | awakened | ascended
  scarf_template + simulation_quality
  socketed_gem_visual_profiles[]
  active_buff_visual_flags[]
  active_status_visual_flags[]
  combat_stance + action_pose
  public_notoriety_title (if visible)
```

**Rules:**
1. Backend/authority confirms equipped items/gems and entitlements; the client builds the visual assembly from stable IDs.
2. Continuous visual configuration replicates as **compact appearance IDs and status bits** to other players; do not continuously sync individual cloth bones/particles.
3. Local client may play effect feedback immediately for responsiveness, but unconfirmed gameplay effects must reconcile to authority and never award damage locally.
4. Cosmetic trails cannot mask an active attack telegraph; at low graphics, public attack cues retain a standardized minimum.
5. If target device cannot render a special material, fall back to a recognizable silhouette and icon; gameplay functionality unchanged.
6. On disconnect/reconnect, rebuild appearance from latest server snapshot rather than stale visual state.
7. The UI preview can show unsaved changes, explicitly labeled; replicated gameplay shows only committed builds.

## 11. Technical production pipeline and conventions

### 11.1 Asset stages
Concept/orthographic turnarounds → blockout → high-poly hero mesh as appropriate → low-poly retopo → UV/material bake → rig/skin → animation → LOD/collision variants → `.glb` import → Godot scene wrapper → VFX/audio integration → multiplayer/readability validation → optimization/sign-off.

### 11.2 File conventions

```text
assets/source/blender/characters/assassin_base.blend
assets/source/blender/weapons/katana_001.blend
assets/export/characters/chr_assassin_base.glb
assets/export/weapons/wpn_katana_001.glb
res://art/characters/assassin_base/assassin_base.tscn
res://art/weapons/katana_001/katana_001.tscn
res://art/vfx/abilities/fx_crimson_moon.tscn
res://art/materials/...
res://data/content/weapons/...
res://data/content/cosmetics/...
```

Asset identifier pattern: `chr_`, `npc_`, `bos_`, `wpn_`, `arm_`, `scf_`, `gem_`, `scr_`, `env_`, `prop_`, `fx_`, `ani_`; suffix style/LOD and version as needed. IDs are immutable in persistent inventories after shipping; migrations map deprecated IDs.

### 11.3 Source import and scale
- Meters and consistent Godot/world axes. Declare one source-export policy and validate every batch with reference humanoid mannequin and 1m cube.
- Pivots: character world root at feet; weapons grip origin with tip marker; environmental modules at grid-friendly corners/centers as specified.
- Preserve bone naming and animation clip metadata. Mesh `.glb` files are imported, then wrapped in authored `.tscn` scenes for sockets, collision, lights and effects.
- Textures: physically plausible PBR channels and roughness/metalness conventions; enforce texture dimension/power-of-two profiles from platform budgets. Use shared materials/texture atlases when appropriate.
- Static world meshes get simplified collision/nav classification; skinned combat hitboxes authored separately from cosmetic attachments.
- Optimization: rig reuse, animation compression, material variant limits, reusable shaders, spatial culling, VFX pooling, scalable particles, retargeted enemies and LOD.

### 11.4 Animation authority / network constraints
- Attack windup, active, recovery, range, parry timing, posture outcome and skill cooldown live in content + server simulation rules. Animation clips map to those timings with authored events.
- Synchronize high-level action ID, start tick, phase and compact cosmetic flags, **not** per-frame transforms of all bones.
- Accept interpolation for other players and client prediction for local presentation only. A sword trail is **never** the hit authority.
- Cosmetic cloth/hair can differ slightly between clients. Relevant tells, guard state, and effective hurtbox volumes cannot.

## 12. VFX, animation, material and cloth quality tiers

| Tier | Player model | Cloth/scarf | Particles | Spirits and bosses |
|---|---|---|---|---|
| Minimum | Simplified mesh/materials, lower texture resolution | Preauthored reduced bones | Essential combat cues only | Clean simplified telegraphs |
| Balanced | Mid/high LOD nearby, scalable shadow | Light spring bones, short trails | Moderate, culled by distance | Restricted spectacle with clear shape |
| High | Full close-range material fidelity | Higher-rate cloth secondary motion | Detailed local particles | Richer hero FX with strict brightness cap |
| Accessibility | Player choice overrides quality | Simplified scarf/trails | Flash reduction, no excessive shake | Mechanic cues preserved via audio/icons/shapes |

Never tie stealth effectiveness or visibility to a quality-dependent particle count. Effects that impact gameplay need a shared logical state and comparable low-quality visual cue.

## 13. Performance and acceptance tests

**Asset review checklist:**
- Silhouette recognizable at gameplay camera distance and under contrasting biomes.
- Every weapon family reads distinctly even with cosmetics and limited lighting.
- Sword/sheath attachment correct across draw/return, stance changes and locomotion.
- Long scarf avoids clipping with katana, shoulders, masks and back sheath on 360° camera orbit; looks reasonable at reduced simulation.
- Foot sliding / weapon hand IK / retarget distortion below accepted thresholds.
- No duplicated item/effect ownership caused by animation events or retry/reconnect.
- Hitbox debug volumes align with authoritative combat rules; effects do not exaggerate reach.
- Reduced VFX and colorblind-safe settings retain boss indicators, parry feedback and status clarity.
- Multiple characters, different outfits, gemstones, active buff scrolls and spirit effects display together without overwhelming combat.
- Stable world representation of dead character and loot bag: protected equipped assets never turn into loot drops.
- Shader compilation/streaming stutter measured during first appearance of a rare spirit weapon.
- Licenses and provenance tracked for sourced meshes, sound, texture and animation files.

**Test scenes:** model turntable; animation wall; scarf clipping obstacle course; sword collision dojo; eight-player cosmetic stress test; many-player crowded sanctuary; boss arena high-VFX; low-end quality preset; reconnect-state visual rebuild; multi-biome lighting suite.

## 14. Practical art production roadmap

### P0 — Combat vertical slice
1. One canonical assassin rig/base body + basic dark outfit + simple long scarf.
2. One gameplay-ready Katana with sheath and accurate socket markers.
3. Idle/run/dodge/guard/parry/basic combo/posture hit/defeat animations.
4. Basic sword trails, parry sparks, posture break, hit/death and loot bag FX.
5. Training dummy, one bandit NPC, one village/dojo modular kit.
6. Cosmetic suppression/reduced-effects test while 2+ clients fight.

### P1 — Alpha systems
1. Wakizashi and Nodachi complete animation sets, three stance presentations.
2. Modular masks, hair, armor and outfit dyes; several long scarf variants.
3. Gem models, socket/material effects, scroll models, crafting workstation assets.
4. 10–20 initial technique FX **target for planning only**, including six-slot demonstration loadouts.
5. Dungeon enemy roster, one named boss with phases; full world resource/loot props.
6. 3D paper-doll/turntable, item inspection and wardrobe previews.

### P2 — Signature identity
1. A small curated set of rare spirit weapons with histories, awakening and signature FX.
2. Technique Weaving combo effects and gem affinity resonances.
3. Limited-holder technique visual signatures, title/icon/avatar identity treatments.
4. More cosmetics and scarf/material variants; shop turntables and execution animations.
5. Special event VFX, Assassin Echo, hideout trophies and boss expansions.

### P3 — Scope expansion
Additional weapon families, large cosmetic catalog, high-fidelity cloth optional platform profiles, advanced creature roster and further world regions after performance/retention evidence.

## 15. Master production spreadsheet fields (when tracking externally)

For each asset, record: `asset_id`, `asset_family`, `display_name`, `stage`, `priority`, `owner`, `concept_link`, `source_file`, `export_file`, `Godot_scene`, `skeleton_version`, `materials`, `texture_profile`, `LOD_variants`, `collision`, `animation_set`, `effect_ids`, `runtime_appearance_tags`, `server_content_id`, `license`, `dependencies`, `QA_status`, `performance_notes`, `revision`.

## 16. Open decisions requiring visual prototypes

- Final stylization target between grounded realism and anime-influenced dark fantasy.
- Exact launch body customization scope, identity representation and number of modular outfit slots.
- True cloth simulation vs bone-chain approximation on local-player scarf after measuring Godot performance.
- Outfit statistical gear versus purely cosmetic layering; appearance UI must not confuse them.
- How visible passive gems are to opponents before a proc, to avoid revealing private build secrets.
- Exact spirit weapon count, awakening intensity, glow budget, camera shake policy and final combat VFX density.
- Release platforms, GPU targets and approved polygon/texture/animation budgets.

---
**Document owner:** Character Art / Animation / Technical Art. A model or FX asset is not release-ready until it is visually excellent **and** compatible with multiplayer hit readability, cosmetic fairness, performance tiers, content IDs, and authoritative item rules.
