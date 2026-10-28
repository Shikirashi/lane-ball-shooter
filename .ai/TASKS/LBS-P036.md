# COMPLETED P036 — Shared monochrome UI redesign (2026-10-28 WIB)

**Status: COMPLETE and technically reviewed.** Source `0e656e93d0054d1f8dbf6e9793db952e7d00d12f`, handoff follow-up `14707d39be35b40651b636df7acf389051bd7f45`, GitHub Web CI `40646655273` SUCCESS, portfolio Pages `40646877117` SUCCESS. Codex reports 32 Godot suites/75 targeted checks PASS, valid 9-file Web export, settings/Web/1280/1600/success/defeat genuine renderer screenshots; `UiPalette` grayscale chrome and game-semantic colors preserved. Independently reviewed code, tests, screenshot tool/source, asset existence and CI. **Review limitation:** Screenshot pixels unavailable for independent inspection via GitHub connector; original-resolution visual inspection is reported by Codex, pending user Web playtest. Known minor cleanup: `project.godot` engine default clear color still dark navy, though game and Web boot cover it with palette black; P037 now explicitly includes this tiny native-startup transition refinement.

**Next:** P037 native Android main/play/controls + illustrated guide + pause now ACTIVE only in `.ai/TASK.md`; P038 Android signed v0.3.0 still queued. Current published Android APK remains v0.2.0.

---

## Original P036 task — historical

# ACTIVE CODEX TASK — LBS-P036: Monochrome black-and-white UI redesign (Web + Android shared game)

**Status:** ACTIVE — user request 2026-10-28 WIB. This is the **ONLY** active task. User's exact design direction: "**change the theme colour of the whole game, including the web and android version. Just use white on black for most of everything unless they need accent colours like the fever stuff and combo and such. Using this dark purple/blue colour reeks of AI generated UI.**" P037 Android main/pause/illustrated control guide and P038 signed Android APK/portfolio release are **QUEUED / NOT ACTIVE**, separately detailed in `.ai/TASKS/LBS-P037.md` and `.ai/TASKS/LBS-P038.md`. Finish P036, commit/push/handoff, STOP. ChatGPT reviews before activating P037.

## Objective / visual direction

Transform **all neutral interface chrome** from existing navy/dark-purple/blue gradients and accents into an intentional **minimal monochrome arcade UI** for the SAME Godot project used on Web and Android:
- Main field nearly black `#050505` or true black; panel backgrounds `#101010` / `#161616`; raised surfaces in neutral charcoal; hairline separators `#454545` or `#777777` (not faux-blue); labels, headings, buttons and outlines `#F4F4F4` / white; secondary labels `#A8A8A8`; disabled text `#666666`. Selected focus and important UI should be white border, not blue glow. Use purposeful spacing, typography hierarchy and crisp separators, **NOT cards everywhere, glowing neon-blue buttons, gratuitous corner radii, gradients or shadows**.
- Colored things with game semantic importance **must stay colored**: four actual team identities/balls/symbols, defender and enemy sprites and crystals, genuine lane/team identity indicators where needed to distinguish lanes, solid-red damage silhouettes, projectile match VFX, danger warning, progression tier/FEVER and COMBO accents. **Do not desaturate the actual game art** or ball colors just to satisfy monochrome chrome. For FEVER/COMBO, sparing warm gold/orange or other existing semantically meaningful color is allowed and should read clearly against black.
- General text, conveyor frame, shooter chassis/rail/aim line, scoreboard, neutral progress bars, lane backdrops, thin dividers, buttons, Web entry menu, YES/NO fullscreen prompt, settings panel, gear button, restart/endgame dimmer should all be **neutral grayscale**. Keep layer contrast without accidentally making characters invisible. A subtle gray per-lane alternation for readability is allowed (no blue tint); preserve game-color lane separators only when genuinely conveying team identity.
- Endgame `WAVE CLEARED` success / `GAME OVER` failure accent can retain one meaningful green/red hue, but the whole-screen dark overlay itself, score, body copy and Restart should be neutral black/white. Preserve fixed **absolute z=200** layer above active sprites/projectiles from P028B-UIFIX.
- Don't introduce artificial menus into Android in P036; **P037 will implement** Android PLAY/CONTROLS/pause and screenshots using P036's final palette. Existing Web boot menu and fullscreen behavior must remain perfectly functional.

