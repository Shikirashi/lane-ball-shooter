# ACTIVE TASK: LBS-P020 — Sickle Snake lane switching and Healyzard healing

**Status: READY FOR CODEX — ACTIVE.** ChatGPT source-reviewed and accepted P019; P020 is now the ONLY active task in `.ai/TASK.md`. Implement ONLY P020, commit/push and STOP.
**Dependency:** P019 has been source-reviewed and accepted. Its implementation commit is `eb6501842e86f43001e4b8c220a75127d8188609`, adding all four typed primitive enemies, canonical stats, weighted global spawn director, single-Snake live limit and 15-second death cooldown.
**User rules:** No rejected concept vector art. Sickle Snake is tall yellow sliding Hopper, 2× Hopper speed and standard 2 HP; after a nonlethal hit, stop for 0.5s and move to a random adjacent lane (edge lanes only have one valid choice). Healyzard is stationary rearmost green 0.7× Hopper; every 15 seconds heal ALL other non-Healyzard enemies currently in its lane by 1 HP (max their own HP), and display a soft yellow circular radial glow with transparent edges BEHIND healer while healing. Decorative orange top squares belong only to Hopper; no HP bars/pips.

## A. Sickle Snake: damage stun and adjacent-lane relocation

- On a NONFATAL projectile hit, Sickle Snake stops horizontal movement immediately for exactly 0.50 seconds of simulation time. At the end of that interval, move to an adjacent lane. Its 0.48 world units/s slide resumes after transfer, not during stun. Fatal hits instead use normal P018 death and start the global 15-second Snake respawn cooldown; no transfer.
- Four lanes 0/1/2/3: lane 0 must go to lane 1; lane 3 to lane 2; lanes 1 and 2 choose between their two valid adjacent neighbors with uniform 50/50 probability. Seed this directional RNG separately from spawn-type and tier-3 target RNG for deterministic replay/tests. No wrapping and never jump two lanes.
- Preserve same immutable global spawn identity, current x, remaining HP, hit state across transfer, without counting it as a NEW spawn or consuming either origin/destination quota. It counts as live in EXACTLY ONE lane at any time and continues using the existing projectile, tier3, emergency, death SFX/VFX, defender contact and breach rules in its actual current lane. Original spawn quota remains charged to origin; neutralization counts are recorded wherever it dies.
- Present the relocation as a smooth short 3D motion between lanes along Z (suggest 0.25–0.35 seconds) if possible, with clear authority for hits while transitioning. Do not make enemy vanish/reappear or spawn a duplicate mesh, or treat transfer as enemy death. If necessary use a visual reparent to a Battlefield-level transition layer. Carefully document collision ownership during the move; keep it targetable rather than granting accidental invulnerability.
- Destination capacity five living enemies maximum. If the randomly selected destination is full, choose the other ADJACENT neighbor when available. Otherwise wait/stall at current x until a neighbor can accept it (not a nonadjacent teleport; no discarding, no quota burn). Cancel on fatal damage.
- A second hit during stun or transfer must not double-schedule a lane switch, double-count damage, or create double corpses; if fatal, normal death prevails. Separate timers/states for 0.5s hold versus ~0.3s transition. Handle same-frame attacks, 30/60/120 FPS and 0.08s updates.
- Preserve global max ONE snake, and 15 seconds after death (not first spawn or first hit) before another Snake is eligible. Applies if killed by projectile, tier3 or emergency. A transferring snake still counts alive; no second one can spawn.

## B. Healyzard: stationary lane healer

- Healyzard never hops or slides. Its own 15.0-second timer starts when spawned, with its first heal exactly 15 seconds later; another heal each 15s if alive and combat running. Every pulse heals all OTHER living, non-Healyzard members of the SAME current lane by exactly 1HP capped at each enemy's own max HP. It cannot heal itself or another Healyzard even if multiple healers are present. Full-HP targets don't exceed their cap.
- Each Healyzard gets an independent timer. Two healers can pulse in one lane and each restore 1HP to nonhealer targets; don't coalesce pulses. If Snake has transferred into/out of this lane before the pulse, use its authoritative CURRENT lane.
- When a 15-second pulse fires, show glow and event even if no enemy actually needs HP, with accurate zero count. Emit typed healer pulse event containing unique healer ID, lane index, targeted IDs, and restored HP amount, suitable for tests. No HP UI or orange top horns.
- Large deltas must handle due pulse boundaries deterministically; no lost/duplicated timer intervals, no postmortem heal, pause, or deferred timer crossing wave-cleared/game-over/reset. Avoid per-frame looping over all historic heal pulses.

## C. Healing aura: soft circular yellow gradient behind model

