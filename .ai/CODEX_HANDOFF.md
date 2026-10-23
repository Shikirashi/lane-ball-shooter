# Codex Handoff — LBS-P004

**Status:** COMPLETE

**Branch:** `master`

**Implementation commit:** `99dbfdb` (`Implement P004 lane projectile combat`)

**Mailbox:** remains on LBS-P004; task/ledger/decision/protocol files were not changed.

## Implemented

- Added pure deterministic `LaneCombatModel` state per color lane for enemies, HP, projectiles, delayed bursts, spawning, attack/hit history, and the temporary P004 left-boundary recycle.
- Wired P003 `match_resolved` results directly through `Battlefield.fire_for_match()` to exactly one matching `LaneActor`. Identity, tier, fever flag, and group size are copied and locked at match time.
- Tier 1/2/3 creates 1/2/3 same-lane shots; FEVER remains tier 3. Burst shots use 0.14-second launch offsets, so they are visually distinct. Group sizes above three do not add shots.
- Added swept relative-motion collision against moving enemies. Hop height is visual only; each projectile hits at most the first enemy reached, applies one damage event, and despawns. Dead targets are removed once so later burst shots can continue to the next enemy.
- Reworked `LaneActor` to render multiple enemy/projectile records with procedural primitives: independent hop/squash and ground shadows, HP pips, hit squash, defender lunge/muzzle flash, hidden delayed shots, and short primitive death bursts.
- Added staggered per-lane spawning with a five-enemy cap. Projectiles also expire at the world-right boundary or after their lifetime, preventing dynamic visual accumulation.
- Preserved P001–P003 chain collision, physical adjacency, cascades, FIFO cache, controls, shuffle bag, score, combo, fever, HUD, and match feedback.
- Documented the P004 combat loop and temporary no-loss boundary in README.

## Tuning defaults

- Enemy HP: 2; projectile damage: 1.
- Enemy speed: 0.48 world units/s; projectile speed: 9.0 units/s.
- Spawn interval: 5.5 seconds per lane, with initial lane staggering and maximum 5 active enemies per lane.
- Projectile lifetime: 2.2 seconds; burst interval: 0.14 seconds; swept hit distance: 0.4 units.
- One initial enemy is placed in every lane. Enemies at/past X = -7.25 are despawned without penalty until P005.

## Validation

Engine: `Godot 4.7.2.stable.official.ed1daf0bf`.

- `godot --headless --path . --script res://tests/headless_smoke.gd` — `P001 headless smoke: PASS`.
- `godot --headless --path . --script res://tests/p002_logic_test.gd` — `P002 gameplay logic: PASS (59 checks)`.
- `godot --headless --path . --script res://tests/p003_logic_test.gd` — `P003 progression and magazine: PASS (72 checks)`.
- `godot --headless --path . --script res://tests/p004_combat_test.gd` — `P004 lane combat: PASS (44 checks)`.
- `godot --headless --path . --quit-after 180` at default 1280×720 and `--resolution 1600x720` — clean bounded runtime startup at both sizes.
- `git diff --check` — PASS before implementation commit.

P004 coverage includes color/lane isolation; locked 1/2/3-shot bursts; group-size independence; combo-timeout retention; burst spacing; empty-lane travel/despawn; swept large-delta hits; damage, death, and no duplicate kill; ordered two-target impacts; hop independence; frame-rate-independent enemy movement; bounded/tunable spawning; temporary boundary recycle; and a genuine `ChainModel → MatchProgression → Battlefield → LaneActor` clear.

Validation used isolated `/tmp` XDG data/config/cache directories.

## Manual playtest

1. Run `godot --path .`. Confirm each colored defender has one independently hopping enemy initially and more enemies enter at staggered intervals.
2. Complete a three-ball match. The defender of that identity should lunge/flash and fire one colored 3D sphere to the right in its own lane, even if that lane has become empty.
3. Complete timely second and third matches to see two- and three-shot sequential bursts. Fourth-match FEVER still fires three shots, with no extra fever damage.
4. Watch shots stop at the first enemy, remove one HP pip per hit, and produce a small orange burst when HP reaches zero. With two one-HP targets, successive burst shots should hit them in order.
5. Confirm enemies remain hittable at the top of their cosmetic hop and neighboring lanes never take damage.
6. Let an enemy reach the far left: it currently disappears with no defender damage or game over. This is the documented P004 placeholder for P005.
7. Recheck top-chain misses/insertion/cascades, FIFO return, magazine swap, score/combo/fever, touch/mouse input, F3 diagnostics, and wide layout.

## Known limitations / scope

- P004 intentionally has one basic enemy type and fixed per-lane tuning; no special abilities or fever bonus.
- Left-boundary enemies are despawned rather than causing knockdown or loss. Defender state, emergency discharge, revival, breach, and restart are reserved for P005.
- No audio, external assets, rigid-body physics, navigation, or export/device QA was added.