## Source surfaces and implementation

Before editing, read `AGENTS.md`, `.ai/PROTOCOL.md`, `.ai/DECISIONS.md`, `.ai/TASK_LEDGER.md`, `.ai/BALL_BATTALION_ROADMAP.md`, `.ai/CODEX_HANDOFF.md`, `.ai/TASK.md`; inspect all currently active UI/Godot scripts. Especially:
- `scripts/main.gd` background currently `Color(0.025,0.035,0.065)`;
- `scripts/boot.gd` Web menu backdrop, title shadow, big blue buttons and popup border;
- `scripts/ui/hud_view.gd` score/combo/FEVER, panel bg/strokes and tier meter;
- `scripts/ui/ball_chain_view.gd` conveyor panel, arrow and debugging;
- `scripts/ui/conveyor_ball_layer.gd`, `scripts/ui/settling_ball_view.gd` neutral highlights;
- `scripts/ui/shooter_view.gd` launcher frame, rail, trajectory preview;
- `scripts/ui/magazine_view.gd` swap control;
- `scripts/ui/control_settings_view.gd` current gear/panel/Classic/Side/hand buttons (currently default Godot styling); this also needs **consistent deliberate black/white buttons, white focus and active contrast**; P037 will redesign selector and add previews later;
- `scripts/ui/game_over_overlay.gd` modal overlay and Restart button;
- `scripts/world/lane_actor.gd` row backgrounds and neutral separators; `scripts/world/battlefield.gd` other neutral backgrounds;
- optionally `project.godot` default clear only if safe in a **clean isolated checkout**, since user's local copy often contains uncommitted custom edits; do not overwrite their real `project.godot` or `scenes/main.tscn`.
Scan `Color(` / `Color("…")`, `StyleBoxFlat`, `.modulate`, `add_theme_color_override` and named material backgrounds systematically. Avoid missing a blue-themed sub-panel, overlay or hover/pressed/disabled state.

## Strong recommendation: central neutral palette

Create a small reusable `scripts/ui/ui_palette.gd` (e.g. `class_name UiPalette`) with a compact set of const `Color` values and helper(s) for consistent standard Button/Panel/selected/focus StyleBoxes if useful. Use it in changed UI scripts so P037 can reuse it. Avoid overengineering a skin framework. All selected, hovered, disabled and keyboard-focus states need readable white/gray contrast; touch targets must remain large enough. If a theme resource is simpler, still keep one authoritative monochrome reference with tests. Do not globally override the four team colors in `TeamData.COLORS`.

## Explicit preservation / exclusions

- **No gameplay balance, controls or input changes:** mild (+50% max) threat-aware next-run color when eligible remains on, original four-color shuffled bag, 102px/s conveyor, original `[20,30,18,13,9,6,4]` run weights, Hopper/Heavy/Snake/Healyzard HP 3/6/3/3; same 2D baked character and enemy sprites, hit masks, projectile flight/match physics, combat, charge crystals, sounds, scoring, fever, victory delay and correct topmost modal draw order.
- Do not change native Android startup yet; P037 will add Android MAIN MENU, pause and annotated Classic/Side control previews. Do not implement that queued task early. Existing Web `START GAME` + YES/NO fullscreen modal and all touch and desktop input must work unchanged.
- Do not modify Android v0.2.0 signed release/tag/asset, package ID `com.shikirashi.laneballshooter`, signing keystore/backup, `export_presets.cfg` versionCode2, homepage Android download card, or Play Console. P038 handles Android v0.3.0 once P036/P037 finish.
- Do not alter unrelated portfolio or unrelated repo history. Keep generated screenshots/previews focused. Do not use image generation or new off-theme art; Godot code and genuine renderer screenshots only. Protect uncommitted user-local `project.godot`/`scenes/main.tscn`, .uid and signing files, do not reset/force push/blanket clean/sudo/reinstall SDK.

