# Codex Handoff — LBS-P015

**Status:** Implementation complete; automated verification passes.

**Branch:** `master`

**Implementation commit:** this scoped P015 commit.

**Mailbox:** remains on LBS-P015. `.ai/TASK.md`, `.ai/DECISIONS.md`, `.ai/TASK_LEDGER.md`, and `.ai/PROTOCOL.md` were not edited or advanced.

## Conveyor root cause and implementation

- P014 deliberately restricted accelerated reverse motion to CAUSAL gaps and left FEED gaps with no closing motor. That preserved the visible player-caused rollback but made a separated FEED/FIFO group capable of remaining permanently detached. Per-gap motor ownership also forced topology repair code to decide which movement policy survived every split and merge.
- Replaced CAUSAL/FEED-specific motors with one support model. The rightmost segment is attached to the virtual source/pusher and moves LEFT at the preserved `34 px/s`. Every segment to the left of a physical gap is unsupported and moves RIGHT from `60 px/s`, accelerating at `900 px/s²` to `420 px/s`.
- Velocity is authoritative per rigid segment. Every member derives its position from one anchor; the existing deterministic constraint pass clamps contacts at exact spacing. A merge inherits support and velocity from its right/source-side segment, propagating support leftward without per-ball motion or overlap.
- CAUSAL and FEED remain stable gap metadata only. Both close physically under gravity, but only a CAUSAL reconnection may scan the contact color and start a staged cascade. A FEED contact merges without matching even when both ends have the same color.
- Removed the separate tail-recoil motion. A surviving rightmost segment is source-supported and continues LEFT; unsupported surviving front sections fall RIGHT only while a real gap exists.
- Preserved the 50 ms insertion settlement and exact match/SFX/event order, P012's 58 px LEFT/front insertion displacement, offscreen-right generation, FIFO return order, masked established conveyor layer, deterministic microsteps, and unlimited generation.
- F3 now reports `U` unsupported segments, `G` gaps, maximum gravity speed `V`, latest rightward gravity displacement `D`, and invariant violations `I`.

## Finite encounter implementation

- Added configurable `enemy_spawn_budget`, defaulting to eight per lane. Each initial enemy consumes one slot, so a normal encounter schedules 32 total enemies.
- Successful spawns consume quota; a lane at its five-enemy concurrent cap defers the remaining quota. Once eight have spawned, that lane cannot produce a ninth, regardless of elapsed time.
- All ordinary projectile kills, tier-3 clears, and emergency clears feed encounter progress. Existing enemy HP, hopping, attacks, knockdown, emergency discharge, revival, and breach behavior remain unchanged.
- `Battlefield` aggregates spawned/live/neutralized counts. Victory requires all four lane quotas to be exhausted and zero live enemies. A terminal breach is checked first, so defeat wins a same-update race.
- Victory freezes all lane simulation, chain input, shooter simulation, and gameplay SFX just like defeat. The overlay shows `WAVE CLEARED`, the final score, and the existing restart control. The HUD shows `ENEMIES neutralized/32`; restart restores fresh quotas and one initial enemy in each lane.

## Regression coverage

Added `tests/p015_gravity_finite_enemies_test.gd` — PASS (587 checks):

- Reproduces a formerly persistent FEED gap with same-color groups, proves rigid rightward fall, physical closure, and no passive match.
- Verifies the source-supported rear train remains at `-34 px/s`, CAUSAL contact alone cascades, match order and 100+150 scoring remain staged, and different-color contact only merges.
- Exercises two simultaneous CAUSAL gaps plus FIFO arrival, FIFO ordering, insertion during gravity, restart during a fall, eventual closure, and continuous non-overlap.
- Compares contact timing at 30/60/120 Hz and a `0.08 s` caller delta; runs a 60-second 120 Hz infinite-source soak with bounded live/offscreen population.
- Verifies initial quota accounting, capacity deferral, exact eight-spawn exhaustion, no ninth spawn across ten simulated minutes, and neutralization accounting for tier 1, tier 2, tier 3, and emergency clears.
- Verifies no premature win during a temporarily empty encounter, exact victory emission, defeat precedence, WAVE CLEARED/final score/HUD state, freeze, and complete restart.

Older assertions in P002, P009, P011, P012, and P014 were updated only where the approved unified-gravity behavior supersedes the retired gap-specific motors and tail recoil.

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
- P010 staged cascade — PASS (179 checks).
- P011 segment stress — PASS (16,493 checks; seed `5011CAFE`; 2,400 operations; 2,460 insertions; 636 matches; 670 fresh balls; 6 cache activities).
- P012 forward insertion — PASS (372 checks).
- P013 shooter preview/mask — PASS (50 checks).
- P014 causal rollback/feed — PASS (289 checks).
- P015 gravity/finite enemies — PASS (587 checks).

Bounded main-scene startup also completed without script/runtime errors at `960x540`, `1280x720`, `1600x720`, and `2400x1080`. Each was intentionally terminated after three seconds. The sandbox cannot create/rotate `user://logs/godot.log`, so Godot prints a log-file warning before otherwise successful test and startup runs.

## Suggested visual playtest

1. Create a middle match and confirm the LEFT/front segment accelerates RIGHT as one rigid group while the rightmost train continues LEFT at normal speed. Create multiple gaps and a separated incoming/FIFO group; every unsupported segment should eventually reconnect without overlap.
2. Confirm only a player-caused reconnection cascades. A same-color FEED reconnection must join without popping.
3. Confirm insertion still pushes only the preceding LEFT/front balls LEFT, including while a segment is falling RIGHT, and the settled ball remains visible for 50 ms before the first match.
4. Play through all eight spawns in one lane and then all 32. Confirm the counter, WAVE CLEARED/final score, frozen gameplay, and restart. Separately allow a breach and confirm GAME OVER still wins.

## Limitations

- Headless tests validate state, ordering, timing, geometry, and generated PCM data, but do not replace visual/touch/audio QA in desktop, Web, and Android builds.
- The enemy counter communicates total progress, not per-lane quota. Per-lane budget details are available through the combat models and deterministic tests but are not separately drawn in the HUD.
