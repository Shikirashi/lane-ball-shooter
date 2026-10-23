# Codex Handoff — LBS-P006

**Status:** COMPLETE (platform exports configured; artifact generation blocked by missing local export toolchains)

**Branch:** `master`

**Implementation commit:** `2ffcf3f` (`Prepare Web and Android platform readiness`)

**Mailbox:** remains on LBS-P006; task/ledger/decision/protocol files were not changed.

## Implemented

- Added Godot 4.7.2 `Web` and `Android Debug` export presets. Web is non-threaded Compatibility/WebGL 2; Android is ARM64 debug, immersive, provisional package `com.shikirashi.laneballshooter`, and project orientation is sensor-landscape. No signing secret, machine path, or generated artifact is tracked.
- Added a pure responsive layout calculator and used it for 960×540, 1280×720, 1600×720 and 2400×1080 composition. HUD, chain, 3D region, shooter track, magazine, and playfield now derive from the platform safe rectangle.
- Converts native `DisplayServer.get_display_safe_area()` coordinates into logical viewport coordinates, with a full-canvas fallback and 10–18 logical-pixel inner edge padding. GAME OVER text and the 220×54 RESTART button center within the safe rectangle.
- Keeps the swap target at 64×56 logical pixels, updates its hit geometry on resize, and prevents the shooter track from extending beneath the magazine.
- Uses integer SubViewport downscaling above 1600×720 render dimensions and modest aspect-aware orthographic camera sizing. Gameplay coordinates/models are unchanged.
- Hardened touch ownership: one finger owns a playfield gesture; unrelated fingers cannot steal/release it; canceled/focus-lost touches clear without firing; gestures beginning outside never arm; game over/restart clear ownership and cooldown. Touch-to-mouse emulation remains disabled, and GUI swap input does not route into a shot.
- Added `tests/p006_platform_qa_test.gd` with layout/safe-region tests, synthetic Viewport input for touch/mouse/no-accidental-shot cases, restart-release and repeated cleanup coverage, plus enemy/projectile/history boundedness checks.
- Expanded README with export prerequisites/commands, Web local serving/browser notes, Android debug install/package/signing notes, tunable locations, and the requested end-to-end playtest checklist.
- Preserved all P001–P005 chain, FIFO/cache adjacency, progression, magazine, combat, survival and restart behavior.

## Validation

Engine: `Godot 4.7.2.stable.official.ed1daf0bf`.

- `godot --headless --path . --script res://tests/headless_smoke.gd` — `P001 headless smoke: PASS`.
- `godot --headless --path . --script res://tests/p002_logic_test.gd` — `P002 gameplay logic: PASS (59 checks)`.
- `godot --headless --path . --script res://tests/p003_logic_test.gd` — `P003 progression and magazine: PASS (72 checks)`.
- `godot --headless --path . --script res://tests/p004_combat_test.gd` — `P004 lane combat: PASS (44 checks)`.
- `godot --headless --path . --script res://tests/p005_survival_test.gd` — `P005 survival loop: PASS (63 checks)`.
- `godot --headless --path . --script res://tests/p006_platform_qa_test.gd` — `P006 platform QA: PASS (66 checks)`.
- Bounded runtime startup at `--resolution 960x540`, `1280x720`, `1600x720`, and `2400x1080` — exit 0 with no runtime diagnostics.
- Bounded headless editor import — completed; only sandbox-denied local TCP listener diagnostics occurred.
- `git diff --check`, tracked-artifact scan, export credential scan, and runtime external-URL scan — PASS.

### Export attempts

- `godot --headless --path . --export-debug Web /tmp/lbs-p006-export/web/index.html` — exit 1, BLOCKED: matching Standard `web_nothreads_debug.zip` / `web_nothreads_release.zip` templates are absent. No Web files were produced.
- `godot --headless --path . --export-debug "Android Debug" /tmp/lbs-p006-export/android/lane-ball-shooter-debug.apk` — exit 1, BLOCKED: matching Standard `android_debug.apk` / `android_release.apk` templates are absent; Godot has no configured Java/Android SDK paths; installed `/usr/lib/android-sdk` contains only `platform-tools` and lacks SDK platforms, build-tools, and `apksigner`. No APK was produced.
- Local tools found: OpenJDK 21 and `adb` 34.0.4. The only Godot templates present are `4.7.2.stable.mono` Windows templates, which do not satisfy this Standard GDScript editor.

After installing the matching Godot 4.7.2 Standard templates and configuring complete SDK paths, reproduce with:

```sh
godot --headless --path . --export-release Web exports/web/index.html
godot --headless --path . --export-debug "Android Debug" exports/android/lane-ball-shooter-debug.apk
```

Validate Web output includes `index.html` plus generated JS/WASM/PCK files, serve via `cd exports/web && python3 -m http.server 8000`, and install Android with `adb install -r exports/android/lane-ball-shooter-debug.apk`.

## Manual playtest

1. Resize through 960×540, 1280×720, 1600×720 and 2400×1080. Confirm chain balls, all four lanes/status labels, shooter travel, magazine/HUD and GAME OVER/RESTART are unclipped; repeat on a notched landscape device.
2. Desktop: move with mouse X, left-click only in the playfield to fire, right-click/Space to swap, and F3 for diagnostics. Clicking magazine UI must not fire.
3. Touch: press/drag/release in the playfield for exactly one shot. Swap tap must only swap. Test a second finger, canceled gesture, outside-to-inside gesture, game-over touch, and restart-button release; none may add an unintended shot.
4. Reproduce match -> timely tier burst -> fourth-match FEVER -> defender knockdown/emergency -> two separate same-color revival matches -> next-match attack -> later terminal breach -> restart. Confirm P001–P005 behavior and clean entities/effects after restart.
5. Repeat in a served Web build and on a physical Android device. Synthetic input and headless rendering do not establish real-browser/on-device touch, notch, thermal, or FPS results.

## Known limitations / follow-up

- Web/Android artifacts and their file formats could not be validated until the missing templates and Android SDK components are installed.
- No browser or physical-device test was performed, and no FPS/thermal profiling is claimed.
- Team identity continues to use centralized color plus DOT/SQUARE/TRIANGLE/DIAMOND geometry in both 2D and 3D. A runtime high-contrast palette toggle was deliberately left as an accessibility follow-up to avoid risky material replacement during final stabilization.
- Before store submission, replace the provisional package ID and configure a private release keystore outside Git.
