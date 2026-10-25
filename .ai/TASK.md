# ACTIVE TASK: LBS-P016 — Triple conveyor speed and reliable automatic FIFO recirculation

**Status:** READY FOR CODEX
**Branch:** `master`
**User playtest decision (2026-10-25):** P015 virtual-gravity motion feels great. Increase the NORMAL TOP conveyor flow speed from 34 to **102 pixels/second (3×)**. User also observed balls leaving the LEFT edge simply disappear and do not reappear. Restore truly automatic left-to-right FIFO recycling without dependence on another match.
**Baseline:** P015 implementation `3d2623e` and source-reviewed mailbox state. Read `AGENTS.md`, `.ai/PROTOCOL.md`, `.ai/DECISIONS.md`, `.ai/TASK_LEDGER.md`, this task, latest `.ai/CODEX_HANDOFF.md`. Historical `LBS` is only an internal identifier, not branding.

## Root cause already identified

In `scripts/chain_model.gd`:
- `_roll_off_left()` correctly appends exited colors to `cache`.
- `_feed_right_edge()` admits cached balls only while `pending_cache_returns > 0`; otherwise it generates a fresh color.
- `pending_cache_returns` is ordinarily populated by `return_cached()` called following a **successful match**. Thus a player can watch many balls exit left without EVER seeing them automatically return, even though the cache fills. With conveyor movement tripled, this deficiency will be much more visible.
- Fix the scheduling architecture, not merely the display or cache counter.

## A. Top conveyor 102 px/s

- Change `ChainModel.DEFAULT_SPEED` from `34.0` to **`102.0`**, with one canonical configurable speed source. All SOURCE-SUPPORTED connected ball segments move LEFT at that rate. Fresh and FIFO returned balls emerge from fully offscreen RIGHT and advance at the same 102 px/s, no speed jumps once their circles are visible.
- Keep unsupported groups under P015 virtual RIGHTWARD gravity (initial right speed 60, accel 900, cap 420 px/s, independent of conveyor speed) and physically merge at correct spacing. If source motion changes relative contact timing, respect existing deterministic contact/non-overlap solver; do not let source balls push overlapping geometry or defeat gravity. No permanent unsupported gaps.
- Don't change 0.20-second VERTICAL fired-shot travel, 0.40-second shot cooldown, 0.05-second shot-insertion settle, 58 px spacing/22 px ball radius, P012 LEFT push insertion, P013 conveyor-only clipping/unmasked shot visuals, fixed 8 enemies/lane (32 total), enemy hop speed 0.24, score/combo/fever, defeat/victory, SFX.
- Update EVERY headless assumption and documentation that expects **34 px/s normal conveyor movement** (P001–P015 tests, README), retaining all meaningful assertions for exact source advance, gravity support, feeder entry and events. Never casually delete regression coverage.

## B. Self-sustaining FIFO recirculation on left rollover

**Gameplay contract:** Balls exiting the LEFT edge are never permanently lost or penalized. Their COLORS retain left-exit FIFO order and they become automatically eligible for offscreen-RIGHT admission, even if the player doesn't make another match. The user should actually see exited colors reappear in order as feeder slots become available. This is a loop, not a match-only bonus mechanism.

