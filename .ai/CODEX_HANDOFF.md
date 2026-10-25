# Codex Handoff — LBS-P013

**Status:** COMPLETE

**Branch:** `master`

**Implementation commit:** `11816ab` (`Implement P013 shooter preview and conveyor masking`)

**Mailbox:** remains on LBS-P013; task, ledger, decision and protocol files were not changed.

## Implemented

- Moved the real `MagazineState.next_identity` onto `ShooterView` as a 9 px symbol-bearing ball directly below the existing 19 px loaded ball. Both centers follow shooter X and remain inside the landscape safe area at both track extremes. Fire and swap update both identities through one `set_ammunition` call.
- Replaced the old loaded/next magazine panel with a single circular two-arrow swap button. Its logical and hit target is 56×56, it remains in the upper-right safe HUD outside `playfield_rect`, and existing Space/right-click/touch ownership, cooldown, game-over and one-SFX behavior are unchanged.
- Added authoritative offscreen entry at `lane_width + radius + ENTRY_MARGIN` (`ENTRY_MARGIN = 4`). Fresh and FIFO-returned balls therefore begin with their entire 22 px circle beyond the right boundary.
- Added an event deadline for the next legal feed slot. Normal continuous entrants attach at exact segment spacing and move left at 34 px/s, producing the same physical position at 30/60/120 fps and with a single large delta. Admission remains capped at 24 live automatic balls and cannot create an unbounded invisible tail.
- FIFO return batches use the same offscreen staging point and retain exact color order. A separated typed FEED segment moves at normal speed until its first member is fully visible; only then may the existing feed catch-up motor close its physical gap.
- Split chain drawing into three explicit layers: the panel/background; an exact `lane_rect` clipping parent containing established conveyor artwork; and an unclipped sibling overlay that draws only pending inserted UIDs. Loaded/next/in-flight balls remain in the independent unmasked shooter view.
- The inserted ball is excluded from established drawing for 49 ms, then atomically transfers to the clipped layer when its model settlement retires at 50 ms. Both render classifications use the same authoritative UID, identity and segment-derived position. Game over hides the pending overlay and restart clears pending UIDs before restoring it.
- Updated superseded P001/P002/P011 assertions for shooter-owned ammo, delayed offscreen return entry and the circular 56×56 control. P012 insertion direction, segment invariants, FIFO, staged cascades, balance and procedural SFX were not changed.
- Updated README with the new ammunition UI, offscreen geometry, mask ownership, regression command and manual checks.

## P013 regression coverage

Added `tests/p013_shooter_preview_mask_test.gd` — PASS (50 checks):

- Shooter loaded/next alignment and safe-area containment at both track edges for 960×540, 1280×720, 1600×720 and 2400×1080, including inset safe rectangles.
- Actual magazine identity synchronization after swap and fire; 56×56 control and non-overlapping playfield geometry.
- Fresh entry starts fully beyond the right edge, moves at exactly 34 px/s, remains invisible until circle-edge crossing, then partially intersects rather than popping in.
- Identical entry positions at 30/60/120 fps and one 0.5-second update.
- FIFO RED/GREEN/BLUE offscreen admission, typed FEED topology, normal-speed initial transit and invariant checks.
- One simulated minute of continuous feed remains bounded, replenishing and overlap-free.
- Dedicated mask hierarchy and exact conveyor window bounds.
- Exclusive unmasked ownership at insertion time and 49 ms, exclusive clipped ownership at 50 ms, plus game-over hiding and restart cleanup.

## Validation

Engine: `Godot 4.7.2.stable.official.ed1daf0bf`.

- P001 headless smoke — PASS.
- P002 gameplay logic — PASS (61 checks).
- P003 progression/magazine — PASS (73 checks).
- P004 lane combat — PASS (42 checks).
- P005 survival — PASS (63 checks).
- P006 platform/input QA — PASS (69 checks).
- P007 playtest revision — PASS (49 checks).
- P008 gamefeel/SFX — PASS (82 checks).
- P009 rollback — PASS (46 checks).
- P010 staged cascade — PASS (190 checks).
- P011 segment stress — PASS (16,258 checks; seed `0x5011CAFE`, 2,400 operations, 2,460 insertions, 636 matches, 670 fresh, 6 cache activity).
- P012 forward insertion — PASS (377 checks).
- P013 shooter preview/mask — PASS (50 checks).
- Bounded startup at 960×540, 1280×720, 1600×720 and 2400×1080 — all exit 0.
- `git diff --check`, external-binary scan and credential-pattern scan — PASS.

Every Godot invocation printed the known non-fatal sandbox diagnostic because `user://logs` is not writable; all suites and startups returned exit 0. No Web/Android export or physical-device playtest was attempted.

## Manual QA

1. Move the shooter to both extremes at each supported landscape size. Confirm the small NEXT ball stays below the loaded ball and both swap instantly after the HUD button, Space or right click.
2. Tap the circular control: it should swap once, play one swap sound and never shoot. Drag/release directly below it and at both playfield edges; firing should remain full width and occur exactly once.
3. Watch the right boundary after a slot opens. A new circle should reveal progressively from nothing at 34 px/s rather than appearing whole. Returned cache colors should use the same entrance and order.
4. Insert near every conveyor boundary. The shot should remain visible during the 50 ms settle even outside the lane window, then join the masked conveyor without a ghost, duplicate or blink. Established incoming/outgoing balls, including outline/shadow/symbol, should clip exactly at the lane rectangle.
5. Recheck rapid insertion, simultaneous rollback/cascade, FIFO rollover, SFX, combo/fever, defender attacks and restart. F3 should continue to report `I0`.

## Limitations

- Headless state tests verify render ownership and clipping hierarchy, but exact edge antialiasing, high-DPI appearance and the procedural SFX still require human desktop/Web/Android review.
- A distant FIFO test batch deliberately remains a separate FEED segment while it crosses the mask at normal speed; its faster physical gap closure begins only after the batch is fully visible.
- Pre-existing local editor-generated changes in `project.godot`, `scenes/main.tscn`, and generated untracked `.uid` files were preserved and intentionally excluded.
