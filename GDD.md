# Samurai Assassin — Game Design Document

> **Status:** Pre-production design baseline (v0.1)  
> **Genre:** Third-person 3D action PvPvE / persistent-session battleground with extraction-style loot risk  
> **Setting:** Fictional supernatural Edo-inspired Japan  
> **Engine:** Godot 4.x · **Languages:** GDScript (game) and Go (services)  
> **Companions:** [ARCHITECTURE.md](ARCHITECTURE.md) · [MULTIPLAYER.md](MULTIPLAYER.md)

## 0. Decision register

| Topic | Current decision | Notes |
|---|---|---|
| Structure | Players join online servers and explore shared dangerous areas | **Not** a traditional massively scaled MMO; server capacity is a measurable target, not a promise |
| Core loop | Prepare → explore/fight/loot → return to safety → secure rewards → refine build | Players may team up, duel, compete or betray |
| Combat | Precision swordplay + supernatural abilities | Readable animation and counterplay ahead of spectacle |
| Abilities | **Six equipped active slots**, plus universal core sword actions | No mandatory class; ability compatibility and tradeoffs apply |
| Skills | Common, rare, secret, legendary, limited-holder and legacy | Obtained through scrolls, masters, bosses, hidden trials, exploration |
| Skill ownership | Learned techniques and mastery persist through death | Limited-holder/legacy succession follows separate explicit rules |
| Gems | Freely removable and resocketable **outside combat** | Gems grant attributes or passives; socket restrictions and stacking budgets |
| Buff scrolls | Consumable preparation items | Explicit type slots, durations and stacking rules |
| Death | **Only unsecured carried loot drops** in dangerous areas | Equipped weapon, equipped gems/gear, permanent progression and cosmetics remain safe |
| Spirit weapons | Rare legendary weapons | Distinct behavior, awakenings and remembered history; equipped copies are protected under current death rule |
| Identity | Cosmetics, long scarves, sword effects, masks, titles, combat signatures | Effects must not compromise opponent readability |
| Initial release | PC-first, one dense region, small player population | Larger populations/platforms are uncommitted |

### Open questions (not silently decided)

- Exact visual direction: grounded/stylized/anime balance, camera field of view, accessibility options.
- Server target: initial design/test bracket **20–40 concurrent players** per region instance; increase only after tests. This is a planning target, not a finalized player cap.
- PvP consent in intermediate regions; party friendly fire; penalty for attacks in governed territories.
- Whether six slots can equip any mix of ability categories; proposal: yes, with per-ability tags, resource costs and anti-spam constraints.
- First launch content counts, monetization, seasonal reset policy and final name.

## 1. Elevator pitch

A wandering assassin enters a haunted, beautiful Edo-inspired realm. In sanctuaries they equip weapons, slot gems, select six techniques, buy scrolls and join allies. Outside the gates, they discover forbidden sword arts, challenge supernatural bosses, clash with other assassins and gather valuable loot. Dying in a dangerous zone costs the **unsecured items carried during the expedition**, not a character's learned skills or equipped gear. Mastery, unusual builds, rivalry, and the stories left behind by players matter more than a raw character level.

**Player promise:** *Forge a unique fighting style. Risk what you carry. Become someone the world remembers.*

## 2. Experience pillars

1. **Swordplay first:** readable attacks, movement commitment, posture, parries, feints and punish windows.
2. **Build discovery:** six abilities, weapon stances, socketed gems, rare passives, scroll preparation and controlled synergies.
3. **Risk without erasing identity:** meaningful carried-loot loss; durable mastery, owned equipment and cosmetics.
4. **Exploration with surprises:** hidden teachers, multi-route dungeons, rare encounters, world events and environmental puzzles.
5. **Living rivalries:** alliances, cooperation, betrayal, bounty hunts and recorded notable victories.
6. **Fair danger:** new players can compete through skill; stronger gear must create options and specialization, not unavoidable wins.

**Non-goals for first playable:** massive seamless continent, thousands of players in a single simulation, unrestricted procedural generation, player-run cities, fully simulated NPC societies, unlimited unique techniques, full housing construction, AI-driven combat decisions, pay-for-power.

