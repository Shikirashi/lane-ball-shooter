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
- The user requires that **once Mintbase hosting (P022) and its auto-deployment pipeline (P024) are accepted/installed**, every later intentionally committed/pushed `master` change automatically rebuilds, validates, and updates the hosted Godot Web game.
- Continue normal Codex mailbox ownership: implement active task, tests, commit and push source to GitHub, write handoff, then STOP. Once live, deployment is triggered BY THAT PUSH; Codex must not manually overwrite or restart the Mintbase service on ordinary game-code tasks. Validate and report CI/deployment status when available, but do not claim hosted deployment succeeded merely because the Git push succeeded.
- The project does NOT yet have this pipeline. P023 is complete; P022 initial Mintbase hosting is the ONLY active task; P024 post-push automation remains queued. **Do not provision a runner, persistent services, credentials or any external/public network exposure before those tasks are explicitly activated**. Keep generated Web binaries out of Git.
