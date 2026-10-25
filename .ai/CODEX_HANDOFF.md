# Codex Handoff — LBS-P021 Web menu and portable export

**Status:** COMPLETE

**Branch:** `master`

**Implementation commit:** this scoped P021 commit.

**Mailbox:** remains on LBS-P021. P022 was not implemented or activated, and ChatGPT-owned mailbox files were not edited.

## Web bootstrap and fullscreen lifecycle

`project.godot` now starts at `scenes/boot.tscn`. Its lightweight `scripts/boot.gd` checks platform features before creating anything from `scenes/main.tscn`:

- Web creates only a responsive dark menu with `LANE BALL SHOOTER` and `START GAME`; no chain, enemies, score, timers, SFX, or gameplay scene exist underneath it.
- START GAME reveals one blocking prompt with exact text `Play in fullscreen?`, plus finger-sized, keyboard-focusable `YES` and `NO` buttons.
- YES calls `DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)` synchronously from the actual `pressed` handler, before any await/defer/timer or scene transition, then starts Main exactly once. An injected requester verifies call ordering headlessly.
- NO starts Main exactly once without touching the fullscreen API. Choice locking, disabled buttons, and hiding the menu prevent duplicates and shooter click-through.
- Desktop and native Android bypass the menu and change to Main on the next safe idle tick. This avoids mutating the SceneTree while the bootstrap itself is entering it while preserving immediate native startup. `scenes/main.tscn` remains directly loadable by every older fixture.
- `--web-menu-preview` forces the menu on desktop for manual inspection. Normal browser fullscreen exit simply resizes the viewport; both menu and existing Main layouts remain safe-area responsive.

## Repeatable Web build

Added executable `scripts/build_web.sh`. It clears only `exports/web/`, performs the release export, verifies HTML/WASM/PCK presence, and packages the runtime files with `index.html` at the ZIP root. `export_presets.cfg` keeps the Web preset single-threaded (`variant/thread_support=false`), non-PWA, and Compatibility-rendered; `exports/**` is now explicitly excluded to prevent a prior build from being scanned back into its own PCK.

The installed Godot binary is `4.7.2.stable.official.ed1daf0bf`. Initially only mismatched `4.7.2.stable.mono` Windows templates were present. I downloaded the official `Godot_v4.7.2-stable_export_templates.tpz` release asset, verified its SHA-256 `f298490b8d44d934be425a5a65a51bf15f422428b229a06a6e11d9ffea248011` against GitHub release metadata, and installed only these matching files:

- `/home/shiki/.local/share/godot/export_templates/4.7.2.stable/version.txt`
- `/home/shiki/.local/share/godot/export_templates/4.7.2.stable/web_nothreads_debug.zip`
- `/home/shiki/.local/share/godot/export_templates/4.7.2.stable/web_nothreads_release.zip`

Exact build command:

```sh
./scripts/build_web.sh
```

Local ignored output:

| File | Bytes |
|---|---:|
| `exports/web/index.html` | 5,447 |
| `exports/web/index.js` | 279,815 |
| `exports/web/index.wasm` | 39,514,754 |
| `exports/web/index.pck` | 337,612 |
| `exports/web/index.audio.worklet.js` | 7,298 |
| `exports/web/index.audio.position.worklet.js` | 2,973 |
| `exports/web/index.png` | 21,443 |
| `exports/web/index.icon.png` | 5,700 |
| `exports/web/index.apple-touch-icon.png` | 11,944 |

`exports/lane-ball-shooter-web.zip` contains exactly those nine files at archive root. Final ZIP SHA-256:

`aea1571db05a3f82de2b741855a041d391ba2a92076b4349fef0b55773c75490`

The entire `exports/` tree remains gitignored and uncommitted.

## HTTP/browser verification

Documented server command:

```sh
python3 -m http.server 8765 --bind 127.0.0.1 --directory exports/web
```

