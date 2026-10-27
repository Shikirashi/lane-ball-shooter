# Codex Handoff — LBS-P035 Android 0.2.0 release

**Status:** COMPLETE

**Branch:** `master`

## Published release

- Release source/tag: `3d08d8e2e75dd1b4068ef87e46ca699134137528` / `android-v0.2.0`. The annotated tag dereferences to that exact tested commit. Release: https://github.com/Shikirashi/lane-ball-shooter/releases/tag/android-v0.2.0
- Public asset: https://github.com/Shikirashi/lane-ball-shooter/releases/download/android-v0.2.0/lane-ball-shooter-android.apk
- APK: `com.shikirashi.laneballshooter`, versionName `0.2.0`, versionCode `2`, ARM64-v8a only, min SDK 24, target SDK 36, 27,472,312 bytes, SHA-256 `d207eda8e5d7a011c9acb7bbf4d81a37238bf9e4b301d4007e6ce6f551f569aa`.
- `apksigner` verified one RSA-4096 release signer with v2/v3 signatures. Certificate SHA-256 `796f2c679d962a8195ebf1a38d959002829561dfd26d2dae86e52ccdec7224fc` exactly matches the downloaded v0.1.0 APK, preserving same-package update compatibility. The old `android-v0.1.0` tag/release/asset remains unchanged.
- Built from a detached clean worktree with Godot 4.7.2, the existing Temurin JDK 17, Android SDK/build-tools 35.0.1 and original protected release identity. No signing material was regenerated, copied into Git, printed, or changed. The public asset was downloaded again and matched the local build byte-for-byte; the downloaded signer also matched.

## Included current gameplay

- The release source includes the live mild (+50% maximum) eligible-threat-aware run-color selector with exact baseline/no-RNG fallback when no legal color is urgent, unchanged four-color bag, 102 px/s conveyor and `[20,30,18,13,9,6,4]` run weights.
- It includes the P034 all-2D battlefield/sprites and charge crystals, P033 Classic/Side Android controls and red hit silhouettes, HP 3/6/3/3, and P028B-UIFIX terminal overlay at absolute z-index 200. No additional balance, content, permission, package, ABI or branding changes were made.
- Both Android Debug and Android Release presets now use version `0.2.0` / code `2`. The release verifier and fail-closed scaffolding tests require those values while retaining package, signature, ABI, debuggable, alignment and permission checks.

## Portfolio and Web verification

- Portfolio commit `f9519864037c5cdd93c82235c05c6b16d9c612c0` updates only the existing Lane Ball Shooter card URL and visible version label. No duplicate card, thumbnail, unrelated tile, CSS/JS, or `lane-ball-shooter/` Web file changed.
- Portfolio Pages run `40605307320`: **SUCCESS**. Live root HTML has exactly one APK card and one v0.2.0 asset URL.
- Game Web build/publish run `40604815821`: **SUCCESS** from release source `3d08d8e`; its portfolio Pages run `40605015305` also succeeded before the card update.
- All nine public Web runtime URLs return HTTP 200. `verify_browser_startup.mjs` passed against https://shikirashi.github.io/lane-ball-shooter/ with secure context, title `Lane Ball Shooter`, one 1280×633 live canvas and no loader.

## Verification

- `./scripts/ci/run_regression_tests.sh`: **PASS, all 31 suites**, including P028B mild live/restart (19 checks), P018 terminal layer (44 checks), P011 stress (16,485 checks / 2,400 operations), current 2D/control/crystal suites and all earlier gameplay regressions.
- `scripts/ci/test_android_release_scaffolding.sh`: **PASS**. `scripts/ci/test_android_toolchain_setup.sh`: **PASS**. Shell syntax checks: **PASS**.
- Clean `./scripts/build_android.sh` and `scripts/verify_android_release.sh`: **PASS**. Verified package/version, non-debuggable status, ARM64-only ABI, min/target SDK, no unexpected sensitive permissions, v2/v3 signature and zip alignment.
- Public APK direct-download hash and signer comparison: **PASS**. GitHub release is public, non-draft and non-prerelease with the required stable asset name.
- Portfolio diff/card count, exact-nine preservation, public HTML, Pages workflow, all-nine HTTP and live browser startup checks: **PASS**.

## Limits and preservation

