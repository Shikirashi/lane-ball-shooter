# ACTIVE TASK: LBS-P006 — Web/Android readiness, input QA, UI polish, performance and regression

**State:** READY FOR CODEX
**Branch:** `master`
**Prerequisite:** P001–P005 source-reviewed and accepted; P005 implementation `0c61edc`, handoff `387a512`.
**Read first:** `AGENTS.md`, `.ai/PROTOCOL.md`, `.ai/DECISIONS.md`, `.ai/TASK_LEDGER.md`, and this file.

## Mission
Prepare the existing **complete playable hybrid 2D/3D survival prototype** for desktop browser (Godot HTML5/Web) and Android landscape APK/AAB **without replacing the gameplay architecture or adding external art**. Fix responsive layout and input bugs, add export presets/documentation, bound performance and maintainability risks, and provide executable/manual QA instructions.

The user works on Linux Mint with Godot 4.7.2. The project must remain GDScript + Compatibility renderer, one shared layout/control logic on both platforms. Work through text/code/CLI only — no GUI/mouse automation. Do not claim on-device or browser testing unless actually performed.

## Required work

### 1. Export configurations
- Inspect `project.godot`, local Godot version and installed export templates.
- Add/revise committed **Web** and **Android** export presets compatible with the installed Godot version and current Godot export schema; no hardcoded private machine paths, signing secrets, passwords, or Android keystores in Git.
- Configure Android **landscape**. Keep a consistent project/application identity. Specify a reasonable package ID as **provisional**, clearly document how to change it before store submission. No release signing is needed for prototype; debug APK is sufficient.
- Aim to produce a self-contained exported Web build (`index.html`, JS/WASM, PCK) and debug APK **if** templates/Android SDK/JDK/tools are present. Test the export via CLI with bounded commands. If unavailable, document precise missing prerequisites and commands a user can execute locally; do not download heavyweight SDKs or commit binaries just to fabricate success.
- Preserve `*.apk`, `*.aab`, exports/build outputs in `.gitignore`; commit export PRESETS, not generated export binaries. Document minimal static local web-server launch (`python3 -m http.server`), browser compatibility caveats, and APK install procedure. For browser, verify no external asset URLs / online dependencies.

### 2. Landscape responsive UI & safe area
- Review actual node sizes/anchors and layout formulas for 1280×720, 1600×720, **960×540** and at least one **ultrawide mobile landscape** (e.g. 2400×1080). Don't crop top-chain balls, four 3D lanes, defender/emergency/revival labels, shooter travel, magazine controls or GAME OVER/RESTART.
- Keep top ball chain, 3D center and bottom shooter/magazine visually distinct; ensure any SubViewport render dimensions/aspect preserve usable camera composition without stretching or cutting off lane ends. Tune the orthographic camera based on its viewport aspect if needed.
- Account for mobile landscape **safe-area/cutout/inset** where supported. Do not assume there is no notch/navigation-bar overlay. Keep critical GUI away from extreme corners and edges, and scale text/tap regions to stay readable. Document fallbacks for Web when native safe-area data isn't available.
- Preserve obvious consistent shooter loaded/next and swap icon; ensure touch controls have practical hit targets (prefer ~44 logical px or higher).
- Game-over overlay must remain legible with a clickable/tappable restart button at all target sizes. Remove/reduce gratuitous placeholder text if it competes with combat readability.
- All team identities remain distinguishable by **color + geometry/symbol**. Implement a simple optional **alternate/high-contrast palette** control/toggle if feasible without destabilizing the prototype; ensure both 2D/3D visuals use the same shared palette. If not feasible, explicitly document accessibility follow-up.

### 3. Input and control correctness
- Desktop: mouse X follows shooter, left click fires only in playfield, right click/Space swaps; F3 debug; R restart after death.
- Android touchscreen: touch down/drag playfield positions shooter X and **release fires exactly once**; touching swap UI swaps only; never also fires due to synthetic mouse events. Prevent a touch that begins outside playfield from creating an active shot when released inside. Consider multi-touch ownership and cancellation/lost touch, and avoid firing on a paused/game-over screen.
- Mouse click on magazine swap button must not also create a shot; right-click anywhere on playfield can swap, as before.
- Ensure input never continues unexpectedly after game-over and RESTART. Clear active touch ownership and cooldown appropriately. Test the case of pressing restart and releasing finger on the board.
- Add automated synthetic-input tests where practical (use `Input.parse_input_event` or a similarly reliable Godot integration approach), plus unambiguous manual mobile test cases. Do not falsely claim that synthetic input guarantees actual-device success.

### 4. Gameplay regression and edge-case audit
- No regression of P002 physical contact and spatially disconnected cache rules, FIFO order, continuous chain movement, empty recovery, 3+ match cascades.
- No regression of P003 3-second combo, fourth-match fever, scoring by group size, shuffle-bag swapping/draw counts.
- No regression of P004 per-color 3D combat, projectile swept hits and enemy HP.
- No regression of P005 ACTIVE/DOWN, one-use emergency discharge, two-color-match revival, breach-game-over, frozen simulation and clean restart.
- Investigate and fix *reproducible* critical gameplay bugs found during final integration (e.g. offscreen shooter track after resize, unwanted shoot from GUI control, stuck touch, runaway nodes). Keep changes small and add tests.
- Use bounded event/diagnostic history and verify visual node cleanup after repeat restarts. Avoid constant mesh/material creation every frame; high priority is runtime stability and low overhead on ordinary Android hardware. Avoid adding shader/rendering features unsupported by Compatibility.
- Where feasible, document tunable speed/HP/spawn/shot cooldown and debug controls for subsequent balancing.

### 5. Validation
- Add `tests/p006_platform_qa_test.gd` (or equivalent) for layout geometry at reference/mobile aspect ratios, safe UI regions as available, touch/mouse input/no accidental shot, reset/restart, and steady-state dynamic-entity boundedness, without external assets.
- Run prior headless suites P001, P002, P003, P004, P005; report actual check counts and exit codes.
- Run bounded Godot editor import and headless startup with all relevant resolutions. CLI export Web/Android when prerequisites exist. Validate generated Web output file names, not just exit code, and Android APK presence/format if produced.
- If local CLI engine or export templates are missing, report BLOCKED for that particular validation, not necessarily for the task as a whole. No unsupported claim of Chrome/Firefox/mobile browser, physical Android touch or FPS profiling if untested.
- Check `git diff --check`, no unintended tracked binary builds or credentials in export configuration.
- A smoke-test checklist in README should tell user how to reproduce **match -> tier burst -> knockdown -> two-color revive -> terminal breach -> restart**, plus touch/swap, Web local serve and Android debug install.

## Acceptance
- One Godot project remains launchable and mechanically playable on desktop.
- Web/Android export configurations and clear setup instructions committed; artifacts only when tools available, not required to commit.
- Screen composition works at 960×540, 1280×720, 1600×720, 2400×1080; no obvious clipped essentials.
- Tested or honestly documented platform/input limitations, with regression suites passing.
- Scope remains a prototype: no music, external assets, paid/store release setup, in-app purchases, analytics, new complex mechanics or art pipeline. Don't invent an extra gameplay mode.

## Handoff & mailbox
Update only `.ai/CODEX_HANDOFF.md` with P006 status, changes, exact validation results and blocked tools, local export commands/instructions, usability caveats, manual test checklist and any recommended next backlog. Update README implementation/export instructions as needed.
Commit/push to `master` then **STOP**. Do not edit `.ai/TASK_LEDGER.md` or self-advance beyond P006. ChatGPT will review, and then we will do a user-directed visual/playability pass.
