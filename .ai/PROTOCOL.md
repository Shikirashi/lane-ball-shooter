# Shared Mailbox Protocol

This is the coordination surface between ChatGPT (design/task owner), Codex (implementer), and the user (tester).

1. ChatGPT writes **one active** implementation request to `.ai/TASK.md`, updates decisions and ledger, commits/pushes.
2. User starts Codex inside the **local clone of this same repository**.
3. Codex pulls latest, reads `AGENTS.md` and all mailbox files, executes only the active task, runs available tests, then commits/pushes its code and `.ai/CODEX_HANDOFF.md`.
4. User can say **"check push"**. ChatGPT reviews GitHub commit and handoff, requests fixes or advances `.ai/TASK.md`/ledger for the next task.
5. No automatic self-advancement by Codex. No parallel overlapping mailbox writers. Pull before editing, push after verification.

## Required Codex handoff (short)
- Task ID and status: COMPLETE / PARTIAL / BLOCKED.
- Commit SHA / branch; concise files/features changed.
- Tests attempted, commands and results (including Godot/headless/version if known).
- Manual playtest instructions (controls and what to look for).
- Known issues / assumptions / questions for next task.

## Ownership
- ChatGPT edits: `AGENTS.md`, `.ai/TASK.md`, `.ai/TASK_LEDGER.md`, `.ai/DECISIONS.md`, `.ai/PROTOCOL.md`.
- Codex edits implementation, README and `.ai/CODEX_HANDOFF.md`.
- Codex can propose alternate rules in handoff, but must not rewrite established decisions unasked.

## Completion criteria
- Deliver a running incremental build, not just pseudocode, subject to current active task scope.
- Run bounded automated verification whenever available; do not start infinite game loops without timeouts.
- Use descriptive commits; push normally (never force).
- Stop and report blocking tool/environment absences; do not claim exports were tested without the SDK/templates.