- No Android device was attached. `adb devices -l` returned an empty list, so physical install/update, touch ergonomics, audio, background/resume, heat and device performance remain manual QA. Recommended update command: `adb install -r lane-ball-shooter-android.apk`.
- The first clean export attempt correctly failed until the existing Godot user setting for the JDK was restored to the already installed JDK 17; no SDK/JDK reinstall or license action was performed.
- Existing user modifications to `project.godot`, `scenes/main.tscn`, and generated UID files remain uncommitted and untouched. APKs remain outside source and portfolio Git history.

---

# Previous handoff — LBS-P028B-EXPR eligible-threat correction

**Status:** COMPLETE

**Branch:** `master`

## Correction delivered

- Corrected the simulation-only `ThreatRunSelector` to calculate urgency over the colors still legal in the current four-color bag. If no legal color has positive urgency, it returns the original baseline candidate exactly, consumes no bias RNG and does not reshuffle unrelated colors.
- Preserved adaptive selection when at least one legal color is genuinely threatened. This includes the case where the globally most urgent color is exhausted but a secondary threatened color remains legal.
- Split diagnostics into world-active threat, eligible legal urgency, no-eligible urgency, actual interventions, ineligible interventions and bias RNG draws. Schema-v2 JSON and both CSVs expose those counters; compatibility aliases remain inside selector summaries only.
- Expanded the deterministic P028B suite from 29 to 574 checks. It repeatedly exercises `[BLUE, YELLOW, GREEN]` with only exhausted RED urgent across mild/moderate/strong, proves exact baseline output and zero RNG draws, verifies secondary BLUE urgency remains eligible, and proves the fallback plus observer leave the subsequent RNG sequence unchanged.

## Corrected experiment and findings

Command: `./scripts/analyze_threat_bias.sh --seeds 500 --scenario-seeds 12 --seed-start 29001 --duration 90 --step 0.1 --output analysis/reports/p028b_exp`

- Godot `4.7.2.stable.official.ed1daf0bf`; 500 paired synthetic seeds × 300 balls × five schedules × four arms; 144 authentic model scenarios, 36 paired seed/policy cases per arm; canonical runtime 80.62 seconds.
- The `urgent_exhausted` schedule produced 51,099 world-threat selections per arm. Only 500 had an urgent legal color; all 50,599 no-eligible states per adaptive arm had zero interventions and zero bias RNG draws. Ineligible interventions were zero across every schedule and arm. Bag and immediate-repeat violations remained zero.
- The corrected results no longer support moderate as the leading candidate. Mild is merely the least-bad later human-A/B candidate: summed paired threatened-starvation deltas were -0.27 seconds for `basic_matcher` and -1.53 seconds for `delayed_matcher`, but basic BLUE worsened by +0.43 seconds and delayed YELLOW by +0.05 seconds.
- Moderate worsened the basic-policy total by +0.65 seconds and delayed RED by +0.63 seconds. Strong worsened both playing-policy totals (+0.58 / +0.49 seconds). All 12 seeds per playing-policy arm still won, which reinforces that the bots do not establish human difficulty. Recommendation: ship none; only mild merits a later human A/B, and only as an explicitly unapproved experiment.
- A second independent full run reproduced `scenario_summary.csv` and `baseline_comparison.csv` byte-for-byte. JSON was identical after removing timestamp, runtime and output path.

## Verification

- Focused P028B suite: **PASS, 574 checks**.
- Smoke workload: **PASS**, 8 synthetic seeds and 24 authentic scenarios.
- Full workload above: **PASS**, twice; canonical 80.62 seconds, repeat 80.74 seconds; deterministic CSV/normalized-JSON hashes matched.
- `./scripts/ci/run_regression_tests.sh`: **PASS, all 30 suites**; P011 remains 16,485 checks / 2,400 operations, P028A remains 38 checks, and P028B now passes 574 checks.
- Exact-nine Web release validation: **PASS**; unchanged PCK SHA-256 `95bd5ebffb7e52dc739bc03645d79ec16823b431f8a45a34a3aaae3f0718a901`.
- `git diff --check`: **PASS**.

## Preservation and limitations

