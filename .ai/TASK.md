# ACTIVE TASK: LBS-P009 — Zuma-style chain gap rollback and reconnection

**Status:** READY FOR CODEX
**Branch:** `master`
**Why:** User's desktop playtest (2026-10-25) shows that after clearing a large group, balls to the RIGHT rush left/new balls appear to fill the hole, rather than the surviving balls to the LEFT rolling backward (to the RIGHT) as in Zuma. This is a high-priority gameplay physics correction.
**Code baseline:** P008 implementation `327077e`, user conveyor-speed correction `d1df357`, handoff `eeff275`. The conveyor speed must remain **34 px/s**. Player-fired vertical ball travel remains **0.20 seconds**.
**Read:** `AGENTS.md`, `.ai/PROTOCOL.md`, `.ai/DECISIONS.md`, `.ai/TASK_LEDGER.md`, this file, `.ai/CODEX_HANDOFF.md`.

## Source research / essential principle

Reference Zuma Deluxe's chain-gap / magnetic rollback behavior. When matching balls disappear, an actual spatial gap opens. **The forward/exit-side section** (on our straight track, balls to the **LEFT** of the removed group) should move **backward/right** toward the trailing/right section rather than instantly pulling the trailing/right section left to fill the hole. Original Zuma especially pulls the forward section back when matching colors face one another across the gap, potentially causing a physical reconnection and another clear.

For this user-requested implementation, make ordinary player-triggered clears visibly recoil/retract the left surviving connected section toward the right-side section; **matching boundary colors** may produce a faster/stronger magnetic pull and a delayed cascade. This is Zuma-INSPIRED, not an instruction to copy the other game's exact levels or patented code.

Example in left-to-right (exit to feeder) screen order:

```
BEFORE: [RED RED][BLUE BLUE BLUE][GREEN GREEN][...new balls at RIGHT EDGE]
                (player inserts BLUE, clears blue group)
AFTER CLEAR: [RED RED]         <visible gap>       [GREEN GREEN]   [right-edge feed]
ROLLBACK:         [RED RED]-----> (to the right)    [GREEN GREEN]
LATER:                 [RED RED][GREEN GREEN]       (gap closed physically)
```

If the two exposed boundary ends instead share a color (e.g. RED ... cleared BLUE ... RED RED), reverse/attract the left segment until it actually contacts the right one, then evaluate eligible Zuma-like cascades. **No automatic clearance just because 3–7 same-colored balls spawned together**: only a player-initiated removal followed by its causally linked reconnection can initiate a cascade.

## Confirmed current defects, from `scripts/chain_model.gd`

- `_remove_group(start,count,identity)` computes right-side connected segment and calls `_shift_logical_positions(start,...,-spacing*count)`: shifts RIGHT survivors LEFT into the hole, with no left-section rollback.
- `_close_disconnected_gaps(delta)` moves the **right-hand suffix** left by `RETURN_CATCHUP_SPEED` whenever it sees a gap. This defeats Zuma-like left-section rollback after a clear.
- `_resolve_inserted_match()` attempts cascades immediately after removal, before any visibly moving separated groups reconnect; P008 deliberately permits passive 3+ runs, so this must be isolated to true player-caused reconnections.
- `_feed_right_edge()` adds fresh/FIFO balls from the right as space becomes available. The feeder must remain INFINITE but must **never teleport or logically inject fresh balls inside an interior gap**, nor allow new feed to be mistaken for the correct visual closure.

## Required behavior (authoritative)

### A. Logical chain geometry with separate connected segments
1. Chain order remains ascending screen X from LEFT/front/exit to RIGHT/back/feed. Do not reverse identity order, UID order or cache order.
2. On a successful player-triggered clear of N balls, leave both survivor sections at their existing X positions initially (apart from the actually removed balls); create a spatial gap of approximately N*spacing. **Do not teleport RIGHT survivors LEFT** through it.
3. Apply an animated **backward/recoil displacement to the contiguous surviving section immediately LEFT of the removed group**, with X increasing toward the right. This should visibly move ALL members of that left connected section as a rigid train with their normal spacing and stable UIDs. A configurable rollback/catch-up speed ~250–500 px/s is an initial suggestion, tune for noticeable ~0.25–0.7 second closure on common 3–7 clears.
4. Maintain exact separation until physical joining: don't overlap balls, tunnel over adjacent segments, oscillate around the target, or snap `x` vs `display_x`. The target contact gap is `spacing` (within a small contact epsilon); cap backward travel accordingly. Use logical and rendered coordinates consistently so player hit tests use actual ball positions during rollback.
5. As the left segment recoils right, the other section should continue its normal **34 px/s leftward conveyor progression** (or a documented brief soft pause); it must NOT be forced an extra N*spacing left. Visually, the cleared space closes through motion of existing balls, not through new arrivals.
6. On full clear at far LEFT, there is no left section to recoil: retain ordinary right-side forward movement, with no manufactured reverse actor. On clear at far RIGHT with a left survivor section but no trailing section, allow a bounded brief left-section recoil (toward the vacant right) then resume normal progression; no teleport. If the entire chain is removed, infinite right-edge supply resumes promptly.
7. Rollback/collision must work regardless of different or same colors at exposed ends. **Same-color boundary** can be magnetically accelerated, and upon actual physical reconnection it is eligible for cascade resolution. If ends differ, merge without a cascade. Do not trigger a general passive 3+ scan elsewhere.
8. Multiple independently disconnected groups are possible (from prior matches, FIFO cache re-entry, or feed spacing). Apply the correct dynamics only to the gap *caused by the clear*. Preserve sensible independent **normal forward catch-up** for pre-existing right-edge feeder/recycled-ball gaps; don't globally reverse every segment or attract unrelated gaps with no player-triggered connection.
9. At most one pair should contact per rollback boundary; once merged remove/retire rollback state. Track boundaries robustly by persistent UIDs/segment endpoints or explicit segment topology rather than brittle static array indices that change after shots/rolloff/cascades. Overlapping quick successive shots or cascades should not leave a stale gap motor, duplicate match, reverse another segment or become permanently stuck.

