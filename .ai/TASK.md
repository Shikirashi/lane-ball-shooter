# Lane Ball Shooter — USER BROWSER PLAYTEST AFTER P021 / NO ACTIVE CODEX TASK

**Status:** WAITING FOR BROWSER PLAYTEST
**Branch:** `master`
**P021 implementation:** `f21e3637ab29bd067006f06b4e5ba0c06565e821` (source/handoff reviewed and accepted; interactive browser/fullscreen/device QA pending).
**P022:** QUEUED but NOT ACTIVE. Next step, only after user requests Mintbase deployment and local browser build is verified, is static HTTP hosting on Mintbase at the chosen network IP and port.

## Implemented

- P021 added `scenes/boot.tscn` plus `scripts/boot.gd` as main scene. Web boots to minimal dark main menu; gameplay scene is not instantiated until player selects START GAME > YES/NO. Desktop/Android directly transition to game.
- START GAME opens dialog exactly `Play in fullscreen?` with YES and NO. YES calls `DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)` synchronously from pressed callback, then loads the game. NO loads the game without changing window mode. Keyboard/mouse/touch UI controls, safe-area layout, and duplicate start guard are implemented. Actual browser fullscreen permission and user gesture still require manual test.
- Existing four enemies, P020 special abilities, P018 enemy defeat VFX/SFX/3s WAVE CLEARED delay, and P017 physical offscreen-LEFT ball return remain unchanged.
- New `scripts/build_web.sh` builds Web release to `exports/web/index.html` using existing SINGLE-thread Godot Compatibility Web preset and bundles all runtime files at ZIP root into `exports/lane-ball-shooter-web.zip`. Build artifacts remain ignored/local, NOT present on GitHub. A real local build was reported in P021 Codex handoff, with `index.html`, JS, WASM, PCK, audio worklets, icons; full list and SHA256 in `.ai/CODEX_HANDOFF.md`.
- Codex installed matching official 4.7.2 standard (non-Mono) single-threaded Web export templates on its development machine. It reports 9 local HTTP resources 200, correct MIME types, headless Chrome resource fetch and all P001–P021 Godot headless tests passing including P021 46 checks. Its headless screenshot remained on Web splash, so REAL browser rendering/menu and fullscreen interaction are unverified.

## User browser playtest — on the SAME machine that ran Codex P021

```bash
cd ~/Documents/GitHub/laneballshooter
git pull --ff-only
ls -lh exports/web/index.html exports/web/index.js exports/web/index.wasm exports/web/index.pck exports/lane-ball-shooter-web.zip
python3 -m http.server 8766 --bind 127.0.0.1 --directory exports/web
```

Then visit `http://127.0.0.1:8766/` in Firefox/Chrome on that machine. 8765 was occupied by an unrelated service in Codex's environment; 8766 is a suggested test port (confirm free). Verify the title/menu and START button, prompt, NO normal embedded game, reload and YES fullscreen, Escape exit without breaking playfield, responsive sizes, audio after user click, shoot/swap/touch if applicable, and the Snake/healer/game-over interactions. Use Ctrl+C to stop temporary local HTTP server. Do not open `file://` directly.

If exports are absent, binaries were local to Codex environment and NOT in the pushed repository. On the machine with official matching Web templates, run `./scripts/build_web.sh` to regenerate. No inferred sandbox artifact links: published source repo deliberately omits WASM/PCK and ZIP.

## Next deployment

P022 spec at `.ai/TASKS/LBS-P022.md` is QUEUED and NOT ACTIVE. After verifying the real Web build, user can request to deploy it on Mintbase. Need transfer ZIP/runtime folder to Mintbase (git pull alone won't transfer compiled build), select unused port (default suggestion 8766 or another confirmed free port), and restrict interface/access as desired. A private `http://mintbaseIP:PORT/` is LAN/Tailscale-accessible only, not automatically publicly accessible. Do not change Mintbase services/firewall without user direction.

## Validation source

P021 accepted as source/handoff complete, not as independently validated live browser/remote hosting. Godot tests P001–P021 were REPORTED PASS by Codex. No independent WebGL interactive fullscreen test was run here. No active code task until user feedback.
