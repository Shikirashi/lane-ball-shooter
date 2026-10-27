# Codex Handoff — LBS-P033 mobile controls, ergonomics and enemy feedback

**Status:** COMPLETE

**Branch:** `master`

## Delivered

- Added deterministic `TouchControlRouter` handling Classic primary absolute aim/release-fire, one secondary down-swap, ignored extra fingers, cancellation/focus/reset cleanup, and Side mode's handed 1:2:1 fixed-role regions. Side aim is relative 1:1 drag with no down teleport or release shot; action taps fire/swap once on down.
- Added an in-game, event-consuming gear/settings panel for Classic/Side and right-/left-handed selection. `ConfigFile` persistence uses safe Classic/right defaults for absent or corrupt data. Native Android detection is test-injectable and hides the legacy swap button; desktop/Web keeps button, right-click and Space behavior.
- Desktop/Web left click now aims and fires anywhere on noninteractive canvas; right click swaps. Existing Controls retain input priority, so settings, restart and Web menu interactions cannot leak gameplay actions.
- Raised the shooter responsively (140-pixel bottom reserve at 1280×720), reflowed the four-lane battlefield above its muzzle, and added a thumb-rest strip. Loaded ammo remains on exact shot X; NEXT is horizontal at the same Y and flips left near the right edge with hysteresis.
- Canonical HP is now Hopper 3, Heavy 6, Sickle Snake 3 and Healyzard 3. Spawn/full/max HP and Healyzard caps agree. Projectile damage, piercing/deduplication, Snake behavior, emergency clear, speeds, budgets, chain and all other combat rules are unchanged.
- Replaced the weak tint with a per-enemy Compatibility canvas shader that mixes textured RGB strongly toward red while preserving alpha. Real damage refreshes the 0.16-second parameter independently. Lethal visuals begin vividly red, then retain the existing explosion, fall and fade; restart removes transient state.

## Real renderer evidence

Reproduce on a graphical session with:

```sh
./scripts/capture_p033_gameplay.sh
```

- `assets/previews/p033_controls_hit_flash_1280x720.png` — SHA-256 `b84acbe4fbfc371913f50302fb6bd9a9eb05f672e7cecd896ca1da86e7b10912`; raised shooter/horizontal ammo, all rows and full-strength red hit.
- `assets/previews/p033_controls_settings_1600x720.png` — SHA-256 `51f93825f967ea3d8f88c2cc13ac39f49d8c0619fec06013bbd87de441229875`; wide framing with the modal control selector.

Both were captured from deterministic live Godot state after `RenderingServer.frame_post_draw` using Godot `4.7.2.stable.official.ed1daf0bf`, OpenGL 4.6 Compatibility, AMD Radeon RX 6700 XT / Mesa 26.2.5, and inspected at rendered resolution. The capture-only `SubViewport` is not part of runtime gameplay.

## Verification

- `./scripts/ci/run_regression_tests.sh`: **PASS — all 27 suites**. P033 adds 43 checks; P011 stress remains **16,485 checks / 2,400 operations**.
- Historical HP and intentionally superseded vertical-ammo/playfield-only input assertions were updated without reducing tier, healing, transfer, cascade or 2D-runtime coverage.
- `./scripts/build_web.sh`: **PASS**, ignored local nine-file release and ZIP rebuilt; no deployment performed.
- `./scripts/ci/validate_web_release.sh exports/web`: **PASS**; PCK SHA-256 `4958642720be7bb33d9e6f29a4fd19f92d864bcde8a0944bba44326f27dc170d`.
- `./scripts/ci/test_android_release_scaffolding.sh`: **PASS**.
- `./scripts/ci/test_android_toolchain_setup.sh`: **PASS**.
- `git diff --check`: **PASS**.

## Limits / preservation

- No Android device was attached, so physical multi-touch, safe-area ergonomics, haptics/audio and device GPU performance remain manual QA. No APK was built, published or replaced; version/signing/release metadata is untouched.
- The Web build was statically validated only. Existing P024 publishing automation was not edited or manually invoked.
- Pre-existing user modifications to `project.godot` and `scenes/main.tscn`, plus unrelated generated UID files, remain present and uncommitted.
- P034A/B/C sprites and crystals remain intact. P028 and every other queued task were not started.

Stop after P033.

---

# Previous handoff — LBS-P034C charge crystal revision

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