### B. Cascades and deliberate long runs
1. Only `try_insert_shot` accepted physical contact may initiate the first match; a mismatched shot must not cause unrelated nearby 3+/7-color groups to clear.
2. If a player-triggered removal exposes same-colored ends across the gap, let those sections **visibly reconnect first**, then check for a valid physically touching combined group of 3 or more. A qualifying 2+1 RED connection is one cascade event with its true size; record progression and score once per group.
3. Cascades can create more gaps and corresponding rollbacks; repeat predictably until no eligible cascades, with eventual termination; don't auto-clear untouched seeded or continuously fed repeated runs.
4. Preserve existing `match_completed(identity, group_size)` event semantics, scoring formula, 3-second combo timing (cascade counts as distinct event on completion), defender attack/revival, tier-3 clearing and existing match SFX semantics. No duplicate sound for a single match, and the deferred cascade sound occurs only when it actually clears.
5. The P008 weighted run generator allowing 4–7+ same-color balls must remain untouched. A pre-existing seven GREEN train must survive rolling/feeding, but a player-inserted GREEN into it should clear all eight as ONE event.

### C. Infinite spawning, FIFO caching and recycling
1. Preserve continuous generation at the **far RIGHT EDGE only**, original P008 weighted fresh color runs, 24 simultaneous ball cap (or conservative bounded equivalent), FIFO left-exit caching and requested cache return ordering (RED,GREEN,BLUE stays ordered). New balls may appear at the edge as room opens, but must never be spawned at an internal cleared-gap coordinate.
2. When a match clears part of the train, new balls can still enter normally at far right. They must not drive interior gap collapse or supplant the surviving left section's rollback. Document feeder scheduling if briefly blocked during the rollback; don't let the infinite chain run permanently dry.
3. No penalty or game-over from upper chain rollover; no cache loss or reversal; preserve P002 spatial-adjacency collision tolerance and no match across large gaps.
4. Repeated rounds and reset clear all transient rollback/magnetic/contact state and don't leave balls stuck after pause/game over/restart.

### D. Headless validation / acceptance
Create `tests/p009_zuma_rollback_test.gd` and update old tests only where this newly approved physics supersedes assumptions:
- Construct a known ordered chain A (LEFT), 3–7 matching balls middle, B (RIGHT). Fire a genuine contact shot clearing middle. Immediately after clear: A and B retain their prior X positions and a visible gap exists (no sudden rightward-section left shift).
- After small `advance(delta)` steps, **A's X increases (backward to right)**; B never receives special extra left displacement to close the cleared gap; actual left-right separation shrinks smoothly with no overlap. Chain remains sorted throughout.
- Both exposed ends equal color: no premature cascade; after physical contact, qualifying 2+1 match clears exactly once as a causally linked cascade, correct event sequence and score/tier/SFX once each. Different-color ends reconnect with NO auto-clear.
- Short and very wide clears (including 7+) do not teleport or create excessive catchup. Test end clear near left exit, right tail clear, and clear all balls.
- Two quick consecutive shots into different segments, repeated rollback/cascade stages, FIFO cache returning while a gap is closing, and a restart mid-rollback: no stale indexed segments or duplicate match.
- Fresh feeder keeps generating from far-right boundary only; after middle match, no newly generated ball occupies the interior hole or causes the gap closing; FIFO cached RED/GREEN/BLUE order still correct, bounded live population, weighted run distribution unaffected.
- Existing passive long same-color groups do not self-clear without a player-caused causal chain, even when they join normal feeder segments.
- Time subdivisions / 1 large delta should give approximately consistent positions without contact tunneling, even if one call spans final physical reconnection. Verify shot collision against visible `display_x` during retraction.
- Run **all P001–P008 headless suites**, adjusting superseded chain-position assertions rather than deleting unrelated coverage, plus P009 suite, and bounded startup at 960x540, 1280x720 and 1600x720. Ensure procedural audio still builds, combo/fever still works, P005 survivals and P008 0.2s shot remain.
- Report exact commands and pass/fail counts. Run `git diff --check`, no unnecessary binaries/exports.

## Integration and finishing

- Prefer explicit segmented chain / gap state logic rather than patching old suffix-left-shift with cosmetic animation alone. Positions, insertion collision, contact and match criteria must stay logically and visually consistent.
- Keep `ChainModel.DEFAULT_SPEED=34.0` and `ShooterView.SHOT_TRAVEL_TIME=0.20`; enemy average movement **0.24 world units/s**. No unrelated tuning, enemy types, 3D art, audio redesign, platform exports, or other feature work.
- Update README with the new front-segment rollback and player-triggered delayed cascade behavior. Update `.ai/CODEX_HANDOFF.md` with P009 change details, collision/contact ordering, tests, caveats and manual 3–7-ball removal playtest steps.
- Do not modify `.ai/TASK_LEDGER.md` or `.ai/DECISIONS.md`; ChatGPT owns them. Commit and push code, tests, README, handoff to `master`. **STOP**, do not self-advance to P010. On next "check push", ChatGPT will review.
