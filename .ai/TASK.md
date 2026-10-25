# ACTIVE TASK: LBS-P008 — Second playtest: 0.2s shots, slower hopping enemies, clustered ball patterns, procedural SFX

**State:** READY FOR CODEX
**Branch:** `master`
**Priority:** user feedback from second desktop playtest on 2026-10-25.
**Prerequisites:** P001–P007 completed and source-reviewed; P007 implementation `ab5359f`, handoff `5b0e7c8`.
**Read:** `AGENTS.md`, `.ai/PROTOCOL.md`, `.ai/DECISIONS.md`, `.ai/TASK_LEDGER.md`, this task, then `.ai/CODEX_HANDOFF.md`.
**Workflow:** Execute the full P008 task using code/text edits only, run tests, update the handoff, commit/push to `master`, then **STOP**. Do not advance task/ledger or invent P009.

## Intent and crucial disambiguation

The user says a "ball needs to be even faster: it should take maybe 0.2s to reach the top." This means the **PLAYER-FIRED VERTICAL PROJECTILE**, not the moving top conveyor. **Do not change `ChainModel.DEFAULT_SPEED=68 px/s`.**

Five explicit revisions:
1. Player's fired ball travels from shooter to upper chain in approximately **0.20 seconds**.
2. Halve enemies' average horizontal progress: **0.48 -> 0.24 world units/s** while preserving hop-only movement and grounded rests.
3. Make naturally consecutive balls of the **same color considerably more common** in the upper conveyor.
4. Allow **4 or more**, including occasional **seven** consecutive balls of the same color in the stream. Never automatically remove them just because they spawn/come together: only matching initiated by a player's successful ball insertion triggers clears and subsequent legitimate cascades.
5. Design and IMPLEMENT lightweight but recognizable audio cues for: **shoot**, **successful ball insertion/impact**, **swap**, **match**, **defender attack**, **defender knockdown ("dying")**, and **defender revival**. No existing sound files required; synthesize/code-generate them.

## P008-A — ~0.20 second shooter projectile travel

Existing `scripts/ui/shooter_view.gd` advances fired balls upward at hardcoded 610 pixels/s: too slow. Introduce a tunable `SHOT_TRAVEL_TIME := 0.20` seconds. For each accepted shot record launch X, initial Y, target lane Y (as provided by current responsive layout), elapsed time, and identity. Position with elapsed-time interpolation or with speed calculated from that shot's actual initial-to-target distance, so each shot reaches upper lane in **0.20s in 960x540, 1280x720, 1600x720 and 2400x1080** layouts rather than only at one viewport height.

- Keep straight vertical path and stable X; shooter movement AFTER firing must not steer a shot.
- Cross lane boundary exactly once even for a single `_process(0.5)` update. Emit `shot_reached_lane` exactly once and remove finished shot; no double consume, no score or **insertion/impact SFX** for a miss. The accepted firing still plays its **shoot** SFX even if the shot eventually misses.
- The 0.4s firing cooldown is unchanged (shot speed is NOT fire rate). Keep loaded/next generation, swaps, desktop and touch, and their no-double-input rules.
- Player's input snapshot is at moment of firing; maintain correct impact X against the chain's current position after travel. Do not teleport an impossible shot into a distant train. If a resize happens while a shot is active, preserve sensible shot termination and avoid duplicate insertion.
- Visually confirm shot reaches upper chain quickly but visibly (not instantly). Any firing VFX cadence may be adjusted.

## P008-B — halve hopper average horizontal speed

Current `LaneCombatModel.DEFAULT_ENEMY_SPEED=0.48`. Change to exactly **0.24 world units/second average over full hop cycles**. Preserve current `HOP_GROUND_DURATION=0.55`, `HOP_AIR_DURATION=0.75` and phase-aligned 3D visuals unless minor justified cosmetic tuning is necessary. No X movement when grounded, forward X only in air.

- Existing `_hop_air_speed()`, `_hop_displacement()`, piecewise swept projectile collision, defender contact, first-emergency contact before breach and downed defender breach must remain frame-rate-independent and correct for large steps.
- Spawn rate and maximum enemy population unchanged unless a clear serious test failure mandates it. Adjust test assertions explicitly tied to old 0.48 speed; do not weaken unrelated P004–P007 coverage.

## P008-C — more interesting same-color clusters in infinite feeder

The `ChainModel` P007 right-edge feeder currently uses a four-color shuffle bag; that discourages consecutive repeats and makes the stream look noisy. **Replace only the TOP CONVEYOR's FRESH-BALL color generator** with a repeat/run-weighted generator. Do **not** change the separate `MagazineState` four-color shuffle bag for fired ammunition.

