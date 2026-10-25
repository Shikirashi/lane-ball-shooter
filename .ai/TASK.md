# ACTIVE TASK: LBS-P022 — Triple enemy HP, rebuild Web version, host on Mintbase

**Status:** READY FOR CODEX / ONLY ACTIVE TASK. User requested Mintbase hosting after the Web build and established the follow-on automatic-update requirement. ChatGPT has reviewed and accepted P023. Codex is authorized to configure the INITIAL Mintbase static Web hosting in P022, but NOT the future P024 CI/CD automation or unapproved public exposure.
**Goal:** FIRST **triple the maximum HP of all four enemy archetypes**, then compile a **NEW single-threaded Godot Web release with the HP changes**, and make THAT release reachable at `http://<Mintbase-reachable-IP>:<chosen-port>/` by devices on the intended network, using Mintbase (user's Linux Mint desktop) as the static HTTP host.

**Forward compatibility:** The user has explicitly requested fully automatic build/deploy for all later approved changes after first Mintbase hosting. **P024 remains QUEUED** at `.ai/TASKS/LBS-P024.md` and must not be implemented yet. P022 should create a deployment-friendly stable static service, versioned release directory, atomic `current` pointer and clean logs/rollback hooks so that P024 can later install the auto-update pipeline without downtime. Do not install a CI runner or enable automatic deployments in P022 unless ChatGPT/user explicitly expands scope.

## A. User-requested gameplay rebalance — three times HP on EVERY enemy (new P022 scope)

**Explicit user request (2026-10-25 21:24):** Fold the HP increase into P022 before building/hosting: **TRIPLE every enemy archetype's canonical maximum and initial HP**, exactly ×3 over P023. These are base enemy stats for every newly spawned game enemy, including the four initial enemies and later weighted spawns.

| Enemy | Previous Max/Spawn HP | P022 Max/Spawn HP | Other traits unchanged |
| --- | ---: | ---: | --- |
| Hopper | 2 | **6** | Speed 0.312, gray hopping, two permanent orange decorative horns |
| Heavy | 4 | **12** | Speed 0.2184, orange wider slide |
| Sickle Snake | 2 | **6** | Speed 0.624, yellow taller slide, 0.5s nonfatal-hit stun / random adjacent-lane transfer, 15s global post-death cooldown |
| Healyzard | 2 | **6** | Speed 0, green smaller stationary healer, +1 HP to others every 15s, yellow aura |

- Update authoritative `EnemyTypes.MAX_HP` entries to **6/12/6/6**. Also update historical/default `LaneCombatModel.DEFAULT_ENEMY_HP` / `enemy_max_hp` expectations to 6 wherever relevant, so no generic/default spawn path accidentally creates 2HP Hoppers. Keep both `enemy.hp` and `enemy.max_hp` canonical for default typed spawns. An explicitly overridden `hp_value` in old unit test fixtures can be smaller for test purposes, but must not override the actual canonical max HP in gameplay. Audit direct typed spawn/test fixture overrides and ensure healer caps are canonical.
- **Critical combat rules:** Tier 1 = one projectile for 1 damage; Tier 2 = two projectiles, EACH 2 damage (maximum 4 if both hit); **Tier 3 = instant clearance of all enemies in the matched-color lane plus one selected adjacent lane**, ignoring HP entirely, as before. Emergency lane clear likewise kills regardless of HP. NEVER turn tier 3 or emergency clear into damage-based attacks as part of this HP change.
- Preserve Snake movement and behavior: surviving tier1/tier2 hits stun for exactly 0.5s and then lane switch once, not just when on its final HP; fatal hit during stun/transfer removes it once. After transfer remain at correct remaining HP / `max_hp=6`. The global cap of one live Snake / 15s after death stays intact.
- Preserve Healyzard **+1 HP per 15-second pulse** (NOT tripled to +3), no self/other healer healing, cap targets at new 6/12/6 HP, no max-HP overflows. Healyzard's own 6 HP permits surviving hits but not self-healing. No HP UI: Hopper's orange blocks are decorative horns and never change with damage; other enemy types have no horns or health bars.
- Preserve movement and spawn balance: Hopper 0.312, Heavy 0.2184, Snake 0.624, Healyzard 0; 50/20/20/10 base weights, 5 concurrent enemies per lane, 8 successful spawns/lane (32 total), P017 102px/s conveyor, P018 3s delayed victory presentation, P023 exact subtitle `All enemies neutralized`, P021 Web-only fullscreen menu and native direct boot. No other balance alterations.

### Tests for new HP values
- Add `tests/p022_enemy_hp_test.gd` or equivalent with exact canonical max/default spawn and runtime HP **6/12/6/6**, + tier1/tier2 damage scaling, lethal thresholds, healer restoring exactly one point (up to new caps), Snake nonfatal stun/transfer retaining 6HP max and remaining damage, tier3 full-lane instant kills of full-HP Heavy/Snake/Healyzard, emergency instant clears and correct P018 death events.
- Audit and update prior P001–P023 regression fixtures and assertions that hardcode former 2/4/2/2 HP, particularly typed roster and P020 special-ability tests. **Do not merely update expected values to make old damage-logic tests pass**: maintain or extend tests ensuring multi-hit durability, damaging a Snake and its special state transitions, and heal cap behaviors with 6/12/6HP.
- Run **all P001–P023 suites plus the new P022 HP tests** under Godot 4.7.2 with no skipped stress test, plus bounded Web/native boot checks and `git diff --check`. Report outcomes and manual balance QA in handoff.

## B. Mandatory NEW Web build from post-HP source (old P023 zip is stale)

- Once the HP changes and tests are implemented, execute `./scripts/build_web.sh` to build from the **new P022 source tree**. Verify fresh generated `index.html`, JS, WASM, PCK and all runtime companions, then produce a NEW ZIP and record its SHA256. **Do not deploy the P023 archive SHA `08a8d52201b1d3fd03c983267bd54659a5350db109a07bc31e6f09526e5dfccb`**; it contains old 2/4/2/2 enemy HP. If build tools unavailable, document blockers instead of deploying a stale build.
- Record the build's source commit (or precise precommit worktree state and subsequent source commit) in a release manifest; compare new and old PCK hashes, and verify the new HP behavior from bundled source/pack if feasible. The package must match the committed P022 gameplay changes.
- As before, exported binaries remain LOCAL and ignored. The later P024 automated pipeline will build on trusted source pushes; P022 does not enable that CI/CD pipeline.

## C. Mintbase static hosting

## Prerequisites

- Confirm a newly built **P022 HP-adjusted** `exports/web/` directory or `exports/lane-ball-shooter-web.zip` produced AFTER the above HP changes on the local development machine; ZIP root contains `index.html` plus JS/WASM/PCK files. Source repository `exports/` is ignored: do not assume `git pull` alone transfers exported binary assets. Don't use a stale build if code changed since export.
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
9. Verify deployed `index.pck` comes from the NEW P022 ×3-HP Web build, and NOT the older P023 archive/hash. Record NEW current archive SHA256 and source revision; demonstrate bundled HP changes where feasible. Use a safe versioned release directory and retain previous release for rollback. Never promote an old-HP archive.

## Future pipeline handoff to P024 (no implementation in P022)

- Record service type/name, serving user, listen interface/port, live pointer, release staging paths, updater permissions, Web build provenance and exact deploy/rollback commands; protect unrelated Mintbase services.
- Confirm whether Mintbase can support the build toolchain locally or if external trusted GitHub CI plus a secure transfer method is preferable. Do not run an untrusted webhook or publicly expose a CI runner.
- A later **P024** will trigger automatic Godot Web builds on each approved `master` push, validate, deploy atomically and report status. Git push triggers deployment, so binaries aren't pushed to GitHub, and there is no automatic commit of unsaved working-directory changes.

## Test and handoff

- Verify HTTP 200 on index and every generated asset from Mintbase, MIME types and console errors if browser testing available, fullscreen request initiated only by YES button, NO windowed. Avoid claiming public internet reachability without external test.
- Keep ordinary game mechanics P017–P021 and P023 unchanged EXCEPT the explicitly authorized **×3 enemy HP** rebalance in this P022 task. Preserve tier3/emergency instant clears.
- Update README with hosting/how to update, `.ai/CODEX_HANDOFF.md`, commit/push source and documentation, STOP. Do not commit generated WASM/PCK to repository or edit ChatGPT-owned mailbox unless explicitly tasked.

## P022 completion discipline

Run ALL project P001–P023 suites plus new P022 HP test(s), then rebuild the Web release with 6/12/6/6 HP BEFORE deployment and run deployment smoke and runtime service checks. Update README and `.ai/CODEX_HANDOFF.md`, commit/push source gameplay stat changes, tests, safe hosting scripts/configuration/docs, then STOP. Do not edit ChatGPT-owned mailbox files, run P024, install a CI runner, or change Internet exposure. Report service status and the actual tested Mintbase URL only after verified access.
