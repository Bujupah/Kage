# Kage (working title: Samurai Assassin)

Third-person PvPvE assassin battleground set in a fictional Edo-era province. Design lives in [GDD.md](GDD.md), boundaries in
[ARCHITECTURE.md](ARCHITECTURE.md), wire behaviour in [MULTIPLAYER.md](MULTIPLAYER.md), world in
[ENVIRONMENT.md](ENVIRONMENT.md), art in [3DMODELS.md](3DMODELS.md), interface in [GUI.md](GUI.md).

**Online PvPvE pre-alpha.** A headless Godot region server (16 players by default) runs the pure,
tick-based combat rules for players and server-driven bandit NPCs. Clients predict their own movement;
hits, parries, posture, death and zone rules are server-authoritative. Players enter in the Lantern
Village sanctuary and walk past the vermilion torii into the PvP frontier (bamboo grove, clearing,
ruin) where the bandit camps are. The client presents it with a 4K-textured assassin (CC BY) retargeted
onto shared animation, armour/blade/scarf cosmetics, Terrain3D hills under a golden-hour HDRI, and a
Where Winds Meet-style title screen showing your own assassin, plus Armory and Store.

## Run

Godot **4.7.2** (pinned; see `config/features` in `project.godot`).

Game with menus (splash → first-run accessibility → title menu → Training Dojo / Duel Online):

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path .
```

Or open the folder in the Godot editor and press F5. The game opens borderless fullscreen at the
display's native resolution (change it in Settings → Video → Display mode); `-- --windowed` forces a
window. `-- --sandbox` skips straight to the dojo.

Two-player duel: start the headless server, then two windowed clients (same machine or LAN):

```bash
tools/run_server.sh --port=7777 --max-players=16
tools/run_client.sh --host=127.0.0.1 --name=Musashi
tools/run_client.sh --host=127.0.0.1 --name=Kojiro
```

The scripts wrap `godot --headless --path . -- --server` and `godot --path . -- --client` (which joins
immediately through the UI shell); every game option goes after `--`. Client options: `--host`, `--port`, `--name`, `--bot=passive|guard|attack|duelist`
(the training AI drives the client), and `--quit-after=SECONDS`. In the editor you can do the same
with *Debug → Customize Run Instances*. Set `GODOT` to point the scripts at another engine binary.

Tests (headless, exit code gates CI), and an end-to-end network smoke run (headless server plus two
bot clients over real ENet; it fails on script errors, missing joins or a duel with no outcome):

```bash
tools/run_tests.sh
tools/net_smoke.sh 30
```

Assets are committed. To re-fetch them (all CC0 except two OFL fonts; manifest in
`assets/third_party/CREDITS.md`), and to render review screenshots without the editor:

```bash
python3 tools/fetch_assets.py
```

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path . -s res://tools/shot.gd -- --level --cam=0,2,-17 --look=0,2,-40 --out=/tmp/torii.png
```

## Controls

| Action | Keyboard / mouse | Gamepad |
|---|---|---|
| Move / sprint | WASD / Shift | Left stick / L3 |
| Light attack (3-hit chain) | LMB | RB |
| Heavy attack | E | Y |
| Guard (fresh press = 5-tick parry window) | RMB or Q | LB |
| Feint | Guard during an early windup | — |
| Dodge (bounded i-frames) | Space | B |
| Lock-on | Tab / MMB | R3 |
| Cycle dummy behaviour · reset | F1 · F5 | Back · — |

In a duel, the sandbox-only keys (F1, F5) do nothing; the server starts a new round 3 s after a death.

Dummy modes: passive, always-guard (posture pressure), rhythmic attacks (parry practice), duelist
(strings, heavies, feints, reactive guard/parry).

## What's implemented

- **Pure combat core** (`scripts/combat/`): `Combatant` state machine (neutral → windup → active →
  recovery, guard, dodge, hitstun, posture break, death), `CombatStats` (health, stamina, posture,
  Spirit — integers only), one central `HitResolver` path (dodge → parry → guard → hit), and the
  fixed 30 Hz `CombatSimulation` loop that emits confirmed events.
- **Rules from the GDD**: timed parry with anti-mash rearm, front-only guard, posture break with a
  critical punish window, feints with a stamina cost, buffered light chains, bounded dodge i-frames,
  windup-only tracking, ability-scoped hit de-duplication, order-independent simultaneous trades,
  party friendly fire off, clamped move intents.
- **Content as data**: katana moves and weapon are typed Resources in `data/` with stable versioned
  IDs (`move.katana.light_1.v1`) and validation.
- **Sandbox** (`scenes/sandbox/`): placeholder fighters with readable tells (amber = light windup,
  red = heavy, white = parry window, yellow pulse = posture broken), orbit/lock-on camera, HUD with
  the four resources, event feed and tick cost.
- Physics runs at 30 Hz with physics interpolation, so rendering stays smooth at any frame rate.