- This remains analysis-only. No playable `Main` instance installs the selector; production colors, 102 px/s conveyor speed, `[20,30,18,13,9,6,4]` run weights, HP 3/6/3/3, spawning, controls, graphics, Web or Android release settings are unchanged.
- The same P028B bot and bounded-seed limitations remain. Correct selection accounting removes the confound but cannot turn exact-perception automated policies into human playtest evidence.
- Existing user modifications to `project.godot`, `scenes/main.tscn`, and unrelated generated UID files remain uncommitted and untouched.

---

# Previous handoff — LBS-P028B-EXP threat-aware generator study

**Status:** COMPLETE

**Branch:** `master`

## Delivered

- Added an analysis-only, per-instance fresh-run selector/observer seam to `ChainModel`. With no selector—the state of every playable instance—the original bag branch and fresh RNG calls remain exact. A 420-ball regression compares the untouched and observed paths byte-for-byte.
- Added `ThreatRunSelector`, implementing baseline and mild/moderate/strong boosts of 0/0.5/1.5/3.0 with `urgency = clamp((15 - live_ttd) / 12, 0, 1)`. It can reorder only currently legal entries in the real four-color bag, never immediately repeats when another color is legal, records exhausted urgent colors, and returns the exact baseline candidate without drawing bias RNG when no threat is active.
- Extended `BalanceLab.run_scenario()` without changing existing call behavior. Harness-owned adaptive instances receive actual live `Battlefield` time-to-danger immediately before chain advance (at most the configured 0.1-second snapshot lag), while authentic chain, run lengths, magazine, 0.20-second fixed-X shots, settling, matching, progression, attacks, spawn director and terminal rules continue to run.
- Added exact first-fresh-UID tracking from run selection to first visibility and first visible adjacent pair, plus first subsequent real match of that color. Added 5/10/15/20-second danger bands, adaptive intervention diagnostics and a deterministic `delayed_matcher` with an invented 1.2-second decision cadence to expose more pressure without free actions or fake damage.
- Added `./scripts/analyze_threat_bias.sh`, synthetic fixture sweeps, a Godot report generator, and stable schema-v1 JSON/CSV/Markdown artifacts under `analysis/reports/p028b_exp/`.
- Added `p028b_threat_bias_test.gd` covering exact baseline/no-threat equivalence, determinism, bag fairness, no repeats, partial bags, monotonic controlled urgency response, unavailable urgent colors, RNG isolation, live Battlefield danger, Healyzard exclusion, accounting, fixed-X misses and unchanged production constants.

## Executed workload and findings

Command: `./scripts/analyze_threat_bias.sh --seeds 500 --scenario-seeds 12 --seed-start 29001 --duration 90 --step 0.1 --output analysis/reports/p028b_exp`

- Godot `4.7.2.stable.official.ed1daf0bf`; 500 paired synthetic seeds × 300 balls × five schedules × four arms; 144 real-model scenarios, 36 paired seed/policy cases per arm; canonical runtime 78.87 seconds.
- All 500 no-threat seeds in mild/moderate/strong produced the exact baseline sequence. Across all synthetic arms/schedules there were zero four-color bag violations and zero immediate-repeat violations. Under rotating threat, legal urgent selection rose from 44.0% baseline to 51.7% mild, 62.2% moderate and 71.2% strong; the unchanged bag frequently made the desired color unavailable, correctly preventing a rescue override.
- A paired shadow production generator preserves the exact baseline run-length sequence in every adaptive arm, preventing bag-boundary RNG coupling from contaminating the color-order experiment. The dedicated suite proves equality for mild/moderate/strong.
- Moderate was the best later human-A/B candidate, but is **not ready to ship**. Summed paired mean threatened-starvation improved by 1.52 seconds across colors with `basic_matcher` and 1.12 seconds with `delayed_matcher`; all 12 playing seeds won. Delayed YELLOW nevertheless worsened by 0.74 seconds, failing the all-color fairness gate cleanly.
- Mild improved totals but worsened delayed YELLOW by 1.02 seconds. Strong offered no clear advantage over moderate and worsened basic RED by 0.94 seconds. Recommendation: collect human data only for moderate; reject mild/strong for now; enable none in production.
- A selected run's first ball became visible in roughly 0.08–0.09 seconds in these retained offscreen/right-edge states, but reaching a visible pair commonly took 0.8–3.0 seconds and the next real same-color match roughly 3.3–4.3 seconds. This confirms that manipulating run order is not instant defensive assistance.

