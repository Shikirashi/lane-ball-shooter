# QUEUED TASK: LBS-P024 — Automatically build, validate and deploy each approved Web update

**Status:** QUEUED / NOT ACTIVE. **Do not execute P024 until P022 Mintbase hosting is complete, manually verified, and ChatGPT explicitly activates P024.** Current active task remains whatever `.ai/TASK.md` states (P023 at planning time); this archived spec is NOT authorization.
**User decision 2026-10-25:** Once Mintbase is serving Lane Ball Shooter, ALL subsequent approved game changes should automatically propagate to the browser version hosted on Mintbase, without repeated manual Godot exports, file copying or web-service restarts. Source changes still need normal Codex implementation, tests, commit and GitHub push.

## Goal and intended order

1. Codex/user makes intended source modifications in `Shikirashi/lane-ball-shooter` and runs local checks.
2. Codex commits and **pushes `master`** (do not confuse with pushing generated WASM/PCK).
3. That approved push automatically triggers a CI/CD job against that exact commit (never blindly deploy an uncommitted checkout).
4. Build with pinned **matching Godot 4.7.2 official non-Mono Web export templates** using existing `scripts/build_web.sh` or a repeatable improved noninteractive equivalent; Godot Compatibility and single-threaded Web export must remain intact.
5. Validate tests and static HTML/JS/WASM/PCK output, ensure all referenced files exist and are correctly packaged.
6. Stage output into a versioned release directory on Mintbase, verify it before promotion, and atomically activate the new release so **the same IP:PORT** immediately serves it for fresh page loads. Preserve a known-good release for rollback.
7. Report deployed commit, build status and errors through the CI/deployment logs (optionally check/status endpoint), and leave prior live version serving if build/deploy/health check fails.

**IMPORTANT:** Do NOT design "automatically push every file change in a watched worktree." Only deliberate Codex/user commits to the designated trusted branch deploy. Never force-push, auto-commit secrets or publish arbitrary local files. Avoid a CI loop from bot-generated commits; deployment should not need to push source commits back to GitHub.

## Deployment design

- Use the Mintbase server/service and port already provisioned and tested under P022, keeping other apps (including rembg) untouched. Avoid hardcoded prior LAN/Tailscale IPs, changing firewall rules or exposing the game publicly. Read actual P022 handoff to learn service name, directory layout, privilege/port boundaries and whether Mintbase is also the dev/build machine.
- Prefer a GitHub Actions `push` trigger on `master` combined with an **isolated, non-root self-hosted runner on Mintbase** if its security and credentials can be configured safely. Alternatively, if already-provisioned trusted infrastructure better fits, document/choose a GitHub-hosted builder plus authenticated private deployment channel (e.g. Tailscale) or a secure server-side pull agent. No inbound public webhook/SSH port should be required as a default. Discuss risks of executing repository workflow code on Mintbase; limit accepted triggers to trusted branch, do not run untrusted PR jobs on the Mintbase runner, scope credentials minimally, and obtain user's approval for persistent runner/service installation before starting it.
- Separate **source repo/worktree**, **build cache**, **staging release**, and **live static document root**. Bind the static host to the desired authorized network only. A release could be `~/srv/lane-ball-shooter/releases/<commit-sha>/` and a `current` symlink, with appropriate per-user filesystem permissions; adapt to P022 actual paths.
- Use a temporary staging directory and verify exported assets, sizes and MIME/HTTP before switching `current`. Atomic symlink swap or equivalent prevents readers seeing partial exports. Keep >=2 known-good versions and offer one-command rollback. Never `rsync --delete` directly into the live `current` target.
- Static server should **stay running if only web files change**. Restart/reload its user service only if actual server config/service binary changes, not with every update. Existing live games need not be forcibly reloaded; newest game is served after a page refresh. Consider cache control for `index.html` and fresh build asset URLs to prevent HTML/PCK/WASM mismatches while avoiding unnecessary bandwidth or cache busting.
- Godot build/web package currently in ignored `exports/`. Continue not committing compiled `index.wasm`, `index.pck` or ZIP to Git. CI can store a temporary, access-controlled build artifact/manifest if useful, but publicly sharing it requires explicit permission. The source GitHub repository remains the canonical source of truth.
- Pin/verify Godot and export template versions, refrain from silently downloading incompatible or modified tools, and ensure reproducible dependencies. If template installation/bootstrap is part of CI, source from trusted official releases.
- A newly pushed commit supersedes a still-running older CI job: serialize deploys, cancel safely, and prevent an older build from becoming live AFTER a newer valid build. Check expected SHA under a release lock before promotion. Protect against partial ZIP, failed checks, unavailable disk/network, and simple retries without downtime.
- Each source push should trigger fresh Web build even for post-P024 gameplay code changes. Allow explicit manual rebuild/rollback actions for recovery, with clear logs and last-deployed SHA.
- If workflow files have modified permissions/execution path, review security; do not run arbitrary shell under root, write to unrelated service dirs, or grant GitHub credentials access to system resources.

## Acceptance / tests

1. Push an intentionally benign code change on `master` (after separate user/Codex task authorization). Verify auto workflow starts, Godot Web export completes, HTTP serves correct new content from Mintbase at same address/port without manual file copy or service restart.
2. Verify `P001`–latest gameplay regression suite, new packaging/smoke tests, and Web entry menu behavior; do not depend on stale `exports/` outputs. If full suites are expensive, use gating tiers with mandatory relevant tests and no silent claims of complete coverage.
3. Deliberately introduce a **test fixture-only simulated build failure**, with no persistent broken commit: verify last good deployed build remains accessible, live symlink unchanged, clear job FAILED status. Also simulate missing asset/HTTP failure pre-activation.
4. Race two successive trusted commits: only newest validated commit can be promoted after both builds complete.
5. Restart Mintbase to verify static service AND trusted deployment runner/agent recover automatically without elevated root access.
6. Confirm browser shows latest content after reload and normal non-fullscreen and fullscreen YES/NO flows still work, including real browser checks if supported. Verify no unintended restarts/interruptions.
7. Update `README.md` with once-only setup, credentials/permissions overview (NEVER document tokens), workflow semantics, logs, status, how to trigger deployment, how to disable automatic deployments, rollback and recovery.
8. Update `.ai/CODEX_HANDOFF.md` with actual verified workflow, commit→build→deploy→health proof, names/paths of user services and pipeline files, exact commands, test results and any remaining operational risks.

## End

Commit/push only CI workflow sources, safe scripts/docs and Codex handoff to `master`; do not modify ChatGPT-owned mailbox files or other tasks. **STOP**. ChatGPT will review and mark P024 complete. Hosted build assets remain separate from Git source. P024 remains queued until P022 hosting is installed and the user is ready to authorize automatic deployment services.
