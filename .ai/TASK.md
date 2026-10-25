# ACTIVE TASK: LBS-P023 — Simplify victory subtitle and raise enemy speed by 30%

**Status:** READY FOR CODEX / ONLY ACTIVE IMPLEMENTATION TASK
**Branch:** `master`
**Requested:** 2026-10-25, after user played the real P021 Web build. The game feels too easy; increase ALL MOVING enemy horizontal movement speeds by **30% of CURRENT values**, and remove only the word "scheduled" from the WAVE CLEARED subtitle.
**Baseline:** P021 Web menu/export `f21e3637ab29bd067006f06b4e5ba0c06565e821`, P020 special enemies `8f37cb8`. Read `AGENTS.md`, `.ai/PROTOCOL.md`, `.ai/DECISIONS.md`, `.ai/TASK_LEDGER.md`, `.ai/TASK.md`, latest `.ai/CODEX_HANDOFF.md`. Implement only P023; P022 Mintbase deployment is STILL QUEUED and NOT ACTIVE. No GUI/mouse automation.

## A. Victory subtitle — exact copy change
- In `scripts/ui/game_over_overlay.gd`, change **only** the WAVE CLEARED supporting subtitle from `All scheduled enemies neutralized` to exactly **`All enemies neutralized`**.
- Preserve the title `WAVE CLEARED`, score formatting, `RESTART [R]`, 3.0-second delayed victory reveal, and the distinct immediate defeat subtitle `The lane was breached`.
- Check any tests or documentation that assert the old subtitle and update them accordingly. The word "scheduled" may still exist in internal spawn descriptions; do not globally strip it.

## B. Movement balance — 1.30× current baseline
- Existing authoritative `LaneCombatModel.DEFAULT_ENEMY_SPEED` is **0.24** units/s for Hopper; `EnemyTypes.SPEED_MULTIPLIERS` supplies Heavy 0.7, Snake 2.0, Healyzard 0.0. Prefer raising the **single base speed** to **0.312** (= 0.24×1.30) so relative archetype speeds remain intact, rather than scattering four overrides.
- Exact resulting enemy linear-average horizontal speeds:
  | Enemy | Before | After | Behavior |
  | Hopper | 0.24 | **0.312** | Keep existing 0.55s grounded / 0.75s airborne cycle and hop displacement; 30% faster travel, not shorter animation timings |
  | Heavy | 0.168 | **0.2184** | Ground slide, 4HP, 70% Hopper speed |
  | Sickle Snake | 0.48 | **0.624** | Ground slide, standard 2HP, 2× Hopper speed |
  | Healyzard | 0.0 | **0.0** | Remains stationary in rear support slot |
- The phrase "30% faster" means new speed=old×1.30, not old+0.30 world-units/s or old/(1.30).
- Preserve all other game rules: no change to HP, spawn percentages 50/20/20/10, 5 live enemies/lane, 8 lifetime spawns/lane (32 total), one Snake globally, 15s post-Snake-death respawn limit, 0.5s Snake post-hit stun and 0.3s adjacent-lane transfer animation, 15s Healyzard healing, 3s victory delay, 102px/s ball conveyor, shooting, scoring, input or web menu/fullscreen behavior.
- Preserve swept projectile collision with faster hopper air velocity, faster sliding Snake/Heavy, stationary Healyzard. Pay attention to large delta / 30Hz & collision not tunneling. Defender contact/emergency lane clear and breach must still register.

## C. Tests and Web build refresh

1. Add `tests/p023_enemy_speed_victory_copy_test.gd` with assertions for exact new 0.312/0.2184/0.624/0.0 speeds, relative multipliers, 1.30× displacement for moving types under fixed dt (including hop cycle), unchanged hop timing, Snake stun/transfer timing and Healyzard immobility.
2. Assert exact new WAVE CLEARED subtitle `All enemies neutralized` and unchanged defeat copy and existing 3.0s end presentation (validate scene/UI if possible, not only source-text search).
3. Audit existing P001–P021 suites for hardcoded old speed assertions/assumptions (notably `tests/p019_enemy_roster_spawning_test.gd` and P020 Snake movement tests). Update expected movement numbers where they are NOW intentionally obsolete; retain substantive test coverage.
4. Re-run ALL P001–P021 regression suites plus P023 under Godot 4.7.2 headless, bounded native and web entry startup, `git diff --check`. Do not quietly skip stress test P011.
5. IMPORTANT: User is currently PLAYING THE WEB VERSION; the old P021 exported `exports/web` binaries and portable ZIP are STALE after source changes. **Run `./scripts/build_web.sh` again** to regenerate a REAL updated `exports/web/index.html` and `exports/lane-ball-shooter-web.zip` in the user's working checkout; verify exported index/JS/WASM/PCK and all nine runtime files, test local HTTP requests, report artifact sizes and SHA-256 of updated ZIP. If the matching Web export templates/toolchain are unexpectedly unavailable, document blocker and executable build instructions—never imply updated assets exist when they do not. Generated compiled assets stay `.gitignore`d, NOT committed, so the user must rebuild on a machine other than the original Codex workspace.
6. Include explicit short manual verification: new text in WAVE CLEARED, visibly faster Hopper/Heavy/Snake but stationary Healyzard, still functioning hit/damage/Snake lane swap/heal, and Web main menu YES/NO.

## D. Completion
- Update README for new canonical speeds and exact victory subtitle, while preserving prior details.
- Update `.ai/CODEX_HANDOFF.md`: implementation commit, changed files, actual test suite outcomes, Web export command/status/ZIP SHA, manual test, limitations.
- Commit and push code, tests, README and handoff to `master`; **STOP**. Do not alter ChatGPT-owned `.ai/TASK.md`, `.ai/TASK_LEDGER.md`, `.ai/DECISIONS.md`, `.ai/PROTOCOL.md`. Do NOT self-activate queued P022 or deploy to Mintbase. Keep scope limited to copy/speed rebalance and refreshed web build.
