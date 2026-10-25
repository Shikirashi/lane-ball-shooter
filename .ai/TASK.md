# ACTIVE TASK: LBS-P010 — Zuma theatrical insertion, staggered match, accelerating group rollback and chain reaction

**Status:** READY FOR CODEX — P009 reviewed and accepted
**Depends on:** P009 implemented as `d5cd73b`, handoff `81fa461`, reviewed and accepted. This task EXTENDS the Zuma-style gap rollback already in `master`.
**Owner of mailbox:** ChatGPT. This is the one active implementation task; Codex must not self-advance beyond P010.
**Platform:** Godot 4.7.2, GDScript/Compatibility, Web/Android landscape.
**Read before coding:** `AGENTS.md`, `.ai/PROTOCOL.md`, `.ai/DECISIONS.md`, current `.ai/TASK_LEDGER.md`, P009 handoff/code/tests, and this file.

## Player's exact desired sequence

Initial row from LEFT/exit/front to RIGHT/feed/back:

```
[RED][RED] [YELLOW][YELLOW] [RED][RED]
```

Player shoots YELLOW into the yellow pair.

**Expected actions are DISTINCT IN TIME, NOT simultaneous:**

1. Shot physically contacts the chain and a yellow ball **visibly inserts and rests as a real part of the moving chain**, producing:
   ```
   [RED][RED] [YELLOW][YELLOW][YELLOW] [RED][RED]
   ```
   Play insertion/plop sound now; it is not yet a match event. It travels with the conveyor while settled.
2. Wait **0.05 seconds (50 milliseconds)** of gameplay simulation time, with all three yellow balls still visible.
3. Only now remove **the three yellow balls** together, fire exactly ONE yellow `match_completed(YELLOW, 3)` event, play the match SFX, award yellow score/combo, and initiate the yellow defender response. Expose a real spatial hole.
4. The LEFT/front pair of RED balls then reverses RIGHT and **rolls back as a SINGLE rigid segment**, accelerating toward the RIGHT/back red pair. Both left reds keep their mutual spacing and move together: no independent per-ball chasing/slipping/teleporting. The right reds remain the receiving group, progressing at normal conveyor speed (unless P009 explicitly documents a brief pause).
5. At first **physical contact**, the red pairs form a run of four. Only then resolve ONE RED cascade `match_completed(RED,4)` event, separate from the earlier yellow event, awarding red score/combo and causing the red defender response. Optionally use a short 20–40ms contact/hit emphasis only if it remains clearly distinct and deterministic; NEVER fire red cascade at the instant yellow was removed.
6. If this new red removal exposes another matching boundary, repeat rollback/physical reconnection for further cascades, each visibly sequenced. No matching of unrelated pre-existing runs.

**Nonnegotiable:** This is a deliberately theatrical **insert -> 50ms pause -> first pop -> accelerate whole-group rollback -> physical impact -> second pop** sequence. Avoid emitting both yellow and red events in one handler or at one simulation timestamp, even on a 30/60Hz normal frame. No visual appearance of fresh feeder balls filling this internal hole.

## Requirements A — correct delayed insertion/initial match

- Keep `ShooterView.SHOT_TRAVEL_TIME=0.20` and normal conveyor `ChainModel.DEFAULT_SPEED=34.0`. The 50ms delay begins at the **moment the fired ball contacts/inserts into the chain**, not when it is launched.
- `ChainModel.try_insert_shot(...)` should immediately return accepted-contact status, insert a visible ball with a stable UID and valid `x/display_x`, play/inform semantic **insert** cue now, and register a pending **player-initiated match check** to happen **no earlier than 0.05s later**. Misses do not register pending checks.
- During the settle interval the newly inserted ball must be visibly attached/in proper sequence with its neighbors, participate in the conveyor movement as one chain, and not get duplicated or erased. The shot must not cause a hidden instantaneous clear underneath a visual fake.
- On expiration, recompute the physically connected group **containing that inserted UID** (or robustly stored contact context) and remove it only if the same-color group has >=3. If not, no match event. Take care if a second accepted shot inserts elsewhere during those 50ms, or if the group has shifted due to P009 rollback, and ensure one pending check cannot resolve twice. If insertion into a pre-existing run of seven, count the resulting eight as one group if still connected.
- State should advance by deterministic gameplay delta (NOT `create_timer`/wall clock); advancing exactly 0.049s must show no match, and 0.050s must enable the yellow pop. A large step that spans several events should process them in correct temporal order instead of skipping rollback theater.
- Avoid unmatched inserted balls being held hostage forever; if an inserted UID exits the board, is removed by another actual match, or is invalidated by restart, retire its pending check cleanly.
- Preserve P008/P009 collision and no-passive-matching semantics.

## Requirements B — accelerated synchronized rollback