## Verification

- `./scripts/analyze_threat_bias.sh --smoke`: **PASS**, 8 synthetic seeds and 24 authentic scenarios.
- Full command above: **PASS**. A second independent full run completed in 78.97 seconds; both CSVs were byte-identical, normalized JSON was identical, and the generated report matched after normalizing runtime/output path.
- `godot --headless --path . --script res://tests/p028b_threat_bias_test.gd`: **PASS, 29 checks**.
- `godot --headless --path . --script res://tests/p028a_balance_lab_test.gd`: **PASS, 38 checks**.
- `./scripts/ci/run_regression_tests.sh`: **PASS, all 30 suites**; P011 remains 16,485 checks / 2,400 operations.
- Exact-nine Web release validation: **PASS**; unchanged PCK SHA-256 `95bd5ebffb7e52dc739bc03645d79ec16823b431f8a45a34a3aaae3f0718a901`.
- `git diff --check`: **PASS**.

## Limitations and preservation

- Threat-aware choice is not connected to `Main`, `Battlefield`, UI, or any shipped runtime configuration. Production remains 102 px/s, `[20,30,18,13,9,6,4]` run weights, four-color bags, enemy HP 3/6/3/3 and all existing spawn/combat/control/render/export settings.
- `delayed_matcher` is deliberately weaker but not human-calibrated; both bots retain exact perception and lack touch error, occlusion, planning and human emergency strategy. Twelve encounter seeds per policy/arm are paired evidence, not population tails or phone usability.
- Run-to-match associates a selected run with the first later real match of its color; overlapping runs can share that match. Unresolved delays remain explicitly counted in JSON rather than assigned fabricated durations.
- Godot's optional `user://logs` and editor-settings writes were denied by the restricted CLI environment; tests and experiments still exited successfully with complete artifacts.
- Existing user modifications to `project.godot`, `scenes/main.tscn`, and unrelated generated UID files remain uncommitted and untouched.
- P028B-SHIP and all unrelated tasks remain unimplemented. No Web/Android build, deployment, signing, version or credential changes were made.

---

# Previous handoff — LBS-P028AR fixed-X balancing correction

**Status:** COMPLETE

**Branch:** `master`

## Correction delivered

- Replaced the analysis bot's target-UID homing with one immutable chain-local `shot_x`, captured when the shot is fired and retained for its complete 0.20-second flight. The target UID is now diagnostic only and cannot change collision, insertion, matching, or damage.
- Added exact within-step arrival sequencing. The chain advances to the projectile's impact boundary, the real `ChainModel.try_insert_shot()` resolves against geometry at that instant, and any remainder of the outer simulation step advances afterward. Settling is scheduled from the exact impact time rather than the start of a coarse step.
- Kept the bot deliberately naïve and documented: it aims one pixel left of the selected ball's current launch-time X, with no predictive lead or future-state access. Shots can now miss, hit a different ball that crosses the fixed axis, or insert without forming a match. Only actual `match_completed` events reach `MatchProgression` and combat.
- Added arrival, insertion, miss, nonmatching insertion, original-target contact, off-target insertion, minimum flight-time and minimum shot-interval metrics. Renamed the interpretation to a **launch opportunity** proxy while retaining the old JSON field for schema compatibility.
- Expanded `p028a_balance_lab_test.gd` with a 240 px/s moving-target fixture that misses at its immutable X but would have hit under the old homing behavior; a removed diagnostic UID/current-ball collision case; equivalent coarse/fine-step timing; exact 0.20-second flight; and 0.4-second cooldown checks.
- Regenerated all four tracked analysis artifacts with schema v2 and revised README/report conclusions. Production speed 102 px/s, run weights `[20,30,18,13,9,6,4]`, colors, HP 3/6/3/3, spawning, controls and gameplay are unchanged.

## Corrected experiment and findings

Command: `./scripts/analyze_balance.sh --seeds 500 --seed-start 28001 --duration 120 --step 0.1 --output analysis/reports/p028a`

