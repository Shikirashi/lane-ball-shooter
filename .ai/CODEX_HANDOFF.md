# Codex Handoff — LBS-P016

**Status:** COMPLETE

**Branch:** `master`

**Implementation commit:** this scoped P016 commit.

**Mailbox:** remains on LBS-P016. `.ai/TASK.md`, `.ai/DECISIONS.md`, `.ai/TASK_LEDGER.md`, and `.ai/PROTOCOL.md` were not edited or advanced.

## Implementation

- Changed the single canonical `ChainModel.DEFAULT_SPEED` from 34 to **102 px/s**. Source-supported rigid segments, fresh entrants, and recycled entrants all use that same normal speed.
- Preserved the separate movement values: vertical player shots remain 0.20 seconds, cooldown 0.40 seconds, insertion settlement 0.05 seconds, enemy average speed 0.24 units/s, and unsupported-segment gravity remains initial 60 px/s, acceleration 900 px/s², cap 420 px/s.
- Fixed the rollover root cause by making `cache` the canonical eligibility queue. `_roll_off_left()` appends each fully crossed color once, increments `total_exited`, and immediately exposes the full queue through `pending_cache_returns == cache.size()`.
- Ordinary `_feed_right_edge()` calls now drain cached colors without a match. The deterministic policy admits up to three FIFO returns, then one weighted fresh color. This prioritizes recycling while guaranteeing continued fresh generation.
- Preserved the legacy `return_cached()` API as a compatibility prompt. In continuous mode it can immediately admit already-eligible colors when a legal slot exists, but it cannot add quota tokens or schedule the same color twice. Its return value is the number actually admitted during that call. Deterministic fixtures with continuous feed disabled retain direct requested-count admission.
- Recycled and fresh colors use the same single offscreen-right slot, mask, segment admission, 102 px/s motion, and maximum 24 live automatic balls. FIFO colors retain order and get new unique live UIDs.
- Added bounded F3 counters: `Q` queue length, `P` eligible count, `X` total left exits, `A` returns admitted automatically by ordinary simulation, and `F` total fresh generations, alongside P015 gravity diagnostics. The model also retains total recycled admissions for exact reconciliation.
- Restart clears queue, eligibility and all recycle counters. Main's existing terminal guard prevents movement, spawning, exits, and returns after defeat or WAVE CLEARED.

## Scheduling and memory trade-off

The queue is a compact `Array[int]` of color identities and uses front-pop FIFO semantics; it does not scan the queue per frame. With lossless recycling plus a required independent fresh source, an indefinitely full-throughput no-match run introduces one new color for each group of up to three returns. The stored queue can therefore grow over unlimited time. This is intentional and documented: live/offscreen geometry remains bounded, and exited colors are never silently dropped. Matches create additional capacity and let the return-priority policy service the backlog.

## Regression coverage

Added `tests/p016_speed_auto_recycle_test.gd` — PASS (72 checks):

- Exact 102×delta source movement at 120/60/30 Hz and larger deltas; unchanged shot, enemy, and gravity tuning.
- Known RED/GREEN/BLUE sequence exits and automatically re-enters FIFO without any shot, match, or `return_cached()` call.
- Multiple exits in one update, queued returns waiting for a legal slot, repeat compatibility calls, exactly-once bookkeeping, no negative/phantom quota, unique UIDs, and zero overlap.
- A player match while returns are pending cannot double-book them; natural seven-color FEED reconnection closes physically without a passive match.
- Two-minute seeded no-match stream and two-minute frequent-match stream at 60 Hz. Both preserve bounded live/offscreen population, nonzero automatic returns, continuing fresh supply, exact `exited = returned + queued` reconciliation, stable geometry, and eventual gap closure.
- Terminal defeat freezes stream counters and restart restores the 102 px/s seed, empty recycle state, and four one-of-eight enemy lanes.

Updated P007, P008, P009, P013, P014, and P015 assertions only where 102 px/s or automatic eligibility superseded their earlier speed/quota assumptions. P011/P012/P015 invariant, insertion, gravity, and encounter coverage remains active.

## Validation

Godot 4.7.2 headless, all passing:

- P001 smoke — PASS.
- P002 gameplay logic — PASS (61 checks).
- P003 progression/magazine — PASS (73 checks).
- P004 lane combat — PASS (42 checks).
- P005 survival — PASS (63 checks).
- P006 platform QA — PASS (69 checks).
- P007 playtest revision — PASS (49 checks).
- P008 gamefeel/SFX — PASS (82 checks).
- P009 Zuma rollback — PASS (46 checks).
- P010 staged cascade — PASS (162 checks).
- P011 segment stress — PASS (16,485 checks; seed `5011CAFE`; 2,400 operations; 2,460 insertions; 636 matches; 679 fresh; 58 cache activities).
- P012 forward insertion — PASS (364 checks).
- P013 shooter preview/mask — PASS (50 checks).
- P014 causal rollback/feed — PASS (289 checks).
- P015 gravity/finite enemies — PASS (523 checks).
- P016 speed/automatic recycle — PASS (72 checks).
- `git diff --check` — PASS.

Bounded main-scene startup completed without script/runtime errors at `960x540`, `1280x720`, `1600x720`, and `2400x1080`; each was intentionally terminated after three seconds. The sandbox cannot create/rotate `user://logs/godot.log`, so Godot prints a log-file warning before otherwise successful test and startup runs. Web/Android export artifacts and physical-device QA remain unverified because this task did not install or exercise those external toolchains.

## Manual playtest

1. Watch the top conveyor and incoming balls move at the new 102 px/s speed. Confirm vertical shots, enemies, 50 ms settlement and rightward gravity still look unchanged.
2. Do not shoot. Note several colors leaving LEFT, then watch the same color sequence enter fully offscreen RIGHT. In F3, `X` and `A` should rise and `Q` and `P` should agree; the model's total returned plus `Q` equals `X`.
3. Make rapid matches while returns are entering. Confirm the P012 insertion push remains LEFT, unsupported groups fall RIGHT, FEED joins never self-match, and `I` stays zero.
4. Finish or lose the 32-enemy encounter, confirm the stream freezes, then restart and verify the original chain plus zeroed `Q/P/X/R` counters.

## Limitations

- Visual speed, touch behavior and synthesized audio still require desktop/Web/Android playtesting.
- The FIFO queue's deliberate long-run growth follows from combining lossless recycling with perpetual fresh introduction. It stores only integer colors, while live/offscreen balls remain capped.
