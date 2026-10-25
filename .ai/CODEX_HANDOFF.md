# Codex Handoff — LBS-P014

**Status:** COMPLETE

**Branch:** `master`

**Implementation commit:** `589846c` (`Restore authoritative causal rollback motion`)

**Mailbox:** remains on LBS-P014; task, ledger, decision and protocol files were not changed.

## Root cause reproduced

- The isolated P010/P011 CAUSAL formula still targeted the left/front segment correctly: after a YELLOW x3 middle clear, the first 50 ms moved the front anchor `+2.425 px` while the right/rear anchor moved the normal `−1.700 px`.
- P013 introduced a much more visible competing motion: once a separated FEED return batch became fully visible, `_integrate_segments` added `−120 px/s` catch-up on top of the `−34 px/s` conveyor. The batch jumped from `−34` to `−154 px/s`, visually reading as individual incoming balls racing left to repair the chain while the initial causal reverse was only `+26 px/s` net.
- Gap dictionaries contained only type/index-era state. Although ordinary cases remained ordered, CAUSAL motors were assigned through mutable array indices instead of persistent segment endpoints, leaving concurrent FEED merges and topology changes under-specified. Existing stress tests proved non-overlap but did not assert which segment moved or its velocity.

## Implemented

- Removed special FEED acceleration. Fresh and FIFO entrants move at exactly `−34 px/s` before and after becoming visible. Normal admissions still append at exact spacing whenever legal; a deliberately distant FIFO batch remains one rigid typed FEED segment rather than sprinting in isolated bursts.
- Added persistent `left_segment_id` and `right_segment_id` bindings to every typed gap. All segment creation, removal, rollover, split and merge paths explicitly maintain the bindings, and invariant validation now rejects stale endpoints.
- CAUSAL integration resolves its stable segment IDs and assigns the 60/900/420 rollback motor only to the bound LEFT/front segment. The bound RIGHT/rear segment receives baseline conveyor motion unless it independently owns another causal edge.
- Preserved the P011 constraint solver: it can clamp a causal front at exact spacing but cannot transfer its motion to the right segment. Physical CAUSAL contacts now resolve before simultaneous FEED contacts, after which remaining endpoint bindings are repaired deterministically.
- Added bounded per-step `segment_motion_log` diagnostics with anchor before/after, displacement, actual velocity, velocity relative to normal, member count, and adjacent gap IDs/types. F3 now reports active CAUSAL motors (`MC`), FEED motors (`MF`, intentionally zero), and latest positive causal reverse displacement (`R`).
- Preserved P012 insertion-left displacement, P010 50 ms settlement/cascade order, P013 offscreen entry/masking, 34 px/s conveyor, weighted runs, FIFO order, live cap, shooter UI, SFX and combat balance.
- Updated only the P002 and P011 assertions superseded by the approved removal of FEED catch-up. They now verify that separated return batches remain rigid, non-overlapping and noncausal at normal speed.
- Updated README with CAUSAL-versus-FEED ownership, stable endpoint behavior, velocity policy and F3 troubleshooting.

## P014 regression coverage

Added `tests/p014_causal_rollback_feed_test.gd` — PASS (289 checks):

- Exact front/rear UID displacement over 0.05, 0.1 and 0.2 seconds: front members move RIGHT identically; rear members remain exactly `−34 px/s`.
- Stable causal gap/segment IDs and motion-log classification/velocity checks.
- RED 2 / YELLOW 2 + shot / RED 2 sequence: YELLOW x3 first, then RED x4 only after distinctly later physical contact.
- Active causal rollback with an offscreen/visible entrant: front reverse persists, rear and entrant remain baseline, and no `34→154` speed jump occurs.
- Two concurrent CAUSAL gaps plus a FIFO batch: each surviving causal-left segment moves as its own rigid group while FEED has no motor.
- Insertion during rollback still shifts the preceding prefix LEFT 58 px, preserves causal ID/type, then resumes RIGHT rollback.
- Equivalent event order and bounded contact-time variance at 30/60/120 fps and 0.08-second updates.
- A deterministic 120-second mixed stream with 300 accepted rapid shots, 152 matches, ongoing fresh arrivals, bounded population and zero overlap/topology violations; FIFO concurrency is covered separately.

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
- P014 causal rollback/feed — PASS (289 checks).
- Bounded startup at 960×540, 1280×720, 1600×720 and 2400×1080 — all exit 0.
- `git diff --check`, external-binary scan and credential-pattern scan — PASS.

Every Godot invocation printed the known non-fatal sandbox diagnostic because `user://logs` is not writable; all suites and startups returned exit 0. No Web/Android export or physical-device playtest was attempted.

## Manual QA

1. Enable F3, arrange RED RED / YELLOW YELLOW / BLUE BLUE, and insert YELLOW. After the 50 ms pop, expect `MC1`, `MF0`, positive `R`; both front reds visibly accelerate RIGHT together while both rear blues continue LEFT at 34 px/s.
2. Repeat with RED on both exposed sides. Confirm the later RED x4 cascade occurs only after the red pairs physically touch.
3. Trigger matches while fresh/cache balls are crossing the right mask. Incoming balls must stay smooth at 34 px/s with no post-visibility sprint, while the existing causal front—not the arrivals—closes the match gap.
4. Create two quick middle matches and insert again during rollback. Confirm rigid group motion, P012's immediate LEFT insertion push, preserved causal reversal, no overlap, and F3 `I0`.
5. Recheck restart/game-over cleanup, shooter preview/swap, mask handoff, SFX, combat and FIFO order.

## Limitations

- A deliberately separated FIFO batch no longer closes its noncausal FEED gap faster than the conveyor. This is intentional to guarantee smooth normal-speed entry and prevent FEED from masquerading as causal rollback; normal continuous admissions attach at exact spacing when possible.
- Headless tests verify authoritative positions and render ownership, but final animation feel, high-DPI clipping and audio require human desktop/Web/Android playtesting.
- Pre-existing local editor-generated changes in `project.godot`, `scenes/main.tscn`, and generated untracked `.uid` files were preserved and intentionally excluded.
