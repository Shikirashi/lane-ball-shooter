# Lane Ball Shooter

A hybrid 2D/3D lane-defense game prototype in **Godot 4 / GDScript**, targeting Web and Android (landscape).

- 2D Zuma-like moving ball chain, shooter and two-ball swap magazine.
- Four 3D horizontal combat lanes with primitive defenders and hopping enemies.
- Matches activate same-color defender attacks; successive matches build combo/fever.
- Balls exiting left are cached for re-entry; defenders have an emergency lane clear and require matching-color revival.

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
- On touch devices, press and drag in the playfield, then release to fire once. Tap the magazine's center swap control to swap without firing.
- Press F3 to show or hide live ball/segment/gap/rollback/invariant diagnostics.
- Press M to mute or unmute procedural sound effects.
- After a lane breach, press R or use the on-screen RESTART button to begin a fresh run.

The layout targets landscape screens and has automated coverage at 960×540, 1280×720, 1600×720 and 2400×1080. Native safe-area information is used when the platform supplies it; Web falls back to the browser canvas with an additional logical edge margin. The shooter track now spans the chain's full safe width with symmetric 24-pixel edge margins, so both edge balls are targetable. Loaded/next indicators and the 64×56 swap button form a compact HUD-right panel above the chain, outside the firing playfield; it no longer blocks right-side aiming or touch drags. The 3D SubViewport resolution is capped through integer downscaling on very wide/high-density windows to limit mobile fill cost.

Player-fired balls cross from their launch position to the upper lane in 0.20 seconds at every supported landscape height. Each shot locks its launch X and identity, while the 0.4-second firing cooldown remains unchanged.

The top lane is a functional ordered chain moving right-to-left at 34 pixels/second. Its authoritative physics state is an ordered list of rigid connected segments: each segment owns one anchor plus persistent UID/color members at exact 58-pixel slots. The `balls` array consumed by drawing is derived from those anchors rather than moved independently. Typed feeder and player-causal edges hold real distance between segments; one deterministic integration/constraint pass moves them and clamps contact before any merge. Logical and rendered neighbors therefore remain ordered and non-overlapping through rapid insertions, simultaneous rollbacks, feed joins and cascades.

A shot must horizontally overlap a visible ball using the physical 22-pixel chain radius plus the projectile's 12-pixel radius. On contact, an accepted shot becomes a real UID-addressed member immediately. Because the conveyor flows right-to-left, insertion opens one legal slot by pushing the existing LEFT/front prefix exactly 58 pixels LEFT in the normal flow direction; the old RIGHT/trailing suffix remains at its world X and is never shoved backward. At a typed segment seam, every preceding segment receives the same leftward slot displacement, preserving the FEED/CAUSAL gap's identity, width and motor state. A short scale-in supplies visual settling without changing authoritative center spacing. Its player-caused match check waits exactly 0.05 seconds of gameplay simulation time, so the completed group remains visible before its first pop. The insert/plop cue occurs at contact; match scoring, combo progression, defender response and match SFX occur only when that delayed check actually removes a group.

A successful clear preserves the removed balls' spatial gap. The contiguous left/front/exit-side section then rolls backward to the right as one rigid group, starting at 60 px/s, accelerating at 900 px/s² and capping at 420 px/s. Every member receives the same rollback displacement while the trailing/right section continues only its normal conveyor travel. Logical and rendered rollback positions move together, so shots can hit retracting balls accurately. Same-color ends cascade only on physical contact and emit a separate later match event; different colors simply merge. Multiple gaps are tracked by stable ball UIDs, and a right-tail clear uses a short bounded recoil. Simulation is event-bounded at settle deadlines and subdivided to at most 1/60 second, preserving insert → pause → initial pop → accelerating rollback → contact cascade order even for a larger update.

This rollback is player-causal rather than a passive board scan. The independent fresh feeder intentionally builds same-color runs using weights of 20%, 30%, 18%, 13%, 9%, 6% and 4% for lengths 1 through 7. Pairs are common and runs of four to seven are valid, but pre-existing groups never clear merely because they spawn, move, reconnect through ordinary feed/cache catch-up, or return from cache. Only a matching player insertion starts a clear and its causally linked physical cascades. The magazine remains a separate fair four-color shuffle bag.

Fresh balls are continuously admitted through the same segment-edge system whenever one legal slot opens at the right boundary, so the supply continues indefinitely without creating an offscreen backlog or filling an internal match hole. Balls that leave on the left enter a FIFO cache; matches request FIFO returns that share this one admission path with the fresh stream. A distant return batch forms a typed feeder segment and closes physically before merging. Live automatic population remains capped at 24, while the cache intentionally uses linear storage for legitimate exits that have not yet returned. Returned and fresh groups never auto-match merely because their noncausal edge reconnects.

The canonical palette is shared by balls, magazine/shooter, lane stripes, defenders and projectiles. BLUE is a saturated `#3677E8` and GREEN an emerald `#37C45A`; neutralized battlefield ambient light preserves that distinction. DOT/SQUARE/TRIANGLE/DIAMOND symbols and enlarged lane status labels remain the redundant non-color identity channel.