- Godot `4.7.2.stable.official.ed1daf0bf`; paired generator seeds 28001–28500; 300 fresh balls each = 150,000 per run-weight set; 25 physical/combat scenarios; runtime 8.03 seconds.
- Generator-only figures are unchanged: GREEN was 37,876 / 150,000 (**25.251%**); GREEN run-color share was **24.987%**; length 7 was **4.00% of runs / 9.43% of emitted balls**.
- The three baseline 102 px/s `basic_matcher` seeds produced 148 arrivals, 128 insertions (**86.5% hit rate**), 20 genuine misses and six nonmatching insertions. Of those insertions, 93 contacted the originally selected ball and 35 legitimately contacted a different ball at the fixed axis. All 3/3 cases still won, so this exact, instantaneous bot remains too strong to establish human difficulty.
- The paired two-seed baseline speed probe measured: 102 px/s — 88.5% hit, 12 misses, GREEN pair drought 11.45 s; 120 — 87.0%, 14, 10.95 s; 140 — 82.8%, 20, 9.45 s; 160 — 84.5%, 18, 7.65 s. Faster feed can expose pairs sooner while reducing fixed-X accuracy; no live speed increase is recommended without phone playtesting.
- The exploratory run weights at 102 px/s measured 82.1% hit and an 8.75-second GREEN pair drought versus baseline 88.5% / 11.45 seconds, but each comparison cell has only two seeds. P028AR supersedes the prior combat/speed conclusions, not the unchanged generator distribution.

## Verification

- `godot --headless --path . --script res://tests/p028a_balance_lab_test.gd`: **PASS, 38 checks**.
- `./scripts/analyze_balance.sh --smoke`: **PASS**, three bounded cases with real fixed-X misses/off-target insertions.
- Full 500-seed/25-scenario command above: **PASS**. An independent second full run produced byte-identical CSVs and identical JSON after normalizing timestamp, runtime and output path.
- `./scripts/ci/run_regression_tests.sh`: **PASS, all 29 suites**; P011 remains 16,485 checks / 2,400 operations.
- Web release validation: **PASS**, exact nine-file runtime set; PCK SHA-256 remains `95bd5ebffb7e52dc739bc03645d79ec16823b431f8a45a34a3aaae3f0718a901`.
- `git diff --check`: **PASS**.

## Limitations and preservation

- The harness uses authentic production models and collision, but the bot selects exact geometry instantly, has no finger error, perception/reaction delay, touch occlusion, predictive lead, multi-shot planning or strategic emergency timing. Adjacent pairs are potential launch opportunities, not guaranteed hits or matches. Two seeds per speed/weight cell describe sensitivity, not population tails.
- Godot could not write its optional `user://logs` file in this restricted CLI environment; test and analysis processes still exited successfully and produced complete results.
- Existing user modifications to `project.godot`, `scenes/main.tscn`, and unrelated generated UID files remain uncommitted and untouched.
- P028B and every unrelated task remain unimplemented. No build, release, deployment or production-balance changes were made.

---

# Previous handoff — LBS-P028A deterministic balancing laboratory

**Status:** COMPLETE

**Branch:** `master`

## Delivered

- Added `BalanceLab`, a non-rendering Godot harness over the real `ChainModel`, `MagazineState`, `MatchProgression`, headless `Battlefield` director and `LaneCombatModel`. It explicitly advances the production models, queues a 0.20-second shot flight, enforces the 0.4-second cooldown, uses actual visible collision geometry/`try_insert_shot()`, and sends only real `match_completed` results into combat.
- Added `./scripts/analyze_balance.sh` with `--smoke`, `--seeds`, `--seed-start`, `--duration`, `--step`, `--output`, `--policy` and `--scenario`. Named policies are `observe_only`, `basic_matcher` and `threat_priority`; none changes feeder choices or grants free matches/damage.
- Added a validated per-instance run-weight seam to `ChainModel`. Ordinary instances duplicate the unchanged production `[20,30,18,13,9,6,4]`; the lab alone can inject `[12,30,40,10,5,2,1]`. A regression proves baseline injection returns the exact original RNG sequence. Production speed remains 102 px/s and all colors, HP 3/6/3/3, spawns, controls and other balance remain unchanged.
- Metrics distinguish the fixed starter, fresh generator/run colors, rolling windows/droughts, visible/off-left/off-right physical state, entering balls, adjacent pairs vs passive 3+ groups, loaded/next/generated/fired ammo, real insertion/match results, threat timing/reasons, spawn types, hits/kills/heals/emergency/knockdown/revival/breach, and finite outcomes.
- Committed `analysis/reports/p028a/REPORT.md`, `baseline.json`, `scenario_summary.csv` and `comparison.csv`. JSON schema version 1 includes bounded summaries for every generator seed and every scenario, not per-frame dumps. `analysis/.gdignore` prevents Godot importing report data.

