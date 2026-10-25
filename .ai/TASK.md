# ACTIVE TASK: LBS-P012 — Forward-direction insertion displacement

**Status:** READY FOR CODEX
**Branch:** master
**Reason:** After playing P011, user confirms the new rigid-segment conveyor is more robust but observes that inserting one ball shoves the balls on its RIGHT toward the RIGHT (backward against conveyor flow). This is incorrect gamefeel. On insertion, the **LEFT/front/exit-side balls must be pushed LEFT**, in the direction of normal conveyor movement. Do not disturb the RIGHT/trailing section for this insertion.
**Baseline:** P011 code `696a1f0`, handoff `2414e57`. Read `AGENTS.md`, `.ai/PROTOCOL.md`, `.ai/DECISIONS.md`, `.ai/TASK_LEDGER.md`, this task and latest handoff. Historical LBS IDs are internal, not branding.

## Authoritative direction rule

The upper conveyor flows RIGHT -> LEFT. Existing balls to the LEFT of an inserted ball are the **front/ahead** section. A newly fired ball inserted between existing neighbors expands chain length by one spacing, by displacing the whole LEFT/front prefix LEFT by one slot (`spacing=58`), **not** by moving the RIGHT/trailing suffix RIGHT. This applies to insertion into the middle of a segment and immediately at a seam or front/tail endpoint.

Concrete example from left to right:
- BEFORE: `[R][R][Y][Y] | [B][B]` moving LEFT
- INSERT GREEN at bar: `[R][R][Y][Y][G][B][B]`
- Expected: front `[R][R][Y][Y]` shifted **one spacing LEFT**, the new `G` occupies the opened slot and the trailing `[B][B]` keeps its original X (apart from ordinary elapsed-time conveyor travel).
- Reject current P011 behavior where inserting shifts all following RIGHT-side segments right by one spacing, visibly reversing the train.
- A front-end insertion adds one ball to the left without moving the existing chain if there is room; a tail-end insertion must make room by pushing the **entire existing left/front train LEFT**, not moving the new right edge farther right. Never teleport through the left exit or cheat the feed boundary.

## Implementation

1. Inspect `ChainModel._insert_into_segment()`. It currently shifts `following` segments' anchors **+spacing** on middle insertion; replace with forward-side expansion by **-spacing**. Crucially, if the insertion splits internal members between prefix/suffix, preserve one physical slot between them and keep stable UID/color order. Authoritative rigid segments may need to be split temporarily or updated with a coherent anchor shift, but do not revert to independent per-ball X as physics authority.
2. For an insertion at segment-local index `k`: preserve the X coordinates of the old members with local index `>= k` (and all balls farther RIGHT). Shift every old member before `k`, including all LEFT neighboring connected segments that need displacement, **-spacing**. Place the inserted ball at the position immediately before old member `k`, or for a tail insertion immediately after old trailing member. Mathematically preserve a one-slot insertion while pinning the RIGHT neighbor/continuation; choose an equivalent coherent segment anchor transformation:
   - For a single uninterrupted segment at index k < N, new anchor = old anchor - spacing, and insert at k, resulting old prefix shifted left while old suffix retains exact original world X.
   - For insertion after last member, add new member at `old_end_x + spacing` while shift entire preexisting connected LEFT chain left by spacing, keeping new member at old right edge location where feasible (i.e. no rightward expansion relative to existing trailing endpoint).
   - At gap boundaries, only displace the physically connected preceding segment(s) as needed; don't collapse a separate rollback gap accidentally, destroy typed FEED/CAUSAL metadata or change its motor target. Maintain legal spacing and no segment crossing after insertion.
3. **No overlap** in either logical or rendered positions; preserve 58px exact internal slot spacing, at least physical diameter at boundaries, ascending IDs, no teleports, consistent shot hit tests, stable segment UIDs, legal feeder admission. For a near-left-boundary prefix pushed offscreen, let normal left-rollover/cache collect it safely in correct order; no penalty. If another rollback is active, coordinate push displacement with its segment/gap constraints and avoid a motor reversal or duplicated collision.
4. Keep insertion visual settle at exactly `0.05s` (P011 scales a real inserted ball from 72% to 100%). The push should be visible and feel forward; use a subtle shared front-group nudge/brief tween if easy, **but never** render overlapping balls or independently displace their visual positions. The new ball remains physically placed and match waits until settle ends.
5. Recheck the larger causal direction distinction: **INSERT** shoves LEFT/front train LEFT in normal flow; **AFTER MATCH CLEAR**, LEFT/front segment may intentionally roll RIGHT through P010 accelerating rollback to join next segment. Do not conflate them.
6. Right-edge perpetual feeder with weighted same-color runs, FIFO cache return sequence, 24 live auto cap, long naturally occurring 3–7+ runs, physically triggered cascades, 34 px/s conveyor, 0.20s shooter projectile, 0.4s cooldown, 0.24 enemy hopping, 60/900/420 rollback profile, combat tiers/revival, seven procedural SFX, full-width aim and compact HUD swap, distinct BLUE/GREEN palette all remain unchanged.
7. Change no unrelated gameplay parameters or visuals.

## Acceptance tests

Add `tests/p012_forward_insert_test.gd` and update old tests asserting the superseded rightward insertion behavior:
- Six-ball example with insertion at a chosen middle seam: old LEFT UIDs move -58, old RIGHT UIDs retain original X (within tolerance), new shot UID inserts at correct position/order; no ball is pushed RIGHT.
- Insert into interior at k=1, k=middle, just before last, k=0, and k=N; verify both segment and cross-segment cases, including typed FEED and active CAUSAL gaps.
- Two accepted shots within same 50ms settle, and a shot during accelerating rollback/cascade: no overlap or UID reorder, no double match or deadlock.
- Assert segment-authoritative invariants after EACH microstep: exact within-segment 58px, >=44px cross-neighbor physical clearance, logical/rendered positions identical or consistently derived, strictly increasing ball centers, no invariant violations. Capture before/after positions by UID to prove direction, not merely assert total ball count.
- FIFO exit order and returns preserved when pushing left near viewport boundary; no ghost offscreen balls.
- Delayed RED-RED / YELLOW-YELLOW / RED-RED cascade: at insertion pop after 0.05s, LEFT reds roll RIGHT on a causal match-created gap, and then physically reconnect before red size-4 cascade; this is the only justified reversal.
- Check full-width extreme shots/swaps at all four landscape resolutions, and preservation of headless P001–P011 behavior. Run all previous suites and new P012 suite, bounded starts 960x540/1280x720/1600x720/2400x1080 and `git diff --check`.
- Report actual test counts and any compatibility assertion updated because it expected trailing-right movement.

## Done

Update README and `.ai/CODEX_HANDOFF.md` with the changed insertion policy, edge handling, tests/commands and manual examples. Commit and push to master. **STOP**. Do not self-advance P013, do not edit `.ai/TASK_LEDGER.md` or `.ai/DECISIONS.md`. ChatGPT reviews next "check push".