## 3. Core player journey

### First hour

1. Customize appearance and choose starter Katana or Wakizashi (starter gear remains usable).
2. Learn universal sword actions in a safe dojo: attack, guard, parry, dodge, lock-on, stamina/posture and a starter technique.
3. Explore a low-risk edge of the Bamboo Frontier; defeat bandits and recover a common gem.
4. Return to the sanctuary, secure materials, resocket a gem for free and learn a technique from a master.
5. Join a short co-op shrine encounter; learn the difference between PvE enemy tells and human feints.
6. Attempt a voluntary dangerous expedition with clear UI explaining exactly what is at risk.

### Repeatable session (20–60 minutes as a design target)

Prepare in sanctuary → select loadout and party → select route/objective → leave safety → defeat enemies / explore / acquire items → decide whether to push deeper → escape or return through a safe gate → bank loot → improve build/mastery → view events and rivals.

No forced storm circle or automatic match reset is assumed. This is a **persistent-session battleground**, not a last-team-standing battle royale. Optional instanced expeditions may have timers or separate victory conditions.

### Long-term aspiration

Create a personal combat style, master weapon families, find hidden masters, learn rare arts, awaken one of a few spirit weapons, complete legendary duels, earn cosmetics/titles, establish rivalries and gain a place in the Assassin Chronicle.

## 4. World and risk structure

| Area | Example | Hostile players | Death rule | Purpose |
|---|---|---|---|---|
| Sanctuary | Lantern Village, dojo, hideout | No damage/loot PvP | No carried-loot PvP loss | Preparation, storage, trading, crafting, social play |
| Frontier | Bamboo paths, river crossings | PvP enabled with clear region warnings and potential reputation rules | Drop unsecured carried loot | Gathering, smaller encounters, early contested objectives |
| Lawless | Cursed Valley, broken keep | Open PvP | Drop unsecured carried loot | Highest-risk routes, bosses and rare material sources |
| Instanced dungeon | Buried Shrine | PvE-only or explicitly flagged contested instance | Published per-instance rule, default dangerous: carried loot drops | Controlled cooperative or PvPvE dungeon encounters |
| Arena | Dojo duels | Consensual fights | No equipment/loot loss | Practice and ranked standardized combat |

**Precise death semantics:** An item in the *secured stash* is never at risk. An item in a character's *unsecured carried inventory* is lootable on death in a dangerous zone, including unequipped consumables, gems, scrolls, materials and unequipped loot carried into the zone. **Equipment in active protected equipment slots** (weapon, armor/cosmetics, and socketed gems) remains owned and equipped. This distinction must be unmistakable in UI. It is a game-design choice—not a client security mechanism; the server enforces it.

**Prevent loopholes:** Changing an item from carried to equipped to shield it during combat/danger is not allowed: equipment/loadout changes occur only in sanctuaries or designated safe staging points. No instant mail-to-bank while in danger. Death-dropped items must have one authoritative owner/claim transaction.

### World layout (first region)

- **Lantern Village:** sanctuary, training dojo, storage, traders, master NPCs, bounty board and personal hideout.
- **Bamboo Frontier:** low-density bandits, gathering, hidden passages, introductory PvP tension.
- **River Crossroads:** caravan routes and ambush positions; multiple traversal options.
- **Ruined Temple:** cooperative dungeon with a boss and an optional secret trial.
- **Cursed Valley:** high-value gathering and contested supernatural events.
- **Broken Keep:** a public boss arena with extraction/return risk.

Design dense encounter routes, sight lines, escape routes and landmarks before increasing map size. Never gate every objective behind a single choke point.

## 5. Combat design

### Universal actions (independent of the six slots)

Light combo, heavy attack, guard, timed parry, dodge, sprint, jump/vault (scoped to level design), target lock-on and stance change. Universal actions must remain viable without finding a rare ability.

### Four combat resources