Recommended explicit baseline for easy playtesting: decide one run color from the four colors (avoid immediately repeating the previous run color to make run lengths meaningful); choose run length from a weighted distribution:
- length 1: **20%**
- length 2: **30%**
- length 3: **18%**
- length 4: **13%**
- length 5: **9%**
- length 6: **6%**
- length 7: **4%**

This is a suggested tunable implementation: the same-color continuation probability is much higher than a uniform four-color shuffle, and 4–7 consecutive colors should be **possible and visibly present**. Keep balanced representation of all four colors over longer runs, deterministic seeded testing and reset. If better architecture is needed, document deviations while preserving these measurable goals.

- The initial seeded portion should also demonstrate clusters, not just later offscreen generated balls. Use the new generator to seed the initial population, or provide an explicit sensible seed pattern with some 2–4 repeats; do not automatically resolve seeded groups.
- A run of 7 GREEN balls generated/placed on the chain must **remain untouched** while simply moving left and through feeder insertion, right-edge re-entry, gap closure and FIFO cache operations. There must be **NO automatic three-match scan on spawn, passive movement, or cache merge**. The matching resolver fires **only when a shot successfully inserts into an existing ball group**, then cascades only if player-triggered removal joins other physically adjacent qualifying runs. This is intentional even if 3+ are already touching before the shot. A matching-color shot contacting seven GREEN balls should clear the qualifying group as ONE event (eight balls if inserted adjacently), awarding the existing larger-group score formula once.
- Shots of a DIFFERENT color must not cause unrelated pre-existing long runs elsewhere in the board to disappear. Physical connectedness still governs insertion/group/cascade. No match may span a disconnected spatial gap.
- Keep continuous infinite fresh generation, bounded simultaneous live ball count, non-overlapping right-edge supply, FIFO cache order and pending returns, no ball penalty on rollover, no permanently empty board.
- When cached colors interleave with fresh runs, do not corrupt run generator state or silently reorder cache. Long runs formed across independently sourced balls are acceptable; never clamp at seven if contiguous colors legitimately exceed that.
- Expose generator weights/seed in constants and modest statistical counters/test access. No infinite per-run debug history or transient node buildup.

## P008-D — generate and integrate seven purposeful SFX cues

Use **procedural sound synthesis authored inside the Godot project**, not proprietary game SFX, external downloads, TTS, added audio plugins or external runtime dependencies. Recommended robust approach: generate short in-memory 16-bit PCM mono `AudioStreamWAV` assets at startup (e.g. 22050 Hz), with sine/triangle and very restrained noise/tick components; play via a small reusable `AudioStreamPlayer` voice pool so simultaneous shot+match+defender cues can overlap. Another native Godot audio method is acceptable if tested in Web-compatible Godot 4.7 Compatibility. A headless engine without audio output must not crash.

**Sonic design (distinct, soft arcade style; no harsh full-volume square waves):**

| Event | Desired sound | Trigger |
|---|---|---|
| `shoot` | ~70–110ms quick upward 'pew', pitch glide | accepted `Main._shoot()` **once** after cooldown, not for blocked inputs |
| `insert` | ~45–90ms soft click/plop, with round attack | `ChainModel.try_insert_shot()` returns **true** only; no insertion SFX for empty-lane misses |
| `swap` | ~120–180ms two-note 'bip-bop' | actual `Main._swap()`, one sound for Space/right-click/touch UI; no sound while game over |
| `match` | ~180–260ms bright upward arpeggio/pop | **each** `match_completed` event, cascade groups separately; may mildly scale pitch/brightness with size, bounded |
| `attack` | ~100–230ms punchy zap/boop, tier-dependent; tier 3 a stronger lower swoosh/sting | actual ACTIVE defender attack **once per match result**, even if no enemies; tier 3 origin+neighbor area clear emits ONE global attack SFX (not two) |
| `knockdown` | ~230–330ms descending 'womp' / sad tone | `defender_knocked_down` signal; user calls this "defender dying" although mechanically it remains DOWN/revivable |
| `revive` | ~220–350ms rising two/three-tone chime | actual `defender_revived` signal on second relevant match; first revival progress has **no revive jingle** |

