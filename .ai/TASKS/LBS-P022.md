# ACTIVE TASK: LBS-P022 — Triple HP, penetrating tier attacks, rebuild Web, host on Mintbase

**Status:** READY FOR CODEX / ONLY ACTIVE TASK. User requested Mintbase hosting after the Web build and established the follow-on automatic-update requirement. ChatGPT has reviewed and accepted P023. Codex is authorized to configure the INITIAL Mintbase static Web hosting in P022, but NOT the future P024 CI/CD automation or unapproved public exposure.
**Goal:** FIRST triple every enemy's max/spawn HP, REPLACE tier 1/2/3 attack mechanics as specified below, then compile a NEW single-threaded Godot Web release with BOTH gameplay changes and make THAT release reachable at `http://<Mintbase-reachable-IP>:<chosen-port>/` by devices on the intended network, using Mintbase (user's Linux Mint desktop) as the static HTTP host.

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
- **Critical combat rules, newest user override (21:35):** Tier 1 = one 1-damage projectile stopped by the FIRST enemy it touches; Tier 2 = ONE penetrating projectile dealing 1 damage to EACH enemy it traverses on the matched lane; Tier 3 = ONE WIDE penetrating projectile dealing 1 damage to EACH enemy it traverses on the matched lane AND one adjacent lane. NO skill tier is an instant full-lane kill anymore. ONLY the unrelated defender one-use EMERGENCY lane discharge remains an instant clear independent of HP. See authoritative section A2.
- Preserve Snake movement and behavior: surviving tier1/tier2 hits stun for exactly 0.5s and then lane switch once, not just when on its final HP; fatal hit during stun/transfer removes it once. After transfer remain at correct remaining HP / `max_hp=6`. The global cap of one live Snake / 15s after death stays intact.
- Preserve Healyzard **+1 HP per 15-second pulse** (NOT tripled to +3), no self/other healer healing, cap targets at new 6/12/6 HP, no max-HP overflows. Healyzard's own 6 HP permits surviving hits but not self-healing. No HP UI: Hopper's orange blocks are decorative horns and never change with damage; other enemy types have no horns or health bars.
- Preserve movement and spawn balance: Hopper 0.312, Heavy 0.2184, Snake 0.624, Healyzard 0; 50/20/20/10 base weights, 5 concurrent enemies per lane, 8 successful spawns/lane (32 total), P017 102px/s conveyor, P018 3s delayed victory presentation, P023 exact subtitle `All enemies neutralized`, P021 Web-only fullscreen menu and native direct boot. No other balance alterations.


## A2. NEW authoritative tier attack mechanics (user revision 2026-10-25 21:35)

**These rules take priority over all previous P001–P023 skill descriptions, any historical instant tier-3 clear, and ALL conflicting text in earlier decision/task documents.**

| Tier | Projectile | Damage and targets |
| --- | --- | --- |
| **Tier 1** | **ONE ordinary non-piercing projectile** | Deals **exactly 1 HP** to the **FIRST enemy physically hit** in the matched-color lane; stops/despawns on impact. No damage to further enemies, even if it kills the first target. |
| **Tier 2** | **ONE penetrating projectile** | Deals **exactly 1 HP to EACH encountered enemy** in the matched-color lane as it travels, continuing past each impact until its normal right-side exit/lifetime. Every enemy hit once per projectile. NOT two projectiles, NOT 2 damage each. |
| **Tier 3** | **ONE WIDE penetrating projectile/wave** | Horizontally travels through BOTH the matched-color lane and **ONE randomly selected adjacent lane**. Deals **exactly 1 HP to EACH enemy it physically passes** in those two lanes. Does NOT clear/kill entire lanes instantly and does not damage the other two lanes. |

### Precise projectile semantics

