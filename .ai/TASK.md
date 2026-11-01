# LBS-PHOTO-001 — Ball Battalion 2D portfolio screenshot capture

**ACTIVE ONLY ON ISOLATED BRANCH `portfolio/lbs-photo-001`.** The original `master` branch must retain the active **LBS-P040 Android signing/release continuation** and its existing tested source history. Do not touch the current release, APKs, Web build, publish pipeline or signing keys.

Read `AGENTS.md`, `.ai/PROTOCOL.md`, the relevant decisions and `.ai/TASKS/LBS-PHOTO-001.md`, then execute only this photo task. The active task authorization is this `.ai/TASK.md` branch copy; ignore the QUEUED heading in the unchanged master copy of the source photo-task document.

## Photograph goal — real 2D game screenshot, no timing

Create 2–3 **genuine Godot 4.7.2 Compatibility-renderer** screenshots of the current 2D **Ball Battalion** gameplay. The scene must show the existing horizontal ball conveyor, four defense lanes, shooter with current/next balls, placed defenders, a plausible enemy threat and readable gameplay HUD. A clearly identifiable colored/symbol ball should be held roughly **midway along the upward shot path**, with a **short localized vertical motion trail / afterimage**. The ball and its trail must be STATIC so the user can take all the time needed to review/recompose — **no requirement to capture a live flying ball at exactly the right frame**.

## Technical approach

1. Inspect current `scenes/main.tscn`, gameplay rendering, `scripts/capture_p036_monochrome.sh`, `assets/previews/` and existing screenshot/test conventions, WITHOUT modifying the Android release baseline. Find safe ways to reuse genuine runtime 2D nodes/sprites, defender/enemy visuals, UI and projectile.
2. Build an **opt-in, deterministic, capture-only fixture** or documented screenshot mode with a manually frozen board, projectile and trial, zero hostile AI movement/damage, no conveyor advancement, no auto-spawns or gameplay progression. Use actual game assets. Do not add a new permanent gameplay projectile effect or alter match logic, color distribution, controls or other mechanics to get the picture. If a static trail is useful, it may be drawn with existing game visuals/shader as photo-only geometry; do not globally blur the frame.
3. Capture **2–3 candidates** with different mild static ball position/conveyor/threat arrangements or lens/framing, all real engine renders at native 16:9 (1600×900/1920×1080 preferred, 1280×720 acceptable). The ball must read clearly, without hiding the lane units, shoving gameplay offscreen, clipping or extra debug/pause graphics. The user can select the best later.
4. Codex MUST commit **actual image files** to `docs/portfolio/review/lbs_photo_001/` (preferred), and may keep large originals in an ignored local folder. All 2–3 image files must be accessible via GitHub blob/raw links after push so ChatGPT can review the actual visuals directly.
5. Codex should perform ONLY **mechanical image checks** (file existence, native resolution, PNG/JPG/WebP decode, sensible byte count, no accidental black/blank frames, paths). **Do not spend Codex usage assessing artistic composition** or picking the hero. ChatGPT and the user will do visual evaluation. Do not publish to the website without explicit user approval.

## Project preservation / verification

- Strictly preserve all LBS-P040 accepted Controls layout, haptics, Android permission/build/signing/versionCode and pinned tested release commit. `master` remains unchanged and independently usable for the release task. This branch is photography-only.
- Use a separate photo scene/script or opt-in mode and keep normal `scenes/main.tscn` default entry unaffected. No gameplay features, balance, control remaps, 3D reintroduction, shipping exports or website deploy.
- Test Godot headless parse and existing regressions where feasible; run actual graphical capture rather than pretending headless checks provide images. If graphical backend unavailable, report the exact blocker and provide a reproducible manual capture method, but never claim screenshots exist when they don't.
- Preserve clean worktrees and unrelated local files. For this task, a worktree separate from the production development checkout is mandatory. Make a concise handoff in `.ai/CODEX_HANDOFF.md` or a dedicated `docs/portfolio/LBS_PHOTO_001_CAPTURE.md` with exact source, staging state, resolutions, capture commands, limitations, test results, image links and implementation commit SHA.
- After all photo-task criteria pass, commit/push **only to `portfolio/lbs-photo-001`**, do not cherry-pick/merge to `master` without approval. Stop for user review. No premature gallery publication.

**Design intent:** truthful gameplay screenshot demonstrating the current released game, not a cinematic illustration or mockup that falsely implies unimplemented mechanics.
