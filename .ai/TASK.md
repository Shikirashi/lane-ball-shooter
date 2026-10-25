# ACTIVE TASK: LBS-P007 — First playtest revision: faster infinite conveyor, combat tiers, actual hopping locomotion

**State:** READY FOR CODEX
**Branch:** `master`
**Priority:** User-observed gameplay problems from first desktop playtest (2026-10-25). This task supersedes conflicting earlier P002/P004 tuning and tier mapping only.
**Read first:** `AGENTS.md`, `.ai/PROTOCOL.md`, `.ai/DECISIONS.md`, `.ai/TASK_LEDGER.md`, this task, and `.ai/CODEX_HANDOFF.md`.
**Implementation:** One coordinated revision; modify code and tests, commit/push, stop. Do NOT self-advance to P008.

## User feedback (verbatim meaning)
1. Top ball chain speed must be **twice as fast**.
2. Basic enemy dies to **two normal (tier-1) projectile hits**; **one tier-2 projectile hit** must kill one basic enemy. Change tier 3 to **kill every enemy on the matched lane AND every enemy on one randomly chosen adjacent lane (above OR below; edge lanes only have one neighbor)**.
3. Top chain must be **continuously replenished forever**, rather than only ~12–15 initial balls and sporadic recycle/reseeding. User should not run out of matchable balls while playing.
4. Enemies should actually **travel by hopping**; on the ground their logical X must be stationary. Existing constant leftward X movement plus cosmetic vertical bounce is wrong.

### Interpretations fixed for this implementation
- Four combat rows are lane indices 0,1,2,3 in current `Battlefield.lanes` order. Neighbor sets: 0->[1], 1->[0,2], 2->[1,3], 3->[2]. Each tier-3 activation chooses exactly ONE valid neighbor (not a second random nonadjacent row).
- Tier 1: one ordinary 3D projectile, **1 HP damage**. Standard enemy stays at **2 HP** by default.
- Tier 2: preserve the short **two-projectile burst** but make **EACH projectile deal 2 HP damage** (thus *one hit* of a tier-2 projectile kills a fresh 2-HP enemy; the next projectile may kill another). Shots remain first-target, swept collision, and same lane.
- Tier 3 (including fourth-match FEVER): **replaces** the previous 3-projectile burst with an immediate, lane-wide lethal clear of **all living enemies** in (a) the origin/matched-color lane and (b) exactly one randomly selected adjacent lane. This is NOT the one-time defender emergency discharge, and must not spend or replenish either lane's emergency charge, knock defenders down, revive them or award extra match score. Show a legible lightweight primitive clear wave/flash across both 3D lanes. One successful origin-color match produces one attack event with metadata for both targeted lanes. No normal 3-projectile burst is required for tier 3.
- A match belonging to a **DOWN** origin defender still contributes one revival point instead of launching any tier attack, including tier 3; it must NOT clear either lane. However a tier-3 attack from a different ACTIVE origin may clear enemies on a DOWN neighbor lane without changing its defender state.
- Existing combo, score, 3-second timing, fourth-match FEVER visual, ball symbol/colors, 2D shooter inputs, and game-over/emergency/revival are otherwise preserved.

## P007-A — Ball speed exactly 2x
- In `scripts/chain_model.gd`, change `DEFAULT_SPEED` **34.0 -> 68.0 pixels/second**. No arbitrary multiplier on delta or hidden duplicate acceleration.
- Verify frame-rate-independent progress at 0.016/0.1/1.0-second test increments, excluding deliberate gap closure/spawn.
- Keep shot contact against moving **display** X, no long-distance insertion. Keep `RETURN_CATCHUP_SPEED` a separate tunable unless needed for stable doubled-speed recycling.

