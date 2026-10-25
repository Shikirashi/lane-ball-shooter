# Codex Handoff — LBS-P017 (corrected physical-left interpretation)

**Status:** COMPLETE

**Branch:** `master`

**Implementation commit:** this scoped P017 commit.

**Mailbox:** remains on corrected LBS-P017. `.ai/TASK.md`, `.ai/DECISIONS.md`, `.ai/TASK_LEDGER.md`, and `.ai/PROTOCOL.md` were not edited or advanced.

## Correction and root cause

P016 deleted every ball whose circle cleared LEFT: `_roll_off_left()` removed its member/UID, stored only its color in `cache`, and `_feed_right_edge()` later built a different member/UID beyond RIGHT. A later gap therefore had no original left-hand object for virtual gravity to move. The visually similar color was a respawn on the wrong side, not Zuma-style rollback.

P017 removes that gameplay path. Crossing `x=0` or `x=-radius` has no topology mutation. The same member remains inside its authoritative rigid segment with its original UID, identity, signed position, order and 58 px spacing. Only an actual match or run reset removes it.

## Implementation

- Normal advancement no longer invokes left rollover. Segment anchors and derived ball positions may continue arbitrarily negative.
- The right feeder now admits only NEW weighted-run colors. Match resolution no longer calls `return_cached()`, and continuous gameplay makes that deprecated API a no-op. Its old direct behavior remains only for isolated non-continuous historical fixtures.
- The 24-ball automatic cap now uses `active_population_count()`: balls whose circles have not fully cleared LEFT, including a staged right entrant. Fully hidden left history does not block fresh generation. Right staging remains limited to one ball.
- Existing P015 gravity needs no animation substitute: when a match splits the chain, every segment left of the gap—including negative-X members—becomes unsupported and accelerates RIGHT as one rigid group using the preserved 60/900/420 profile. Contact clamps at exact spacing and only a CAUSAL edge can cascade.
- P012 insertion still translates the entire preceding prefix LEFT by 58 px, including hidden members. Source-supported trains and NEW right entrants still move LEFT at 102 px/s.
- Shot collision now rejects wholly clipped balls on either side. A crossing circle remains targetable once it physically intersects the visible lane.
- The established conveyor render layer filters wholly offscreen members before issuing draw commands; the existing mask supplies progressive clipping at both LEFT and RIGHT. Settling/in-flight/loaded/next visuals retain their existing unmasked ownership.
- F3 replaces P016's retired queue counters with `L` retained-left count, `X` leftmost center, `A` active population, `U/G` unsupported segments/gaps, `V/D` gravity speed/displacement, `F` fresh count and `I` invariant violations.
- Restart discards the whole run, including hidden history. GAME OVER and WAVE CLEARED continue to freeze all chain physics.

## Performance and memory policy

Hidden history is intentionally lossless and can grow for the lifetime of an encounter. Member storage and the compatibility snapshot/validation pass are linear in total retained balls; segment integration/contact remains based on the much smaller segment list, and rendering skips wholly clipped members. No operation introduced by P017 is quadratic in history length. The mandatory three-minute no-shot simulation retained more than 100 hidden balls, continued generating fresh balls, and completed inside the 10-second regression bound.

This is an honest memory trade-off: there is no distance-based pruning because any left segment can become unsupported and return. A future extremely long/endless-mode optimization could use a chunked prefix representation, but the present finite 32-enemy encounter keeps practical history modest.

## Regression coverage

Added `tests/p017_offscreen_left_reentry_test.gd` — PASS (352 checks):

- Tracks a known hidden RED pair through YELLOW insertion, 49/50 ms settlement, gap creation, frame-by-frame rightward gravity and progressive LEFT reappearance. Both original UIDs survive, remain ordered at 58 px, never appear at RIGHT, and never exceed the gravity speed cap.
- Verifies hidden balls cannot be shot or reported by the established render layer, while partially crossing balls become renderable/targetable.
- Retains more than 24 balls offscreen LEFT while NEW fresh generation continues and active/right populations remain capped.
- Runs 90-second and three-minute no-shot histories with fresh generation, unique UIDs, stable spacing, no passive matches and bounded runtime.
- Demonstrates a far-left group begins moving from its actual negative coordinate without teleporting to zero.
- Exercises insertion into a chain with hidden prefix members, two concurrent causal gaps, gravity closure, UID survival and zero overlap.
- Verifies authorized yellow-then-red contact cascades at 30/60/120 Hz and `0.08 s`, always after physical contact.
- Verifies terminal freeze, restart cleanup and the preserved 32-enemy encounter.

Updated P002, P005, P007, P008, P009, P011, P012, P013, P014, P015 and the superseded P016 suite only where old cache/right-respawn or total-live-cap assumptions conflicted with corrected P017. Existing collision, rigid geometry, insertion, staging, cascade, speed, SFX and finite-encounter checks remain.

## Validation

Godot 4.7.2 headless, all passing:

- P001 smoke — PASS.
- P002 gameplay logic — PASS (66 checks).
- P003 progression/magazine — PASS (73 checks).
- P004 lane combat — PASS (42 checks).
- P005 survival — PASS (63 checks).
- P006 platform QA — PASS (69 checks).
- P007 playtest revision — PASS (53 checks).
- P008 gamefeel/SFX — PASS (82 checks).
- P009 Zuma rollback — PASS (46 checks).
- P010 staged cascade — PASS (162 checks).
- P011 segment stress — PASS (16,485 checks; seed `5011CAFE`; 2,400 operations; 1,836 visible insertions; 620 matches; 707 fresh; 57 hidden-left).
- P012 forward insertion — PASS (366 checks).
- P013 shooter preview/mask — PASS (50 checks).
- P014 causal rollback/feed — PASS (289 checks).
- P015 gravity/finite enemies — PASS (523 checks).
- P016 speed/retained-history compatibility — PASS (76 checks).
- P017 offscreen-left reentry — PASS (352 checks).
- `git diff --check` — PASS.

Bounded main-scene startup completed without project/runtime errors at `960x540`, `1280x720`, `1600x720`, and `2400x1080`; each was intentionally terminated after three seconds. The sandbox cannot create/rotate `user://logs/godot.log`, so Godot prints a log-file warning before successful tests/startups. Web/Android exports and physical-device QA remain unverified because their external toolchains were not exercised.

## Manual playtest

1. Enable F3 and follow a recognizable color sequence as it leaves LEFT. `L` should rise while `A` remains bounded; nothing should reappear from RIGHT except newly generated colors.
2. Match a group immediately to the hidden sequence's RIGHT. Confirm the same balls slide back progressively from LEFT as one accelerating group, with no flash, teleport or spacing change.
3. Fire near the left boundary: a wholly hidden ball must not receive the shot, while a partially visible returning circle may be hit.
4. Make rapid matches and insertion during rollback. Confirm insertion still pushes the whole front prefix LEFT, gravity pulls unsupported segments RIGHT, noncausal FEED joins do not pop and F3 remains `I0`.
5. Complete or lose the 32-enemy encounter, confirm chain freeze, then restart and verify `L0` with the original seed.

## Limitations

- Headless tests validate model/render classification, but progressive clipping, apparent motion, touch targeting and audio still require desktop/Web/Android visual playtesting.
- Retained history is lossless and therefore grows linearly with play time until victory, defeat or restart.
