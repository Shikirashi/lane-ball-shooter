# Lane Ball Shooter — P022 HOST VERIFIED / AWAITING REMOTE BROWSER QA

**Status:** NO ACTIVE CODEX IMPLEMENTATION TASK; **P022 complete on source and host evidence**, second-device browser QA still needed. P024 automatic CI/CD is QUEUED / NOT ACTIVE until user validates the new hosted build in a real browser and ChatGPT explicitly activates it.
**Branch:** `master`
**P022 gameplay commit:** `cca99baba7805dd05c358c70ffa105aecc75efdc`.
**P022 hosting documentation commit:** `f51eb8e967a16d9d57d16fea59ec29a5f6343012`.
**Trusted deployment endpoint from Codex handoff:** `http://100.79.250.8:8770/` — **TAILSCALE ONLY**, not public internet or unrestricted LAN.

## Accepted gameplay changes

- All default/max enemy HP tripled: Hopper 6, Heavy 12, Sickle Snake 6, Healyzard 6. Explicit low-current-HP fixture uses its canonical type max to allow appropriate healing.
- Tier 1: ONE projectile hitting the first enemy along matched-color lane for 1 HP and stopping. Tier 2: ONE penetrating projectile dealing 1 HP per physically crossed enemy, each at most once, in matched-color lane. Tier 3: ONE wide penetrating projectile across matched-color lane and ONE selected adjacent lane, deals 1 HP per crossed enemy in either lane, at most once per global spawn ID, not an instant clear.
- DEFENDER one-use EMERGENCY discharge remains an instant full-lane clear regardless of HP, distinct from tier 3.
- Preserve P023 movement speeds Hopper 0.312 / Heavy 0.2184 / Snake 0.624 / Healyzard 0, P020 Snake 0.5s stun and transfer / Healyzard +1 every 15s, P018 3s victory delay / exact WAVE CLEARED subtitle `All enemies neutralized`, P017 conveyor, P021 Web fullscreen menu.
- Source review: `scripts/world/enemy_types.gd`, `scripts/world/lane_combat_model.gd`, `scripts/world/battlefield.gd`, `scripts/world/lane_actor.gd`, `tests/p022_hp_penetrating_attacks_test.gd`, deployment script and service template. Codex reports all **23 P001–P023/P022 suites PASS**, new P022 48 assertions; tests not independently rerun here.

## Host verified by Codex (not independently network-tested here)

- Host `Mintbase`: Tailnet URL `http://100.79.250.8:8770/` served from systemd user service `lane-ball-shooter-web.service` as unprivileged user `shiki`, bound to Tailscale IP only. User lingering enabled; existing rembg services on 8765/8766 untouched. HTML/WASM/PCK and other static assets all HTTP 200 with correct MIME from host. Restart reported successful.
- Release pointer: `/home/shiki/srv/lane-ball-shooter-web/current` -> `releases/cca99ba-p022`, versioned releases in `/home/shiki/srv/lane-ball-shooter-web/releases`.
- Deployed PCK SHA-256: `887b08c77b71283a388836c054294042cc84ff755852d38c9de5e039634ce619` matching newly exported P022 source.
- Web ZIP SHA-256: `5711dbb5341d6546e564e96ab059801cf8df389687687942b583cc392b2749d4`. Binaries are on development/host machines, not in Git.
- `scripts/deploy_web_release.sh` stages and atomically promotes validated releases, can rollback after a second deployment. `scripts/build_web.sh` builds matching Godot 4.7.2 Compatibility single-thread release.
- No public internet exposure, CI webhook, GitHub runner or automatic deploy installed. Initial release has no earlier hosted release to roll back to.

## USER QA REQUIRED before P024 activation

1. From a SECOND device connected to the SAME TAILSCALE tailnet, open `http://100.79.250.8:8770/`. Confirm Web main menu loads.
2. START GAME -> NO should start windowed; reload and START GAME -> YES should request fullscreen immediately; ESC should exit fullscreen gracefully. Test browser mouse/touch/audio.
3. Check enemies' increased 6/12/6/6 durability and +30% speeds, tier1 single-first-hit, tier2 one-lane piercing, tier3 two-lane piercing at +1 damage each, and emergency instant clear.
4. Check scene starts/restarts, Snake transfer and healer pulses, finishing encounter shows delayed `All enemies neutralized`.
5. If tailnet URL fails, inspect `systemctl --user status lane-ball-shooter-web.service`, `journalctl --user -u lane-ball-shooter-web.service -n 100 --no-pager`, Tailscale status and current bind; do not modify unrelated services without user approval.

Once user confirms loading/interaction remotely, ChatGPT may activate queued `LBS-P024` from `.ai/TASKS/LBS-P024.md`: GitHub `master` push -> pinned Godot Web build and tests -> atomic deploy on Mintbase with rollback on failure; P024 requires authorizing/securely configuring persistent CI runner/deploy credentials. Until then, **NO ACTIVE CODEX TASK** and manual deployment only.