## Demonstrable completion requirements

1. Build a coherent shared grayscale palette and apply it throughout **boot + actual gameplay + controls + terminal UI**, not just main background. Important **team, fever, combo and damage colors remain colored and visually distinct**.
2. Record actual Godot 4.7.2 **Compatibility-renderer** screenshots from live game at 1280x720 AND 1600x720, plus Web `START GAME` and fullscreen prompt, control settings open and both win/lose UI. Use `scripts/capture_p036_monochrome.sh` (or reuse/extend existing screen-capture tools in `tools/`), wait for real `RenderingServer.frame_post_draw`, commit compressed focused PNGs under `assets/previews/p036_*.png`. A game-only capture without the launcher/controls/terminal is insufficient. This screenshot of **actual new monochrome gameplay** should later serve as the base for P037's instructional guide; P037 may install a smaller cropped/resized copy as an importable `assets/ui/` texture. No fake PIL/photoshop-generated "Godot screenshots."
3. Visually inspect original-resolution previews for consistent neutral colors: black background instead of navy; white text/clear focus; settings selected/pressed states not default blue; enemy and ball colors intact; white level/lane separators; win/lose dimmer covers every sprite/shot; legible on 16:9 and very wide phones. Watch for text collision in the existing HUD and overlays and preserve safe-area correctness.
4. Add focused GDScript regression `tests/p036_monochrome_ui_test.gd`: immutable semantic team color map unchanged, palette grayscale RGB equality for all **neutral** palette constants, accessible contrast on #050505 surfaces, live Main `_background`, Web Boot `_background`, HUD/chain/launcher/row `StyleBoxFlat` neutral colors and controls, settings open/select, end overlay z200 and dark color; FEVER/COMBO still have meaningful color, existing Web menu YES/NO path still starts exactly once. Avoid brittle tests comparing unrelated render details; explicit tests for one blue/purple leftover among targeted neutral surfaces welcome. Run full regression, not just new suite.
5. Run `./scripts/ci/run_regression_tests.sh` (currently 31 suites), fresh `./scripts/build_web.sh` and `./scripts/ci/validate_web_release.sh exports/web` with exact 9-file rules, and check Web publish job/P024 browser verification after push. If needed amend screenshot tooling but do not modify Web publisher credentials, portfolio homepage or nine-file safety logic. Android release scaffolding checks should still pass (no APK needed in this phase).
6. Update `README.md` with brief visual direction and reference capture command (no dense design essay), `.ai/CODEX_HANDOFF.md` with paths, screenshots, tests/commands, Godot version and color exceptions. Check `git diff --check`, commit/push all appropriate source/tests/real previews, **STOP**. Codex may edit implementation, screenshots, README and handoff only. **Do NOT edit ChatGPT-owned** `AGENTS.md`, `.ai/TASK.md`, `.ai/TASK_LEDGER.md`, `.ai/DECISIONS.md`, `.ai/BALL_BATTALION_ROADMAP.md`, `.ai/PROTOCOL.md` or queued `.ai/TASKS/LBS-P037.md` and `LBS-P038.md`.

## Exit gate

A visually consistent minimalist **white-on-black** Web/native gameplay UI with no residual navy/purple general chrome; gameplay semantic colors intentionally retained; documented real Godot screenshots of main/start/settings/win screens; regressions and Web build green; no change to Android signed APK yet. On completion, report tests and push, then STOP so ChatGPT can review and activate P037.
