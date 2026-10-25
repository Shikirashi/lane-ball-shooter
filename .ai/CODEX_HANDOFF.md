# Codex Handoff — LBS-P010

**Status:** COMPLETE

**Branch:** `master`

**Implementation commit:** `891ad0d` (`Implement P010 staged insertion cascades`)

**Mailbox:** remains on LBS-P010; task, ledger, decision and protocol files were not changed.

## Implemented

- Accepted shots now become visible UID-addressed chain balls immediately and register an independent simulation-time settle state. Their display position eases into the moving logical slot; the insert SFX still fires at contact.
- Matching the inserted UID is deferred until exactly `ChainModel.INSERT_SETTLE_TIME = 0.05` seconds. At 0.049 seconds the full group remains present; at 0.050 seconds the connected group is recomputed and, if eligible, emits one match event. Misses create no timer, unmatched shots retire normally, removed/exited UIDs cancel stale checks, and reset clears all pending states.
- `advance()` now bounds steps at both 1/60 second and the next settle deadline. Large deltas therefore preserve insertion, initial match, rollback, contact and cascade ordering instead of collapsing them into one handler/timestamp. Match log entries include deterministic simulation timestamps.
- Replaced P009 constant-speed rollback with one motor per UID-anchored gap: 60 px/s initial speed, 900 px/s² acceleration and 420 px/s cap. The complete connected left/front segment receives the same logical and rendered displacement each substep; the receiving right section retains ordinary 34 px/s conveyor travel. Contact is clamped to exact spacing.
- Same-color cascades remain causal and occur only when the physical rollback boundary reconnects. Each stage emits one later `match_completed` event. Different-color ends merge without a scan, and passive feeder/cache runs remain untouched.
- Main now advances the combo timer to each chain event's simulation time while processing a frame, then advances the remainder. This keeps score, combo/fever, match SFX and defender response ordered at their actual yellow/red event times, including a larger frame delta.
- Game over continues to freeze the model because Main stops advancing it. Restart clears settle clocks, rollback motors, event time and existing SFX/progression/combat state. F3 diagnostics now report pending SETTLE and ROLLBACK counts.
- Preserved P009 rollback direction, far-right-only fresh/FIFO feed, stable identities, continuous generation, 34 px/s conveyor, 0.20-second player projectile, enemy hop balance, combat tiers, revival and all seven P008 procedural cues.
- Updated only older assertions whose approved synchronous-match assumption changed. Added `tests/p010_staged_cascade_test.gd` with 190 checks covering exact timing, rigid acceleration, contact-only cascade, 30/60/120 FPS and large deltas, guard cases, concurrent/rollback-time shots, cleanup, and live SFX/score/attack ordering. README documents the P010 sequence and tunables.

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
- `godot --headless --path . --script res://tests/p010_staged_cascade_test.gd` — P010 PASS (190 checks).
- Bounded startup at 960×540, 1280×720 and 1600×720 — all exit 0.
- `git diff --check`, export-binary scan and credential-pattern scan — PASS.

Every Godot invocation printed the known non-fatal sandbox diagnostic because `user://logs` is not writable; every suite and startup returned exit 0. No Web/Android export or physical-device/audio listening test was attempted because those external toolchains/devices remain outside this environment.

## Manual playtest

1. Arrange `[RED][RED] [YELLOW][YELLOW] [RED][RED]` and shoot YELLOW into the pair. At contact, hear only insert and see seven real balls. The three yellows should remain visible for 50 ms, then pop together with one match cue, score/combo step and yellow defender response.
2. Watch the remaining left red pair: both balls should reverse right together, start gently, accelerate, and preserve their spacing. The right red pair should continue ordinary left conveyor travel without jumping into the hole.
3. Verify no red response occurs before contact. When the pairs meet, one four-red cascade should pop with a separate later cue, larger score award, second combo step and red defender response.
4. Repeat with different exposed colors, long groups, three-stage cascades, two quick shots and a shot into the retracting section. Check that gaps remain physical, ordering stays stable, passive 3–7+ runs survive and no event/SFX duplicates.
5. Let balls roll into FIFO cache and return while gaps close; confirm fresh generation remains at the far right and cached identity order is unchanged. Trigger game over during settle/rollback, wait, then restart and verify no stale match, motor, cue or attack resumes.

## Notes / limitations

- The 60/900/420 rollback profile closes the common three-ball hole in about 0.59 seconds before contact, within the requested theatrical range. Tail recoil uses the same motor profile but remains capped at P009's 1.25-spacing distance.
- The 50 ms visual settle is intentionally brief: high-refresh displays show several easing frames, while a 30 FPS display normally shows contact plus one intermediate frame before the pop. Simulation timing remains exact and deterministic at all tested rates.
- Procedural cue synthesis/routing is automated, but timbre, loudness and perceived separation still require human listening on desktop, browser and Android hardware.
- Pre-existing local editor-generated changes in `project.godot`, `scenes/main.tscn`, `scripts/audio/sfx_manager.gd.uid`, `tests/p007_playtest_revision_test.gd.uid` and `tests/p008_gamefeel_sfx_test.gd.uid` were preserved and intentionally excluded.
