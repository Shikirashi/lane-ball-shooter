# Codex Handoff — LBS-P034A 3D-to-2D sprite baking

**Status:** COMPLETE

**Branch:** `master`

## Implementation

- Added `ActorVisualFactory`, now shared by the live `LaneActor` and the capture tool. Enemy and defender primitive meshes, dimensions, materials, names, Hopper horns, Healyzard scale/aura setup, launcher and charge orb remain sourced from one implementation; gameplay behavior is unchanged.
- Added the CLI baker `tools/bake_actor_sprites.gd` plus `scripts/bake_actor_sprites.sh`. It uses a transparent 512×512 `SubViewport`, the live battlefield's orthographic viewing direction, ambient/directional lighting, Compatibility OpenGL, 4× MSAA, and waits for `RenderingServer.frame_post_draw`. No screenshot scraping, chroma key, external art or dummy headless capture is used.
- Baked eight normal/resting RGBA masters under `assets/sprites/baked/`: `enemy_hopper.png`, `enemy_heavy.png`, `enemy_sickle_snake.png`, `enemy_healyzard.png`, and `defender_red/blue/yellow/green.png`.
- Added `pivots.json` with each silhouette's alpha bounds and grounded pivot. Floors and shadows are deliberately excluded from the individual actors.
- Added `contact_sheet.png` (1088×544 checkerboard; enemies top row, defenders bottom row).
- Added isolated `scenes/previews/p034a_sprite_preview.tscn`. It uses only 2D drawing, labels and eight `Sprite2D` nodes, with Hopper hop/spring, Heavy squash, Snake wiggle, Healyzard pulse and defender recoil/knockdown-style loops. It is not referenced by normal boot/main gameplay or exports.
- Added `tests/p034a_sprite_baking_test.gd` with 107 deterministic asset/alpha/pivot/source-factory/preview-wiring checks and documented commands in README.

## Rendering and verification

- Engine: Godot `4.7.2.stable.official.ed1daf0bf`.
- Capture renderer: OpenGL 4.6 Compatibility on AMD Radeon RX 6700 XT (Mesa 26.2.5), using existing X display `:0` noninteractively.
- `./scripts/bake_actor_sprites.sh`: **PASS**, eight RGBA PNGs plus metadata/contact sheet.
- Immediate second bake on the same engine/GPU: **byte-identical PASS** for every PNG and `pivots.json`. This determinism is scoped to this renderer/toolchain; other GPUs/drivers can legitimately rasterize edge samples differently.
- `godot --path . --audio-driver Dummy --rendering-method gl_compatibility res://scenes/previews/p034a_sprite_preview.tscn -- --p034a-smoke`: **PASS**, real renderer, clean one-second startup/animation exit.
- `./scripts/ci/run_regression_tests.sh`: **all 24 suites passed** (P001–P023 plus P034A), including P011's 16,485-check stress suite.
- P034A checks confirm every master is 512×512 RGBA, has transparent corners and over 150,000 fully transparent pixels, nonempty colored/opaque actor pixels, multisampled partial-alpha edges, no meaningful RGB fringe in zero-alpha pixels, valid grounded metadata, and loads into `Sprite2D`.
- P019/P020 source-model and ability suites pass after the visual-factory extraction. The playable game's start scene, cameras, input, combat, balance, Web/Android identity and runtime 3D battlefield remain unchanged.

## Review

```sh
./scripts/bake_actor_sprites.sh
godot --path . res://scenes/previews/p034a_sprite_preview.tscn
```

Review `assets/sprites/baked/contact_sheet.png` directly for silhouettes/materials and run the preview for relative scale, grounded pivots and illustrative 2D motion.

## Limitations / future scope

- P034A bakes only the requested standing/resting masters. Ground shadows, Healyzard glow, hit flashes, projectile/attack frames, muzzle flash, death explosion/fall/fade, full defender knockdown/revival states and additional animation frames remain live 3D effects; they require explicit treatment if P034B is later approved.
- The preview's squash/stretch is an isolated motion study, not a gameplay renderer or final animation timing decision.
- A real display/GPU or safe offscreen OpenGL display is required to rebake; the wrapper intentionally rejects a display-less dummy-headless environment.
- Pre-existing user edits to `project.godot`, `scenes/main.tscn`, and unrelated generated `.uid` files were preserved and excluded from this task's commit.

Stop after P034A. P034B, P033, P028 and other roadmap tasks were not implemented or activated.