| Resource | Function | Recovery/constraint |
|---|---|---|
| Health | Defeat threshold | Consumables or limited encounter-based healing; no permanent damage inflation |
| Stamina | Movement, attacks, guards, dodge | Recovers after a short inactivity window; anti-roll-spam cost |
| Posture | Resistance to stagger/guard break | Builds under pressure; recovers faster when not pressured; break creates a punish window |
| Spirit | Supernatural technique fuel | Built primarily by meaningful skilled interactions; capped and anti-farm diminishing returns |

**Combat cadence proposal (to test):** melee encounters should allow observing tells, choosing a response and punishing errors. Do not lock timings without user testing. A skilled neutral duel should not be decided by one unseen ability or a single high-level-stat difference.

### Combat state machine

Neutral → windup → active hit frames → recovery; interrupts include hit-stun, guard break, dodge invulnerability (bounded), parry response and death. Attack-cancel/feint windows are authored per move. No universal cancel that removes commitment. Server validates the transition timeline and authoritative result.

### Weapon family identities

| Weapon | Strength | Tradeoff | Example signature style |
|---|---|---|---|
| Katana | Balanced reach/speed, parry and precision | No extreme specialization | Iaijutsu quick draw, counter-slash |
| Wakizashi | Fast recovery, close range, mobility | Short reach, lower posture pressure | Shadow ambush, rapid punish |
| Nodachi/Ōdachi | Reach, cleave, guard pressure | Long windup/recovery, high stamina | Wide counter, execution sweep |
| Future: Yari | Zone control and thrust reach | Weak at point blank | Line pressure |
| Future: dual blades | Relentless close-range tempo | Commitment and stamina demands | Cross-cut combo |

Avoid strict class locks. Weapon compatibility tags can constrain individual techniques (e.g., Iaijutsu requires a sheathed blade) while allowing hybrid builds.

### Stances

- **Stone:** defense, guard stability, stronger predictable counters; slower initiative.
- **Storm:** fast pressure and aggression; greater stamina exposure.
- **Moon:** draw attacks, spacing and carefully timed burst; punishable misses.

Stances are learned through weapon mastery, switchable in combat with a readable transition/cost. First playable may ship only **one stance per weapon** until the combat base is proven.

### Hit readability and PvP fairness

- Visible startup cues, audible tells, bounded VFX brightness/opacity, distinct hit reactions.
- No indefinite stunlocks; crowd-control resistance or short diminishing returns where needed.
- Target tracking and lunge corrections have explicit limits.
- No invulnerable instant teleports through an opponent without a telegraph or response.
- Combat camera, lock-on behavior and controller input must be tested against multiple human enemies.
- Accessibility: camera shake slider, reduced flashing/VFX, remapping, high contrast cues, configurable scarf visibility.

## 6. Six-slot technique system

Skills are **permanently learned** unless governed by an explicitly separate limited-holder/legacy ownership system. Players can own many skills but equip exactly up to six actives. Passives primarily come from equipment/gems/weapon traits; a passive is not secretly a seventh active. No skill use may exceed resources, cooldowns, equipment conditions or state prerequisites.

### Tags and data every skill needs

`skill_id`, identity/name, acquisition type, allowed weapon tags, stance constraints, categories, Spirit/stamina cost, charges, cooldown, windup/active/recovery timings, range/shape, damage/posture/status effects, counterplay flags, VFX/SFX references, mastery branches, PvP/PvE coefficients, version, and balance metrics.

### Acquisition routes

- **Common:** trainers, first quests, ordinary scrolls.
- **Rare:** dungeon scrolls, monster drops, dungeon puzzles.
- **Secret:** environmental clues, hidden masters, stance challenges and skill-specific trials.
- **Legendary:** difficult events, boss challenges and long-form multi-stage discovery.
- **Limited-holder:** server-scoped active ownership with clear challenge/expiration rules.
- **Legacy:** ownership transferred through sanctioned inheritance/duel; no spontaneous theft from PvP inventory.

An unlearned **skill scroll** is an unsecured inventory item and may be lost on death; on successful server-confirmed use it is consumed and the learned skill becomes permanent. The skill journal tracks discovered clues separately from possession.

### Upgrade and mastery model

