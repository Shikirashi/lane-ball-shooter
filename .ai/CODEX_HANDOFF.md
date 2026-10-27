# Codex Handoff — LBS-P034B live 2D gameplay conversion

**Status:** COMPLETE

**Branch:** `master`

## Implementation

- Replaced the ordinary gameplay `SubViewportContainer`/`SubViewport`/`Camera3D` battlefield with a direct 2D `Battlefield` `Control` containing four `LaneActor` row controls. Normal main-scene startup now instantiates no `Node3D`, `Camera3D`, `WorldEnvironment`, 3D mesh or hidden render viewport.
- Preserved `LaneCombatModel` and the existing global `Battlefield` director as the only gameplay authorities. Enemy HP/motion, Hopper phases, quotas and weighted spawning, Snake uniqueness/cooldown/transfer, Healyzard healing, projectile swept hits, breach/victory, attack targeting and seeded test hooks are unchanged.
- Live defenders and all four enemy types now use the authentic P034A transparent PNGs and `pivots.json`. Responsive `Sprite2D` deformation supplies Hopper hop/squash, Heavy weight, Snake wiggle and cross-row transfer, Healyzard idle, defender recoil/knockdown/revival and per-hit feedback without altering collision positions or timing.
- Rebuilt presentation effects in 2D: animated shadows, normal/piercing/two-lane wide projectile shapes, healer aura, hit tint, muzzle flash, emergency/revival/tier waves, and enemy burst/sparks/tumble/fade. Death animation updates remain independent of frozen combat during the three-second victory delay. Existing SFX event hooks are intact.
- The spent emergency state dims the entire baked defender plus its charge orb and displays `SPENT`, so the embedded yellow orb cannot be mistaken for a live charge after knockdown or rotation.
- Responsive framing now places the battlefield two pixels below the conveyor and ends it 54 pixels above the shooter center. Four equal rows fill that rectangle; authoritative combat X maps into 5.5% internal side margins. Visual controls ignore mouse input, preserving drag/release fire, cursor fire and HUD swap routing.
- P034A's factory, baker, transparent masters, contact sheet and isolated preview remain intact for regeneration/review, but are not instantiated as a live 3D fallback.

## Required renderer evidence

- Added `tools/capture_p034b_gameplay.gd` and executable `scripts/capture_p034b_gameplay.sh`. The wrapper rejects a display-less environment and invokes the actual Compatibility renderer; a capture-only `SubViewport` renders the real `main.tscn`, deterministic live models and real 2D effects after completed frames. This viewport exists only in the evidence tool.
- Committed real gameplay captures:
  - `assets/previews/p034b_gameplay_1280x720.png` — 1280×720, SHA-256 `0629e38b135af41e43b8215c24b717fd4ed8b4c7c7c827dfc6e1983f26a20b5f`
  - `assets/previews/p034b_gameplay_1600x720.png` — 1600×720, SHA-256 `9b39eeea715b5da5a9df00fe05b54fd1f90202d5d7589ca768962ac25cf86be5`
- Reproduce with `./scripts/capture_p034b_gameplay.sh`. Capture passed with Godot `4.7.2.stable.official.ed1daf0bf`, OpenGL 4.6 Compatibility, AMD Radeon RX 6700 XT and Mesa 26.2.5. Both images were inspected at original resolution after the final spent-state correction.

## Tests and builds

- `./scripts/ci/run_regression_tests.sh`: **PASS — all 25 suites** (P001–P023, P034A and P034B). This includes P011's 16,485-check/2,400-operation chain stress suite and P034A's 107 transparency/source-fidelity checks.
- New `tests/p034b_live_2d_battlefield_test.gd`: **PASS — 94 checks**. It verifies no live 3D/viewport nodes, four responsive rows at 960×540 through 2400×1080 plus cutout-safe layout, 5.5% world-X mapping, mouse pass-through, all eight baked actor sprites and transparency, hop transform, healer aura, two-lane projectile shape, death fall/fade and the committed renderer captures.
- Narrowly updated old renderer-specific assertions in P001/P006/P011/P018/P019/P020 from meshes/camera/Z to equivalent 2D nodes/textures/Y while preserving their model/combat assertions.
- `./scripts/capture_p034b_gameplay.sh`: **PASS**, two real Compatibility-renderer screenshots.
- `./scripts/build_web.sh`: **PASS**, new nine-file single-threaded Compatibility Web export and ZIP generated locally under ignored `exports/`.
- `./scripts/ci/validate_web_release.sh exports/web`: **PASS**, exact nine-file set, nonempty files, WASM/PCK/PNG magic and relative runtime references. New PCK SHA-256: `a3409bf4a52dc5516a2c93a0b8a44628a2f17e184792ca3a012a60328a57fb72`.
- Editor/import runs emit expected sandbox-only warnings for blocked TCP/ADB and inability to save `/home/shiki/.config/godot/editor_settings-4.7.tres`; all commands exit successfully and those warnings do not affect project files or results.

## Documentation and preservation

- README now describes the all-2D live runtime, responsive framing, sprite provenance, screenshot command/assets and P034B regression command.
- Pre-existing user edits to `project.godot`, `scenes/main.tscn`, and unrelated generated `.uid` files were preserved and excluded from the task commit. Generated Web binaries remain ignored and were not committed.

## Limitations / follow-up QA

- No physical Android device was attached, so touch feel, GPU performance, audio and cutout behavior still need a real-device playtest. No Android release/APK was rebuilt or published by P034B.
- The Web artifact was built and statically validated locally; P034B does not publish it or alter the existing deployment workflow/public portfolio release.
- Gameplay screenshots are deterministic staged review fixtures rather than recordings of a full human playthrough. Automated suites cover control routing and combat semantics; final motion feel and sprite legibility remain appropriate visual playtest items.

Stop after P034B. P033, P028 and all other proposed tasks were not implemented or activated.