- Attack, match, insert may play close together; overlap deliberately without clipping or loudness spikes. Gentle ADSR envelopes (fast attack, fade out) and bounded PCM amplitude. Low default SFX volume (e.g. -12 to -18 dB), max ~8–12 pooled voices, sensible voice stealing or drop policy if flooded. Sound cues must not rely on visually rendered frames, physics frame rates, network or external sound devices. No audio processing on every graphics frame if clips can be pre-generated.
- Connect **existing semantic signals/events** instead of polling: `Main._shoot`, `Main._swap`, success bool from `_on_shot_reached_lane`, `ChainModel.match_completed`, result from `Battlefield.handle_match`, lane-model knockdown and revival signals. Avoid double registration per restart. Important: `Main._on_match_resolved` already routes active attacks or revival through Battlefield; trigger attack SFX ONLY for a real `action == "attack"`, not during a downed defender's revival progress. Tier-3 clears generate only one attack event/cue.
- Audio should stop/avoid new events once game over; on restart clear any held voices/buffers as appropriate and restore readiness. Optionally support **M** to mute/unmute for comfortable playtesting (recommended); mute must preserve gameplay events and not emit sounds while muted. No GUI redesign required.
- Fail gracefully in headless automated tests without audio hardware. If native procedural PCM is unsuitable, code-generate small original WAV files as checked-in project assets; ensure they are reproducible, portable, and license-clean. No binary audio files from the environment or outside the repo without need.
- Test event/trigger dispatch using counters or a test spy rather than relying only on whether actual audio is audible in headless mode. Test synthesis format, nonempty PCM, duration, peak amplitude, mix/clipping limits, voice bounds and restarts. Mark audio timbre/volume as requiring human listening tests, not verified by headless checks.

## Headless regression/test plan

Create `tests/p008_gamefeel_sfx_test.gd` (split into more suites if useful) and run **ALL P001–P007** existing suites and bounded startup. Include deterministic checks:

1. At each target resolution, accepted shot arrives exactly once after about 0.20 seconds (and not at 0.10); a large delta crosses once; launch X/identity preserved, shooter moving after fire doesn't change shot X, misses don't insert or play insertion SFX.
2. Cooldown 0.4s and magazine draw counts unchanged; mouse/touch/swaps preserved.
3. Enemy default speed is 0.24; grounded X unchanged, airborne X decreases, full-cycle average 0.24; large vs many small update subdivision agrees, swept projectile hits & first knockdown/emergency/breach ordering remain sound.
4. New fresh generator produces reproducible same-color runs, many adjacent duplicate pairs, and demonstrable run length 4 and 7 under known seeds; no 3+/7-ball passive self-clear during spawning, movement, gap closure or cache return. Player inserts matching color into pre-existing seven group: ONE match of true resulting group size; a wrong-color shot does not clear unrelated group.
5. All four colors appear over sufficiently long fresh generations, infinite feeder still supplies >100 balls over a long run, live population bounded, cache FIFO RED,GREEN,BLUE preserved even amid fresh admissions and right-edge returns.
6. Each of seven SFX plays only on its semantic event (shoot accepted, insert success, swap once, match once per cleared group, attack ACTIVE, defender DOWN signal, defender REVIVED signal). No insert for misses, attack for downed-origin revival, revive jingle at 1/2, sounds after game-over or mute.
7. Clip duration/amplitude valid; simultaneous cue requests don't explode voices; headless mode with no audio output does not fail; repeated restart doesn't duplicate sound signal connections.
8. Existing P001–P007 regressions pass (update only outdated generator/speed assertions explicitly superseded by this user-approved task). Run bounded startup with 960x540, 1280x720, 1600x720, 2400x1080; verify `git diff --check` and no exported binaries/secrets.

## Manual acceptance

- At all four landscape view sizes, 2D projectile visibly reaches upper lane around **0.2s** after firing. The conveyor's own speed remains the old 68 px/s.
- Enemies hop toward the defenders at **half** the former overall speed; pause without drifting when grounded.
- Top train often includes runs of 2, sometimes 4–7 (7 GREEN in a row is valid). These long runs do not disappear until the player inserts a matching ball into them. One inserted same-color shot clears the entire resulting run, with score based on group size and one combo step.
- Audio: distinctly hear soft shoot 'pew', successful insert 'plop', swap 'bip-bop', match arpeggio, active attack zap, defender knockdown 'womp' and revival chime. Sound layers stay comfortable during a fast cascade and fever. No impact sound on a shot into empty space. Muting (if implemented) silences all SFX.
- Check normal tier-2 kill, tier-3 two-lane wipe, revival, emergency charge, breach and restart. No sound or simulation leaks after death/restart.

## Finish and report

Update `README.md` with new 0.20s shot travel, slow enemy speed, feeder run distribution, SFX list and volume/mute control if implemented. Update `.ai/CODEX_HANDOFF.md` with implementation status, tests and EXACT Godot commands/results, authored synthesis approach, voice/volume choices, known shortcomings and real-audio listening checklist. Commit and push to `master`. **STOP**, do not self-advance task ledger, do not modify `.ai/DECISIONS.md`; ChatGPT will review on the next "check push".