Mastery is primarily horizontal: a skill gains alternate branches or changes its timing, utility, risk, or combo connections. Avoid unchecked linear multipliers. A branch choice can be reversible in sanctuary for a clear respec cost or cooldown (TBD); branch unlocks persist. Example: `Shadow Step` → **Phantom** (decoy) or **Blood** (next flank hit gains status pressure).

### Technique Weaving

A finite, authored catalog of interactions triggered by conditions:

1. **Sequential:** Shadow Step → Smoke Veil → Crimson Moon = delayed Phantom Crescent.
2. **Reactive:** perfect parry → Moon stance heavy = precision counter.
3. **Environmental:** wind technique near a shallow river disperses smoke faster while improving movement visibility (advantages **and** drawbacks).
4. **Gem-mediated:** Frost gem marks a chilled foe; a compatible attack spends the mark for posture pressure.

Interactions are server-authoritative, short-window, resource-bounded and telegraphed. Discoveries may be recorded in the journal. Never allow open-ended dynamic ability scripting from players.

## 7. Gems, scrolls, and resonance

### Gem categories

1. **Attribute:** small bounded stat modifiers (e.g., posture efficiency or stamina recovery).
2. **Passive:** condition-based gameplay change (e.g., next counter gains posture pressure after perfect parry).
3. **Cursed:** upside balanced by a clear negative modifier.

Affinities can include Blood, Shadow, Wind, Thunder, Frost, Fire and Stone. Sockets may have tags or polarity; weapon quality controls available sockets. Proposed constraint: at most one **major gameplay-altering passive gem** per weapon and a total stat-budget cap. No independent unlimited multiplier stacking.

**Gem swap rule:** freely remove/swap at safe preparation points, with no removal fee, loss or destruction. Swapping during combat or a dangerous expedition is blocked. Gem fusion/crafting can voluntarily consume gems as an economic sink; routine removal does not.

### Resonance

Compatible gem/weapon/technique combinations trigger modest, named interactions. Resonances require prerequisites and can introduce vulnerabilities or cooldowns. Catalog them explicitly; show discoverable hints in item tooltips and the journal. Pure damage multipliers should not dominate.

### Buff scrolls

Consumables dropped, crafted, traded or purchased for in-game currency. Proposed active slots: **one offense, one defense, one utility**; stronger of same-type effects replaces weaker where sensible; no duplicate stacking. All active buffs end on defeat; unused scrolls in carried inventory can drop. PvP normalization/caps prevent wealthy players from simply buying victory. Example scroll effects: posture pressure, stamina efficiency, reduced PvE detection, or temporary posture resistance.

## 8. Rare spirit weapons

Ordinary weapons may be crafted and customized; only rare named weapons have spirits. A spirit weapon has distinct lore, a dormant/awakened/ascended track, a signature passive **with counterplay**, VFX identity and an event history of notable achievements. Awakening comes from trials/behavior rather than repetitive kills alone.

**Identity is not limitless power:** stages can unlock alternate mechanics, cosmetic transformations and new skill links. Stronger options carry opportunity costs. In the current loot rule, actively equipped spirit weapons and their socketed gems cannot be looted on defeat. The history system records notable legitimate events; it must never expose private account information.

## 9. Inventory, extraction, defeat, and looting

Inventory distinguishes four states:

1. `SECURED`: village storage/hideout.
2. `EQUIPPED_PROTECTED`: active equipment slots; includes socketed gems.
3. `CARRIED_UNSECURED`: backpack, looted drops, spare gear, unused scrolls/gems/materials.
4. `WORLD_DROP`: authoritative loot container, corpse, boss chest, or ground entity.

**On dangerous-zone death:** server moves eligible `CARRIED_UNSECURED` items into a lootable remains container exactly once; protected and secured possessions remain unchanged. Destroy/consume expended active buffs, respawn at a valid sanctuary/checkpoint and apply temporary return-to-combat safeguards. All players see the same authoritative loot claim result; no duplicated corpse or double pickup.