- A piercing projectile affects **every enemy whose collision region it actually sweeps past** during its motion. It does NOT instantly subtract HP from every enemy when the attack is triggered; an enemy spawning behind an already-passed projectile or outside its reach is unaffected. Empty lanes may yield zero hits. Ordinary projectile travel direction stays left-to-right, positive X, from defenders toward incoming enemies at existing projectile speed.
- Each physical enemy can receive **AT MOST 1 damage from the SAME tier-2 or tier-3 projectile**, even if overlapping its collision region for several frames. Maintain a per-projectile hit set that survives frame updates and accounts for globally unique encounter IDs. A Snake transferring between targeted lanes during the tier-3 wave must not be damaged twice by the SAME wave, even if its lane-local UID changes.
- Retain/extend swept collision logic for hopping Hopper movement, sliding Heavy/Snake and stationary Healyzard. At 30/60/120 Hz and at 0.08-second steps, no tunneling, no repeat damage and correctly ordered contacts. Tier 1 stops at the earliest contact. Tier 2 continues after all hits; Tier 3 hits across both lanes without duplicate hits/attack IDs.
- Tier 3 picks ONE adjacent lane ONCE per match attack: lane 0 => 1, lane 3 => 2, middle lanes randomly choose one neighbor with existing independent attack RNG. Fix targets through the lifetime of the wide projectile. A coherent wide visual spans both lane depths and moves across X; implementations may use synced lane collision proxies but should maintain ONE authoritative wide projectile/attack identity, deduplicated hits and no duplicate launch SFX.
- Update LaneCombatModel.fire_attack, _spawn_projectile, _update_projectiles, swept intersection/first-hit or multi-hit logic, and Battlefield.handle_match / _resolve_tier3_attack so live Tier 3 **does NOT call clear_enemies_for_tier3**. Update visuals in LaneActor and Main/HUD/SFX/attack histories so tier2/tier3 are represented as ONE penetrating shot each. Preserve all existing typed projectile neutralization/death events and lane accounting.
- **Distinct emergency remains lethal:** A defender's one-use automatic emergency discharge on first knockdown STILL instantly removes ALL enemies in THAT lane, even 12-HP Heavy. It is not tier 3 and must not be converted into 1 damage. Healer healing stays +1 HP per 15 seconds, with new caps.
- No damage to unintended lanes, no projectile hitting the same Snake twice after transfer, and no wave wipe via simply setting enemy HP to zero. Attacks that only wound must not increment killed or neutralized counters; victory waits until enemies truly die. Keep current 32-enemy quota, P018 3.0-second victory delay, Snake cooldown and entire P021 Web menu.

### New P022 regression requirements for tier attacks

1. Full-health 6-HP Hopper, 12-HP Heavy, 6-HP Snake, 6-HP Healyzard spawn as specified; explicit damaged test fixtures remain healable to canonical max. Retain no health bars.
2. Tier 1: two enemies in line => only first takes 1 damage; projectile vanishes. First at 1HP dies but the second survives untouched.
3. Tier 2: one 1-damage piercing shot hits at least three collinear enemies once each, never the other lanes; no duplicate damage over successive frames or large frame deltas. It persists after hitting the first enemy and expires normally.
4. Tier 3: one wide projectile hits enemies in matched and selected adjacent lanes exactly once for 1 damage each, not the two other lanes; middle-lane selection seedable/unbiased; edge-lane selection valid. Full HP Heavy loses 1HP rather than dying.
5. Snake lane-transfer crossing both selected wide-projectile lanes must not lead to second hit by same attack, even with remapped UID; correct max/current HP, global occupancy and cooldown.
6. Test later/newly spawned enemies behind a projectile that already passed: no retroactive damage. All attacks may miss. High delta / 30/60/120Hz projectile collisions reliable.
7. Emergency **still insta-kills** full-health Heavy/Healyzard/Snake and emits proper typed death effects; normal tier 3 does not. Healyzard pulses +1 up to 6/12/6, never heals healers.
8. Rework/extend P001–P023 tests which previously assumed tier2 two 2-damage shots and tier3 instant full-lane kills. Maintain test intent; no silent skips, and still run P011 16,485-check stress. Keep original 3-second victory delay and subtitle.

### Tests for new HP values
- Add dedicated P022 HP/skill regression test(s) for canonical max/default HP 6/12/6/6, tier 1 first-only 1-damage shot, tier 2 1-damage-per-enemy lane penetration, tier 3 1-damage-per-enemy two-lane wide penetration, healer +1 capped at new max, Snake nonfatal transfer with retained health, EMERGENCY instant clear of even full-HP 12HP Heavy, and P018 typed death VFX/event accounting. Tier 3 must NEVER instant-kill a full-health enemy.
- Audit and update prior P001–P023 regression fixtures and assertions that hardcode former 2/4/2/2 HP, particularly typed roster and P020 special-ability tests. **Do not merely update expected values to make old damage-logic tests pass**: maintain or extend tests ensuring multi-hit durability, damaging a Snake and its special state transitions, and heal cap behaviors with 6/12/6HP.
- Run **all P001–P023 suites plus the new P022 HP tests** under Godot 4.7.2 with no skipped stress test, plus bounded Web/native boot checks and `git diff --check`. Report outcomes and manual balance QA in handoff.

