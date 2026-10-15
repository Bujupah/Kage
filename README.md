# Kage (working title: Samurai Assassin)

Third-person PvPvE samurai battleground. Design lives in [GDD.md](GDD.md), boundaries in
[ARCHITECTURE.md](ARCHITECTURE.md), wire behaviour in [MULTIPLAYER.md](MULTIPLAYER.md).

**Current milestone: M1 / P1 — real two-player server.** A headless Godot server runs the same pure,
tick-based combat rules as the M0 sandbox; two windowed clients duel over ENet with predicted
movement and server-authoritative hits, parries and death. The single-player sandbox still runs by
default.

## Run

Godot **4.7.2** (pinned; see `config/features` in `project.godot`).

Single-player sandbox (default when no role is given):

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path .
```

Or open the folder in the Godot editor and press F5.

Two-player duel: start the headless server, then two windowed clients (same machine or LAN):

```bash
tools/run_server.sh --port=7777
tools/run_client.sh --host=127.0.0.1 --name=Musashi
tools/run_client.sh --host=127.0.0.1 --name=Kojiro
```

The scripts wrap `godot --headless --path . -- --server` and `godot --path . -- --client`; every game
option goes after `--`. Client options: `--host`, `--port`, `--name`, `--bot=passive|guard|attack|duelist`
(the training AI drives the client), and `--quit-after=SECONDS`. In the editor you can do the same
with *Debug → Customize Run Instances*. Set `GODOT` to point the scripts at another engine binary.

Tests (headless, exit code gates CI), and an end-to-end network smoke run (headless server plus two
bot clients over real ENet; it fails on script errors, missing joins or a duel with no outcome):

```bash
tools/run_tests.sh
tools/net_smoke.sh 30
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

All frame data is a first guess to be tuned in playtests (GDD §18).

## Layout

```text
scripts/bootstrap/     Boot — picks sandbox / server / client from the command line
scripts/core/          CombatIntent — the client→server intent payload
scripts/combat/        pure authoritative rules (no nodes, no wall clock)
scripts/multiplayer/   protocol manifest, input/snapshot codecs, RPC surface, client prediction
scripts/server/        headless duel server and peer admission/input routing
scripts/world/         DojoLevel — level geometry shared by sandbox, server and clients
scripts/actors/        FighterBody (physics + visuals), PlayerController, DummyBrain
scripts/presentation/  camera, HUD, input bindings, contact sparks
scripts/sandbox/       M0 sandbox wiring
data/                  move and weapon definitions (.tres)
tests/                 headless runner + unit tests
tools/                 run_tests.sh, run_server.sh, run_client.sh, net_smoke.sh
```

The Godot project sits at the repo root rather than in `game/` as ARCHITECTURE.md §5 suggests;
move it when the Go `backend/` arrives in P2.

## Next (P2 — secure admission + persistence)

Go login and short-lived join tickets replace the local stub. Character leases and session epochs
are issued by the control plane (MULTIPLAYER.md §1, §15). Before then, worth measuring: playing at
50–200 ms RTT with loss (§12), predicting attack/dodge starts, and lowering the remote snapshot rate.
