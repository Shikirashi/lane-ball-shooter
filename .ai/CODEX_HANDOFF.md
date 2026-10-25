# Codex Handoff — LBS-P022 HP, penetrating attacks, and private Mintbase hosting

**Status:** COMPLETE

**Branch:** `master`

**Gameplay/build source commit:** `cca99ba` (`Rebalance enemy HP and projectile tiers`)

**Mailbox:** remains on LBS-P022. P024 automation was not activated, no CI runner/webhook was installed, and ChatGPT-owned mailbox files were not edited.

## Gameplay implementation

- Canonical spawn/max HP is now Hopper 6, Heavy 12, Sickle Snake 6, and Healyzard 6. `LaneCombatModel.DEFAULT_ENEMY_HP` is 6. Explicit low-HP test fixtures retain canonical `max_hp`, so healer caps stay correct.
- Tier 1 creates one 1-damage non-piercing projectile and stops at the earliest physical contact.
- Tier 2 creates one 1-damage penetrating projectile which continues through every physically encountered enemy in the matched lane.
- Tier 3/FEVER creates one visible wide penetrating wave spanning the matched lane and one adjacent lane chosen once at launch. An invisible synchronized adjacent-lane collision proxy shares the same attack identity/hit set; audio and rendering still represent one attack.
- Piercing projectiles store immutable global `spawn_id` hits. Each enemy can take at most one hit per projectile even across frame overlap or a Snake UID remap/lane transfer. Later enemies behind an already-passed projectile are not hit retroactively.
- Swept contacts are sorted by impact time (then spawn ID), remain deterministic at 30/60/120 Hz and 0.08-second steps, and preserve Hopper hop, Heavy/Snake slide, and Healyzard stationary collision models.
- Live tier 3 no longer calls `clear_enemies_for_tier3`; full-health enemies take only 1 damage and do not increment neutralization/victory counters. The existing one-use emergency discharge remains an immediate full-lane clear at any HP.
- Wide visuals use one coherent cross-lane primitive; tier 2 is visually elongated. Collision proxies are never drawn and do not request duplicate launch SFX.
- Healyzard pulses remain +1 every 15 seconds, capped at the new 6/12/6 target maxima. Snake stun, transfer, global uniqueness/cooldown, roster weights, movement speeds, death VFX/SFX, finite encounter, victory delay, conveyor, Web menu, and exact victory copy are unchanged.

Older P004, P005, P007, P018, P019, and P020 assertions were updated only for the approved HP/projectile changes. Their routing, revival, VFX/SFX, spawning, Snake, healer, and survival coverage remains.

## New P022 coverage

Added `tests/p022_hp_penetrating_attacks_test.gd` — PASS (48 checks):

- canonical/full/current HP and explicit damaged fixtures;
- tier-1 first-contact and lethal-first-target stopping;
- tier-2 three-target penetration, once-only hits, normal expiry, 30/60/120 Hz and 0.08-second sweeps;
- no retroactive damage to a later enemy behind the projectile;
- tier-3 exact two-lane 1-damage routing, full-HP Heavy survival, edge/middle selection, seeded near-50/50 middle-lane distribution, and untouched other lanes;
- shared immutable-spawn-ID deduplication after a Snake is remapped into the other selected lane;
- +1 healer caps at 6/12/6 and emergency clearing of full-HP typed enemies.

## Full validation

Godot `4.7.2.stable.official.ed1daf0bf`, all passing:

- P001 smoke — PASS.
- P002 — 66 checks.
- P003 — 73 checks.
- P004 — 43 checks.
- P005 — 63 checks.
- P006 — 69 checks.
- P007 — 55 checks.
- P008 — 84 checks.
- P009 — 46 checks.
- P010 — 162 checks.
- P011 stress — **16,485 checks**, seed `5011CAFE`, 2,400 operations; not skipped.
- P012 — 366 checks.
- P013 — 50 checks.
- P014 — 289 checks.
- P015 — 524 checks.
- P016 — 76 checks.
- P017 — 352 checks.
- P018 — 41 checks.
- P019 — 117 checks.
- P020 — 67 checks.
- P021 — 46 checks.
- P023 — 38 checks.
- P022 new suite — 48 checks.
- `git diff --check` — PASS.

Native gameplay and forced Web-menu preview startup both passed bounded three-second runs at 960×540, 1280×720, 1600×720, and 2400×1080. The recurring sandbox denial for `user://logs/godot.log` is harmless.

## Exact-source Web build

The build was made from a clean temporary `git archive` of source commit `cca99ba`, not the dirty primary checkout:

```sh
./scripts/build_web.sh
```

