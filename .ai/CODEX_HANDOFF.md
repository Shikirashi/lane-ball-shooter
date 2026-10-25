# Codex Handoff — LBS-P019 typed enemy roster and spawn director

**Status:** COMPLETE

**Branch:** `master`

**Implementation commit:** this scoped P019 commit.

**Mailbox:** remains on LBS-P019. P020 abilities were not implemented, and `.ai/TASK.md`, `.ai/DECISIONS.md`, `.ai/TASK_LEDGER.md`, and `.ai/PROTOCOL.md` were not edited or advanced.

## Authoritative roster

Added `scripts/world/enemy_types.gd` as the single definition for type enum, display names, max HP, speed multipliers and base spawn weights:

- HOPPER: 2 HP, existing 0.24-unit/s average grounded/air hop, gray original silhouette and exactly two permanent orange top horns.
- HEAVY: 4 HP, continuous 0.168-unit/s slide, wider dark-orange body/helmet and pale contrasting eyes, no horns.
- SICKLE_SNAKE: 2 HP, continuous 0.48-unit/s slide, taller strong-yellow body and dark eyes, no horns.
- HEALYZARD: 2 HP, zero velocity, green 0.7-scale body in a rear support slot, no horns.

Enemy records now carry immutable `type`, `spawn_id`, canonical `max_hp` and per-instance `speed`. Historical `LaneCombatModel.spawn_enemy()` calls remain source-compatible and default to a 2-HP Hopper; tests may pass an explicit type and global ID. Only Hopper advances the existing hop clock/height/squash. Heavy and Snake use continuous swept linear movement; Healyzard remains stationary. Projectile collision now branches between the existing piecewise hop sweep and constant-speed/stationary sweep, avoiding tunneling at large frame steps.

All HP pips/health-bar behavior was removed. The two old orange top blocks are now named permanent Hopper horns and are independent of HP. Other types have zero horns. Hit flash, tier damage, emergency/tier-3 removal, P018 death actor capture and fades apply to every type. Typed neutralization detail carries the full removed record before legacy kill/state signals, so death fallback visuals retain the correct archetype.

## Global spawn director

Live-game automatic spawning now has one Battlefield-owned scheduler instead of four lane RNGs. Battlefield owns a spawn-only RNG (`0x19E019` default), injectible through `set_spawn_rng_seed()` and reseeded on restart independently of conveyor and tier-3 target RNGs. It samples configured base weights 50/20/20/10. When Snake is ineligible, only its weight is removed, producing a 50:20:10 eligible pool; capacity rejection does not draw or consume quota.

Every directed spawn receives a unique encounter-wide `spawn_id`; lane-local UID remains unchanged for combat/visual compatibility. A successful Snake spawn registers occupancy before the next lane can spawn. Projectile, tier-3 and emergency neutralization release that exact spawn ID once and set `cooldown_until = simulation_time + 15.0`. The Battlefield gameplay clock stops at victory/defeat. Nonfatal damage does not release the gate, and eligibility becomes true at the exact 15-second boundary.

Each lane remains capped at five living and eight successful encounter spawns. A full lane leaves its timer due and quota untouched. Initial enemies are also weighted, spawned sequentially only after all lane connections exist, and restart reproduces the same sequence from the configured seed. A weighted initial Healyzard goes directly to its rear slot. Multiple Healyzards receive descending 0.82-unit-separated support slots starting at x=6.7, leaving the ordinary x=7.6 entrance free.

Standalone LaneActor/LaneCombatModel fixtures retain their prior local Hopper auto-spawn behavior. Runtime Battlefield lanes explicitly disable it and must use `spawn_directed_enemy`; direct model typed spawns are test fixtures and intentionally do not participate in global Snake ownership.

## P020 boundary

P019 does not implement post-hit Snake stun/lane switching, Healyzard healing, healing timers or yellow aura. Those remain queued in P020 exactly as required.

## Regression coverage

Added `tests/p019_enemy_roster_spawning_test.gd` — PASS (117 checks):

- canonical 2/4/2/2 HP and 0.24/0.168/0.48/0 speeds; Hopper-only hop and historical default spawn;
- colors/scales, exactly two persistent Hopper horns, zero other horns and no HP meshes;
- sliding/stationary projectile sweeps at 30/60/120 Hz and 0.08-second steps, including Heavy multi-hit durability;
- 20,000 fully eligible draws within 2% of 50/20/20/10, 16,000 ineligible draws within 2% of normalized 50:20:10, and exact seeded sequence replay (`0x50102010`, `99173`);
- global one-Snake gate, nonfatal retention and projectile/tier-3/emergency death cooldown checks at 14.999 and 15.000 seconds;
- deterministic weighted initialization/restart, unique global IDs, capacity deferral, eight-spawn quotas, distinct healer support slots and continued ordinary movement/spawning;
- a complete directed 32-enemy encounter with same-frame Snake/cap audits and preserved victory;
- preserved 102 px/s P017 original-UID history, 0.05-second insertion and invariant `I0`.

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
- `git diff --check` — PASS.

Bounded main-scene startup reached the running game without project/runtime errors at `960x540`, `1280x720`, `1600x720`, and `2400x1080`; each was intentionally terminated by `timeout` after three seconds (exit 124). The sandbox still denies Godot's `user://logs/godot.log` rotation, producing the known harmless warning. Web/Android exports and physical-device QA were not exercised.

## Manual playtest

1. Identify gray hopping Hopper/two orange horns, broad orange Heavy, tall fast yellow Snake and small stationary green Healyzard. Damage a Hopper to 1 HP: both horns must remain. No health display or non-Hopper horn should exist.
2. Watch motion over several seconds: Hopper alone pauses then hops; Heavy slides slowly, Snake slides twice baseline speed and Healyzard stays in a rear slot. Shoot each type and confirm hits register throughout motion.
3. Let several lanes spawn simultaneously. Never observe two living Snakes. Kill one by projectile, tier-3 and emergency in separate runs and confirm no replacement for 15 gameplay seconds.
4. Let Healyzards coexist with later entrances. They should not stack or block spawning. They intentionally do not heal or glow yet.
5. Complete the 32-enemy encounter and verify typed deaths, three-second WAVE CLEARED delay, immediate defeat, restart reseeding and all accepted conveyor behavior.

## Limitations / assumptions

- Headless checks validate model data and primitive/material properties; silhouette readability, grounding, color contrast and perceived relative speed still need desktop/Web/Android visual playtesting.
- Base weights are probabilities, not a promised per-encounter composition, especially while the global Snake gate renormalizes the eligible pool.
- Direct lane-model spawn calls remain intentionally local fixtures. Runtime callers requiring the global Snake invariant must use Battlefield's director API.