Weight/burden: carrying loot can affect *travel* speed/stamina efficiency, but should not create extreme in-combat handicaps. Establish limits through testing. Clear escape routes and optional protected early-game trips reduce griefing. Prevent gear protection abuse with loadout locks outside safe areas.

### PvP and social rules

- Groups can cooperate but retain individual identity, loot ownership and reputation.
- **Initial proposal:** friendly fire disabled for active parties, with party membership changes barred during combat; revisit after tests.
- PvP-enabled regions are clearly indicated before crossing boundaries; optional duel mode in sanctuary.
- Bounties and notoriety may track predatory kills, but avoid automatic punishment for sanctioned PvP or self-defense.
- Guard against spawn camping, collusion-based reward farming, alt-account bounty abuse and party-kill laundering.

## 10. Dungeons, bosses, and world events

**Dungeon archetypes:** private co-op trial, contested shared shrine, elite boss lair. Encounters mix navigational choices, readable enemy behaviors, occasional co-op mechanics and optional hidden mastery challenges. Boss drops are subject to deterministic eligibility rules and transactional pickup; avoid opaque loot ownership.

**Boss model:** phases driven by health/posture and positioning; attacks offer discoverable tells; exploit windows after dodges/parries; crowd scaling should avoid making large groups trivial or punishing solos impossibly.

**Example events:** Oni Incursion (public boss), Caravan Ambush (escort/raid), Celestial Fracture (contested gem hotspot), Master's Challenge (duel to unlock technique clue). Event rewards create points of interest, not unescapable mandatory funnels.

## 11. Identity, cosmetics, lore, and reputation

Customization: faces, silhouettes, masks, Edo-inspired clothing, armor appearance, swords/sheaths, sword visual effects and flowing scarves. Cosmetics are appearance-only; no hidden hitbox, camera, collision or animation benefits. For multiplayer fairness, opponent threat readability can override cosmetic opacity/effect intensity.

**Assassin Chronicle:** notable boss defeats, world-first discoveries (opt-in/pseudonymous), limited-holder transfers, famous duels and weapon achievements. **Echo of Battle:** rare, short-lived stylized combat echoes containing no private data; not a general recording of players. **Rivalries/Bounties:** opt-in or rules-based noticeboards with anti-harassment controls and coarse-location hints, not exact position tracking.

## 12. Loot economy and crafting

| Item class | Faucets | Sinks |
|---|---|---|
| Weapons | Boss drops, crafting, discoveries | Dismantling, optional fusion, crafting inputs; **not routine equipped-gear loss** |
| Gems | Exploration, bosses, crafting | Voluntary fusion, crafted recipes, dropped unsecured inventory |
| Scrolls | Gathering, crafting, vendors, loot | Consumption and carried-loot loss |
| Materials | Enemies, nodes, events | Weapon progression, scrolls, gem crafting, cosmetics |
| Skill scrolls | Secrets, bosses, rewards | Consumed to learn; loss while unsecured |
| Currency | Activities, sales, contracts | Trading fees, services, recipes, cosmetics |

**Economic caution:** Because equipped gear is protected and learned skills persist, durable goods can accumulate. Deliberate non-punitive sinks (fashion crafting, consumables, optional fusion, rare recipes, trading fees) and supply tuning are critical. No open-ended real-money purchase of stat power. If cosmetics are monetized, publish fairness and transparency principles.

## 13. UX requirements

- HUD: health/stamina/posture/Spirit, six-slot quickbar, scroll buffs, enemy posture, party health, connection warnings.
- Equipment screen: sockets, affix comparison, explicit **PROTECTED WHEN EQUIPPED** badge, loadout editor accessible at safe points.
- Inventory: visually distinguish **secured** vs **unsecured**; pre-departure checklist indicates value at risk.
- Death screen: cause, opponent/environment, recoverable drops, respawn location, short learning feedback.
- Journal: technique acquisition clues, weaving discoveries, spirit memories, rivalries, notable location discoveries.
- Map: risk boundaries, safe return paths, dungeon rules, event markers with discovery/fog rules.
- Accessibility: input remapping, gamepad support, scalable interface, reduced motion/flashes, captions, color-independent telegraphs.