## P007-B — Truly continuous/infinite right-edge ball supply
- Inspect the current initial 12-ball `seed_stream()`, `advance()`, `_ensure_playable_stream()`, `return_cached()`, `_append_on_right()`, and `max_auto_population` cap; the current supply is finite/recycled rather than a perpetual stream.
- Implement a **continuous right-edge feeder** that supplies *newly generated ball identities over the entire run*, as room opens at the right boundary. Never make gameplay depend on clearing the board completely or first scoring a match. Introduce clear tunable pacing/spacing and choose an independent 4-color shuffle-bag or similarly fair repeating generator (not the player's separate magazine bag). Generate unboundedly over time while **limiting simultaneous live/visible/offscreen-right balls** and preventing automatic spawn overlaps.
- Once the rightmost live ball has advanced left far enough for another ball at normal spacing, admit one from the right. When the chain was completely cleared, start another feed promptly; don't strand an empty playfield awaiting a match. Ball IDs stable, no periodic visual teleports or huge time-dependent offscreen-right buildup.
- **Preserve the previously promised FIFO rollover cache**: balls leaving left cause no penalty and are cached in exit order; successful matches request their normal cached returns at right, with the exact RED/GREEN/BLUE order preserved. Integrate cached returns into the right feeder using a pending-return quota if physical space isn't yet free; don't append a long offscreen-right backlog. Make sure cache returns do not suppress **all** fresh-ball generation indefinitely; fresh generation should keep occurring during a long survival run. Prefer a documented deterministic scheduling policy balancing return requests vs fresh stream.
- Matching must require *physical* adjacency; a distant recycled group and a fresh group must not form an instantaneous match across a spatial gap. Preserve correct insertion, cascades, collision and spacing. Don't silently drop cached balls to enforce a cap.
- Conservation/memory: avoid explosive/infinite *on-screen* growth, unbounded offscreen-right nodes and per-frame O(run duration) work. Cache can contain legitimately exited balls not yet returned; if it grows over long sessions, store compactly or document its **linear** behavior rather than silently deleting cache data. Distinguish finite **simultaneous population** from **infinite total number generated over lifetime**.
- Reset feeder/shuffle bag/pending quota/FIFO state on RESTART. Preserve no-loss left rollover.

## P007-C — Combat tiers and adjacent-lane wipe
- Update `LaneCombatModel`, `Battlefield` and `LaneActor` as appropriate. Keep HP=2 default, normal damage=1, tier-2 projectile damage=2 *locked per projectile at creation*. No later mutable tier changes can affect midflight damage.
- For tier 3, perform origin+adjacent wipe through a single central `Battlefield` decision, so it knows lane order and can select a **seeded/injectable RNG** for deterministic tests while still varying neighbors in real play. Edge lane 0 or 3 must never attempt an out-of-range neighbor; inner lanes must be able to select either valid neighbor across seeded trials. On restart, reset RNG appropriately.
- The wipe kills **all current living enemies on those two lanes only**, uses existing kill/removal/visual syncing rather than leaving ghost nodes, and emits appropriate distinct effects for both lanes. Must not wipe future spawns; no global freeze, collateral shots, double-counting, or manual emergency-charge side effects. Enemies at or beyond a terminal breach must not be able to evade game-over by retroactive wipe. When target lane is empty, it's a safe no-op plus optional VFX.
- Tier 1 still requires 2 hits against a default 2-HP enemy; tier 2 one hit kills, its second fired projectile can hit a *different* enemy. Tier 3 must work without projectile contact/range and must not create three conventional projectiles.
- Preserve normal score/combo advancement for each distinct matching group, independent of number of enemy kills; while origin DOWN, revival takes precedence over all attacks and leaves both enemy lists intact.
- Attack history/test interfaces should record tier, origin lane, chosen adjacent lane and number killed (actual), using existing bounded history rules. Support debugging without printing every kill/frame.

## P007-D — Hopping is the **only** translation
- Refactor `LaneCombatModel` enemy state and `LaneActor` visuals so enemy X moves **left only while airborne**, using a real hop cycle with an explicit **grounded dwell/rest phase** (not just a sinusoidal bounce with constant speed). While grounded/landing rest, logical X **must remain identical** across update steps; hopping has a forward displacement that completes by landing.
- Each enemy can have a per-enemy staggered hop offset but must preserve a clear rest interval, lift-off, forward travel in air, landing, repeat. `LaneActor` vertical hop/squash/shadow must read the SAME movement phase from the logical model: shadow remains on ground and X tracks enemy; no phase mismatch.
- Preserve roughly the previous average **enemy** approach pace (0.48 world units/second) unless small tuning for playability is justified and documented. Do not accidentally double enemy speed just because the **ball chain** doubled.
- Combat collisions must use the enemy's **actual discontinuously varying horizontal velocity/positions** rather than P004's assumption of constant `enemy_speed` in `_first_swept_hit()`. Use a deterministic swept/piecewise step/analytic solution that cannot tunnel through enemies on large delta or while hopping, and does not make grounded enemies invulnerable.
- Defender touch/one-time discharge/breach ordering must remain correct when a hop passes both thresholds in one update: first contact + available emergency resolves before a new breach; once charge spent, a later living breach ends run. No X creep while grounded; no crossing a boundary by a ground animation only.
- Restart resets hop phase, actor visuals, enemies/projectiles and pending effects consistently. Consider clamping large gameplay steps or splitting at hop phase boundaries to keep frame-rate independence.

## Acceptance tests (required; create `tests/p007_playtest_revision_test.gd`)
1. Confirm default conveyor speed is 68.0 and movement over known time deltas doubles prior default; new right-edge feed supplies >100 new ball identities over a sufficiently long simulated run without player matches. The visible playable train doesn't become permanently empty/stuck (allow brief entry transit only); live/offscreen-right population remains bounded.
2. After matching repeatedly, fresh feeder continues; FIFO cached return order (RED, GREEN, BLUE) persists with partial batches, and pending returns drain as right-edge slots open. Distant same-color groups cannot match until they reconnect. Unbounded-by-design *lifetime generation* does not imply runaway live population.
3. A previously valid tier-1 shot reduces default 2HP enemy to 1 HP; a second kills; one tier-2 projectile kills default 2HP enemy, and a 2-shot burst can kill two spaced enemies. Projectiles locked to tiers and normal swept hits remain valid.
4. Tier-3 origin lane 0 clears lanes 0&1; lane 3 clears lanes 3&2. Lanes 1 and 2 can EACH choose either physically neighboring lane (deterministic RNG injection/seed). A third uninvolved lane retains its enemies. Empty lanes safe; future spawns unaffected.
5. A tier-3 match with origin defender DOWN gives one revival progress only and clears no lanes, including on the second revival match. After revival, active tier-3 clears work. Origin+neighbor wipes do not consume emergency charges, alter defender states, or award extra score.
6. Enemy logical X has zero change in the ground-dwell portion, decreases during midair portion, and moves about 0.48 world units/s **on average** across complete hop cycles. Frame subdivision (many small vs one larger delta) yields approximately the same positions, including multi-cycle advance.
7. Enemy visual vertical height is zero at grounded/landing periods and positive during airborne phase; projectiles still hit both airborne and stationary grounded targets even for a large delta. Knockdown/discharge/breach remain correct with hop jumps crossing thresholds.
8. Run every existing P001–P006 headless suite; update old P004/P005 tests **only where user-approved tier-3 behavior and hop speed assumption supersedes expectations**. Never delete unrelated assertions to make tests green. Run bounded game startup at 1280x720 and wide 1600x720.
9. Manual playtest: visibly never run out of incoming ball groups over minutes; conveyor is 2x speed; tier 1 two hits to kill, tier 2 one-hit kills, tier 3 matching lane + randomly chosen adjacent lane visibly clears; enemies stand still while feet touch ground, then jump forward, then pause.

## Implementation notes
- Keep GDScript, Godot 4.7.2, Compatibility/Web+Android landscape, all procedural primitives; no GUI/mouse automation, new art assets, external libraries or unrelated feature work.
- Keep all state authoritative in models; view reads state. Prefer small testable methods and tunable constants.
- Existing P001–P006 tests may legitimately require revised assertions for user-approved tier rules. Document each intentional change in the handoff and do not weaken key coverage for shot contact, FIFO order, score, revival, emergency charge, loss or restart.
- Document in README the new ball stream, new tier attack meanings and hop movement; remove old misleading 'tier 3 = 3 projectiles' explanations.
- Update `.ai/CODEX_HANDOFF.md` with status COMPLETE/PARTIAL/BLOCKED, commit, exact tests/commands and failures, gameplay tuning, performance/memory notes, any unresolved edge cases and manual playtest steps.
- Commit/push changes normally to tracked `master`, then **STOP**. Do not rewrite task/decision/ledger files or self-advance beyond P007. ChatGPT will review a later "check push".
