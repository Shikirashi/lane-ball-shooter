# Codex Handoff — LBS-P020 special enemy abilities

**Status:** COMPLETE

**Branch:** `master`

**Implementation commit:** this scoped P020 commit.

**Mailbox:** remains on LBS-P020. `.ai/TASK.md`, `.ai/DECISIONS.md`, `.ai/TASK_LEDGER.md`, and `.ai/PROTOCOL.md` were not edited or advanced.

## Sickle Snake

A nonfatal hit now moves the living Snake from `moving` to an authoritative `stunned` state for exactly 0.5 simulation seconds. Its horizontal speed and swept-collision motion are zero throughout that interval. It then chooses a valid adjacent lane: edge lanes always choose inward, while middle lanes use a dedicated seeded 50/50 RNG so spawn sampling remains reproducible. If the preferred lane is full, it tries the other adjacent lane; if both are full it waits without moving and retains the original choice until capacity becomes available.

Transfer is atomic between the two lane models and does not invoke spawning or neutralization. The enemy retains its global `spawn_id`, HP, X position, type, original lane quota charge, live-enemy accounting, one-Snake ownership, and eventual 15-second death cooldown. A destination-local UID is allocated to avoid collisions. The same visual nodes are reparented and cross lane depth smoothly over 0.3 seconds; combat ownership moves to the destination at transfer start, so the Snake remains targetable and projectile, tier-3, and emergency deaths are attributed exactly once. After the crossing, normal 0.48-unit/s movement resumes. Large simulation steps consume stun/transfer time deterministically and apply only their remaining fraction to movement.

## Healyzard

Every Healyzard now owns an independent 15-second gameplay timer. At each exact boundary it targets every other non-Healyzard currently in its lane and restores one HP, capped by each target's canonical maximum. It never heals itself, another Healyzard, or an enemy in another lane. Pulses still publish deterministic target/restoration details when all eligible targets are already full, and timers stop with the existing terminal combat freeze/reset with the encounter.

The LaneActor reuses one generated 64×64 radial-alpha texture across all healer visuals. Each healer owns a Sprite3D behind its body; a pulse shows the soft yellow center/transparent-edge glow, expands it, and fades it completely over 0.85 seconds. The aura is hidden on death, while the existing P018 body fall, sparks, fade, SFX, and three-second victory delay continue unchanged. No external asset or additional audio cue was introduced.

## Regression coverage

Added `tests/p020_special_enemy_abilities_test.gd` — PASS (67 checks):

- exact 0.5-second stun at 30/60/120 Hz and 0.08-second steps, followed by a 0.3-second visual transfer and fractional movement resumption;
- preservation of global identity, HP, X, quota/live accounting, and collision-safe destination-local UID remapping;
- deterministic edge/middle routing, balanced seeded middle choices, preferred-full fallback, and both-full waiting;
- fatal damage during transfer plus destination projectile, tier-3, and emergency clears, with one death cue and normal cooldown;
- independent healer timers, exact 15-second boundaries, maximum-HP caps, exclusions, zero-restoration events, transfer recipients, terminal freeze, and restart;
- generated radial texture center/edge alpha, sharing, render order, pulse animation/reuse, and death cleanup;
- retained P017 original-UID conveyor history and P010 staged insertion/cascade timing.

## Validation

Godot 4.7.2 headless, all passing:

- P001 smoke — PASS.
- P002 gameplay logic — PASS (66 checks).
- P003 progression/magazine — PASS (73 checks).
- P004 lane combat — PASS (42 checks).
- P005 survival — PASS (63 checks).
- P006 platform QA — PASS (69 checks).
- P007 playtest revision — PASS (53 checks).
- P008 gamefeel/SFX — PASS (84 checks).
- P009 Zuma rollback — PASS (46 checks).
- P010 staged cascade — PASS (162 checks).
- P011 segment stress — PASS (16,485 checks; seed `5011CAFE`, 2,400 operations, 1,836 insertions, 620 matches, 707 fresh, 57 hidden-left).
- P012 forward insertion — PASS (366 checks).
- P013 shooter preview/mask — PASS (50 checks).
- P014 causal rollback/feed — PASS (289 checks).
- P015 gravity/finite enemies — PASS (524 checks).
- P016 speed/retained-history compatibility — PASS (76 checks).
- P017 offscreen-left reentry — PASS (352 checks).
- P018 enemy death/victory delay — PASS (41 checks).
- P019 typed roster/spawning — PASS (117 checks).
- P020 special enemy abilities — PASS (67 checks).
- `git diff --check` — PASS.

Bounded main-scene startup reached the running game without project/runtime errors at `960x540`, `1280x720`, `1600x720`, and `2400x1080`; each was intentionally stopped after three seconds (exit 124). The sandbox still denies Godot's `user://logs/godot.log` rotation, producing the known harmless warning. Web/Android exports and physical-device QA were not exercised.

## Manual playtest

1. Hit a full-health Snake once. Confirm it stops immediately for about half a second, crosses to an adjacent non-full lane without disappearing, and then resumes its fast slide with the same remaining HP.
2. Fill its preferred neighboring lane and repeat; it should use the other adjacent lane. Fill both neighbors; it should wait motionless, then transfer after space opens.
3. Shoot or clear a Snake while it is crossing. Confirm one death animation/SFX, no duplicate body, no replacement before the established 15-second cooldown, and unchanged encounter counts.
4. Wound several non-Healyzards beside one or more Healyzards. Every healer should pulse independently at 15-second intervals, restoring one HP up to each target's maximum. Healyzards and other lanes must remain unchanged.
5. Confirm each pulse shows a soft circular yellow glow behind the healer, with transparent edges, expanding and disappearing in under one second. Kill the healer during/after a pulse and confirm the aura leaves no ghost.

## Limitations / assumptions

- Logical lane ownership changes when the visible crossing begins. This keeps the transfer atomic and the Snake continuously targetable; attacks from its destination lane can therefore kill it before the visual reaches the destination centerline.
- A waiting Snake preserves its initial random preference and only uses the alternate as a capacity fallback; it does not reroll every frame.
- The aura is a procedural billboard and has headless property/pixel coverage, but perceived softness, depth, and readability still need desktop/Web/Android visual playtesting.