## 14. Balance rules and measurement

- Basic moves always work; rare items offer specialization, not deterministic superiority.
- Quantify win rates by weapon, skill, gem, latency bracket, party size and experience; avoid interpreting raw win rate without player-skill controls.
- Author damage categories and diminishing returns; bound burst, healing, mobility, crowd control and passive triggers.
- Ensure time-to-kill permits response; boss spectacle need not equal PvP damage.
- Evaluate low-equipment vs high-equipment duel outcomes in controlled tests.
- Instrument abandonment after loot loss, first successful extraction, PvP grief incidents and fraction of viable builds.

## 15. First playable vertical slice

**Goal:** prove fun, fairness, recoverable technical performance and a real loop—not breadth.

1. Third-person movement, Katana combat, parry/dodge/posture, one enemy type, one boss prototype.
2. One sanctuary and adjacent dangerous combat zone, return/escape to bank loot.
3. Six-slot ability UI with **three or four implemented actives** and a few clear synergies.
4. One 2-socket weapon, 3 gem types (including a passive), two consumable buff scrolls.
5. One hidden skill scroll, one skill trainer and persistent learned skill.
6. Two or more players online with authoritative damage, loot/drop/pickup, reconnect, and party basics.
7. Basic appearance customization including a scarf, adjustable VFX quality.
8. Automated tests proving no duplicated loot or client-forged combat result.

**Explicitly deferred:** player-driven economy, dozens of skills, limited-holder transfers, full spirit awakenings, seasonal progression, open-ended crafting, elaborate guilds. Implement a single rare spirit weapon as a prototype only after core combat feels good.

## 16. Milestone gates

| Gate | Playable proof | Must pass before expanding |
|---|---|---|
| M0: Combat sandbox | Local duel vs training dummy | Attacks/parries feel readable, correct reactions |
| M1: Two-player prototype | Two humans fight via dedicated server | Server authoritative health/hits, acceptable local feel |
| M2: Risk loop | Fight, loot, die, extract, bank | Transaction integrity; protected inventory retained |
| M3: Buildcraft | Six-slot bar, gems, scrolls, skill discovery | Distinct playstyles; bounded combinations |
| M4: Region slice | Village, wilderness, dungeon, boss | Full 20–60-minute loop enjoyed by testers |
| M5: Scale/security | Synthetic clients + real testers | Defined network/CPU budget, no known high-impact exploits |
| M6: Content alpha | Events, lore, more techniques, first spirit weapon | Healthy retention and reward pacing |

## 17. Quality bar and success measures

- **Fun:** playtesters voluntarily repeat expeditions and understand why they lost fights.
- **Fairness:** apparent attack tells and actual authoritative results match; no recurring unavoidable one-shots.
- **Clarity:** test users can explain which items drop *before* leaving the sanctuary.
- **Persistence:** power loss, crash or reconnect never duplicates currency/items or forgets a learned skill.
- **Performance:** benchmark player count, tick duration, packet loss and per-client bandwidth as an explicit acceptance gate; do not advertise capacity until demonstrated.
- **Content sustainability:** new weapons/gems/skills reuse existing authored systems rather than requiring bespoke rewrites.

## 18. Decisions to validate with playtests

- Exact stamina and posture values; dodge timing; time-to-kill; stance change windows.
- 6 unrestricted active slots versus category budget restrictions.
- Zone PvP consent and guard/anti-griefing rules.
- Group size and party friendly-fire policy.
- Depth and fairness of technique weaving and Spirit generation.
- Density of rare/limited-holder skills and their account-inactivity succession rules.
- Should players be able to equip spare weapons outside sanctuaries? Current baseline: **no**, to preserve loot risk and integrity.
- Travel burden, extraction availability and bank placement.
- Art style and camera framing, especially scarf visibility and VFX clarity.

---

**Document ownership:** Game direction and player rules live here. Technical module boundaries live in `ARCHITECTURE.md`; wire protocol, authority, replication and failure states live in `MULTIPLAYER.md`. Any rule changed here must be reflected in both companions.
