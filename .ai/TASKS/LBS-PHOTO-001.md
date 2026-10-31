# LBS-PHOTO-001 — Portfolio gameplay hero screenshot (QUEUED; NOT ACTIVE)

**Status:** QUEUED. Do not replace or execute the current `.ai/TASK.md` (LBS-P040) until ChatGPT explicitly activates this task. Screenshot work is portfolio-only and must not alter production gameplay or shipping Android builds.

## Updated capture rule — static, non-hostile, Codex first

Codex must set up a **frozen, deterministic 2D composition**, and take the first 2–3 real renderer screenshots before asking for user feedback. The desired ball may appear halfway up its launch path, with its *vertical trail already drawn*, but **it must NOT be moving and the user must NOT need to time the shot**. Create an isolated portfolio-only render state with ball/projectile, conveyor, defenders and enemies held at attractive static positions and enemy attacks/time progression disabled. The trail is a static visual element sourced from the game's own rendering logic; no need to catch a live physics frame. Never apply this freeze to normal gameplay, and preserve the current match/game balance. User can then take unlimited time to reframe and manually capture the exact still. If rendering is not available, leave reproducible static fixture instructions and label capture blocked.

## Goal
Create a truthful, attractive **Ball Battalion** 16:9 gameplay screenshot in the real current 2D Godot 4.7.2 Compatibility-renderer game. A colored ball must be visibly **in flight upward**, with a short *vertical motion trail / blur*; conveyor, horizontally positioned shooter, matching threat, defenders/enemies and readable UI should be visible together. Don't simulate screenshot composition by fabricating an image outside the game.

## Two-pass workflow
1. **Codex draft**: Inspect the current game `scenes/main.tscn`, gameplay/render scripts and existing `scripts/capture_p036_monochrome.sh` and `assets/previews/` screenshot conventions. Create a reproducible screenshot-only static staging/capture mode using genuine game assets, with the projectile held halfway up its flight path and a non-animating trail; no active firing or enemy movement. The user may review the draft and adjust the live scene manually.
2. **User review**: Provide 2–3 genuine in-engine shots of the same staged, non-moving gameplay composition. User picks a hero shot or sends a manual low-resolution reference.
3. **Final pass**: Reproduce the approved frame/state, ideally at 1600×900 or 1920×1080 when rendering resources permit; a sharp native **1280×720 is acceptable**. Never upscale a 720p bitmap and call it a high-resolution render. Preserve original aspect ratio, camera/UI framing and input-safe areas.

## Composition
- Projectile in the center-to-upper path, captured roughly midflight. Use a *localized* narrow vertical trail/afterimage, keeping the ball color/symbol readable; **do not apply full-frame blur** or change ball trajectory/speed solely for portfolio.
- Chain and threats must indicate real tactical context. Avoid win/lose/pause screens, clipped edges or hidden gameplay controls.
- Preserve existing white/black UI palette and meaningful ball/enemy colors.
- If effect code is required, keep capture-only toggles disabled by default and add a screenshot-mode test so production gameplay never changes. Do not introduce new external art.

## Outputs and proof
- Produce 1 proposed hero + 2 alternatives. Suggested local paths: `portfolio_capture/draft/`, `portfolio_capture/reference/`, `portfolio_capture/final/`; add only bounded approved image files to git (prefer `assets/previews/portfolio_*.png` for small review assets), and never huge raw footage.
- Note exact version/commit, Godot version, capture command, screen resolution, deterministic/seeded frozen board, projectile position and fixed vertical trail, and where the approved final screenshot is stored for the website repo.
- If graphical display is unavailable, prepare repeatable script/scenario and mark **CAPTURE BLOCKED—requires graphical host or manual screenshot**. Headless parse tests do not prove the screenshot looks right.

## Acceptance
- Current Web/Android game untouched by default; existing tests still pass; capture helper isolated.
- Image is real in-engine gameplay, with one clearly ascending ball and localized motion trail, readable lanes/conveyor, no debug clutter.
- User explicitly approves the selected hero image before it is advertised as final.
- Codex handoff records actual image dimensions, checks, limitations, and reference frame details. No release, APK or portfolio deploy in this task.

**Out of scope:** revamping controls, difficulty, porting to portrait, PvP, recreating 3D battlefield, changing current active P040 release or game version.