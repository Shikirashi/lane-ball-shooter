# Codex Handoff — LBS-P034C charge crystal revision

**Status:** COMPLETE

**Branch:** `master`

**Implementation commit:** `16347b377d044702c7748a94ebb53f8bce435e57`

## Implementation

- Removed `ChargeOrb` creation and the `charge_orb` return entry from `scripts/world/actor_visual_factory.gd`. Defender body, head, visor, launcher, hidden muzzle flash, palette, camera and lighting remain unchanged.
- Ran the real `./scripts/bake_actor_sprites.sh` Godot/OpenGL baker twice. The four defender PNGs, contact sheet and pivot bounds were regenerated from the source model with genuine transparency and no isolated yellow orb. Both runs were byte-identical. All four enemy PNG hashes remained exactly unchanged.
- Replaced P034B's obsolete cover polygon/full-defender dimming with one separate procedural `Node2D` crystal per lane. Each crystal has team-colored dark/bright facets, highlight, outline and subtle glow; it sits behind and rear-left of the full-color defender and scales responsively.
- The existing authoritative `emergency_discharged` signal now triggers exactly one deterministic seven-shard burst. Shards fly, rotate, shrink and fade over 0.52 seconds while the intact crystal disappears immediately. Direct/loaded spent state hides without faking a burst, revival leaves it absent, and `reset_run()` clears particles and restores the intact crystal with the model charge.
- No gameplay rules, combat accounting, controls, lane framing, balance, SFX routing, package identity, Android release or deployment credentials changed.

## Rebaked assets

- `assets/sprites/baked/defender_red.png` — SHA-256 `2b67b74546563334b7f59e90ef778f621a712e5a12b468732dbf79d1d8bce54f`
- `assets/sprites/baked/defender_blue.png` — SHA-256 `672fe28dfc43e7c09d2e0a1a38d1d549eabcd5e0db99488ef439bbf1bedcc082`
- `assets/sprites/baked/defender_yellow.png` — SHA-256 `01f48a6c74f5e18a39a60056b0553d192972206f1fc4cbd232524087ee858cd5`
- `assets/sprites/baked/defender_green.png` — SHA-256 `fe080ed1de22c4f263003d4beac09e875ae46c43d8169746c727438acff1b7d8`
- `assets/sprites/baked/contact_sheet.png` — SHA-256 `18f3ffa57a50a8c57da43bc88d70d495b7802bd1559f70f40dd80b53607758df`
- `assets/sprites/baked/pivots.json` — SHA-256 `6cf3c5fbc92a57fc498cc29056d12712c6b83dd2ee0bfe89623c0b52a917c7c0`

The defender alpha bounds moved from X=95/width=362 to X=158/width=299 while retaining the grounded Y pivot at 420, which is the expected removal of the isolated rear orb. Automated checks also require zero alpha throughout its former image region.

## Real renderer evidence

Reproduce with:

```sh
./scripts/capture_p034c_crystals.sh
```

- `assets/previews/p034c_crystal_states_1280x720.png` — intact red/blue/yellow crystals and full-color spent/down green defender; SHA-256 `29088e99cd3ae09ffad4d45e412d98e881ab9bc297ba5eba0db3ec7524325e1c`.
- `assets/previews/p034c_crystal_shatter_1600x720.png` — intact red/blue, authoritative yellow mid-shatter, and spent green; SHA-256 `fbde34819f862794f01c7f4752f6dcab27621e18c31ccd4f9bff54768c1f54bd`.
- Capture and bake used Godot `4.7.2.stable.official.ed1daf0bf`, OpenGL 4.6 Compatibility, AMD Radeon RX 6700 XT, Mesa 26.2.5 and the existing display. Both screenshots were inspected at original resolution. Capture exits cleanly with audio muted and no leaked-object warning.

## Verification

- `./scripts/bake_actor_sprites.sh` twice: **PASS**, byte-identical outputs on the same engine/GPU.
- `./scripts/capture_p034c_crystals.sh`: **PASS**, two real-renderer gameplay screenshots.
- `./scripts/ci/run_regression_tests.sh`: **PASS — all 26 suites** (P001–P023, P034A, P034B, P034C).
- P011 stress: **PASS**, 16,485 checks / 2,400 operations.
- Updated P034A: **PASS**, 108 checks including no source `ChargeOrb`.
- New `tests/p034c_charge_crystal_test.gd`: **PASS**, 85 checks covering source/bake transparency, four team colors, layering/placement, responsive/cutout layout, input pass-through, authoritative one-time shatter, bounded shard lifetime, no revival respawn, restart restoration, full-color spent defender, 2D-only runtime and renderer evidence.
- `./scripts/build_web.sh`: **PASS**, local ignored Web build and ZIP created.
- `./scripts/ci/validate_web_release.sh exports/web`: **PASS**, exact nine runtime files and valid formats/references. PCK SHA-256 `1d305609bf5996c9b53b085075ae07818019e1626531dd388ae131e7eb981d7a`.

Expected sandbox-only editor warnings about blocked TCP/ADB and inability to save user-global Godot editor settings appeared during headless import; commands still exited successfully and project validation passed.

## Manual review / limitations

- Visually confirm the crystal remains legible during normal motion at 960×540 and 2400×1080; trigger a defender contact and verify the matching crystal alone shatters while the defender stays vibrant. Revive with two matches and confirm the crystal stays absent; restart and confirm all four return.
- No physical Android device was attached, so touch, audio, and GPU performance still require device QA. No APK was rebuilt or released.
- The local Web artifact was statically validated; the existing P024 workflow is expected to build/publish after push. This task did not edit or invoke portfolio credentials.
- Pre-existing user changes to `project.godot`, `scenes/main.tscn`, and unrelated generated `.uid` files remain preserved and outside both P034C commits.

Stop after P034C. P033, P028 and all unrelated tasks were not implemented or activated.