- Make a visibly round radial yellow glow whose center has alpha and whose circumference fades smoothly to alpha 0, appearing BEHIND the small green healer model. Use a lightweight generated radial alpha texture on a billboard or 3D quad/Sprite3D, with proper 3D layer position and Compatibility-renderer alpha handling. No user-rejected art, image generation, external textures, advanced shading add-ons or permanent bright solid rings.
- Pulse over ~0.6–1.0s, slight outward expansion and fade to zero; don't obstruct eyes/body. One reusable effect per live Healyzard, no per-frame texture reallocation; cleanup on death, transfer no-op, terminal reset and restart. Glow should be peripheral-vision readable at 1280x720 and not bloom excessively in Web/Android Compatibility renderer.
- Keep P018 explosion / sideways body fall / fade and death SFX for all variants; show heal VFX before any final victory overlay. Don't add a separate healing audio cue without user direction.
- Keep permanent two orange horn-like squares on Hopper only, unrelated to health; no health bars/pips/numeric labels on any archetype.

## D. Tests: tests/p020_special_enemy_abilities_test.gd

1. Snake at 2HP hit for 1: freeze at same x immediately; remain stopped through t=0.499s; after t=0.5 begins exactly one legal adjacent-lane move; once complete it resumes 0.48 units/s at same original x/UID/remaining 1HP. Check 30/60/120fps and 0.08s.
2. Four-lane boundaries: 0->1, 3->2 forced, seeded mid-lane choices balanced 50/50; no wrapping, no re-roll that produces a nonadjacent choice.
3. No more than 5 in target lane; fallback other neighbor or stall, no double quota. Kill snake during stun or transition, ensure one death cue/corpse and 15s global cooldown. Tier3/emergency in destination lane affect it correctly.
4. Healer pulse no earlier than t=15.000; restore exactly 1 to wounded Hopper/Heavy/Snake, cap at max, no healing for self or other Healyzards, no cross-lane heals. Multiple independently timed healers, several pulses and restart/terminal freeze.
5. Snake crossing shortly BEFORE or AFTER a Healyzard pulse: heal eligibility based on actual current lane at pulse instant.
6. Gradient texture sampled center vs perimeter, transparent edges; visible behind Healyzard at pulse and gone after ~1s, no per-frame allocations/leaked effects; other types don't glow.
7. P019 spawn distribution, global single-Snake live cap, cooldown, 8 spawns per lane/32 total, three-second victory presentation and death animations remain correct after transfers/heals.
8. No change to 102px/s conveyor and offscreen-left original-UID gravity return (P017); no health UI or orange squares outside Hopper.
9. Run P001–P019 suites plus P020. Update only superseded assumptions; preserve test coverage. Godot 4.7.2 headless bounded start 960x540, 1280x720, 1600x720, 2400x1080 and git diff --check.

## Existing P019 APIs and migration notes

- Canonical `EnemyTypes.Type` lives at `scripts/world/enemy_types.gd`; runtime global scheduling and Snake occupancy live in `scripts/world/battlefield.gd` (`_living_snake_spawn_id`, `_snake_cooldown_until`, `_spawn_simulation_time`); typed authoritative enemy dictionaries and HP/linear/hop sweep are in `scripts/world/lane_combat_model.gd` (`spawn_id` immutable); 3D variants and P018 death actors are in `scripts/world/lane_actor.gd`.
- Very important: moving an enemy into another lane requires preserving its `spawn_id` and its entire dictionary, not calling `spawn_directed_enemy` or `spawn_enemy`, so the quota and global Snake cap remain untouched. Lane-local `uid` can COLLIDE with a UID already in the destination; define a deterministic collision-safe remap for local presentation UID at transfer while KEEPING the immutable global `spawn_id`, or refactor visuals/collisions to globally unique IDs. Test transfers into a lane with matching local UIDs and make sure it cannot delete somebody else's live mesh, projectile target or death VFX. Only one Snake ever exists globally.
- Healyzard's P019 rear positions come from `_healyzard_spawn_x` in Battlefield and it is already stationary. Pulse timers must persist through normal lane updates, not be overwritten by visual synchronization.
- The director's existing 15-second Snake cooldown starts ONLY on actual neutralization. A nonfatal Snake hit/lane transfer must not free it. Ensure transferring a Snake still counts toward `encounter_live()` correctly and never creates a transient false victory when the last quota is exhausted. Damage and transfer ownership transitions must be atomic with respect to state-change signals.
- As before, P019's global spawn RNG is independent of tier-3 target RNG. Keep P020 direction RNG separately seeded.

## Finish
Update README and .ai/CODEX_HANDOFF.md with actual state machine, visual radial texture implementation, testing, and human visual QA steps. Code-only; no GUI/mouse operations. Commit/push master, STOP. Do not change ChatGPT-owned .ai/TASK.md, .ai/TASK_LEDGER.md, .ai/DECISIONS.md, .ai/PROTOCOL.md; do not activate P021.
