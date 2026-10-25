# Codex Handoff — LBS-P012

**Status:** COMPLETE

**Branch:** `master`

**Implementation commit:** `412b18e` (`Fix P012 insertion displacement direction`)

**Mailbox:** remains on LBS-P012; task, ledger, decision and protocol files were not changed.

## Implemented

- Corrected authoritative segment insertion to expand in conveyor direction. For insertion at segment-local index `k`, the contacted segment and every earlier/LEFT segment translate exactly `-spacing` (−58 px), then the new member is inserted at `k`.
- This single anchor transformation gives the required per-UID result: old members before `k` move LEFT 58 px; old members at/after `k` retain their exact world X; all later/right segments remain pinned. No existing ball is pushed RIGHT.
- Front insertion (`k=0`) places the shot one slot left while all old members remain fixed. Tail insertion (`k=N`) shifts the complete old train left and places the shot at the old tail X. Interior insertion shifts only the old prefix while preserving the old suffix.
- At FEED or CAUSAL seams, every preceding segment receives the same −58 px translation. Therefore all intervening typed gap IDs, types, widths and motor speeds remain unchanged; the new endpoint is derived normally from segment membership. Active rollback remains valid and terminates without motor reversal or deadlock.
- Near-left members displaced beyond the exit are not deleted during insertion. The existing ordered rollover event collects them into FIFO on the next simulation update; tests verify RED/GREEN/BLUE exit and return order.
- Preserved P011 segment authority and non-overlap constraints. Logical/rendered centers remain derived from segment anchors at exact 58 px internal spacing; the 50 ms 72%→100% scale settle remains unchanged.
- Kept insertion and rollback direction deliberately separate: insertion advances the front prefix LEFT; only a match-created causal gap drives the left/front segment RIGHT with the existing 60/900/420 rollback profile.
- Updated P002's near-edge fixture to avoid intentionally rolling off before its three-ball match, P009's superseded rightward-insertion position assertions, and P011's FIFO fixture isolation. No regression coverage was removed.
- Updated README with the forward insertion policy, seam behavior, end cases, manual direction checks, and P012 command.

## P012 regression coverage

Added `tests/p012_forward_insert_test.gd` — PASS (377 checks):

- Position-by-UID checks for insertion indices 0, 1, middle, before-last and N.
- Documented `[R][R][Y][Y] | [B][B]` seam insertion: four front UIDs move −58, both trailing UIDs remain fixed, GREEN occupies the opened slot and FEED edge identity/distance survives.
- Insertion on both sides of an accelerating CAUSAL seam preserves gap ID, type, distance and motor speed.
- Two accepted shots within one 50 ms settle window and rollback-time endpoint shots preserve UID order, retire once and never overlap.
- Near-left insertion push performs normal FIFO rollover and exact ordered return without ghost balls.
- Explicit direction sequence verifies insertion LEFT, yellow pop at 50 ms, causal rollback RIGHT, physical reconnection, then one RED size-4 cascade.
- Independent segment/logical/render invariant checks run after every 1/120-second microstep.
- Full-width shooter and nonblocking compact swap geometry remain valid at all four landscape sizes.

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
- P009 rollback — PASS (59 checks).
- P010 staged cascade — PASS (190 checks).
- P011 segment stress — PASS (16,258 checks; seed `0x5011CAFE`, 2,400 operations, 2,460 insertions, 635 matches, zero invariant violations).
- P012 forward insertion — PASS (377 checks).
- Bounded startup at 960×540, 1280×720, 1600×720 and 2400×1080 — all exit 0.
- `git diff --check`, export-binary scan and credential-pattern scan — PASS.

Every Godot invocation printed the known non-fatal sandbox diagnostic because `user://logs` is not writable; every suite and startup returned exit 0. No Web/Android export or physical-device playtest was attempted.

## Manual QA

1. Insert into the middle of a visible train. Existing balls left of the shot should move one slot LEFT with the conveyor; balls right of it must not move RIGHT. Repeat at the first and last ball.
2. Insert at a visible gap/seam and again while the front segment is rolling back. The gap width should not snap or collapse, and no ball should overlap, reorder or deadlock. F3 should remain `I0`.
3. Reproduce RED RED / YELLOW YELLOW / RED RED. Observe the insertion push LEFT first, the 50 ms yellow settle/pop, then—and only then—the front red pair reversing RIGHT into physical contact for the later four-red cascade.
4. Insert repeatedly near the left exit and let displaced balls recycle. Confirm exit/cache/return order remains exact and no life/score penalty occurs.
5. Recheck extreme-left/right aiming, HUD swap touch, SFX, combo/tiers, revival and BLUE/GREEN distinction; none were intentionally changed.

## Limitations

- The one-slot insertion displacement is immediate and authoritative, while the inserted ball retains P011's non-overlapping scale settle. No separate positional tween was added because interpolating front centers independently would weaken the zero-overlap invariant.
- Visual feel, palette perception and procedural audio still require human desktop/Web/Android review.
- Pre-existing local editor-generated changes in `project.godot`, `scenes/main.tscn`, and generated untracked `.uid` files were preserved and intentionally excluded.
