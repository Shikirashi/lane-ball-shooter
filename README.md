# Lane Ball Shooter

A hybrid 2D/3D lane-defense game prototype in **Godot 4 / GDScript**, targeting Web and Android (landscape).

- 2D Zuma-like moving ball chain, shooter-mounted two-ball ammunition preview and compact swap control.
- Four 3D horizontal combat lanes with primitive defenders and hopping enemies.
- Matches activate same-color defender attacks; successive matches build combo/fever.
- Balls exiting left automatically queue for FIFO re-entry; defenders have an emergency lane clear and require matching-color revival.

## Codex development mailbox
This repository uses a shared mailbox: read [AGENTS.md](AGENTS.md) first, then `.ai/PROTOCOL.md`, `.ai/DECISIONS.md`, `.ai/TASK_LEDGER.md`, and the current `.ai/TASK.md`. Codex implements the active task and writes `.ai/CODEX_HANDOFF.md`.

## Run the prototype

Open the folder in Godot 4.x and run the project, or launch it from a terminal:

```sh
godot --path .
```

The project uses GDScript and the Compatibility renderer. All visuals are created with Godot drawing APIs and primitive 3D meshes; there are no external assets or add-ons.

Controls:

- Move the mouse horizontally to position the shooter; left-click in the playfield to fire.
- Right-click or press Space to swap the loaded and next balls.
- On touch devices, press and drag in the playfield, then release to fire once. Tap the circular two-arrow HUD control to swap without firing.
- Press F3 to show or hide live ball/segment/gap diagnostics, including unsupported segment count, gravity speed/displacement, FIFO queue/exited/returned/fresh counters and invariant violations.
- Press M to mute or unmute procedural sound effects.
- After a lane breach or cleared wave, press R or use the on-screen RESTART button to begin a fresh run.

The layout targets landscape screens and has automated coverage at 960×540, 1280×720, 1600×720 and 2400×1080. Native safe-area information is used when the platform supplies it; Web falls back to the browser canvas with an additional logical edge margin. The shooter track spans the chain's full safe width with symmetric 24-pixel edge margins, so both edge balls are targetable. The large loaded ball and a smaller symbol-bearing NEXT ball now travel together on the shooter. The old magazine panel is replaced by one circular 56×56 two-arrow swap control in the upper-right safe HUD, completely outside the firing playfield. The 3D SubViewport resolution is capped through integer downscaling on very wide/high-density windows to limit mobile fill cost.

Player-fired balls cross from their launch position to the upper lane in 0.20 seconds at every supported landscape height. Each shot locks its launch X and identity, while the 0.4-second firing cooldown remains unchanged.

The top lane is a functional ordered chain moving right-to-left at 102 pixels/second. This P016 playtest speed is three times the former 34 px/s baseline; it does not change the 0.20-second vertical shot, enemy movement or virtual-gravity tuning. The chain's authoritative physics state is an ordered list of rigid connected segments: each segment owns one anchor plus persistent UID/color members at exact 58-pixel slots. The `balls` array consumed by drawing is derived from those anchors rather than moved independently. Gap edges hold real distance and stable left/right segment IDs; their CAUSAL/FEED type records whether a later reconnection may cascade, but no longer selects a movement motor. One deterministic integration/constraint pass moves segments and clamps contact before any merge. Logical and rendered neighbors therefore remain ordered and non-overlapping through rapid insertions, simultaneous falls, feed arrivals and cascades.

A shot must horizontally overlap a visible ball using the physical 22-pixel chain radius plus the projectile's 12-pixel radius. On contact, an accepted shot becomes a real UID-addressed member immediately. Because the conveyor flows right-to-left, insertion opens one legal slot by pushing the existing LEFT/front prefix exactly 58 pixels LEFT in the normal flow direction; the old RIGHT/trailing suffix remains at its world X and is never shoved backward. At a typed segment seam, every preceding segment receives the same leftward slot displacement, preserving the FEED/CAUSAL gap's identity, width and segment state. A short scale-in supplies visual settling without changing authoritative center spacing. Its player-caused match check waits exactly 0.05 seconds of gameplay simulation time, so the completed group remains visible before its first pop. During those 50 ms the stable UID is drawn exactly once by an unmasked insertion overlay; at settlement it transfers atomically to the conveyor-only clipped layer. Loaded, next and traveling shot visuals remain owned by the unmasked shooter layer. The insert/plop cue occurs at contact; match scoring, combo progression, defender response and match SFX occur only when that delayed check actually removes a group.

