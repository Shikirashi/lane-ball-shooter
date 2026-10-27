# Lane Ball Shooter — Codex Repository Instructions

This repository uses a shared Git mailbox. ChatGPT writes and advances tasks; Codex executes them and reports back.

## Startup (always)
1. Work only in this repository. Verify its git remote and branch first.
2. Pull latest changes with `git pull --ff-only` if the repository has an existing tracked branch (do not discard local changes).
3. Read in order: `AGENTS.md`, `.ai/PROTOCOL.md`, `.ai/DECISIONS.md`, `.ai/TASK_LEDGER.md`, `.ai/TASK.md`.
4. Execute **only the active task** in `.ai/TASK.md`. The ledger is a roadmap, not authorization to skip ahead.
5. Implement with code and text files; no GUI/mouse automation. The user will playtest visually as needed.
6. Run available bounded noninteractive validations (prefer Godot headless), document tests and any limitations.
7. Write a concise implementation report to `.ai/CODEX_HANDOFF.md`, then commit and push code + handoff to the tracked branch.
8. Stop after the active task. ChatGPT will review your push and post the next task.

## Project constraints
- Godot 4.x (target user's installed 4.7.2) **GDScript**; Web and Android must share one project.
- Godot **Compatibility renderer** for Web, plus Android landscape export later.
- Landscape 16:9 reference with responsive safe-area positioning for wider phones/browser resizing.
- **Latest authorized P034B override:** the formerly hybrid 2D/3D game is being migrated to an all-2D live presentation. Preserve the existing 2D ball chain, shooter and HUD, but replace runtime 3D battlefield/actors/projectiles with 2D sprites and effects sourced from P034A; retain 3D mesh source only for offline sprite rebaking and legacy tests. All gameplay logic stays unchanged. Historical references to a required runtime 3D battlefield are superseded.
- No external assets, add-ons, complex models, shaders requiring advanced renderer, or external network dependencies in the prototype.
- Centralize ball colors/symbols; visuals and game logic must share authoritative state.
- Keep code modular and deterministic where possible. Preserve lightweight authoritative logical positions and hop timers; express character movement as purely cosmetic 2D squash/stretch/hops over that state. Never replace model movement with sprite-driven physics.
- Do not silently invent game rules. Follow `.ai/DECISIONS.md`, document reversible assumptions in the handoff.

## Mailbox ownership
- ChatGPT owns: `.ai/TASK.md`, `.ai/DECISIONS.md`, `.ai/TASK_LEDGER.md`, `.ai/PROTOCOL.md`.
- Codex owns: `.ai/CODEX_HANDOFF.md` and implementation files.
- Do not self-assign a new task or edit task/decision/ledger files. Make proposed changes in handoff instead.

## Safety and scope
- Do not overwrite user work, force-push, reset unrelated commits, or remove files without task justification.
- If a tool/export SDK is absent, make the best useful implementation, describe how to verify later, and do not fabricate successful validation.
- Keep commits clearly scoped. Prefer an immediately inspectable scene over purely architectural scaffolding.

## Web deployment lifecycle (future, conditional)
- P026 has published the real 9-file Godot Web release to `Shikirashi/Shikirashi.github.io/lane-ball-shooter/` on public GitHub Pages at `https://shikirashi.github.io/lane-ball-shooter/`. Portfolio commit `e087383` and game handoff `53bfadb` completed; Pages workflow run `40239268461` succeeded, and user confirmed real-browser gameplay working. P027 is the ONLY ACTIVE CODEX implementation task; P024's Web CI build/test passed, publication awaits user's scoped portfolio token.
- P024 Web CI is implemented and tested but production publish waits on user credential: configure trusted source game `master` push -> pinned Godot 4.7.2 Web test/export -> publish all nine runtime files to portfolio Pages folder. Never replace portfolio root or other demos. Limit cross-repo credentials, and do not check secrets into source. Do not assume current Pages publishing updates itself when only game source changes; it does not.
- Once P024 is authorized and installed, normal Codex edits remain scoped to active mailboxes; Codex tests, commits and pushes source then the pipeline performs Web build and publication. Verify CI/deployment before claiming live update. Game source repository keeps binary exports ignored; only portfolio repo stores Web deploy files.
- Do NOT configure obsolete P025 Tailscale Serve, Mintbase CI runners, DNS certificates or public networking on Mintbase.

## Current cross-repository publishing status
- The P026 portfolio publication has completed and the user confirmed the public browser game works; P024 future auto-publish is ACTIVE. Codex pushed the real Web export to portfolio repository `master`, folder `lane-ball-shooter/`, commit `e087383`. Game documentation and handoff commit `53bfadb`; Pages workflow run `40239268461` succeeded.
- Do not rerun P026 or reconfigure private hosting unless user finds a bug. P024 Web CI is implemented; automatic portfolio publication is pending user token. Additional deploy credentials must be explicitly approved and set by the user if needed; do not silently grant repository permissions or invent credentials.

## Current automation status (P024 credential checkpoint; P027 active)
- P024 implements approved game source push -> tests/pinned Web export -> portfolio GitHub Pages folder publication; excludes game difficulty tweaks and docs-only mailbox changes. P026 game build remains hosted/playable while setup occurs.
- Respect cross-repository credential limits: if a new narrow-scope token, deploy key or GitHub App authorization is necessary, stop at a clear approval/setup checkpoint rather than committing credentials or claiming fully operational automation. No Mintbase runners, Tailscale Serve or public port changes.

## Next after P024 — queued Android portfolio release (P027)
- **P024 remains ONLY ACTIVE task.** P027 is archived in `.ai/TASKS/LBS-P027.md` and queued for Android APK export, signing, release asset publication and native-looking card on existing portfolio homepage. Do not start P027 until ChatGPT explicitly activates it.
- Portfolio actual `index.html` cards are existing Bootstrap/Isotope `item-wrap` screenshot-with-hover-overlay tiles; clone style for new `Lane Ball Shooter` Mobile/Download APK card. Only show working link after verified release-signed APK is published, ideally GitHub Releases CDN; don't bulk-commit Android APK into portfolio Git history. Preserve existing `lane-ball-shooter/` Web assets and P024 updates.
- Never publish debug-signed APK as public production build, commit app signing secrets, or change Google Play settings without explicit approval. Report precise missing JDK/Android SDK/keystore/permission blockers to user and stop safely.

## ACTIVE mailbox and release separation
- P027 is currently the ONLY active Codex task in `.ai/TASK.md`: prepare and, only when signing and release permissions are available/approved, publish actual signed Android APK and matching existing-style portfolio download tile. Do not alter unrelated portfolio cards, switch Pages host, or mark empty/fake APK links live.
- P024 cross-repo publishing token was added by user and worked: run `40244954365` pushed production portfolio `d3c09f58` and Pages `40245097145` completed. Build, static hashes and browser secure live canvas passed; workflow result red only on Chrome temporary-profile cleanup `ENOTEMPTY`. A targeted verifier cleanup repair is permitted; no new token needed.

## P027 current checkpoint
- P027 source scaffolding was pushed as `75f0dd75` and reviewed. Actual release APK/card remains BLOCKED by absent Android SDK, Android release template, signing identity and device. The ONLY active task is to safely bootstrap user-local Android toolchain per current `.ai/TASK.md`, test it and stop before creating a private keystore without explicit user approval. Preserve P024 Web CI and current public portfolio, do not publish placeholder APK links.

## Latest state after SDK/key backup checkpoint
- P027 signing key and local environment already EXIST, created by Codex with user approval. User confirms secure root-protected backup at `/var/backups/lane-ball-shooter/`. Do not recreate key or paste secrets. Next user-dependent step is Google command-line tools installation and explicit SDK license acceptance; then existing scripts can build and verify release APK. Do not publish Android card before actual tested asset.
- P024 cross-repo pipeline has successfully pushed and Pages has deployed; fix only race in `scripts/ci/verify_browser_startup.mjs` by waiting for spawned Chrome to exit and safely removing temp profile without weakening secure canvas assertions; rerun targeted CI. Game mechanics and portfolio homepage stay untouched.

## Authoritative latest status — P024/P027 published (2026-10-25 23:53 UTC)
- **NO ACTIVE CODEX TASK.** All earlier AGENTS text describing P024 token blockers, P027 SDK licensing, release key creation or pending APK publication is HISTORICAL AND SUPERSEDED. Trust current `.ai/TASK.md`, completed task archives and Codex handoff.
- P024 automation COMPLETE: scoped portfolio token configured; Actions run `40246262499` fully SUCCESS; Web game published and verified over HTTPS; browser-profile cleanup bug fixed.
- P027 release delivery COMPLETE: `android-v0.1.0` tag at `0e77dbd`, public release APK `lane-ball-shooter-android.apk`, SHA256 `cf390a1abbbbe3e8e937710e46a32aede297ddf43c0c41507d29549e8450ea26`; portfolio screenshot/mobile DOWNLOAD APK card deployed `94c5e77`, Pages `40246539248` SUCCESS. Android physical-device QA still untested because no device attached; next user action is sideload and test.
- Do not regenerate signing identity, change Android version code/signature unless preparing a NEW release, overwrite user's uncommitted Godot files, or edit public cards without a newly authorized task. Release key backup already confirmed under root-protected `/var/backups/lane-ball-shooter/`.

## Latest active scope — P034B, 2026-10-27

- **ONE ACTIVE TASK: LBS-P034B** in `.ai/TASK.md`. User chose to continue with runtime 2D migration after P034A completed, despite being unable to run a GUI over SSH. The older NO ACTIVE TASK notices elsewhere in this file are historical.
- Build a fully playable 2D-rendered battlefield using committed transparent P034A PNG actors, procedural 2D motion/effects and appropriately filled responsive lanes; keep existing combat, ball chain, enemy schedule/HP/abilities and platform input rules unchanged.
- **Mandatory remote review evidence:** commit reproducible real Godot-rendered screenshots of the live 2D game in standard and wide landscape layouts. Do not require a GUI or user visual intervention. Preserve P034A's baker and reproducibility.
- **P033 touch controls, P028 balancing, P029+ content/branding and Android packaging/release updates are NOT ACTIVE.** Only run P034B. When complete, update Codex handoff, commit/push verified work and stop. Do not self-advance.

## After P034B technical review — 2026-10-27

- **NO ACTIVE TASK:** P034B 2D runtime migration was pushed as `b802096` and verified by code/screenshot review and GitHub Web CI run `40548949659` (all tests, publishing and browser startup SUCCESS). Archived task: `.ai/TASKS/LBS-P034B.md`. User's hands-on visual feedback still pending. This supersedes the earlier "P034B ACTIVE" and legacy 3D-only sections above.
- Only re-activate from a new explicit user request through `.ai/TASK.md`; P033 controls and P028 balancing are proposals. Native Android v0.1.0 release predates P034B and was not updated. Never modify its protected signing files without a separately authorized release task.

## Latest active scope — P034C (2026-10-27)

- **ONLY ACTIVE CODEX TASK:** `LBS-P034C`, specified in `.ai/TASK.md`. Earlier no-active/P034B-active status paragraphs here are historical.
- Remove original 3D baked yellow ChargeOrb, genuinely rebake transparent defender PNGs with existing GPU/CLI pipeline; add independent colored faceted 2D charge crystals behind live defenders, shatter/fade once on authoritative emergency discharge, never restore on revival, restore on run restart. Never dim whole defender when spent. Retain all combat semantics.
- New actual-Godot-rendered gameplay screenshot evidence REQUIRED for SSH review. Preserve existing P034A/P034B assets, tests and live all-2D runtime. `P033` controls, `P028` balancing, branding, Android version/release and other work NOT ACTIVE. No self-advancement.

## After P034C technical review — 2026-10-27

- **NO ACTIVE CODEX TASK.** The prior P034C ACTIVE status above is historical: Codex implemented the transparent rebake / colored crystal / one-shot shatter as `16347b3`, with handoff `04d6075`, source and screenshot review PASS. Archive `.ai/TASKS/LBS-P034C.md`. GitHub CI `40555144242` completed SUCCESS (build/test and public portfolio publication).
- Do not self-activate P033 controls, P028 balancing, branding, levels or Android publishing. `.ai/TASK.md` is the ONLY authority for future work. Preserve local edits/signing files.

## Latest ACTIVE task — P033 (2026-10-27, controls + explicit easing)

- **ONE ACTIVE CODEX TASK: LBS-P033**, specified in `.ai/TASK.md`. All earlier idle-status and P034[A–C]-active passages are historical. P034A/B/C completed and technical reviewed, 2D game and charge crystals must remain intact.
- User explicitly folded **HALVE ALL enemy HP** into P033: Hopper 3, Heavy 6, Sickle Snake 3, Healyzard 3, superseding old P022 6/12/6/6. Update `EnemyTypes.MAX_HP`, model fallback and all affected test assertions/fixtures, but **do not** change damage, enemy speeds, spawn frequency, ball supply, skills, one-use crystal or other balance.
- Also user requests strong **Minecraft-like RED sprite flash** when each enemy takes actual damage, including lethal hit during death animation, and restored survivor colors. Prefer actual per-sprite red color mixing/overlay over multiplicative darkening on green/yellow sprites, retain alpha and 2D animation.
- Complete P033 Classic Android primary aim/drag-release plus second-finger swap, Side left/right-handed 1:2:1 **relative trackpad + upper swap/lower shoot** mode, persisted settings and accessible UI, hidden Android swap button, **raised shooter/horizontal loaded-next** positions, desktop/Web click/shoot anywhere including conveyor (except real settings/buttons). Preserve full current 2D battlefield, responsive fit, combat/chain mechanics, tests and P034C charge crystal.
- **SSH review requires real Godot-rendered gameplay screenshots** committed under `assets/previews/` and deterministic input/HP/red-hit regression tests; Web compatibility and Android platform QA reported honestly. P028A, campaign, branding and Android signed APK/release are NOT ACTIVE. No local signing-key access or changes, no self-advancement after push.

## Current ACTIVE correction after P033 initial push — P033R (2026-10-27)

- **ONLY ACTIVE TASK** is narrowly scoped P033R shader fix in `.ai/TASK.md`. P033 code commit `294ddae` already implemented controls, raised shooter, canonical HP 3/6/3/3 and red hit feedback, but review detected wrongly darkened unhit sprites because a Godot 4 CanvasItem fragment shader multiplied `texture(TEXTURE, UV) * COLOR`; incoming fragment `COLOR` already includes the texture. Fix this double texture sampling, add actual rendered undamaged-vs-source RGBA regression evidence, recapture P033 screenshot, rerun tests/build and push handoff. DO NOT reimplement P033 or start P028 or change release/signing.

## P033R latest user override — solid-red overlay, NO recoloring shader (2026-10-27)

- The **ONE ACTIVE P033R** correction in `.ai/TASK.md` now uses a *separate solid-red alpha-matched `Sprite2D` silhouette over the original untouched enemy sprite*. The user's new explicit choice supersedes the earlier instruction above to **repair** the faulty tint shader. **Remove the shader instead of fixing/replacing it with another shader.**
- Generate exact-alpha red-mask textures from the existing P034A enemy PNGs, ideally as reproducibly committed assets; align overlay to base sprite throughout animation/Snake transfers, fade over the existing real-hit timer and lethal corpse start, leave unhit sprites visually identical. Strict alpha/render tests and new actual gameplay screenshots for SSH review.
- Preserve delivered P033 input and shooter work, canonical enemy HP 3/6/3/3, P034C crystals and all earlier gameplay. P028 and unrelated tasks NOT ACTIVE. No Android signed release or signing secrets.

## After P033R technical review — 2026-10-27

- **NO ACTIVE CODEX TASK.** P033 controls/HP `294ddae` and P033R red silhouette fix `f08ee3d` were delivered. Source, exact-alpha derived red masks and Godot-rendered comparison images have been reviewed; no blocking defects found. P033R archive `.ai/TASKS/LBS-P033R.md`. Earlier P033R ACTIVE notices are historical.
- Only `.ai/TASK.md` authorizes work. P028A color/speed/enemy pressure balancing lab and remaining campaign/branding features are NOT ACTIVE. Physical Android gesture testing remains outstanding; no signed APK rebuild authorized.

## Current ACTIVE scope — P028A analysis-only balancing lab (2026-10-27)

- **ONLY ACTIVE CODEX TASK is LBS-P028A**, authoritative specification `.ai/TASK.md`. User approved continuing after P033/P033R, which are COMPLETE. Earlier NO ACTIVE TASK and P033/P033R-active notices are history.
- Implement and **execute** deterministic, bounded Godot CLI model-driven analysis for color generation, actual conveyor visibility/match opportunity, loaded/next/fired ammo, recorded match outcomes and enemy pressure/time-to-danger, producing JSON/CSV and a causal Markdown report. Record seed provenance and realistic simulation limitations.
- Test only alternate conveyor speed (102/120/140/160) and optional run weights in a sandbox. **NO SHIPPED BALANCE CHANGE**: do NOT adjust ChainModel default speed, current 1–7 run weights, four-color bag, seed policy, enemy HP **3/6/3/3**, speed/spawns, healing/Snake logic, physical off-left history, match/rollback, controls, 2D visuals or crystals.
- **P028B is NOT ACTIVE**: do not implement threat-aware colors, starvation protection, speed increase or new weighted run distribution in gameplay until research report and a separate user decision. P029–P032 campaign/levels/branding and Android APK release NOT ACTIVE either.
- Preserve all user-local files/signing secrets. Run whole regression suite plus bounded simulation smoke tests, commit generated report and tool/tests/handoff, push and STOP. Do not self-advance.

## Current ACTIVE correction — P028AR (2026-10-27)

- **ONLY ACTIVE task:** `LBS-P028AR`, authoritative `.ai/TASK.md`; earlier P028A ACTIVE status historical. The P028A lab landed as `6564001`, but bots were allowed to home horizontally to a moving target's current x at impact, unlike real `ShooterView.launch` which freezes X at firing. Also impact was resolved before time-slice chain motion. Fix these **simulation-only** fidelity errors, add real shot-miss/accuracy regression tests, regenerate authentic seed/scenario report and rerun full test/build validation.
- Never change shipping defaults: conveyor speed 102 px/s, run weights [20,30,18,13,9,6,4], four-color feeder/bag, enemy HP 3/6/3/3, spawn director, physics, Android controls/signing or Web publisher. P028B is proposed only and NOT ACTIVE; stop after verified correction/handoff push.

## After P028AR technical review — no active task (2026-10-27)

- **NO ACTIVE CODEX TASK.** Initial audit `6564001` corrected by `78b535b`, with fixed-X projectile/collision timing, reproducible generator/scenario analysis and reviewed tests/source PASS; archive `.ai/TASKS/LBS-P028AR.md`. The preceding P028AR ACTIVE section above is historical. CI `40571348733` final outcome still requires verification.
- P028B is **not authorized**. No changes to 102px/s production feed, 1–7 run weights, color RNG, HP 3/6/3/3, spawn director, input, 2D VFX or Android release. Await an explicit user decision in `.ai/TASK.md` before more Codex work.
