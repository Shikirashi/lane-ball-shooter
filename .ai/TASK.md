# ACTIVE TASK: LBS-P002 — Targeted Review Corrections

**State:** REVISION REQUIRED following implementation `0283c6e` / handoff `4fb0fb8`.
**Task scope:** P002 has been implemented and its reported 41 tests pass. Do **not** rewrite the chain system. Address the two source-review findings below, preserve previous behavior, extend tests, and repush. P003 is not yet active.

## P002-R1 — Prevent impossible long-distance shot insertion (required)
Existing `scripts/main.gd::_on_shot_reached_lane` unconditionally calls `ChainModel.insert_shot(identity, x)`; `_nearest_gap_index` always returns some index. This lets a projectile far away from the visible train teleport into the nearest group when it reaches lane Y.

- A straight-up projectile **must overlap a ball/occupied chain** at its shot X to connect. A shot outside the occupied portion, or in a wide empty gap, misses and does **not** modify the chain, trigger a match or affect cache.
- Use a documented effective horizontal collision tolerance based on ball radius plus shot radius (or other clearly justified model) with the *actual current logical/display positions* consistently.
- The magazine still consumes one ball when fired, even on a miss; misses do not emit match events or re-credit balls. Keep P001 cooldown and touch/mouse handling.
- Test fired shots from far left while all balls are far right (MUST miss), legitimate near-ball X (MUST insert), and shots while chain is moving. Preserve single-insertion behavior at actual contact.

## P002-R2 — Prevent nonphysical logical adjacency across recycled gaps (required)
`_append_on_right()` may spawn returned cached balls at the right boundary even when the existing last ball is far left. They are immediately treated as contiguous logical neighbors despite a very large physical gap, allowing matches/cascades across disconnected trains.

- Cached balls must still visibly **re-enter from the right**, FIFO order unchanged, while eventually joining the existing train OR remaining logically separate until they physically connect. Choose the simplest deterministic approach; avoid ball teleport, overlap, order reversal and runaway memory growth.
- A pair of balls with a large spatial gap must not count as adjacent for matching or cascading. The game should remain playable when repeated cache batches arrive and when the visible chain empties.
- Explicitly test a tail near the left/middle plus a returned group entering at the far right, including match detection before and after the group reconnects. Test cached RED,GREEN,BLUE remains left-to-right RED,GREEN,BLUE through partial and whole return.
- Retain the original P002 regression suite plus P001 headless smoke test.

## Completion
- Run bounded Godot headless tests; add at least one new test for R1 and R2 and document precise results.
- Do not implement score/combo/fever or 3D combat yet.
- Update `.ai/CODEX_HANDOFF.md` with a clear **P002 revision** heading, fixes, commands/results, short manual verification, and known limitations.
- Commit/push to `master`; stop and report commit SHA. ChatGPT will review and then advance to P003.
---

# Original P002 implementation specification

**State:** Initial implementation delivered; see review corrections above
**Branch:** `master`
**Prerequisite:** LBS-P001 accepted after source/handoff review. Preserve its working controls, 3D battlefield, shared magazine state, and responsive layout.
**Read:** `AGENTS.md`, `.ai/PROTOCOL.md`, `.ai/DECISIONS.md`, `.ai/TASK_LEDGER.md` and this task. Note the authoritative design is in DECISIONS.

## Objective
Replace P001's *sample/looping* upper ball train with a functional Zuma-style **2D ordered moving chain**, including vertical shot interception/insertion, three-or-more adjacent same-color matching, cascades after gap closure, balls leaving the left side entering an ordered FIFO cache, and cached balls re-entering from the right. Maintain a playable visual prototype while leaving actual combo/fever/combat for later tasks.