The matching official Godot 4.7.2 single-thread Web template and Compatibility renderer produced:

| File | Bytes |
|---|---:|
| `index.html` | 5,447 |
| `index.js` | 279,815 |
| `index.wasm` | 39,514,754 |
| `index.pck` | 357,672 |
| `index.audio.worklet.js` | 7,298 |
| `index.audio.position.worklet.js` | 2,973 |
| `index.png` | 21,443 |
| `index.icon.png` | 5,700 |
| `index.apple-touch-icon.png` | 11,944 |

`exports/lane-ball-shooter-web.zip` contains exactly those nine files at archive root.

- New P022 ZIP SHA-256: `5711dbb5341d6546e564e96ab059801cf8df389687687942b583cc392b2749d4`
- New P022 PCK SHA-256: `887b08c77b71283a388836c054294042cc84ff755852d38c9de5e039634ce619`
- Rebuilt clean P023 PCK for comparison: `52052b2380bb4ca978ffd3ba3483acd567c19c7f7e5596cf7da7aa958caea5c4`
- Stale P023 archive SHA from prior handoff: `08a8d52201b1d3fd03c983267bd54659a5350db109a07bc31e6f09526e5dfccb`; it was not deployed.

Running the P022 regression directly from the exported PCK via `godot --headless --main-pack exports/web/index.pck --script res://tests/p022_hp_penetrating_attacks_test.gd` passed all 48 checks, proving the deployed pack includes the new HP and attack code. Export printed known nonfatal Android-tools/editor-socket/settings warnings; Web output completed.

## Mintbase deployment

Mintbase is the current Linux host. The new build is live at:

**`http://100.79.250.8:8770/`** (Tailscale tailnet only)

- Service: systemd user unit `lane-ball-shooter-web.service`, enabled and active.
- Serving user: `shiki` (UID 1000); Python static server is not root.
- Bind: exactly `100.79.250.8:8770`, not `0.0.0.0`; LAN/public Internet exposure was not enabled.
- User lingering: enabled, so the user service starts persistently without an interactive login.
- Release root: `/home/shiki/srv/lane-ball-shooter-web/releases/`.
- Live pointer: `/home/shiki/srv/lane-ball-shooter-web/current -> releases/cca99ba-p022`.
- Manifest: `/home/shiki/srv/lane-ball-shooter-web/current/release-manifest.txt`, recording source/ZIP and per-file SHA-256 values.
- Unit: `/home/shiki/.config/systemd/user/lane-ball-shooter-web.service`.
- Environment: `/home/shiki/.config/lane-ball-shooter-web/environment`.
- Logs: `journalctl --user -u lane-ball-shooter-web.service`.
- The existing rembg site on 8765 and its tailnet proxy on 8766 were inspected and left unchanged.

All nine runtime assets plus the manifest returned HTTP 200 from the actual tailnet URL. MIME checks passed: HTML, JavaScript, `application/wasm`, PCK `application/octet-stream`, and PNG. The deployed PCK hash exactly equals the local P022 PCK. A supervised service restart returned to active state and HTTP succeeded afterward.

`scripts/deploy_web_release.sh` validates all runtime files, refuses overwrite, stages a versioned release, writes a hash manifest, and atomically promotes `current`. On subsequent promotion it records the former live target as `previous`; rollback swaps those pointers without restarting the server:

```sh
./scripts/deploy_web_release.sh rollback "$HOME/srv/lane-ball-shooter-web"
```

Atomic two-release promotion and rollback were exercised successfully in an isolated temporary deployment root. Because this is the first real hosted release, the real deployment has no older known-good hosted version yet; `previous` will be created by the next manual/P024 deployment.

## Manual verification / limitations

1. From an authorized tailnet device, open `http://100.79.250.8:8770/`; confirm the Web menu, NO windowed start, and YES fullscreen request/start.
2. Confirm all types spawn with 6/12/6/6 HP behavior: tier 1 stops on the first enemy, tier 2 penetrates one lane, tier 3 crosses exactly two lanes for 1 damage each, and the emergency still wipes its lane.
3. Watch a Snake move between both wave lanes without taking a second hit from that same wave; verify Healyzard +1 healing caps.
4. Complete the encounter and verify the unchanged three-second delayed WAVE CLEARED copy.

No second online tailnet client was available during deployment (`shikilaptop` was offline), and no GUI/mouse automation was used, so actual remote browser rendering, audio, and YES/NO interaction remain manual QA. The host itself verified the private Tailscale URL and all assets. No firewall, router, Funnel, reverse proxy, public DNS, or public exposure changes were made. P024 automation remains uninstalled.
