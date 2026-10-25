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
- Press F3 to show or hide the P002 chain/cache diagnostics.
- After a lane breach, press R or use the on-screen RESTART button to begin a fresh run.

The layout targets landscape screens and has automated coverage at 960×540, 1280×720, 1600×720 and 2400×1080. Native safe-area information is used when the platform supplies it; Web falls back to the browser canvas with an additional logical edge margin. The 3D SubViewport resolution is capped through integer downscaling on very wide/high-density windows to limit mobile fill cost.

The top lane is a functional ordered chain moving right-to-left at 68 pixels/second: a shot must horizontally overlap a visible ball to insert beside it, contiguous physical groups of three or more clear, and newly connected groups cascade. A separate four-color shuffle-bag feeder continuously admits fresh balls whenever real spacing opens at the right edge, so the supply continues indefinitely without creating an offscreen backlog. Balls that leave on the left enter a FIFO cache; matches request FIFO returns that share right-edge slots with the fresh stream. Live balls remain capped, while the cache intentionally uses linear storage for legitimate exits that have not yet returned. Returned and fresh groups do not become match-adjacent across a physical gap.

Matches award score and advance the three-second combo window through tiers 1–3; the fourth consecutive timely match activates FEVER. The HUD meter drains in real time, while score persists through timeout. Magazine colors come from a fair four-color shuffle bag.

Each match also activates its matching 3D defender using the tier locked at match time. Tier 1 fires one 1-damage projectile, so a standard 2-HP enemy needs two hits. Tier 2 fires two spaced 2-damage projectiles; each can kill a fresh standard enemy. Tier 3 and FEVER replace the old three-shot burst with an immediate clear of the matched lane plus exactly one randomly selected adjacent lane. This clear does not consume either lane's emergency charge, and a down origin defender still receives revival progress instead of attacking.

Primitive enemies spawn independently, display HP pips, and now use a shared logical/visual hop cycle: horizontal X remains stationary during a grounded dwell, advances only through the airborne arc, then pauses again after landing. Projectile sweeps use that same piecewise motion, so both grounded and airborne enemies remain hittable and large frame steps cannot tunnel through them.

When an enemy reaches an active defender, that defender falls and spends its one emergency discharge to clear the lane. The charge is once per run. A down defender needs two separate matches of its own color to revive; those matches still score and build combo but launch no attack. Later knockdowns do not clear enemies. Any live enemy crossing the far-left boundary ends the run immediately, freezes gameplay, preserves the final score, and offers a clean restart.

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
```

For a manual end-to-end smoke test:

1. Resize through the four target landscape sizes. Confirm the chain, four lanes/status labels, shooter track, magazine, and HUD remain distinct and visible.
2. Confirm incoming balls continue indefinitely and move at the faster 68 px/s pace. Mouse-fire a physical chain hit, then make four timely groups: verify tier 1 needs two hits to kill a standard enemy, either tier-2 projectile kills one, tier 3 clears the matching lane plus one adjacent lane, and the fourth match shows FEVER. Confirm right-click/Space swaps without firing.
3. On touch hardware, press/drag in the playfield and release: exactly one ball should fire. A swap tap must only swap. Starting outside the playfield, canceling a gesture, or releasing after RESTART must not fire.
4. Watch enemies pause with their feet grounded, travel left only during the jump, land, and pause again. Let one touch a defender: it falls and the one-time emergency discharge clears that lane. Make two separate matches of that defender's color to revive it; neither revival match launches an attack, while the next does.
5. Let a later enemy cross the left boundary. Confirm the chain/combat freeze, GAME OVER and the tappable RESTART control remain legible, then restart and verify there are no old enemies/projectiles/effects.
6. Serve the Web export over HTTP and repeat touch/swap using browser device emulation, then repeat on a physical Android device after `adb install -r`. Synthetic tests do not replace real browser/notch/multi-touch QA.

Gameplay balance is centralized in `ChainModel`, `MatchProgression`, `Main.SHOOT_COOLDOWN`, and the `LaneCombatModel.DEFAULT_*` constants (chain/refill population, three-second combo window, shot cooldown, enemy speed/HP/spawn cap, and projectile speed/damage). Team identity always uses both the shared color and DOT/SQUARE/TRIANGLE/DIAMOND geometry. An optional user-selectable high-contrast palette remains an accessibility follow-up; it was not added to this stabilization task because existing 3D materials are instantiated procedurally and the symbol channel already prevents color-only identification.