## B. Mandatory NEW Web build from post-HP AND new skill-tier source (old P023 zip is stale)

- Once BOTH enemy HP and tier 1/2/3 attack changes and tests are implemented, execute `./scripts/build_web.sh` to build from the **new P022 source tree**. Verify fresh generated `index.html`, JS, WASM, PCK and all runtime companions, then produce a NEW ZIP and record its SHA256. **Do not deploy the P023 archive SHA `08a8d52201b1d3fd03c983267bd54659a5350db109a07bc31e6f09526e5dfccb`**; it contains old 2/4/2/2 enemy HP AND the now-obsolete tier2 two-shots/tier3 instant-clear combat. If build tools unavailable, document blockers instead of deploying a stale build.
- Record the build's source commit (or precise precommit worktree state and subsequent source commit) in a release manifest; compare new and old PCK hashes, and verify BOTH the new HP values AND tier projectile code from bundled source/pack if feasible. The package must match the committed P022 gameplay changes.
- As before, exported binaries remain LOCAL and ignored. The later P024 automated pipeline will build on trusted source pushes; P022 does not enable that CI/CD pipeline.

## C. Mintbase static hosting

## Prerequisites

- Confirm a newly built **P022 HP-AND-SKILL adjusted** `exports/web/` directory or `exports/lane-ball-shooter-web.zip` produced AFTER the above HP changes on the local development machine; ZIP root contains `index.html` plus JS/WASM/PCK files. Source repository `exports/` is ignored: do not assume `git pull` alone transfers exported binary assets. Don't use a stale build if code changed since export.
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
9. Verify deployed `index.pck` comes from the NEW P022 ×3-HP PLUS tier-1/2/3 projectile-rebalanced Web build, and NOT the older P023 archive/hash. Record NEW current archive SHA256 and source revision; demonstrate bundled HP changes where feasible. Use a safe versioned release directory and retain previous release for rollback. Never promote an old-HP archive.

## Future pipeline handoff to P024 (no implementation in P022)

- Record service type/name, serving user, listen interface/port, live pointer, release staging paths, updater permissions, Web build provenance and exact deploy/rollback commands; protect unrelated Mintbase services.
- Confirm whether Mintbase can support the build toolchain locally or if external trusted GitHub CI plus a secure transfer method is preferable. Do not run an untrusted webhook or publicly expose a CI runner.
- A later **P024** will trigger automatic Godot Web builds on each approved `master` push, validate, deploy atomically and report status. Git push triggers deployment, so binaries aren't pushed to GitHub, and there is no automatic commit of unsaved working-directory changes.

## Test and handoff

- Verify HTTP 200 on index and every generated asset from Mintbase, MIME types and console errors if browser testing available, fullscreen request initiated only by YES button, NO windowed. Avoid claiming public internet reachability without external test.
- Keep ordinary non-skill game mechanics P017–P021 and P023 unchanged EXCEPT explicitly authorized ×3 enemy HP and new TIER 1/2/3 projectile mechanics. **Tier 3 no longer clears entire lanes instantly; only emergency discharge does.**
- Update README with hosting/how to update, `.ai/CODEX_HANDOFF.md`, commit/push source and documentation, STOP. Do not commit generated WASM/PCK to repository or edit ChatGPT-owned mailbox unless explicitly tasked.

## P022 completion discipline

Run ALL project P001–P023 suites plus NEW P022 HP AND tier-combat tests, then rebuild the Web release with 6/12/6/6 HP AND tier-1/2/3 new projectile mechanics BEFORE deployment and run deployment smoke and runtime service checks. Update README and `.ai/CODEX_HANDOFF.md`, commit/push source enemy HP and tier-projectile gameplay changes, tests, safe hosting scripts/configuration/docs, then STOP. Do not edit ChatGPT-owned mailbox files, run P024, install a CI runner, or change Internet exposure. Report service status and the actual tested Mintbase URL only after verified access.