## Core behavior (must implement)
1. **Single source of chain state:** an ordered sequence of ball identities and logical positions, driven by game logic; rendering consumes the model state. Avoid unrelated physics bodies or assigning logic by visual-only sample indices. Use time-based movement with true leftward continuity, **no periodic teleport or color-shifting at spacing boundaries**.
2. **Spawn/stream:** seed an initial chain from the right containing all four identities and opportunities to make matches by inserting a fired ball. Do **not** seed uncontrolled contiguous groups of 3+ that disappear without player action. Provide small configurable population/spawn settings. Automatic replenishment must not produce unbounded growth in total visible+cached balls; player-fired balls may increase total. Stream must continue meaningfully while enemies hop. Expose debug constants for speed, spacing, radius, population, and cache return batch.
3. **Shoot-to-impact:** retain P001's straight-up shot visualization and magazine consumption/cooldown, but have shots actually reach the upper lane, carrying their locked identity and X impact coordinate. At the intersection with the ball path, insert into the ordered chain at the nearest valid position between balls (or at an end when appropriate), producing clear visual placement. Do not fake a match when the shot misses/has not reached the chain. Handle mouse and touch through the existing shared controller path. Make insertion work even while the chain moves.
4. **Adjacency matching:** only when a shot inserts, check the **contiguous same-color group containing the inserted ball**; if group size >=3, remove exactly that group and emit a match event with its identity and actual group size. Groups <3 remain. Larger groups are a single match event (for P003 scoring) rather than an attack-tier bonus.
5. **Gap closure + cascades:** after a removal, close the space in the logical ordering with a readable quick animation if practical (state correctness before animation). If newly connected neighboring groups now form a qualifying >=3 group, remove them in their own match event, repeat until stable. Preserve each distinct group as its own event in occurrence order. Do not scan/delete unrelated preexisting matches globally. Add light visual match feedback, but no elaborate explosions.
6. **Left-edge recycling:** when balls cross the **visible left boundary**, remove them from the visible chain **without destroying or penalizing them**, and append their identities to an FIFO queue in *temporal order of exit*. On match, bring back an initial configurable small batch (suggest 3) from the front of cache at the **right**, preserving the original **visual left-to-right order**. Explicit example: visible left-to-right [RED,GREEN,BLUE] exits RED, GREEN, BLUE; on recycling by sequential spawn at right, the restored visible left-to-right group is still [RED,GREEN,BLUE], meaning RED will again be the first to exit the left. Do not reverse array direction inadvertently.
7. **No stranded empty board:** when all visible balls have cleared or rolled off, automatically return cached balls until there is a playable visible stream. If both cache and chain truly empty (e.g. all matched), generate a fresh seed. Avoid infinite loops or runaway automatic spawn.
8. **Capacity and fairness:** manage physical spacing, offscreen ball positions, shot insertion, recycling and return without overlaps or chain jumps. Set conservative tunable rates/counts for playtest, and don't silently delete cached balls to enforce capacity. Ensure all four colors are periodically available through configurable seeding. Keep balls visually identifiable by both symbol and color.
9. **Observation/debug:** expose counters (e.g. visible count, cache count, last match color/size, total match events) in a subtle temporary debug display or documented key toggle. This is for P002 playtesting; do not implement P003 score/fever yet. The HUD may remain placeholders.

## Architecture guidance
- A pure logical chain model (e.g. `RefCounted`/script) plus renderer is preferred. Define a clear API for shot impact insertion, update/advance, match events, cache management and deterministic test setup.
- Rework `BallChainView` to render externally provided ordered state rather than its repeating constant SAMPLE. It must remain clipped to the top bar.
- Shooter projectiles should signal or callback when crossing the upper ball lane at their present X, not disappear without impact.
- Keep reliable timing: frame-rate-independent movement and no shifting the same ball identity on wrap.
- Prefer simple coordinated horizontal positions/insertion shifts over external physics or complex physics constraints. If gap-closing animation is unsafe, use instant logical closure and a short visual highlight.
- Do not overhaul unrelated P001 3D actor code, except for obvious, minimal visual-framing improvements if tested.

## Automated validation
Add deterministic headless tests for at least:
- insert does not clear a group of only two; inserted third adjacent clears and reports matching identity/group size;
- a larger group is counted as ONE distinct event with the true number of balls removed;
- adjacent-group cascades happen in the right order after gap closure, while unrelated groups remain untouched;
- FIFO cache order is preserved for [RED,GREEN,BLUE] across left exit and right return, including partial batches;
- visible-empty re-entry (or reseeding if cache is empty);
- moving chain does not reset its position/color mapping every one-ball spacing;
- normal shooting updates the magazine exactly once, creates/retains the correct projectile identity, and inserts only after it reaches the chain;
- P001 headless smoke test continues to pass (update its tests only when internal APIs legitimately change).
Run bounded `godot --headless` smoke/tests with the installed engine where available, plus at least one runtime startup check.

## Manual playtest acceptance
- Balls move continuously left with symbols and no visible reset jump.
- Can shoot from different horizontal X locations; each shot goes straight up and inserts the **loaded** color at an appropriate point in the moving chain.
- Groups of 3+ visibly clear; gap closure can cause secondary matches.
- Balls roll off the left into cache and visibly return on matches or when no visible balls remain, with consistent order.
- Loaded/next magazine and swaps remain synchronized with the shooter.
- 3D hopping enemies and four lanes still render beneath the chain.
- No penalties or game over occur from cached balls; P003/P004/P005 deferred.

## Scope boundaries
- **Do not** implement actual combo tiers/fever/scoring (P003), projectile combat (P004), knockdown/revival/game over (P005) or full device exports (P006).
- It is fine to emit structured `match_completed(color, group_size)` events and show temporary match statistics to make P003 straightforward.
- Keep no new art dependencies and no GUI/mouse automation.
- If gameplay assumptions are needed, pick a configurable conservative default and document in handoff.

## Handoff
Update `.ai/CODEX_HANDOFF.md` with LBS-P002 status, commit, key data structures, test output/commands, exact controls, how to reproduce matching/cascades/cache, and known limitations. Commit and push to tracked `master` normally, then **stop**. Only ChatGPT updates task/decision/ledger; do not self-advance to P003.