## Executed experiment and findings

Command: `./scripts/analyze_balance.sh --seeds 500 --seed-start 28001 --duration 120 --step 0.1 --output analysis/reports/p028a`

- Godot `4.7.2.stable.official.ed1daf0bf`; paired seeds 28001–28500; 300 fresh balls each = 150,000 per run-weight set; 25 real physical/combat scenarios; final runtime 7.13 s.
- GREEN was 37,876 / 150,000 = **25.251%**, and direct GREEN run-color share was **24.987%**. All colors had a 20-ball p50 drought; GREEN p95 was 26 and worst 30 versus RED 33, BLUE 32 and YELLOW 37. There is no generator-level GREEN disadvantage in this sweep.
- Baseline length 7 was **4.00% of selected runs but 9.43% of actually emitted balls**. Experimental weights reduced length-7 to 0.92% of runs / 2.33% of balls and reduced per-color p50 drought from 20 to 18.
- In paired basic-matcher speed probes, GREEN adjacent-pair drought fell from 11.85 s at 102 to 10.00 s at 120 and 8.70 s at 140; all paired cases won, but visible GREEN occupancy fell. The experimental distribution at 102 reached 8.85 s on only two seeds. Recommendation: phone A/B 120/140 and the new run weights before any P028B shipping decision; retain 160 only as a sensitivity bound.
- Baseline policy scenarios did not show GREEN as the starved lane. The worked playable-policy worst trace was seed 28001, RED, 7.30 s unavailable, attributed mainly to chain geometry. Bot victories do not prove human difficulty is solved.

## Verification

- `./scripts/analyze_balance.sh --smoke`: PASS, three ≤30 s cases.
- Full command above: PASS. A second independent full run produced byte-identical CSVs and identical JSON after normalizing timestamp/runtime/output path.
- `godot --headless --path . --script res://tests/p028a_balance_lab_test.gd`: PASS, 29 checks (determinism/diversity/schema/conservation, known sequences, geometry, danger timing, real scenarios, no fake actions and untouched defaults).
- `./scripts/ci/run_regression_tests.sh`: PASS, all 29 suites; P011 remains 16,485 checks / 2,400 operations.
- Existing ignored `exports/web` had three editor-created PNG `.import` sidecars, so its strict exact-nine check correctly rejected that local directory. Copying only its nine runtime assets to `/tmp/p028a-web-nine` and running `./scripts/ci/validate_web_release.sh /tmp/p028a-web-nine`: PASS; unchanged PCK SHA-256 `95bd5ebffb7e52dc739bc03645d79ec16823b431f8a45a34a3aaae3f0718a901`. No Web rebuild or deployment was needed.
- `git diff --check`: PASS.

## Limitations / next decision

- The bot uses adjacent-pair heuristics, not multi-shot planning, human perception, touch error, emergency strategy or device readability. Hopper danger uses authoritative average speed; Snake delay is included; stationary healer pressure is measured via pulses rather than direct arrival. Combat sensitivity has only two paired seeds per speed/weight cell; generator conclusions use 500.
- Physical Android testing remains outstanding. P028B is not implemented or activated. No threat-sensitive generator, runtime tuning, P029+, build/release/signing or deployment changes were made.
- Existing user modifications to `project.godot`, `scenes/main.tscn`, and unrelated generated UID files remain uncommitted and untouched.

---

# Previous handoff — LBS-P033R solid-red hit silhouettes

**Status:** COMPLETE

**Branch:** `master`

## Correction delivered

