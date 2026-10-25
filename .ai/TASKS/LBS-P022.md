# QUEUED TASK: LBS-P022 — Deploy verified Godot Web build to Mintbase

**Status:** FUTURE / QUEUED / NOT ACTIVE. NOT authorization for Codex. Activate only after P021 completed and user explicitly asks to host on Mintbase. No current deployment or service configuration was done by ChatGPT.
**Goal:** Make the latest verified **static, single-threaded Godot Web export** (including subsequent P023 changes if accepted) reachable at `http://<Mintbase-reachable-IP>:<chosen-port>/` by devices on the intended network, using Mintbase (user's Linux Mint desktop) as the static HTTP host.

**Forward compatibility:** The user has explicitly requested fully automatic build/deploy for all later approved changes after first Mintbase hosting. **P024 is QUEUED** at `.ai/TASKS/LBS-P024.md` and must not be executed yet. P022 should create a deployment-friendly stable static service, versioned release directory, atomic `current` pointer and clean logs/rollback hooks so that P024 can later install the auto-update pipeline without downtime. Do not install a CI runner or enable automatic deployments in P022 unless ChatGPT/user explicitly expands scope.

## Prerequisites

- Confirm user has a verified `exports/web/` directory or `exports/lane-ball-shooter-web.zip` produced by P021 on their local development machine; ZIP root contains `index.html` plus JS/WASM/PCK files. Source repository `exports/` is ignored: do not assume `git pull` alone transfers exported binary assets. Don't use a stale build if code changed since export.
- Confirm Mintbase hostname/reachable LAN IP or Tailscale IP at **deployment time**, web port the user wants, proper access and relevant mounted file locations. Earlier IPs might have changed. Avoid revealing unrelated private data.
- Clarify what "anyone" means: by default `http://mintbaseIP:PORT` is reachable only from same LAN or Tailscale tailnet, **not automatically all public internet users**. Expose publicly only after explicit scope/security decision (HTTPS/reverse proxy/Tailscale Funnel or tunnel, firewall and DNS), never port-forward indiscriminately.
- For initial copy, `scp`, `rsync` or same-user LAN transfer; validate SHA256/archive contents and put build in e.g. `~/srv/lane-ball-shooter-web` under a non-privileged user. Don't overwrite unrelated directories or services.

## Deployment steps once authorized

1. Verify correct exported `index.html` and companion files. Test locally on Mintbase with `python3 -m http.server 8765 --bind 0.0.0.0 --directory <deploy-dir>` (or configured port) in a bounded way. Check status 200, MIME `application/wasm`, actual browser load from another device via `http://mintbaseIP:PORT/`, then both START GAME > YES fullscreen and NO windowed flows.
2. Once smoke-tested, create a supervised startup configuration (a simple dedicated systemd user service or a minimal stable static server). Use a chosen appropriate bind/interface, restart policy, unprivileged directory permissions, system security defaults, and verified service logs. Avoid a root Python web server; use Caddy/nginx only if already installed or otherwise justified. Do NOT block or conflict with other apps on Mintbase, including its photo background removal website.
3. Configure network/firewall only with explicit user approval and only for the selected interface/access scope. Check remote LAN reachability; if using Tailscale, prefer tailnet-only binding/access restrictions for private distribution. Set exact IP and port dynamically from host rather than guessing.
4. Provide a reusable non-root, idempotent **deploy script for validated runtime files** with versioned release directories, preflight validation and an atomic live-release pointer. Keep prior release for rollback and do not overwrite live files in place. A static server serving a stable symlink generally need not restart on content updates. Document start/stop/status and rollback commands. Make the script safe for the P024 GitHub push → build → deploy automation, but DO NOT activate that automation during P022.
5. Don't enable PWA/cross-origin isolation headers unless export actually requires them. For single-thread default Godot Web build, static server with correct file MIME is normally sufficient; don't add unnecessary SharedArrayBuffer headers. Avoid caching stale .pck/.wasm aggressively during dev iteration.
6. Report correct URLs for LAN/Tailscale where verified, browser requirements (WebGL2/WebAssembly), any platform failures, and exactly which client(s) were actually tested. No assumption that `http://privateIP:PORT` is publicly accessible.

## Future pipeline handoff to P024 (no implementation in P022)

- Record service type/name, serving user, listen interface/port, live pointer, release staging paths, updater permissions, Web build provenance and exact deploy/rollback commands; protect unrelated Mintbase services.
- Confirm whether Mintbase can support the build toolchain locally or if external trusted GitHub CI plus a secure transfer method is preferable. Do not run an untrusted webhook or publicly expose a CI runner.
- A later **P024** will trigger automatic Godot Web builds on each approved `master` push, validate, deploy atomically and report status. Git push triggers deployment, so binaries aren't pushed to GitHub, and there is no automatic commit of unsaved working-directory changes.

## Test and handoff

- Verify HTTP 200 on index and every generated asset from Mintbase, MIME types and console errors if browser testing available, fullscreen request initiated only by YES button, NO windowed. Avoid claiming public internet reachability without external test.
- Keep ordinary game mechanics P017–P020 unchanged. Deployment only, no new game rules.
- Update README with hosting/how to update, `.ai/CODEX_HANDOFF.md`, commit/push source and documentation, STOP. Do not commit generated WASM/PCK to repository or edit ChatGPT-owned mailbox unless explicitly tasked.
