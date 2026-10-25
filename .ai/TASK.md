# ACTIVE TASK: LBS-P022 — Deploy verified Godot Web build to Mintbase

**Status:** READY FOR CODEX / ONLY ACTIVE TASK. User requested Mintbase hosting after the Web build and established the follow-on automatic-update requirement. ChatGPT has reviewed and accepted P023. Codex is authorized to configure the INITIAL Mintbase static Web hosting in P022, but NOT the future P024 CI/CD automation or unapproved public exposure.
**Goal:** Make the **P023-updated static, single-threaded Godot Web export** from source commit `0378d45f60bb00a54ad278a11bed7c4b2ae2b156` reachable at `http://<Mintbase-reachable-IP>:<chosen-port>/` by devices on the intended network, using Mintbase (user's Linux Mint desktop) as the static HTTP host.

**Forward compatibility:** The user has explicitly requested fully automatic build/deploy for all later approved changes after first Mintbase hosting. **P024 remains QUEUED** at `.ai/TASKS/LBS-P024.md` and must not be implemented yet. P022 should create a deployment-friendly stable static service, versioned release directory, atomic `current` pointer and clean logs/rollback hooks so that P024 can later install the auto-update pipeline without downtime. Do not install a CI runner or enable automatic deployments in P022 unless ChatGPT/user explicitly expands scope.

## Prerequisites

- Confirm user has a verified CURRENT P023 `exports/web/` directory or `exports/lane-ball-shooter-web.zip` produced by the P023 Web refresh on their local development machine; ZIP root contains `index.html` plus JS/WASM/PCK files. Source repository `exports/` is ignored: do not assume `git pull` alone transfers exported binary assets. Don't use a stale build if code changed since export.
- Confirm Mintbase hostname/reachable LAN IP or Tailscale IP at **deployment time**, web port the user wants, proper access and relevant mounted file locations. Earlier IPs might have changed. Avoid revealing unrelated private data.
- Clarify what "anyone" means: by default `http://mintbaseIP:PORT` is reachable only from same LAN or Tailscale tailnet, **not automatically all public internet users**. Expose publicly only after explicit scope/security decision (HTTPS/reverse proxy/Tailscale Funnel or tunnel, firewall and DNS), never port-forward indiscriminately.
- For initial copy, `scp`, `rsync` or same-user LAN transfer; validate SHA256/archive contents and put build in e.g. `~/srv/lane-ball-shooter-web` under a non-privileged user. Don't overwrite unrelated directories or services.

## Deployment steps (P022 is now authorized; do NOT enable future auto-deployment)

1. Verify correct exported `index.html` and companion files. Test locally on Mintbase with `python3 -m http.server 8765 --bind 0.0.0.0 --directory <deploy-dir>` (or configured port) in a bounded way. Check status 200, MIME `application/wasm`, actual browser load from another device via `http://mintbaseIP:PORT/`, then both START GAME > YES fullscreen and NO windowed flows.
2. Once smoke-tested, create a supervised startup configuration (a simple dedicated systemd user service or a minimal stable static server). Use a chosen appropriate bind/interface, restart policy, unprivileged directory permissions, system security defaults, and verified service logs. Avoid a root Python web server; use Caddy/nginx only if already installed or otherwise justified. Do NOT block or conflict with other apps on Mintbase, including its photo background removal website.
3. Configure network/firewall only with explicit user approval and only for the selected interface/access scope. Check remote LAN reachability; if using Tailscale, prefer tailnet-only binding/access restrictions for private distribution. Set exact IP and port dynamically from host rather than guessing.
4. Provide a reusable non-root, idempotent **deploy script for validated runtime files** with versioned release directories, preflight validation and an atomic live-release pointer. Keep prior release for rollback and do not overwrite live files in place. A static server serving a stable symlink generally need not restart on content updates. Document start/stop/status and rollback commands. Make the script safe for the P024 GitHub push → build → deploy automation, but DO NOT activate that automation during P022.
5. Don't enable PWA/cross-origin isolation headers unless export actually requires them. For single-thread default Godot Web build, static server with correct file MIME is normally sufficient; don't add unnecessary SharedArrayBuffer headers. Avoid caching stale .pck/.wasm aggressively during dev iteration.
6. Report correct URLs for LAN/Tailscale where verified, browser requirements (WebGL2/WebAssembly), any platform failures, and exactly which client(s) were actually tested. No assumption that `http://privateIP:PORT` is publicly accessible.
7. Prefer directly SSH/scp or rsync to Mintbase from the existing user's development environment when authorized access exists; code and terminal only, NO GUI/mouse control. Do not invent credentials or host aliases. Confirm correct user account and host using the current SSH config/session before copying. If SSH access is unavailable, implement scripts and handoff clear minimal user commands, and report the exact blocker rather than claiming deployment succeeded.
8. Port 8765 is occupied on the DEVELOPMENT machine, not necessarily Mintbase; check actual Mintbase listeners before choosing the game port. Do not stop/reconfigure other app services. Verify one or more separate clients can load the game menu from LAN/Tailscale and use NO and YES; if unavailable, report which interaction remains untested.
9. Verify the deployed `index.pck` comes from the new P023 build, NOT P021, by comparing the current verified ZIP hash (`08a8d52201b1d3fd03c983267bd54659a5350db109a07bc31e6f09526e5dfccb`) when possible. If build recreated deterministically but ZIP hash differs due to metadata, inspect source export and assets carefully rather than assuming failure. Use safe new-release directory and retain previous version for rollback.

## Future pipeline handoff to P024 (no implementation in P022)

- Record service type/name, serving user, listen interface/port, live pointer, release staging paths, updater permissions, Web build provenance and exact deploy/rollback commands; protect unrelated Mintbase services.
- Confirm whether Mintbase can support the build toolchain locally or if external trusted GitHub CI plus a secure transfer method is preferable. Do not run an untrusted webhook or publicly expose a CI runner.
- A later **P024** will trigger automatic Godot Web builds on each approved `master` push, validate, deploy atomically and report status. Git push triggers deployment, so binaries aren't pushed to GitHub, and there is no automatic commit of unsaved working-directory changes.

## Test and handoff

- Verify HTTP 200 on index and every generated asset from Mintbase, MIME types and console errors if browser testing available, fullscreen request initiated only by YES button, NO windowed. Avoid claiming public internet reachability without external test.
- Keep ordinary game mechanics P017–P020 unchanged. Deployment only, no new game rules.
- Update README with hosting/how to update, `.ai/CODEX_HANDOFF.md`, commit/push source and documentation, STOP. Do not commit generated WASM/PCK to repository or edit ChatGPT-owned mailbox unless explicitly tasked.

## P022 completion discipline

Run project P001–P023 applicable tests as appropriate, plus deployment smoke and runtime service checks. Update README and `.ai/CODEX_HANDOFF.md`, commit/push only source/configuration/scripts/docs, then STOP. Do not edit ChatGPT-owned mailbox files, run P024, install a CI runner, or change Internet exposure. Report service status and the actual tested Mintbase URL only after verified access.