Port 8765 was already occupied locally by an unrelated uvicorn process, so the actual bounded smoke used the same command on port 8766. Every one of the nine runtime resources returned HTTP 200. Relevant MIME results were `text/html`, `text/javascript`, `application/wasm`, `application/octet-stream` for PCK, and `image/png`.

Headless Google Chrome requested and loaded the exported HTML, JS, PCK, WASM, splash, and icon without an HTML failure notice. Its noninteractive screenshot mode exited while the Godot loading splash remained visible, so I do not claim automated proof of rendered menu interaction or a successful browser fullscreen transition. Those user-gesture and visual paths remain in the manual checklist below.

Godot's exporter also printed expected environment noise about absent Android build-tools, denied local editor-settings writes, and sandbox socket creation; the Web release export itself completed and all requested artifacts were verified.

## Automated validation

Added `tests/p021_web_menu_export_test.gd` — PASS (46 checks):

- no gameplay creation before selection; exact title/button/prompt labels;
- single modal, no click-through, direct fullscreen-before-game ordering, NO without fullscreen, and duplicate guards;
- Web/native/Android platform gating and direct native Main handoff;
- safe bounds and >=60px controls at 960×540, 1280×720, 1600×720, 2400×1080, and 640×360;
- keyboard focus, relayout without restart, bootstrap/preset/Compatibility/threadless/PWA/export-helper configuration.

Godot 4.7.2 headless, all passing:

- P001 smoke — PASS.
- P002 gameplay logic — PASS (66 checks).
- P003 progression/magazine — PASS (73 checks).
- P004 lane combat — PASS (42 checks).
- P005 survival — PASS (63 checks).
- P006 platform QA — PASS (69 checks).
- P007 playtest revision — PASS (53 checks).
- P008 gamefeel/SFX — PASS (84 checks).
- P009 Zuma rollback — PASS (46 checks).
- P010 staged cascade — PASS (162 checks).
- P011 segment stress — PASS (16,485 checks).
- P012 forward insertion — PASS (366 checks).
- P013 shooter preview/mask — PASS (50 checks).
- P014 causal rollback/feed — PASS (289 checks).
- P015 gravity/finite enemies — PASS (524 checks).
- P016 speed/retained-history compatibility — PASS (76 checks).
- P017 offscreen-left reentry — PASS (352 checks).
- P018 enemy death/victory delay — PASS (41 checks).
- P019 typed roster/spawning — PASS (117 checks).
- P020 special enemy abilities — PASS (67 checks).
- P021 Web menu/export — PASS (46 checks).
- `git diff --check` — PASS.

Bounded native bootstrap/Main startup passed without project/runtime errors at 960×540, 1280×720, 1600×720, and 2400×1080; each was intentionally stopped after three seconds (exit 124). The recurring sandbox denial for `user://logs/godot.log` is harmless.

## Manual browser playtest

1. Run the localhost server and open `http://127.0.0.1:8765/` in a current WebGL 2/WebAssembly browser. Confirm only the dark title and START GAME appear; enemies/chain/audio must not run behind it.
2. Press START GAME. Confirm exact prompt and YES/NO labels, touch target sizes, keyboard focus/Enter/Space, and no shooter click-through.
3. Choose NO: gameplay starts once in-page and never enters fullscreen. Reload, choose YES: the browser fullscreen request occurs from that click; if denied, gameplay still starts in-page.
4. Exit fullscreen with Escape/browser controls and resize through target landscapes. Confirm shooter, ball chain, HUD, and hitboxes remain aligned. Restart must restart the current run rather than return to the menu.
5. Recheck procedural SFX after the first gesture. Browser audio/fullscreen policy, touch behavior, and perceived visuals still require this real interactive pass.

## Limitations

- No deployment, Mintbase connection, firewall change, persistent server, or public exposure was performed; that is P022 and remains unauthorized.
- Chrome's bounded noninteractive load verified resource fetching but not post-splash canvas rendering or a genuine transient-user-activation fullscreen grant.
- Android export was not attempted; its SDK/build-tools are absent and unrelated to the completed Web build.
