# ACTIVE TASK: LBS-P004 — 3D defender attacks, hopping enemies, and projectile combat

**State:** READY FOR CODEX
**Branch:** `master`
**Prerequisite:** P001–P003 accepted; P003 implementation `aa65950`, handoff `1ce5ce6`. Preserve P002's physical hit insertion, connected-segment matching and FIFO cache and P003's match progression and magazine.
**Read first:** `AGENTS.md`, `.ai/PROTOCOL.md`, `.ai/DECISIONS.md`, `.ai/TASK_LEDGER.md`, this `.ai/TASK.md`.

## Objective
Make colored ball matches cause the **corresponding defender in the central 3D battlefield** to fire actual primitive 3D projectiles **to the right across its own lane**, damaging/killing hopping enemies. Add proper enemy spawning, independent movement and HP. Maintain the hybrid Godot scene, mouse/touch shooting, magazine, score, combo/fever and recycling. Keep knockdown/emergency/revival/game-over mechanics **out of this task** (P005).

## Canonical rules
1. Four lanes mapped 1:1 to `TeamData.Identity` (RED, BLUE, YELLOW, GREEN). Defenders always stand on the **left** of each lane, and do not autonomously attack.
2. Subscribe directly to P003's structured `MatchProgression.match_resolved(result)` event. For every result, read and **lock** identity, combo tier and fever state immediately. A match of a color calls only that color's defender to attack. Do not calculate tier later using mutable current combo state. A match of color with no current enemies still fires (shots may be wasted).
3. Initial tier mapping for combat: tier 1 = **one projectile**, tier 2 = **two projectiles**, tier 3 = **three projectiles**. FEVER at fourth match and onward uses tier 3 for now; **no extra fever combat effect** until playtest. Groups >3 still only grant extra score, not additional projectiles. A cascade generates separate attacks in event order.
4. All projectiles are visible **3D primitives** (small spheres/capsules) launched from the defender and traveling toward screen-right along the **same 3D lane**. An attack of N projectiles should be visually distinguishable (short sequential burst or spacing); do not instantiate N projectiles at an identical position/time causing indecipherable stacking. Shooter's upward 2D projectile remains separate and unchanged.
5. Enemies are **3D primitives**, hop left from the right while logical movement and collision remain independent of their jump-height animation. No 3D navigation/pathfinding or rigid-body physics required. Spawn multiple enemies, with tunable per-lane spawn times / overall spawn interval, speed, HP, and projectile damage. Initial difficulty should be relaxed enough to playtest and see attacks. Use a seeded PRNG if randomness is introduced.
6. A projectile damages **the first enemy it reaches in its own lane** (not enemies in neighboring lanes). When an enemy HP reaches 0, remove it with brief simple readable impact/death feedback (squash, flash or burst of primitive nodes, without assets). Otherwise it survives and continues advancing. Projectiles despawn upon hitting, reaching world right boundary, or timing out. A projectile can't hit twice; reliably handle targets being killed mid-burst.
7. Avoid tunneling from fast projectiles: implement logical swept/interval collision against moving enemies or bounded update that handles large delta. Distinguish enemy logical X from model hop Y; jumping is cosmetic, not invulnerability.
8. **Temporary P004 boundary rule:** When enemies reach or pass the defender/left edge, do not permanently kill anyone or end the game. They may be recycled/despawned **only as a clearly documented placeholder** until P005. No surprise damage or game-over logic in P004. Keep state easy to transition to P005.
9. Display attack feedback on defender (brief lunge, tilt, color flash, muzzle effect) and damage/hit feedback on enemy, preferably procedural and cheap. Keep colored/symbol-coded defenders recognizable with existing primitives, avoid elaborate graphics, audio, or external assets.
10. Central battlefield must fit within its allocated `SubViewportContainer` at standard and wider landscape sizes; camera fixed orthographic with four visually separated lanes. Do not position meshes offscreen or place long-lived dynamic nodes in unrelated viewports.

## Implementation guidance
- Refactor `scripts/world/lane_actor.gd` from its P001 single looping demo enemy to support **multiple independently simulated enemies**, projectile instances, per-lane combat methods and VFX. Keep `Battlefield` as coordinator/lookup for 4 lane actors and provide a clean method e.g. `fire_for_match(result: Dictionary)`.
- For code clarity, consider a small pure logical `EnemyState/ProjectileState` script (or compact typed dictionaries) plus a visual primitive factory. Keep collision logic and visuals separate enough to test without rendered frames.
- Use P003 result signal in `scripts/main.gd`; other subscribers (HUD/chain feedback) remain connected. Match result handling should not be duplicated or advanced twice.
- Expose a way to reset/seed enemies in tests, count active enemies/projectiles, inspect HP and attack history, and inject known target positions. Favor deterministic tests not dependent on chance or many seconds of runtime.
- Enemies can spawn at one lane at a time or in staggered per-lane intervals; avoid synchronized dense floods obscuring 3D readability. Make spawn cadence configurable and document it.
- Separate *attack burst timing* from current match tier: any queued burst must retain tier/identity even if the player's combo expires during the burst. A second match can trigger another independent burst without cancelling the first.
- Existing state/UI remains legible and responsive on landscape Web/Android target; no export setup yet.

## Headless validation (required)
Create `tests/p004_combat_test.gd` or equivalent, and rerun P001/P002/P003 suites.
- One RED tier-1 result triggers 1 RED-lane projectile and zero other-lane shots.
- Tier 2 emits 2 and tier 3/FEVER emits 3, even if global progression subsequently times out; attacks lock match-time tier. Group size 5/7 does not add projectiles beyond tier.
- Empty lane still emits and projectiles eventually despawn.
- Explicitly spawn one enemy: projectile advances right, hits, damages, and kills appropriately; remove dead enemy once, no duplicate hit.
- Two enemies in same lane: first takes first impact and remaining projectile can reach second after first dies; projectiles stop on their actual first collision.
- Enemy jumping does not change logical hit probability; a large delta does not tunnel past a target.
- Other lanes are unaffected by attacks, including at nearby visual Z coordinates.
- Multiple enemies can coexist, travel left at frame-independent speed, and spawn cadence is tunable/bounded (no uncontrolled unbounded projectile or visual node growth).
- One genuine 3-ball clear flows through `ChainModel -> MatchProgression -> Battlefield -> corresponding LaneActor` (not only test-injected attack methods).
- Existing gameplay/magazine/collision/cascade/fever/headless startup tests pass. Run bounded runtime startup 1280×720 and if possible 1600×720.

## Player-facing manual playtest
- Load/run scene: four colored primitive defenders and several independently hopping enemies are present.
- Make a 3-ball match; corresponding defender instantly reacts and fires a projectile to the right.
- Make consecutive matches within 3 seconds to see bursts of 2 then 3 projectiles; FEVER uses tier 3.
- Projectiles hit the first enemy in their lane and enemies visibly disappear at zero HP; other lanes remain untouched.
- Match in an empty lane still fires; letting enemies reach left currently produces *no loss*, explicitly reserved for P005.
- Scores, symbols, top matching and magazine work throughout.

## Scope / completion
- Do **not** implement defender knockdown/revival, one-time emergency discharge, lane breach, permanent death, game over/restart (P005).
- Do **not** add external models, music/SFX, advanced shaders, special unit types, hero powers, upgrades, exports or changes to score/fever rules.
- Update `.ai/CODEX_HANDOFF.md` with P004 status, changed files, tests and commands, manual reproduction, tuning defaults, limitations; commit/push normally and **STOP** without advancing to P005. ChatGPT handles the mailbox progression.