Matches award score and advance the three-second combo window through tiers 1–3; the fourth consecutive timely match activates FEVER. The HUD meter drains in real time, while score persists through timeout. Magazine colors come from a fair four-color shuffle bag.

Each match also activates its matching 3D defender using the tier locked at match time. Tier 1 fires one 1-damage projectile, so a standard 2-HP enemy needs two hits. Tier 2 fires two spaced 2-damage projectiles; each can kill a fresh standard enemy. Tier 3 and FEVER replace the old three-shot burst with an immediate clear of the matched lane plus exactly one randomly selected adjacent lane. This clear does not consume either lane's emergency charge, and a down origin defender still receives revival progress instead of attacking.

Primitive enemies spawn independently, display HP pips, and use a shared logical/visual hop cycle averaging 0.24 world units/second: horizontal X remains stationary during a grounded dwell, advances only through the airborne arc, then pauses again after landing. Projectile sweeps use that same piecewise motion, so both grounded and airborne enemies remain hittable and large frame steps cannot tunnel through them.

When an enemy reaches an active defender, that defender falls and spends its one emergency discharge to clear the lane. The charge is once per run. A down defender needs two separate matches of its own color to revive; those matches still score and build combo but launch no attack. Later knockdowns do not clear enemies. Any live enemy crossing the far-left boundary ends the run immediately, freezes gameplay, preserves the final score, and offers a clean restart.

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
```

For a manual end-to-end smoke test:

1. Resize through the four target landscape sizes. Confirm the compact magazine stays in the upper HUD, the 64×56 swap target remains comfortable, and the shooter reaches both extreme chain targets. Fire from both track ends; balls should reach the upper lane in about 0.20 seconds without the right-side UI intercepting input.
2. Confirm incoming balls continue indefinitely at 34 px/s and frequently form pairs plus occasional four-to-seven-ball runs. Insert between two visible groups: every existing ball to the LEFT/front should nudge LEFT one slot, while every existing ball to the RIGHT/trailing side stays pinned apart from normal elapsed conveyor travel. At the left end, the new ball may occupy the new left slot without moving the old train; at the right end, the existing train moves LEFT and the inserted ball occupies the old tail position. No insertion should push anything RIGHT.
3. Arrange RED RED / YELLOW YELLOW / RED RED, then insert YELLOW: first observe the insertion push LEFT, hear insert at contact, see a non-overlapping scale-in and all three yellows rest in-chain for 50 ms, then see/hear one yellow pop. Only after that match-created hole exists should the left red pair reverse RIGHT, accelerate without changing internal spacing, physically contact the trailing reds and produce the later four-red cascade. Repeat with moving seams and concurrent shots; no ball may overlap.
4. On touch hardware, press/drag anywhere across the full playfield and release: exactly one ball should fire. A HUD swap tap must only swap. Starting outside the playfield, canceling a gesture, or releasing after RESTART must not fire.
5. Watch enemies approach at the slower 0.24-unit/s average: they pause with feet grounded, travel left only during the jump, land, and pause again. Let one touch a defender: it falls and the one-time emergency discharge clears that lane. Make two separate matches of that defender's color to revive it; neither revival match launches an attack, while the next does.
6. Let a later enemy cross the left boundary. Confirm the chain/combat freeze, GAME OVER and the tappable RESTART control remain legible, then restart and verify there are no old enemies/projectiles/effects.
7. Listen for distinct shoot, successful-insert, swap, match, active-attack, knockdown and revival cues. A miss must have shoot but no insert sound; revival 1/2 has no jingle. Press M to confirm mute. Check that fast cascades remain comfortable.
8. Compare lanes 2 and 4 at 960×540 and 1280×720: BLUE must remain saturated blue and GREEN unmistakably emerald on stripe, defender, projectile and status marker. Verify square versus diamond symbols remain clear. Headless palette-distance tests do not replace this visual check.
9. Serve the Web export over HTTP and repeat touch/swap/audio using browser device emulation, then repeat on a physical Android device after `adb install -r`. Synthetic tests do not replace real browser/notch/multi-touch/audio QA.

Gameplay balance is centralized in `ChainModel`, `ShooterView.SHOT_TRAVEL_TIME`, `MatchProgression`, `Main.SHOOT_COOLDOWN`, `SfxManager`, and the `LaneCombatModel.DEFAULT_*` constants (chain speed/refill/run weights, 50 ms insertion settle, rollback initial speed/acceleration/cap, shot travel/cooldown, combo window, SFX pool/volume, enemy speed/HP/spawn cap, and projectile speed/damage). Team identity always uses both the shared color and DOT/SQUARE/TRIANGLE/DIAMOND geometry. An optional user-selectable high-contrast palette remains an accessibility follow-up; it was not added to this stabilization task because existing 3D materials are instantiated procedurally and the symbol channel already prevents color-only identification.
