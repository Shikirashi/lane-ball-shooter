# ACTIVE TASK: LBS-P019 — Typed enemy roster, primitive models, weighted spawns, baseline movement

**Status:** READY FOR CODEX
**Branch:** `master`
**Authorized by user (2026-10-25):** Implement enemy variety. All prior vector/character artwork was rejected and MUST NOT be used, imported, traced, or substituted. Continue using procedural Godot 3D primitives based on the CURRENT existing Hopper model.
**Scope P019:** Four enemy types, unmistakably distinct 3D primitive models, stats and ordinary movement, global seeded weighted spawn choice + Sickle Snake global single-instance / post-death cooldown. **P020 is queued, NOT authorized in this task:** implement snake 0.5s hit-stun + cross-lane transfer, Healyzard 15s healing and yellow radial aura in P020. P019 must remain a playable, testable build with all four types. P020 will be activated only by ChatGPT after P019 review.
**Baseline:** P018 code/handoff `b2e91fb`, P017 original-UID offscreen-LEFT conveyor. Read `AGENTS.md`, `.ai/PROTOCOL.md`, `.ai/DECISIONS.md`, `.ai/TASK_LEDGER.md`, `.ai/TASK.md`, latest `.ai/CODEX_HANDOFF.md`. Godot 4.7.2, GDScript, Compatibility renderer, Web/Android landscape. Code only: do not use editor/GUI control, Blender, image_gen, external character assets or third-party packages.

## Canonical roster and stats

Make a typed `EnemyType` enum/definition (e.g. `scripts/world/enemy_types.gd`, or another single authoritative table) consumed by combat logic, spawn director, visuals and tests. Do not scatter arbitrary numeric type literals.

