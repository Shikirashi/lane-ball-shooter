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
- Game is hybrid: 2D ball chain, shooter and HUD; 3D orthographic four-lane battlefield with primitive-mesh defenders, enemies and projectiles.
- No external assets, add-ons, complex models, shaders requiring advanced renderer, or external network dependencies in the prototype.
- Centralize ball colors/symbols; visuals and game logic must share authoritative state.
- Keep code modular and deterministic where possible. Favor lightweight logical positions and procedural 3D hopping over rigid-body physics/pathfinding.
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
- P026 has published the real 9-file Godot Web release to `Shikirashi/Shikirashi.github.io/lane-ball-shooter/` on public GitHub Pages at `https://shikirashi.github.io/lane-ball-shooter/`. Portfolio commit `e087383` and game handoff `53bfadb` completed; Pages workflow run `40239268461` succeeded, and user confirmed real-browser gameplay working. P024 is now the ONLY ACTIVE CODEX implementation task.
- P024 is ACTIVE following user browser confirmation: configure trusted source game `master` push -> pinned Godot 4.7.2 Web test/export -> publish all nine runtime files to portfolio Pages folder. Never replace portfolio root or other demos. Limit cross-repo credentials, and do not check secrets into source. Do not assume current Pages publishing updates itself when only game source changes; it does not.
- Once P024 is authorized and installed, normal Codex edits remain scoped to active mailboxes; Codex tests, commits and pushes source then the pipeline performs Web build and publication. Verify CI/deployment before claiming live update. Game source repository keeps binary exports ignored; only portfolio repo stores Web deploy files.
- Do NOT configure obsolete P025 Tailscale Serve, Mintbase CI runners, DNS certificates or public networking on Mintbase.

## Current cross-repository publishing status
- The P026 portfolio publication has completed and the user confirmed the public browser game works; P024 future auto-publish is ACTIVE. Codex pushed the real Web export to portfolio repository `master`, folder `lane-ball-shooter/`, commit `e087383`. Game documentation and handoff commit `53bfadb`; Pages workflow run `40239268461` succeeded.
- Do not rerun P026 or reconfigure private hosting unless user finds a bug. P024 automatic portfolio publication is ACTIVE. Additional deploy credentials must be explicitly approved and set by the user if needed; do not silently grant repository permissions or invent credentials.

## Current automation scope (P024 active)
- P024 implements approved game source push -> tests/pinned Web export -> portfolio GitHub Pages folder publication; excludes game difficulty tweaks and docs-only mailbox changes. P026 game build remains hosted/playable while setup occurs.
- Respect cross-repository credential limits: if a new narrow-scope token, deploy key or GitHub App authorization is necessary, stop at a clear approval/setup checkpoint rather than committing credentials or claiming fully operational automation. No Mintbase runners, Tailscale Serve or public port changes.

## Next after P024 — queued Android portfolio release (P027)
- **P024 remains ONLY ACTIVE task.** P027 is archived in `.ai/TASKS/LBS-P027.md` and queued for Android APK export, signing, release asset publication and native-looking card on existing portfolio homepage. Do not start P027 until ChatGPT explicitly activates it.
- Portfolio actual `index.html` cards are existing Bootstrap/Isotope `item-wrap` screenshot-with-hover-overlay tiles; clone style for new `Lane Ball Shooter` Mobile/Download APK card. Only show working link after verified release-signed APK is published, ideally GitHub Releases CDN; don't bulk-commit Android APK into portfolio Git history. Preserve existing `lane-ball-shooter/` Web assets and P024 updates.
- Never publish debug-signed APK as public production build, commit app signing secrets, or change Google Play settings without explicit approval. Report precise missing JDK/Android SDK/keystore/permission blockers to user and stop safely.
