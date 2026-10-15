# Kage (working title: Samurai Assassin)

Third-person PvPvE samurai battleground. Design lives in [GDD.md](GDD.md), boundaries in
[ARCHITECTURE.md](ARCHITECTURE.md), wire behaviour in [MULTIPLAYER.md](MULTIPLAYER.md).

**Current milestone: M0 / P0 — local combat sandbox.** One player vs a training dummy, driven by the
same pure, tick-based rules the headless region server will run.

## Run

Godot **4.7.2** (pinned; see `config/features` in `project.godot`).

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path .
```

Or open the folder in the Godot editor and press F5. Tests (headless, exit code gates CI):

```bash
tools/run_tests.sh
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

All frame data is a first guess to be tuned in playtests (GDD §18).

## Layout

```text
scripts/core/          CombatIntent — the client→server intent payload
scripts/combat/        pure authoritative rules (no nodes, no wall clock)
scripts/actors/        FighterBody (physics + visuals), PlayerController, DummyBrain
scripts/presentation/  camera, HUD, input bindings
scripts/sandbox/       M0 sandbox wiring and placeholder level
data/                  move and weapon definitions (.tres)
tests/                 headless runner + unit tests
tools/                 run_tests.sh
```

The Godot project sits at the repo root rather than in `game/` as ARCHITECTURE.md §5 suggests;
move it when the Go `backend/` arrives in P2.

## Next (P1 — two-player server)

Run `CombatSimulation` inside a headless dedicated-server build, send `CombatIntent`s over ENet with
sequence numbers, replicate snapshots + confirmed events, and add local movement prediction and
remote interpolation (MULTIPLAYER.md §5, §15).
