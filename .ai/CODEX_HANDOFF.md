# Codex Handoff — LBS-P018 enemy death presentation

**Status:** COMPLETE

**Branch:** `master`

**Implementation commit:** this scoped P018 commit.

**Mailbox:** remains on LBS-P018. `.ai/TASK.md`, `.ai/DECISIONS.md`, `.ai/TASK_LEDGER.md`, and `.ai/PROTOCOL.md` were not edited or advanced.

## Root cause and event order

The combat model removed the final enemy and synchronously announced victory. Battlefield then set every lane model `game_over=true`, while `LaneActor._process()` returned before visual synchronization or its small spark update. The already-instantiated enemy mesh could therefore remain standing behind an immediately displayed WAVE CLEARED overlay.

P018 introduces one typed `enemy_neutralized(uid, x, cause)` event for every logical removal path (`projectile`, `tier3`, `emergency`). It fires after accounting/removal but before encounter-state/victory evaluation. LaneActor first transfers that UID's existing body/shadow/pips out of the live dictionary into a transient death actor, then Battlefield forwards the scheduled event and Main requests its death cue. Only afterward can `encounter_state_changed` confirm victory. The legacy `enemy_killed` signal and killed-vs-emergency counters remain intact.

## Death VFX and SFX

- The actual enemy root is retained for a 1.0-second cosmetic animation rather than recreated or freed. A primitive explosion core and eight sparks expand at the impact position.
- The body eases to about 85 degrees around Z, settles near the ground, and body/helmet/eyes/HP pips/shadow fade with duplicated per-instance transparent materials. All transient nodes are freed at one second.
- Death actors have a per-lane UID guard, so one enemy cannot create duplicate corpses/cues. Normal projectile kills, the real matched-plus-adjacent tier-3 route, and emergency discharge all use the same event.
- LaneActor no longer returns early at terminal state: logical `combat_model.update()` remains frozen internally, while defender feedback, state effects, visual reconciliation and death cosmetics keep advancing.
- `enemy_death` is a distinct synthesized 0.38-second low crunch/pop/explosion using 22.05 kHz mono 16-bit PCM, the existing envelope, -15 dB voices and 0.28 peak cap. Every UID is auditable in request/play counters; the existing ten-voice stealing pool bounds simultaneous multi-kill playback.

## Victory presentation

Battlefield still declares authoritative victory exactly once as soon as all quotas are spent and no living enemy remains, after its existing breach-priority check. Main immediately enters `_game_over + _victory_pending`: shooting, swapping, chain simulation, settling handoff, combat, spawns, attacks and scoring are locked. The overlay stays hidden and gameplay audio is not stopped yet, allowing the final death cue and one-second animation to finish.

A delta-driven 3.0-second countdown then displays WAVE CLEARED and the captured final score and disables gameplay audio. There is no detached timer that can survive restart. GAME OVER remains immediate. Once Battlefield has emitted victory it is treated as irrevocable; the pre-victory terminal evaluation already gives a concurrent breach priority. Restart clears countdown state, transient bodies/effects, audio state, quotas and overlay whether invoked during or after the delay.

## Regression coverage

Added `tests/p018_enemy_death_victory_delay_test.gd` — PASS (41 checks):

- verifies immediate logical removal plus transfer of the existing mesh, explosion/sparks, near-horizontal fall, alpha fade, cleanup and continued cosmetic advancement with the combat model frozen;
- exercises projectile, actual two-lane tier-3 and emergency removals with once-per-UID causes, sounds and unchanged killed/emergency accounting;
- checks death PCM length/peak, request/play counters and mute behavior;
- confirms immediate authoritative victory and gameplay freeze, hidden overlay at t=0/1.0/2.9, VFX cleanup while terminal, WAVE CLEARED at t=3.0, no duplicate victory, correct score and audio ordering;
- verifies immediate defeat plus restart during/after pending presentation;
- protects 102 px/s chain speed, 0.20-second shot, 0.05-second settle, P017 UID retention and invariant `I0`.

Updated P008 only to permit the new approved death cue's 0.38-second duration while retaining the old 0.35-second ceiling for all earlier cues. Updated P015's obsolete immediate-overlay assertion to require immediate freeze plus the exact three-second presentation delay.

## Validation

Godot 4.7.2 headless, all passing:

- P001 smoke — PASS.
- P002 gameplay logic — PASS (66 checks).
- P003 progression/magazine — PASS (73 checks).
- P004 lane combat — PASS (42 checks).
- P005 survival — PASS (63 checks).
- P006 platform QA — PASS (69 checks).
- P007 playtest revision — PASS (53 checks).
- P008 gamefeel/SFX — PASS (84 checks).
- P009 Zuma rollback — PASS (46 checks).
- P010 staged cascade — PASS (162 checks).
- P011 segment stress — PASS (16,485 checks; seed `5011CAFE`, 2,400 operations, 1,836 insertions, 620 matches, 707 fresh, 57 hidden-left).
- P012 forward insertion — PASS (366 checks).
- P013 shooter preview/mask — PASS (50 checks).
- P014 causal rollback/feed — PASS (289 checks).
- P015 gravity/finite enemies — PASS (524 checks).
- P016 speed/retained-history compatibility — PASS (76 checks).
- P017 offscreen-left reentry — PASS (352 checks).
- P018 enemy death/victory delay — PASS (41 checks).
- `git diff --check` — PASS.

Bounded main-scene startup reached the running game without project/runtime errors at `960x540`, `1280x720`, `1600x720`, and `2400x1080`; each was intentionally terminated by `timeout` after three seconds (exit 124). The sandbox still denies Godot's `user://logs/godot.log` rotation, producing the known harmless warning. Web/Android exports and physical-device QA were not exercised.

## Manual playtest

1. Kill a single enemy with a projectile. Confirm the impact has a small orange explosion/sparks and distinct low pop/crunch, then the actual body falls sideways nearly horizontal and fades with its shadow/pips in about one second.
2. Trigger tier-3 on an edge and middle lane, then an emergency discharge. Every removed enemy should animate once; listen for controlled multi-kill sound density and check that no standing ghost or permanent corpse remains.
3. Neutralize the 32nd enemy. Gameplay should freeze instantly, with no WAVE CLEARED overlay for exactly three seconds. The last death should finish unobstructed, then the overlay/final score/restart should appear.
4. Let a live enemy breach in a separate run. GAME OVER must appear immediately. Restart during a pending win (via code/debug if needed) and after either terminal screen; no old corpse, sound or delayed overlay should return.
5. Recheck F3 `I0`, 102 px/s conveyor movement and the P017 same-UID return from offscreen LEFT; P018 does not change conveyor mechanics.

## Limitations

- Headless tests validate transforms, material alpha, lifecycle, synthesis and timing, but the fall silhouette, particle readability, perceived loudness/timbre and multi-kill mix still need desktop/Web/Android human playtesting.
- The VFX use lightweight primitive meshes rather than GPU particles to stay within the Compatibility renderer and no-assets prototype constraint.