- `_roll_off_left()`: on each successful exit, append the color exactly ONCE to FIFO cache, and schedule automatic return **exactly once** (either by setting/updating the pending return count correctly or by simplifying to one canonical eligible FIFO queue without fragile quota duplication). An ordinary `advance(delta)` should eventually drain cached items into the right feeder as physical room becomes available, independent of player actions.
- Do not require a successful match, fever, or chain-total exhaustion to request cache returns. Handle multiple exits within one large delta, simultaneous matches, pending previously scheduled returns, and game-over/restart without duplicates, missed entries, negative return quotas, or stale waiting counters.
- Preserve `return_cached(requested_count)` API or provide a compatibility adapter if P002–P015 tests use it. **Match-triggered `return_cached` must not schedule the same already-auto-eligible colors twice**; avoid phantom return tokens or inflating quotas. If match effects previously added additional returned balls, clarify in README that an existing eligible item may be prioritized but never duplicated. Return values and counters should have truthful semantics.
- Integrate automatic cached returns and fresh generation through the SAME one-slot-at-a-time offscreen-right feeder, with physical separation >=58 px center-to-center when connected and at least 44px in all cases. Prevent offscreen backlog of live balls. Keep current max 24 automatically live balls unless there is a compelling reason to change.
- The upper ball supply remains infinite: continue adding **new** balls as needed and retain weighted same-color fresh run generator. Do not replace infinite balls with a fixed queue, and do not make cache returns the only possible admission permanently. Define and document an explicit deterministic/fair scheduling policy for interleaving fresh and cached admissions. **Prioritize actually returning existing exited colors** over endlessly generating fresh ones. There is an inherent capacity trade-off: with both ongoing unlimited fresh introductions and lossless recycling under continuous full throughput, the stored cache might grow; if so, keep colors compactly, avoid scanning the whole cache each frame, expose queue length/counters, and document the growth rather than silently deleting balls. When matches remove balls, use freed feeder opportunities to service the backlog and admit fresh as appropriate.
- Recycled colors should be unchanged and FIFO, e.g. exits RED, GREEN, BLUE must reappear RED, GREEN, BLUE in that order (fresh colors may be interleaved but can't reorder cached colors). Assigning a new live UID to a returned color is acceptable and must remain unique.
- If a group at the LEFT edge is moving RIGHT due to virtual gravity, do NOT cache it until it really crosses LEFT completely; support ordinary exit velocity/geometry, not identity position guessing. Balls outside the RIGHT edge are not prematurely treated as left exits.
- Keep P015's distinction: a newly admitted cached or fresh segment can fall RIGHT under virtual gravity if physically unsupported, but **only a player-causal reconnection may match**. Ordinary return/FEED joins never self-clear 3+/7+ runs.
- Add bounded F3 diagnostics: cache queue length, total exited, total automatically returned, pending-eligible return count (if relevant), total fresh generated. No per-frame spam. Test that all counts reconcile across a long no-match run, plus restart reset.
- An empty visible lane must resume smoothly without pausing forever awaiting a match; unlimited player ammunition/defender fight still possible until terminal win/loss.

## C. Required regression tests

Add `tests/p016_speed_auto_recycle_test.gd` and rerun P001–P015:
1. Assert source default speed is 102.0 and connected train translates LEFT by exactly 102*delta at different deltas (accounting for legitimate gravity/contacts), including 30/60/120 Hz.
2. With continuous feeder ON and **zero player matches**, make a known initial LEFT exit sequence RED, GREEN, BLUE. Verify each is cached and automatically gets re-admitted from beyond RIGHT edge in FIFO order, within a reasonable bounded simulated time; no additional `return_cached()` call is permitted in this test. Verify colors preserve identity and counters reconcile.
3. Multiple exits within a single 0.1–1s step, several outgoing balls while recent return awaits a legal slot, and mixed fresh-return admissions: exactly-once automatic scheduling, correct FIFO, no duplicates, no phantom/negative quotas. Explicitly reproduce the pre-P016 behavior (cache grows but total returned stays zero without a match) as a failing old-version fixture where feasible.
4. A successful match while auto-returns are pending must not double-book cached items through `return_cached()` or block fresh indefinitely; verify seven+ naturally same-color runs remain untouched without player-causal matching.
5. Quick successive 50ms insertion/matches, two simultaneous player-created gaps, virtual gravity closing all unsupported groups, FIFO return entering from far right: rigid no-overlap, valid stable UIDs, no permanent gaps, correct cascades and score/tier/SFX order.
6. Long seeded runs (>=2–5 min simulated with no matches, and with frequent matches) at 102 px/s: finite live/offscreen count, nonzero returned count, continued fresh supply per documented scheduler, FIFO order preserved, reasonable runtime/no O(run-length) scans, cache memory policy documented.
7. Repeated game-over, WAVE CLEARED and restart restore original stream, auto queue, counters and feeder; no spawned balls after terminal state. Preserve 32-enemy quota and victory/defeat logic from P015.
8. Rerun P001–P015 full Godot headless suites and P016, explicitly update old 34 px/s assertions where superseded. Ensure no weakened checks for P011 segment invariants, P012 front LEFT push, P013 offscreen masked entry, P015 support-based gravity or finite encounter. Headless bounded game startup at 960x540/1280x720/1600x720/2400x1080, `git diff --check`; note absence of Web/Android export templates/SDK where applicable.

## Manual acceptance
- Normal conveyor looks 3× faster; only upper horizontal speed changes.
- Watch several colored balls leave LEFT. Without shooting or triggering matches, after some circulation time those SAME COLOR IDENTITIES reappear naturally from fully offscreen RIGHT. Use F3 to confirm **automatic return counter grows without matches**.
- Try matching quickly; no visual ball overlap, no right-edge pop-in, no new permanent gaps or bizarre feeder speed changes.
- Finish the finite enemy encounter to confirm 32 total spawns and WAVE CLEARED still work.

## Finish
Update `README.md` with new speed and automatic recirculation scheduling, plus diagnostics and any honest memory trade-offs. Update `.ai/CODEX_HANDOFF.md` with exact root cause, behavior, tests/commands, limitations and manual playtest. **Commit and push master, then STOP.** Do not edit ChatGPT-owned `.ai/TASK.md`, `.ai/TASK_LEDGER.md`, `.ai/DECISIONS.md` or `.ai/PROTOCOL.md`. Do not self-activate P017.
