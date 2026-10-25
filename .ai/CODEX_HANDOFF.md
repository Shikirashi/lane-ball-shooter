# Codex Handoff — LBS-P009

**Status:** COMPLETE

**Branch:** `master`

**Implementation commit:** `d5cd73b` (`Implement P009 Zuma-style chain rollback`)

**Mailbox:** remains on LBS-P009; task/ledger/decision/protocol files were not changed.

## Implemented

- Replaced synchronous right-suffix left shifting with explicit UID-anchored causal rollback states. Removing a player-matched group now leaves both survivor sections at their current logical/rendered positions and preserves the full spatial hole.
- Every ball continues normal 34 px/s leftward conveyor travel. Only the contiguous LEFT/front/exit-side section receives additional rightward rollback: 360 px/s for different exposed colors and 480 px/s magnetic rollback for matching ends. Logical and `display_x` positions move together, remain sorted and stop at exact normal spacing without overlap.
- The trailing/right section is never moved an extra amount to fill a player-cleared gap. Independent feeder/FIFO gaps retain their existing 120 px/s right-suffix catch-up, explicitly skipping causal rollback boundaries.
- Same-color boundary cascades are deferred until physical contact. On contact, only the causally joined group is evaluated; each qualifying group emits one existing `match_completed` event with true size, then creates its next UID-anchored rollback. Different colors merge without a scan. Passive P008 3–7+ runs remain untouched.
- Multiple simultaneous rollback states are supported. Stable endpoint UIDs survive index changes; insertions at retracting endpoints transfer the boundary to the inserted ball; removed/rolled-off endpoints prune stale state. Advance uses bounded 1/60 s substeps so large deltas cannot tunnel through contact and approximate subdivided updates.
- Left-edge clears create no reverse actor. Full clears promptly resume the infinite source. Right-tail clears use a bounded 1.25-spacing recoil, then return to ordinary conveyor motion.
- Reset/test-state setup clears motors, IDs and counters. F3 diagnostics now show active rollback count.
- Preserved weighted fresh runs, 24-live-ball cap, far-right feed behavior, FIFO return order, 34 px/s conveyor, 0.20 s player-shot travel, 0.24 enemy average hop pace, combat tiers, survival, input and procedural SFX.
- Updated P002/P003 only for the approved delayed physical-cascade timing. Added `tests/p009_zuma_rollback_test.gd` with 58 final checks and updated README/manual QA.

## Collision/contact ordering

1. Each bounded step advances every ball left at normal conveyor speed.
2. Noncausal feed/cache gaps perform ordinary trailing catch-up, excluding active causal boundaries.
3. Each causal motor moves its current contiguous left section right, capped at exactly one spacing from its right endpoint.
4. On contact the motor retires; matching ends resolve one boundary group and may create the next motor. Different ends simply become connected.
5. Display interpolation then settles any insertion-only offset; rollback itself updates logical/rendered X together. Rollover/cache and far-right feed run afterward.

This ordering prevents new right-edge balls from occupying an internal clear hole or causing its cascade, while allowing normal FIFO/fresh scheduling to continue behind the trailing section.

## Validation

Engine: `Godot 4.7.2.stable.official.ed1daf0bf`.

- `godot --headless --path . --script res://tests/headless_smoke.gd` — P001 PASS.
- `godot --headless --path . --script res://tests/p002_logic_test.gd` — P002 PASS (61 checks).
- `godot --headless --path . --script res://tests/p003_logic_test.gd` — P003 PASS (73 checks).
- `godot --headless --path . --script res://tests/p004_combat_test.gd` — P004 PASS (42 checks).
- `godot --headless --path . --script res://tests/p005_survival_test.gd` — P005 PASS (63 checks).
- `godot --headless --path . --script res://tests/p006_platform_qa_test.gd` — P006 PASS (66 checks).
- `godot --headless --path . --script res://tests/p007_playtest_revision_test.gd` — P007 PASS (49 checks).
- `godot --headless --path . --script res://tests/p008_gamefeel_sfx_test.gd` — P008 PASS (82 checks).
- `godot --headless --path . --script res://tests/p009_zuma_rollback_test.gd` — P009 PASS (58 checks).
- `godot --headless --path . --resolution 960x540 --quit-after 5` — exit 0.
- `godot --headless --path . --resolution 1280x720 --quit-after 5` — exit 0.
- `godot --headless --path . --resolution 1600x720 --quit-after 5` — exit 0.
- `git diff --check`, exported-binary scan, external-URL scan and credential-pattern scan — PASS.

Every Godot invocation printed the known non-fatal sandbox diagnostic because `user://logs` is not writable. All suites and startups returned exit 0 with no script/runtime failures. No platform exports or physical-device test was attempted; P006's templates/complete Android SDK remain unavailable.

## Manual playtest

1. Clear a 3–7-ball group in the middle. Immediately verify the right survivors stay put apart from normal conveyor motion, the hole remains visible, and the existing LEFT/front section rolls RIGHT smoothly into it.
2. Repeat with different exposed colors: they should meet and stop at normal spacing without another clear. Repeat with matching exposed ends: they must visibly meet first, then emit one cascade/SFX/attack event.
3. Build a two-stage pattern such as RED RED / GREEN GREEN / BLUE BLUE / GREEN / RED, insert BLUE, and observe delayed BLUE → GREEN → RED events without snapping.
4. Fire a second shot while rollback is active and try two quick clears in different sections. Confirm shot contact follows the visible retracting ball, order stays stable and neither gap becomes stuck.
5. Test a seven-ball middle clear, left-edge clear, right-tail clear and full clear. The wide gap should animate, left-edge/full clears should invent no rollback actor, tail recoil should be brief/bounded, and fresh feed should resume from the right.
6. Let cached RED,GREEN,BLUE return while rollback is active. Confirm FIFO order, no fresh/cache ball appears inside the clear hole, passive long runs remain, and F3 rollback count returns to zero.
7. Recheck match/insert/attack SFX, score/combo/FEVER, tier attacks, revival, emergency, breach and restart cleanup.

## Notes / limitations

- Rollback speeds (360/480 px/s), 1.25-spacing tail recoil and 1/60 s maximum simulation step are initial tunables selected for visible, deterministic closure.
- A quick insertion directly at an active exposed endpoint joins that endpoint's section and transfers the motor anchor to the new stable UID. More exotic simultaneous shots that delete a motor endpoint safely retire the stale motor rather than guessing a new unrelated boundary.
- Cache remains intentionally linear for legitimate unreturned exits; rollback state is bounded by current causal gaps and stores only endpoint UIDs plus tail distance.
- Pre-existing local editor-generated changes in `project.godot`, `scenes/main.tscn`, and generated `.uid` files were preserved and intentionally excluded.