- **P1 networking** (`scripts/multiplayer/`, `scripts/server/`, MULTIPLAYER.md §15):
  - Headless dedicated server steps `CombatSimulation` and the `FighterBody` collision at 30 Hz.
  - Clients send quantized `CombatIntent`s with sequence numbers over **unreliable** ENet. Every
    packet repeats the four newest unacked inputs, so a lost packet costs nothing.
  - The server sends each player an **unreliable-ordered** snapshot every tick: position, facing,
    combat state, the four resources and that player's input ack. Confirmed combat events go
    **reliably** on their own channel. `NetProtocol` documents the channel IDs.
  - The client predicts its own movement and reconciles on every snapshot: it rewinds to the server
    state and replays the unacked inputs. Small corrections blend visually; respawns snap.
    Remote fighters are interpolated two ticks behind, with at most three ticks of extrapolation.
  - Security: every RPC's sender is checked on both sides. The server assigns entity IDs and a
    random session epoch, and the sender ID alone picks which fighter an input drives. Tampered
    input packets are rejected whole and counted: bad types or sizes, over-long move vectors,
    unknown action bits, out-of-range facing, unordered sequences, and sequence jumps faster than
    server time. Inputs are rate-limited. Server relay is off, so clients can't message each
    other. Late or reordered snapshots are dropped, never applied.
  - Login is a local stub (protocol version check + free slot). There is no persistence.
  - Not predicted yet: attack and dodge starts show up once the server confirms them (one RTT).
    There is no lag compensation (MULTIPLAYER.md §6). Players collide against a proxy of the
    opponent at its newest server position.
- **World, art and UI** (status tables at the top of ENVIRONMENT.md, 3DMODELS.md, GUI.md):
  - Region server: sanctuary spawns (`--spawn=arena|frontier` for tests), per-fighter respawn,
    four PvE bandits that aggro only where combat is legal and leash home. `NpcDirector` drives them
    with the same intents players send, so they obey every rule.
  - Character: the CC BY "Ninja" by histrix88 (4K PBR, Mixamo rig, retargeted) and both Quaternius CC0 animation libraries
    are retargeted at import onto Godot's humanoid profile (`assets/retarget/`), so any humanoid body
    can replace it. The katana grip is derived from the hand bones, and the scarf ties at the cuirass.
  - Cosmetics: `CosmeticCatalog` (armour lacquers recoloured by shader on the 4K textures, blade
    finishes, scarves). Appearance is replicated as IDs, the server sanitises them, and they carry
    no stats. The Armory and Store use live try-on; the wallet is demo currency (no payments yet).
  - Menu: the 3D `MenuStage` (your assassin on a lit iaidō set, drag to turn, camera framings per
    screen), serif menu, player card and wallet.
  - Environment: Terrain3D (MIT) hills with a painted forest floor, instanced grass and an instanced
    sugi forest; HDRI sky and IBL, AgX tonemapping, volumetric haze. The playable area stays flat for
    fair combat, and the server never loads the terrain.
  - Optimization: static batching per material per 32 m cell, box occluders with occlusion culling,
    chunked MultiMeshes with visibility ranges, auto mesh LODs, on-demand art loading (the server
    loads none). Settings offer presets, FSR 1/2 and MetalFX upscaling, TAA, SSIL/SDFGI and LOD bias.
    Village street: 669 → 332 draw calls.
  - Honest limit: environment modules are still a textured kit (greybox-plus), not authored art.
    The pipeline (retargeting, cosmetic IDs, batching) is built so bought or commissioned assets
    drop in.

All frame data is a first guess to be tuned in playtests (GDD §18).

## Layout

```text
addons/terrain_3d/     Terrain3D GDExtension (MIT), desktop binaries only
assets/third_party/    downloaded CC0/OFL assets + CREDITS.md (tools/fetch_assets.py)
assets/retarget/       BoneMaps onto SkeletonProfileHumanoid (tools/make_bone_maps.gd)
assets/terrain/        packed terrain layers (tools/pack_terrain_textures.gd)
scripts/bootstrap/     Boot — server / scripted client / UI shell from the command line
scripts/core/          CombatIntent (client→server intent), ZoneRule (risk taxonomy)
scripts/combat/        pure authoritative rules (no nodes, no wall clock)
scripts/multiplayer/   protocol manifest, input/snapshot codecs, RPC surface, client prediction
scripts/server/        headless duel server and peer admission/input routing
scripts/world/         RegionMap (zones, landmarks), WorldKit (environment kit), ProvinceLevel
scripts/actors/        FighterBody (physics + presentation hook), PlayerController, DummyBrain
scripts/presentation/  AssassinModel, scarf, sword trail, FX, SFX, camera, HUD, input bindings
scripts/ui/            theme/tokens, settings, UiShell router and every menu screen
scripts/sandbox/       M0 training dojo wiring
data/                  move and weapon definitions (.tres)
tests/                 headless runner + unit tests
tools/                 run/test scripts, net_smoke.sh (PvP + PvE), fetch_assets.py, shot.gd, asset tools
```

The Godot project sits at the repo root rather than in `game/` as ARCHITECTURE.md §5 suggests;
move it when the Go `backend/` arrives in P2.

## Next (P2 — secure admission + persistence)

Go login and short-lived join tickets replace the local stub. Character leases and session epochs
are issued by the control plane (MULTIPLAYER.md §1, §15). Before then, worth measuring: playing at
50–200 ms RTT with loss (§12), predicting attack/dodge starts, and lowering the remote snapshot rate.
