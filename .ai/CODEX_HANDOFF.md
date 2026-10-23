# Codex Handoff — LBS-P005

**Status:** COMPLETE

**Branch:** `master`

**Implementation commit:** `0c61edc` (`Implement P005 survival and restart loop`)

**Mailbox:** remains on LBS-P005; task/ledger/decision/protocol files were not changed.

## Implemented

- Extended each pure `LaneCombatModel` with authoritative `ACTIVE`/`DOWN` defender state, one emergency charge, configurable two-match revival progress, idempotent breach state, and explicit knockdown/discharge/progress/revive/breach signals.
- Enemy movement resolves events in this order: an enemy already beyond the boundary breaches; otherwise active-defender contact resolves; a first contact consumes the charge and clears all currently alive same-lane enemies before any same-frame breach; without protection, a new boundary crossing ends the run.
- Centralized match consumption in `Battlefield.handle_match()`. P003 scoring/combo/fever always resolves first; the matching lane then performs exactly one action: active defender attack, or downed defender revival progress. The finishing revival match does not also fire.
- Revival requires two separate same-color match events regardless of group size. Other colors cannot revive the lane. On completion, one nonlethal pulse moves nearby/passed enemies to `DEFENDER_X + 1.15` or farther, without restoring the spent charge.
- Added prone defender pose, colored emergency discharge wave, revival flash/pose, gold/spent charge orb, and billboard lane status text using both team symbol names and color (`ACTIVE/DOWN n/2`, `CHARGE/SPENT`).
- Replaced P004 boundary recycling with terminal breach. `Battlefield` freezes all lane models and reports game over exactly once; the breached enemy remains frozen for the display.
- Added full-screen `GAME OVER` overlay with final score, mouse/touch-safe RESTART button and keyboard R. Game over blocks chain movement, matching input, shots, swap, combo decay, spawning, enemy/projectile motion, and pending gameplay state.
- Added in-place clean restart for chain/cache, deterministic shuffle bag, score/combo/fever, shooter shots/cooldown, all four defenders/charges, enemies/projectiles/VFX, overlay and touch ownership. Existing connections are reused, avoiding stale/duplicate scene signals.
- Capped lane and battlefield combat diagnostic histories at 128 entries for endless play.
- Preserved all accepted P001–P004 chain, FIFO, magazine, progression, HUD, and swept 3D combat behavior.

## Ordering and assumptions

- Existing defender projectiles continue after knockdown; only new attacks are suppressed while DOWN. All projectiles freeze on game over and are removed on restart.
- If a single large update crosses defender and left boundaries while an active charge exists, contact/discharge wins and prevents loss. If the enemy was already beyond the left boundary before that update/match, breach wins and cannot be reversed.
- Emergency discharge eliminates current enemies only. It does not damage other lanes, remove already-launched friendly projectiles, refresh, score points, or revive the defender.

## Validation

Engine: `Godot 4.7.2.stable.official.ed1daf0bf`.

- `godot --headless --path . --script res://tests/headless_smoke.gd` — `P001 headless smoke: PASS`.
- `godot --headless --path . --script res://tests/p002_logic_test.gd` — `P002 gameplay logic: PASS (59 checks)`.
- `godot --headless --path . --script res://tests/p003_logic_test.gd` — `P003 progression and magazine: PASS (72 checks)`.
- `godot --headless --path . --script res://tests/p004_combat_test.gd` — `P004 lane combat: PASS (44 checks)` with its boundary expectation updated for P005.
- `godot --headless --path . --script res://tests/p005_survival_test.gd` — `P005 survival loop: PASS (63 checks)`.
- P001 smoke at `--resolution 960x540` and `--resolution 1600x720` — PASS (default 1280×720 also passed).
- `godot --headless --path . --quit-after 180` at default and 1600×720 — clean bounded runtime startup.
- `git diff --check` — PASS before implementation commit.

P005 coverage includes four-lane initial state; isolated first emergency; simultaneous/large-delta ordering; spent-charge re-knockdown; two-event color-specific revival; no attack on either revival match; post-revival tier burst; other-color attack isolation; large-group single progress; nonlethal repel; already-breached precedence; one breach signal; top FIFO safety; preserved score; complete gameplay/input freeze; and clean restart with one live signal path and no stale projectiles/VFX.

Validation used isolated `/tmp` XDG data/config/cache directories.

## Manual playtest

1. Run `godot --path .`. Each lane status should show its symbol, `ACTIVE`, and `CHARGE` with a gold orb.
2. Let an enemy reach a defender. The defender should fall, a colored discharge wave should clear only that lane, and status should read `DOWN 0/2 SPENT`.
3. Make one match of that lane's identity: score/combo progress normally, status becomes `DOWN 1/2`, and no defender shots fire. A second separate same-color match revives with a flash/repel and still no attack.
4. Make another same-color match after revival to confirm normal tier-based firing resumes. Let a later enemy contact the defender: it falls again without a second lane clear.
5. Allow a living enemy to cross the far-left boundary. Confirm the final score overlay appears and all chain/combat/input motion freezes. Top-chain rollover alone must never end the run.
6. Press R or click/tap RESTART. Confirm score/combo/fever reset, all statuses return to `ACTIVE CHARGE`, one fresh enemy appears per lane, magazine/chain reset, and no old shots/effects remain.

## Known limitations / scope

- Survival state is complete for the prototype, but tuning, export presets, physical-device touch QA, safe-area polish, and accessibility palette options remain P006.
- Effects are intentionally lightweight primitive geometry with no audio or external assets.