- Removed `HIT_FLASH_SHADER`, every per-enemy `ShaderMaterial`, and all shader-parameter updates. Original P034A enemy sprites now have no material override and are rendered unchanged.
- Added four committed 512×512 solid-red masks under `assets/sprites/hit_masks/`, reproducibly generated by `./scripts/generate_enemy_hit_masks.sh`. The Godot generator copies all 262,144 source alpha values exactly and writes `#ff0000` RGB for every visible pixel. Running it twice produced byte-identical PNG hashes. Original enemy PNGs were not modified.
- Each enemy visual now owns one initially hidden `HitSilhouette` `Sprite2D` above the base sprite, with the same parent, pivot offset, centering, filter and inherited root transform. The dictionary and node transfer intact with Sickle Snake lane changes; hits reuse the same node and imported texture.
- Real damage reveals the overlay at full opacity and the existing model `hit_flash` timer fades it over 0.16 seconds. Damage-caused deaths carry the same overlay into the corpse and fade it during the first 0.16 seconds before the normal one-second fall/fade continues. Healing and an unhurt emergency-cleared enemy do not create false flashes.
- No controls, HP (3/6/3/3), damage, movement, spawning, chain behavior, SFX, crystals, Web automation, APK metadata or signing assets changed.

## Derived mask hashes

- Healyzard: `abd0bdcab70728359a9afa80c70f3aba2887723580ce33c5f8f8c839cf26c344`
- Heavy: `a34ec05921ac970c93df2ea0bccbab2fb15a3a78903938e5a3b484000c283a78`
- Hopper: `c34082a7ebd41f821f631c42255e8dc54f198b8f9da89e3125b7852cdd02e85d`
- Sickle Snake: `1b6995bd8e785e144e1006b267ab8e0178d3c4f771f7f198b168b2fe95255d09`

`tests/p033r_hit_silhouette_test.gd` compares every source/mask pixel, requiring exact alpha equality and exact red RGB for every visible mask pixel.

## Real Compatibility-renderer evidence

Reproduced with `./scripts/capture_p033_gameplay.sh` using Godot `4.7.2.stable.official.ed1daf0bf`, OpenGL 4.6 Compatibility, AMD Radeon RX 6700 XT / Mesa 26.2.5:

- `assets/previews/p033_controls_hit_flash_1280x720.png` — `f08e00603c256d993ed8eb5e51d7b43b4ba3db7f52aa17136485c5a06e9e6ee0`; corrected normal-color unhit roster and solid-red damaged Heavy.
- `assets/previews/p033_controls_settings_1600x720.png` — `7b186b231bc9f1dbbb919d7de5b0dd9d79d77cc14e81b45ad5057362e37395ea`; wide gameplay/settings view with corrected unhit actors.
- `assets/previews/p033r_hit_overlay_comparison_1280x512.png` — `b4b9cc8b20dcbe0b334fa84be69e7f1fea0792f844de64e1791909abf1c9f677`; direct Heavy source PNG, shader-free live unhit Heavy, and live solid-red overlay side by side.

All captures wait for `RenderingServer.frame_post_draw` and were inspected at original resolution.

## Verification

- `./scripts/generate_enemy_hit_masks.sh` twice: **PASS**, byte-identical output hashes.
- `./scripts/capture_p033_gameplay.sh`: **PASS**, three genuine renderer screenshots.
- `./scripts/ci/run_regression_tests.sh`: **PASS — all 28 suites**.
- P033 controls/HP: **PASS, 44 checks**; no control behavior changed.
- New P033R silhouettes: **PASS, 41 checks**, including full-pixel alpha/RGB validation, shader absence, exact visual-node alignment, timer/repeat/lethal behavior, healing, Snake transfer, emergency clear and reset.
- P011 stress: **PASS, 16,485 checks / 2,400 operations**.
- `./scripts/build_web.sh`: **PASS**, ignored local Web release and ZIP rebuilt.
- `./scripts/ci/validate_web_release.sh exports/web`: **PASS**, all nine files; PCK SHA-256 `95bd5ebffb7e52dc739bc03645d79ec16823b431f8a45a34a3aaae3f0718a901`.
- Android release scaffolding and toolchain policy tests: **PASS**. No APK was built or published.
- `git diff --check`: **PASS**.

## Limits / preservation

- No physical Android device was attached; native display/performance remains manual QA.
- Existing user modifications to `project.godot`, `scenes/main.tscn`, and unrelated generated UID files remain uncommitted and untouched.
- P028 and every unrelated task were not started. Stop after P033R.

---

# Previous handoff — LBS-P033 mobile controls, ergonomics and enemy feedback

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