- Extend P009's left/front group reversal, not replace it with artificial movement of the right/back section. The entire connected LEFT group immediately ahead of the yellow removal moves to the RIGHT **as a rigid block**: preserve every internal spacing and identity and stable UID, and all affected ball X deltas must be equal each substep.
- Rollback starts gently and **accelerates over time or distance** (positive acceleration, tunable), starting near zero or a modest speed then rising to a safe maximum. Suggested initial tunables: `ROLLBACK_INITIAL_SPEED=60 px/s`, `ROLLBACK_ACCELERATION=900 px/s²`, `ROLLBACK_MAX_SPEED=420 px/s`. These are prototype values to adjust for satisfying animation while preserving a visibly separate red collision. Provide a coherent 0.2–0.8s typical closure for short 3–7-ball gaps where geometry permits.
- Maintain the correct relative closing velocity to the right segment's normal 34 px/s left travel and clamp displacement to physical contact (`spacing`, small epsilon). Never overshoot, overlap or reorder red balls. Geometry must be correct in both logical `x` and rendered `display_x`; no snap or separate interpolation that makes the red balls move at different speeds.
- Group acceleration is shared, **not independent per-ball acceleration**. A multi-ball forward section can have 2, 5, or more balls and must translate together.
- When another match creates another rollback, retire and/or reassign motor state using segment endpoints/UIDs, not stale indices. Multiple outstanding gaps, intervening shots, chained cascades, right-edge infinite feed, left FIFO rollover, and restart cannot lead to orphaned motors or repeated clears.
- A same-colored exposed boundary becomes cascade-eligible only when real physical contact joins both groups; a different-colored boundary merges without cascading. Avoid global scans of naturally spawned touching runs >=3.
- Optional polish: a brief contact pulse/shake on red pair collision and a stronger secondary match cue, but NO extra duplicate match event/SFX just for a visual pulse. The rest of the P008 seven-SFX system remains functional.

## Requirements C — event ordering, score and visuals

- Use a simple deterministic state machine/event queue: e.g. `SHOT_INSERTED_SETTLING -> INITIAL_MATCH -> GAP_ROLLBACK_ACCELERATING -> PHYSICAL_CONTACT -> CASCADE_MATCH -> ...`, with independent ongoing segments/UIDs where necessary. Do not block unrelated live gameplay while a pending match resolves.
- Match events drive existing `Main._on_chain_match_completed` -> P003 progression -> Battlefield P004/P005/P007 damage/revival and P008 SFX. Yellow score/attack must happen at the yellow pop; red score/attack at red cascade, not both at shot impact.
- The 3-second combo window is refreshed per **actual** match time. If yellow and red happen within window, red is the next combo step. Cascade group length >3 awards bigger score but advances only one step. P007 tier 3 and P005 down-lane revival still respond to actual match events correctly.
- Never auto-clear pre-existing 3–7+ color runs solely because they spawned, advanced, cached, or joined via unrelated feeder gaps. The only exceptions are explicitly *player-caused* physically reconnected chain reaction boundaries.
- A game-over freezes settle clocks, rollback and pending cascades along with existing game state; restart fully clears them and doesn't resume stale match sounds/attacks. Touch/mouse shot behaviors remain unchanged.
- Reasonable short settle/pulse drawings in `BallChainView` are welcome, but **actual chain motion must be animated, not UI-only deception**. Keep responsive layout/30FPS/60FPS Web-Android Compatibility.

## P010 regression tests (required)

Create `tests/p010_staged_cascade_test.gd` and rerun P001–P009:
1. Reproduce EXACT [RED,RED,YELLOW,YELLOW,RED,RED] chain with real shot insertion of YELLOW. At t=0 show 7 total balls, yellow triple still present, no match events. At t=0.049s: no match, still 7. At t>=0.050s: one yellow match event size 3, 4 reds remain split by visible hole, no red event.
2. At first update after yellow removal, left-red pair moves **right**, both with equal X displacement and unchanged spacing; right reds stay on ordinary conveyor displacement. Rollback velocity rises with elapsed time until max; no instantaneous snap.
3. Before red physical collision, no red cascade. At contact, four reds combine and emit exactly one **RED size 4** match. Yellow occurs first, red second with separately observable match SFX/attack/score state.
4. At 30, 60, 120 FPS subdivision and selected larger delta (one step spans initial settle and part/all rollback), event ordering, final counts and positions are consistent; no same-frame instantaneous yellow+red in normal gameplay.
5. Wrong-color shot, shot miss, unrelated seven same-colored ball run and passive feeder joins must not auto-clear. A matching insertion into seven colors clears eight after 50ms. Cascades only from causally linked matched-gap contact.
6. Test long and short gaps, edge removals, chains of 3+ cascades, multiple accepted shots during settle, an additional shot while rollback is active, left-edge rollover, FIFO cached return and infinite right-edge feed during pending rollback; preserve IDs/order and bounded live objects.
7. Game-over pause and restart mid-settle and mid-rollback cancel/clear all timers/motors; no stray SFX, scoring, defender attacks or duplicate callbacks after reset.
8. Existing P001–P009 headless tests pass with clearly documented expectation updates only where approved 50ms delay/staged cascade changes old synchronous behavior; never blindly remove earlier collision or FIFO tests.
9. Check editor import and bounded startup (960x540, 1280x720, 1600x720), `git diff --check` and no untracked export binary dependencies. Include manual reproducible scene/script setup demonstrating yellow-then-red.

## Scope and handoff

This is a **FOLLOW-UP to accepted P009**, now active. Implement against the current P009 source on `master`, preserving its already-fixed rollback direction and FIFO feeder.

Preserve current conveyor 34 px/s, 0.20-second projectile flight, enemy 0.24 units/s average hop, P008 weighted clustered color generation, all SFX (and mute), FIFO recycling, tier attacks, knockdown/revival and game-over logic. Avoid unrelated balance changes, artwork, exports, plugins or sound redesign.

When activated, update README, add P010 tests, update `.ai/CODEX_HANDOFF.md`, run all tests, commit/push, and STOP. ChatGPT reviews and controls any next task. Do not alter `.ai/TASK_LEDGER.md` or `.ai/DECISIONS.md` from Codex.