A successful clear preserves the removed balls' spatial gap. Conveyor motion uses one virtual-gravity rule for every gap: the rightmost source-connected segment is the pusher-driven train and moves LEFT at 102 px/s, while every unsupported segment to its left falls RIGHT as a whole rigid group, starting at 60 px/s, accelerating at 900 px/s² and capping at 420 px/s. On contact, support propagates from right to left and the merged train resumes normal conveyor motion. The non-overlap solver clamps every contact at exact spacing, so even simultaneous gaps cannot compress or pass balls through one another. CAUSAL contacts are resolved before unrelated FEED contacts; only a player-caused edge may turn matching contact colors into a cascade and emit a later match event. A FEED reconnection physically closes by the same gravity but never auto-matches. Simulation is event-bounded at settle deadlines and subdivided to at most 1/60 second, preserving insert → pause → initial pop → gravity fall → contact cascade order even for a larger update.

Gravity is universal, but matching remains player-causal rather than a passive board scan. The independent fresh feeder intentionally builds same-color runs using weights of 20%, 30%, 18%, 13%, 9%, 6% and 4% for lengths 1 through 7. Pairs are common and runs of four to seven are valid, but pre-existing groups never clear merely because they spawn, move, make noncausal contact, or return from cache. Only a matching player insertion starts a clear and its causally linked physical cascades. The magazine remains a separate fair four-color shuffle bag.

Fresh and recycled balls share the same one-slot-at-a-time segment feeder. Their centers begin at `lane_width + radius + 4`, putting the entire 22-pixel-radius circle beyond the right boundary, then advance left at 102 px/s and reveal progressively through the exact conveyor window. Event-bound admission keeps 30/60/120 fps and larger deltas deterministic. Every ball that fully leaves on the left is appended exactly once to one canonical FIFO color queue and becomes immediately eligible to return; ordinary simulation drains that queue without waiting for a match. The deterministic policy prioritizes up to three recycled colors, in exit order, then admits one weighted fresh color so neither recycling nor the independent infinite source is starved. Legacy match requests can prompt the same queue but never duplicate eligibility. Incoming balls join the rightmost source-connected train, while any older segment isolated to their left closes its intervening FEED gap under the same rightward gravity. Live automatic population remains capped at 24 with at most one staged offscreen ball. Because one fresh color is deliberately introduced among recycled colors, a compact linear FIFO queue may grow during an indefinitely full-throughput, no-match run; colors are retained rather than silently discarded. FEED contact never initiates a match.

The canonical palette is shared by balls, magazine/shooter, lane stripes, defenders and projectiles. BLUE is a saturated `#3677E8` and GREEN an emerald `#37C45A`; neutralized battlefield ambient light preserves that distinction. DOT/SQUARE/TRIANGLE/DIAMOND symbols and enlarged lane status labels remain the redundant non-color identity channel.

Matches award score and advance the three-second combo window through tiers 1–3; the fourth consecutive timely match activates FEVER. The HUD meter drains in real time, while score persists through timeout. Magazine colors come from a fair four-color shuffle bag.

Each match also activates its matching 3D defender using the tier locked at match time. Tier 1 fires one 1-damage projectile, so a standard 2-HP enemy needs two hits. Tier 2 fires two spaced 2-damage projectiles; each can kill a fresh standard enemy. Tier 3 and FEVER replace the old three-shot burst with an immediate clear of the matched lane plus exactly one randomly selected adjacent lane. This clear does not consume either lane's emergency charge, and a down origin defender still receives revival progress instead of attacking.

Primitive enemies spawn independently, display HP pips, and use a shared logical/visual hop cycle averaging 0.24 world units/second: horizontal X remains stationary during a grounded dwell, advances only through the airborne arc, then pauses again after landing. Projectile sweeps use that same piecewise motion, so both grounded and airborne enemies remain hittable and large frame steps cannot tunnel through them.