| Type | Relative weight | Max HP | Horizontal velocity | Animation | Primitive appearance |
|---|---:|---:|---:|---|---|
| HOPPER | 50 | 2 | baseline 0.24 world-units/s average | EXISTING ground/air hop cycle | Identical current gray Hopper silhouette; **exactly two orange horn-like squares atop head** as permanent DECORATION (NOT health pips). |
| HEAVY | 20 | 4 | 0.70 × Hopper = 0.168/s | Continuous ground slide (not hops) | **Wider Hopper-shaped** dark/orange body; visually orange, broad, no horns; eyes/visor contrast against orange. |
| SICKLE_SNAKE | 20 | 2 (standard HP) | 2.0 × Hopper = 0.48/s | Continuous ground slide | **Taller Hopper-shaped** character, strongly yellow, no horns; contrasting eye color. P020 will add 0.5s post-hit stop and neighboring lane transfer. |
| HEALYZARD | 10 | 2 (default, because user didn't specify alternate) | 0 | Stays at REAR of its lane (stationary support enemy, from earlier user design) | 0.70 overall scale of Hopper primitive construction, GREEN, no horns; eyes noticeably different from body. P020 will add 1HP/15s healing and an animated yellow radial glow. |

Latest explicit user rules override older notes (Healyzard cooldown becomes 15s in P020, not former 8s). Any HP value is **INVISIBLE in appearance**; maintain logical HP and hit flash/death feedback. The two orange rectangles from prior enemy model were misread as horns: permanently display exactly two ONLY on Hopper. They must NEVER disappear as Hopper takes damage. No health bar, numeric HP, color-changing HP pip, or floating HP display anywhere on any enemy.

Build appearances from existing `PrimitiveFactory`, using editable GDScript scales/material colors. Preserve current Hopper silhouette otherwise; no external vector character art. Respect consistent feet grounding and side-fall death animation for different body sizes (P018's body-fall, explosions and material fades). No hopping/squash bounce for Heavy/Snake/Healy; only Hopper hops.

## Weighted spawning, deterministic global rules

Current `LaneCombatModel._update_spawning` selects generic enemies independently per lane, initial spawns occur during `LaneActor._ready`, and enemy UIDs are local to a lane. Refactor deliberately; do NOT randomize only the visuals while keeping generic stats. Spawn type must be in authoritative enemy record with max_hp, velocity and effects.

- Spawn RNG seeded and injectable for deterministic tests/restarts, **separate from conveyor RNG, attack tier-3 adjacent-lane RNG, and visual RNG**.
- Canonical spawn distribution weights `HOPPER:50, HEAVY:20, SICKLE_SNAKE:20, HEALYZARD:10`. Every new enemy (including four initial enemies unless an explicit documented tutorial exception is needed) draws from this table across all lanes.
- **Eligibility rule:** Global MAX ONE **living** Sickle Snake across all FOUR lanes. No new Sickle Snake until **at least 15.0 seconds after the previous Sickle Snake was neutralized** (projectile/tier3/emergency). Applies to initial and future spawns; if still alive indefinitely, no others. Track gameplay simulation time, not wall clock. At first encounter start, snake eligible unless one exists. On snake death, start cooldown immediately, no double-start on duplicate events.
- When snake is ineligible, **remove only Snake from eligible weights and renormalize remaining original weights (50/20/10)**. Don't block spawns, burn quota, reroll infinitely or silently convert snake picks after sampling. Sampling among remaining types should be deterministic and clear. Thus the **50/20/20/10 are configured base probabilities**, not a guarantee of exact observed proportions in a finite 32-enemy encounter when Snake is globally gated. Document this candidly.
- Spawn/timing scheduler lives at the `Battlefield` or a dedicated encounter director, not four uncoordinated RNGs in `LaneCombatModel`. Choose exactly one authoritative mechanism so lane models cannot bypass global snake eligibility during automatic spawning. Keep public manual/test `spawn_enemy` compatibility or add explicit type parameter while retaining older callers and 2-HP Hopper defaults.
- No more than five **simultaneous alive** enemies per lane, 8 total **successful** initial+subsequent spawns per lane /32 encounter total. If lane is full, defer without consuming quota. Deaths don't replenish budget. Victory when all quotas exhausted + zero alive, as P015/P018; WAVE CLEARED still delayed three seconds after final neutralization, death VFX and SFX still run.
- Avoid ambiguous UID collisions across lanes for global snake tracking. Use a dedicated immutable global `spawn_id` or composite `(lane_index, local_uid)` per actual enemy; visual/event identities must remain stable, with no duplicate death effects/cues.
- Important order: create/register snake occupancy before another lane's same-frame spawn; release it only on neutralization, not damage. At death record cooldown even when tier-3 or emergency kills; do not alter standard neutralization counters.
- **Initial seed/reset semantics:** Currently LaneActor constructs initial enemy in `_ready`. Ensure the director is initialized and type selection applied to all initial enemies without violating `_ready` order/signals; restart consistently reseeds. No accidental victory when transiently empty during initial setup. Document source of spawn-time clock and reset.
- Healyzard is stationary at rear, ideally in a dedicated back position without overlapping new spawns. New enemies must be allowed to spawn later even if a stationary healer remains. Ensure the single-lane capacity limit, collision testing and on-screen presentation are physically coherent (don't stack bodies). This task can use a reserved rear support slot/offset and tests; ability to heal comes P020.

## Movement/attacks and visuals in P019

- Hopper keeps exact existing phase-based `_hop_displacement` and hop-height animation.
- Heavy and Snake use smooth continuous LEFT translation `speed * dt`, no hop height, collision detection swept for linear moving targets (the existing `_first_swept_hit` models only hopping; change this too). Healyzard remains at its rear support x stationary, can be hit, killed, cleared and counted.
- Keep HP values correct under tier1 1 damage, tier2 2 damage and tier3/emergency instakill; heavy survives up to 4, snake baseline 2. Existing enemy hit flash applies to all. No health UI.
- Preserve moving enemy/defender breach logic and first emergency lane clear, revive, and P018 typed death event and actual primitive corpse. Ensure no surviving corpse retained or new enemy created with old UID.
- If the healer at rear is the only remaining enemy, killing it should still allow victory; a stationary healer should NOT automatically breach and should NOT block spawning past its own slot.

## P019 regression tests `tests/p019_enemy_roster_spawning_test.gd`

1. Default no-type `spawn_enemy()` historical call creates 2 HP Hopper; typed spawn verifies 2/4/2/2 HP, exact 0.24/0.168/0.48/0 speed, hopping only Hopper.
2. Visual primitive class/shape colors, sizes, eye contrast, **exactly 2 always-visible decorative orange horns on HOPPER and 0 on other types**; damage Hopper to 1HP and assert both horns unchanged. No HP bars/health-driven mesh toggles.
3. Enemy hit/projectile swept collision works for both slide and stationary types at 30/60/120Hz and 0.08s delta. Heavy survives 2/3 attacks as appropriate, Snake has baseline 2 HP, healer can be killed. No missed hits due to reused hop code.
4. Test inject seeded RNG and run >=10k draws in a **fully eligible isolated sampler** (no alive Snake restriction) — frequencies within reasonable tolerances of 50/20/20/10; with Snake ineligible test exact remaining set/50:20:10 renormalization and deterministic sequence under reset.
5. Live actual encounter 4 lanes: never >1 live Snake (including simultaneous same-frame spawn requests); after projectile/tier3/emergency Snake kill no successor before 15.0s, eligible again at boundary. No quota lost on capacity block or eligibility removal; remain <=5 per lane and <=8 successful spawns per lane, <=32 globally. Test forced/manual spawns vs director ownership and document fixtures.
6. Initialization and restart can spawn weighted initial enemies without stale global snake state; use forced seeded fixtures, not random global assumptions, to retain reliable tests. Distinct IDs or composite identity across lanes.
7. Healy support position doesn't overlap new entrances, doesn't freeze normal lane progress. No healing or snake lane transfer yet (explicit P020 scope).
8. P018 death SFX/VFX 1s and victory 3s still work; no standing enemy ghosts; P017 original UID offscreen-LEFT rollback and 102 px/s chain unchanged.
9. Re-run all P001–P018 headless tests; adjust old tests to specify a forced Hopper fixture or disable randomized spawning where deterministic generic assumptions exist. Do NOT drop coverage to satisfy RNG behavior. Check four landscape startup sizes 960x540 1280x720 1600x720 2400x1080 and `git diff --check`.

## End of P019

Update `README.md` with roster, colors/horns, movement, probabilities and snake global eligibility, and clearly mark P020-specific abilities as NOT YET IMPLEMENTED until P020. Update `.ai/CODEX_HANDOFF.md` with actual code decisions, commands/pass counts, assumptions (including stationary healer rear placement), test seed/eligibility and manual QA. Code-only, no GUI automation. Commit and push `master` then **STOP**; do not implement P020 on your own and do not edit ChatGPT-owned `.ai/TASK.md`, `.ai/TASK_LEDGER.md`, `.ai/DECISIONS.md`, `.ai/PROTOCOL.md`.
