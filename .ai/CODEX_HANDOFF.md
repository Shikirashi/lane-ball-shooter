# Codex Handoff — LBS-P011

**Status:** COMPLETE

**Branch:** `master`

**Implementation commit:** `696a1f0` (`Rebuild P011 conveyor with rigid segments`)

**Mailbox:** remains on LBS-P011; task, ledger, decision and protocol files were not changed.

## Architecture and implementation

- Rebuilt `ChainModel` around authoritative ordered rigid segments. Each segment owns one X anchor and ordered persistent UID/color members; every member center is derived as `anchor + index * 58`. The public `balls` array is now a flattened compatibility/render snapshot, never the physics authority.
- Added typed FEED and CAUSAL edges between segments plus UID-derived rollback diagnostics. All normal 34 px/s travel, feeder catch-up, 60/900/420 accelerated causal rollback and bounded tail recoil produce one desired translation per segment. One constraint solver clamps those translations before application, so no segment can cross or overlap a neighbor and no ball receives competing motor movement.
- Stable per-step event order is: integrate all segment translations and solve constraints; clamp/merge physical contacts and resolve eligible causal cascades; process legitimate left rollover; admit right-edge FIFO/fresh balls or empty recovery; expire 50 ms insertion checks; rebuild/validate the snapshot. `advance()` remains bounded to 1/60 second and exact pending-settle deadlines.
- Insertion contacts actual rendered centers using the documented 22 px chain radius + 12 px projectile radius. Inserting opens one exact slot in the contacted segment and coherently moves every following segment by the same slot width, preserving all external gaps. The new member is physically legal immediately and scales from 72% to 100% during its 50 ms settle, avoiding both logical and visual overlap.
- Match removal splits the authoritative segment while preserving every survivor position. The resulting causal edge moves only its immediate left/front rigid segment. At exact spacing, segments merge in UID order; only matching ends on a causal edge run one local cascade. FEED contacts and passive seeded 3–7+ groups never auto-clear.
- Fresh weighted runs and requested cached colors now share one far-right segment admission interface. Admission occurs only when an exact legal slot exists, never inside internal clear gaps. Distant noncontinuous/FIFO returns form a FEED segment and reconnect physically; FIFO order, 24 automatic-live cap, infinite fresh generation and linear legitimate cache storage remain intact.
- Added bounded diagnostics: segment and typed-gap counts, maximum match events per substep, historical minimum logical/render spacing and invariant violations. F3 displays these alongside settle/rollback state.
- Moved loaded/next and the 64×56 swap button into a compact safe-area HUD-right panel above the chain. The shooter track now spans chain coordinates with symmetric 24 px margins at all four landscape sizes. The panel is outside the firing playfield, so extreme-left/right touch drags remain available and swap taps cannot fire.
- Updated the canonical palette to saturated BLUE `#3677E8` and emerald GREEN `#37C45A`, neutralized 3D ambient lighting, named palette-derived lane materials for verification, and enlarged lane status labels. Balls, shooter/magazine, stripes, defender bodies, effects and projectiles continue to derive from `TeamData`; square/diamond redundancy is unchanged.
- Preserved the 0.20-second shot, 0.4-second cooldown, 0.05-second settle, P010 staged event/SFX/score/attack timing, enemy 0.24 hop pace, tier/revival/game-over rules and all seven procedural cues.

## Regression coverage and measured stress run

Added `tests/p011_segment_chain_stress_test.gd`. Independent assertions reconstruct every ball from segment anchors and verify unique ordered UIDs, exact internal 58 px slots, at least physical-diameter spacing across all neighbors, identical legal rendered centers, typed edge cardinality and zero model-recorded violations after every tiny update.

Reproduction seed: `0x5011CAFE`.

- 16,258 checks across 2,400 seeded rapid operations.
- 2,460 accepted physical insertions, including concurrent settles and moving-endpoint shots.
- 635 real staged match events.
- 669 fresh admissions and 6 cache/return activities, plus a 45-second rollover/feed tail.
- Mixed external deltas: 1/120, 1/60, 1/30, 0.08 and repeated 0.21-second long updates.
- Zero logical/rendered overlap, duplicate UID, ordering, segment-spacing or edge-count violations.
- Automatic live population remained bounded; maximum events per internal substep remained within the asserted bound of four.
- Runtime was under one second in this environment.

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
- P009 rollback — PASS (58 checks).
- P010 staged cascade — PASS (190 checks).
- P011 segment stress — PASS (16,258 checks and counters above).
- Bounded startup at 960×540, 1280×720, 1600×720 and 2400×1080 — all exit 0.
- `git diff --check`, export-binary scan and credential-pattern scan — PASS.

Every Godot invocation printed the known non-fatal sandbox diagnostic because `user://logs` is not writable; every suite and startup returned exit 0. No Web/Android export or physical-device run was attempted because those external toolchains/devices remain unavailable.

## Manual QA

1. Rapidly make several matches before earlier 50 ms settles/rollbacks finish, including shots directly at a moving seam. Watch every ball: none should overlap or pass through another; connected runs should remain rigid. F3 should keep `I0` and show logical/display minimum spacing at 58.
2. Reproduce RED RED / YELLOW YELLOW / RED RED. Verify insert scale-in, 50 ms yellow pause/pop, accelerating rigid left-red rollback, physical contact, then the separate four-red cascade with correctly ordered cues, score and attacks.
3. Exercise mismatched reconnection, a seven-plus-shot clear, multi-stage cascades, two independent gaps, left/tail/full clears and restart during settle/rollback. Confirm no passive clear, stale motor, duplicate event or reordered identity.
4. Let the stream run through rollover and trigger returns. Confirm new balls enter only at far right, cached order is exact, no incoming ball fills an internal match hole and visible objects remain bounded.
5. At all four target sizes, drag/fire from the extreme left and right. Confirm both edge balls are targetable. Tap the compact HUD swap button and verify it swaps only; Space/right-click remain functional.
6. At 960×540 and 1280×720, visually compare lane 2 BLUE with lane 4 GREEN across stripe, defender, projectile/status and chain/magazine balls. BLUE should remain saturated blue and GREEN clearly emerald, with square versus diamond symbols readable.

## Limitations / assumptions

- The insertion settle uses non-overlapping scale-in rather than horizontal center interpolation; its center occupies a legal physical slot immediately. This preserves the requested visible settle while making overlap impossible by construction.
- Headless tests verify canonical palette distance and palette-derived material colors, but cannot certify perceived color under a real display. BLUE/GREEN contrast and procedural audio still require the requested human desktop/Web/Android check.
- The flattened `balls` snapshot remains publicly readable for compatibility. Direct external mutation is unsupported; P007's former private snapshot mutation was replaced by the explicit `add_test_segment` fixture helper.
- Pre-existing local editor-generated changes in `project.godot`, `scenes/main.tscn`, and generated untracked `.uid` files were preserved and intentionally excluded.