Each lane has a configurable encounter budget, initially eight enemy spawns including its starting enemy: 32 scheduled enemies overall. A full lane defers its remaining quota instead of consuming it, and no lane spawns a ninth enemy. The HUD reports neutralized enemies against the scheduled total. When an enemy reaches an active defender, that defender falls and spends its one emergency discharge to clear the lane. The charge is once per run. A down defender needs two separate matches of its own color to revive; those matches still score and build combo but launch no attack. Later knockdowns do not clear enemies. Any live enemy crossing the far-left boundary ends the run immediately and shows GAME OVER. Once all four spawn budgets are exhausted and all remaining enemies are neutralized, gameplay freezes and a WAVE CLEARED screen shows the final score. Either terminal screen offers a clean restart with fresh quotas; ball generation remains unlimited until that terminal state.

Seven original soft-arcade SFX are synthesized in memory as 22.05 kHz, mono, 16-bit PCM: shoot, successful insert, swap, match, tier-aware defender attack, knockdown, and revival. They use short sine/triangle tones with gentle envelopes, a -15 dB playback level, a 0.28 PCM peak cap, and a ten-voice stealing pool. No audio files, plugins, or runtime dependencies are required. Headless runs generate and validate the clips but skip device playback; actual timbre and loudness still require listening on desktop, Web, and Android.

## Export

The committed `export_presets.cfg` contains `Web` and `Android Debug` presets. Install the **Godot 4.7.2 Standard** export templates matching the editor build before exporting. Mono templates do not satisfy this GDScript editor's template lookup.

Web export and local serving:

```sh
godot --headless --path . --export-release Web exports/web/index.html
cd exports/web
python3 -m http.server 8000
```

Then open `http://127.0.0.1:8000/`. Do not open `index.html` directly with a `file://` URL: WASM/PCK loading requires an HTTP server. The preset uses the non-threaded Web template, so cross-origin-isolation headers are not required. A current browser with WebAssembly and WebGL 2 is required; browser/OS gesture policy can affect focus and fullscreen behavior. The game has no remote URLs or runtime network dependency.

Android debug export requires matching Android export templates plus a JDK and Android SDK configured under Godot's Editor Settings (`Java SDK Path` and `Android SDK Path`). The SDK must include `platform-tools`, a supported platform, build-tools and its `apksigner`. Then run:

```sh
godot --headless --path . --export-debug "Android Debug" exports/android/lane-ball-shooter-debug.apk
adb install -r exports/android/lane-ball-shooter-debug.apk
```

The provisional package ID is `com.shikirashi.laneballshooter`, the preset exports ARM64, and orientation is sensor-landscape. Change the package ID in `export_presets.cfg` before any store submission and configure a private release keystore outside Git; the prototype preset intentionally needs no committed signing secret. Generated Web/APK/AAB files are ignored by Git.

## Regression and playtest checklist

Run the automated suites with the installed Godot binary:

```sh
godot --headless --path . --script res://tests/headless_smoke.gd
godot --headless --path . --script res://tests/p002_logic_test.gd
godot --headless --path . --script res://tests/p003_logic_test.gd
godot --headless --path . --script res://tests/p004_combat_test.gd
godot --headless --path . --script res://tests/p005_survival_test.gd
godot --headless --path . --script res://tests/p006_platform_qa_test.gd
godot --headless --path . --script res://tests/p007_playtest_revision_test.gd
godot --headless --path . --script res://tests/p008_gamefeel_sfx_test.gd
godot --headless --path . --script res://tests/p009_zuma_rollback_test.gd
godot --headless --path . --script res://tests/p010_staged_cascade_test.gd
godot --headless --path . --script res://tests/p011_segment_chain_stress_test.gd
godot --headless --path . --script res://tests/p012_forward_insert_test.gd
godot --headless --path . --script res://tests/p013_shooter_preview_mask_test.gd
godot --headless --path . --script res://tests/p014_causal_rollback_feed_test.gd
godot --headless --path . --script res://tests/p015_gravity_finite_enemies_test.gd
godot --headless --path . --script res://tests/p016_speed_auto_recycle_test.gd
```

For a manual end-to-end smoke test:

1. Resize through the four target landscape sizes. Confirm the small NEXT ball remains directly below the loaded shooter ball at both track edges, the circular 56×56 swap target stays in the upper HUD, and the shooter reaches both extreme chain targets. Fire from both ends; shots should reach the lane in about 0.20 seconds without the swap control intercepting playfield input.
2. Confirm incoming balls begin completely hidden beyond the right edge and reveal smoothly at 102 px/s, continuing indefinitely with frequent pairs and occasional four-to-seven-ball fresh runs. Without shooting, watch several known colors leave LEFT and later re-enter RIGHT in the same FIFO order. During an insertion, verify the shot/settling ball is not clipped for 50 ms and then hands cleanly to the masked conveyor with no duplicate or missing frame. Every existing ball to the LEFT/front should nudge LEFT one slot, while every existing ball to the RIGHT/trailing side stays pinned apart from normal elapsed conveyor travel. No insertion should push anything RIGHT.
3. Arrange RED RED / YELLOW YELLOW / RED RED, then insert YELLOW: first observe the insertion push LEFT, hear insert at contact, see a non-overlapping scale-in and all three yellows rest in-chain for 50 ms, then see/hear one yellow pop. Only after that match-created hole exists should the unsupported left red pair fall RIGHT, accelerate without changing internal spacing, physically contact the source-supported trailing reds and produce the later four-red cascade. Also observe a nonmatching FEED gap close without a pop. Repeat with moving seams and concurrent shots; every unsupported group should eventually reconnect and no ball may overlap.
4. On touch hardware, press/drag anywhere across the full playfield and release: exactly one ball should fire. A HUD swap tap must only swap. Starting outside the playfield, canceling a gesture, or releasing after RESTART must not fire.
5. Watch enemies approach at the slower 0.24-unit/s average: they pause with feet grounded, travel left only during the jump, land, and pause again. Let one touch a defender: it falls and the one-time emergency discharge clears that lane. Make two separate matches of that defender's color to revive it; neither revival match launches an attack, while the next does. Confirm a lane stops spawning after its eighth total enemy.
6. Clear all 32 scheduled enemies and confirm the chain/combat freeze, WAVE CLEARED, final score and tappable RESTART control remain legible. Restart and confirm the HUD returns to 00/32 with one initial enemy in each lane. In a separate run, let an enemy breach and confirm GAME OVER still takes precedence and restarts cleanly.
7. Listen for distinct shoot, successful-insert, swap, match, active-attack, knockdown and revival cues. A miss must have shoot but no insert sound; revival 1/2 has no jingle. Press M to confirm mute. Check that fast cascades remain comfortable.
8. Compare lanes 2 and 4 at 960×540 and 1280×720: BLUE must remain saturated blue and GREEN unmistakably emerald on stripe, defender, projectile and status marker. Verify square versus diamond symbols remain clear. Headless palette-distance tests do not replace this visual check.
9. Serve the Web export over HTTP and repeat touch/swap/audio using browser device emulation, then repeat on a physical Android device after `adb install -r`. Synthetic tests do not replace real browser/notch/multi-touch/audio QA.

For conveyor troubleshooting, enable F3. `U` is the number of unsupported segments, `G` is the number of physical gaps, `V` is the fastest current rightward gravity speed, and `D` is the latest positive world-X displacement. `Q/P` show the stored FIFO queue and eligible count (they must agree), `X` counts left exits, `A` counts returns admitted automatically by ordinary simulation, and `F` counts fresh generations. During a no-match run, both `X` and `A` should rise; total returned plus `Q` equals `X`. During a middle clear, expect positive `U/G/V/D`, visibly right-moving unsupported front balls and a left-moving rightmost pusher train. `I` must remain zero.

Gameplay balance is centralized in `ChainModel`, `ShooterView.SHOT_TRAVEL_TIME`, `MatchProgression`, `Main.SHOOT_COOLDOWN`, `SfxManager`, and the `LaneCombatModel.DEFAULT_*` constants (chain speed/refill/run weights, 50 ms insertion settle, gravity initial speed/acceleration/cap, shot travel/cooldown, combo window, SFX pool/volume, enemy speed/HP/concurrent cap/eight-spawn lane budget, and projectile speed/damage). Team identity always uses both the shared color and DOT/SQUARE/TRIANGLE/DIAMOND geometry. An optional user-selectable high-contrast palette remains an accessibility follow-up; it was not added to this stabilization task because existing 3D materials are instantiated procedurally and the symbol channel already prevents color-only identification.
