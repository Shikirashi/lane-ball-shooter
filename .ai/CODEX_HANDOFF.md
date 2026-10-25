# Codex Handoff — LBS-P023 enemy-speed rebalance and victory copy

**Status:** COMPLETE

**Branch:** `master`

**Implementation commit:** this scoped P023 commit.

**Mailbox:** remains on LBS-P023. P022 hosting was not implemented or activated, and ChatGPT-owned mailbox files were not edited.

## Implementation

- Raised the single authoritative `LaneCombatModel.DEFAULT_ENEMY_SPEED` from `0.24` to `0.312` units/s, exactly `old × 1.30`.
- Retained `EnemyTypes.SPEED_MULTIPLIERS`, yielding Hopper `0.312`, Heavy `0.2184`, Sickle Snake `0.624`, and stationary Healyzard `0.0`.
- Hopper still has a 0.55-second grounded dwell and 0.75-second airborne phase. Only airborne horizontal displacement changed; animation timing did not.
- Sliding movement, piecewise Hopper/projectile sweeps, large-delta collision, defender contact, emergency clearing, and breach detection continue to use the authoritative per-enemy speeds.
- Snake's 0.5-second post-hit stun and 0.3-second adjacent-lane transfer remain unchanged; it resumes at `0.624` units/s only after transfer.
- Changed only the WAVE CLEARED supporting copy to exact `All enemies neutralized`. Title, score, restart copy, three-second delay, and defeat subtitle `The lane was breached` remain unchanged.
- Added `GameOverOverlay.title_text()` and `subtitle_text()` as the same authoritative strings consumed by `_draw()`, allowing UI-state tests without brittle source-text matching.

Updated obsolete P008, P016, P019, and P020 speed assertions while retaining their existing movement, collision, conveyor, roster, and ability coverage. README now documents the canonical speeds, unchanged hop timing, exact terminal copy, and P023 command.

## P023 regression coverage

Added `tests/p023_enemy_speed_victory_copy_test.gd` — PASS (38 checks):

- exact `0.312 / 0.2184 / 0.624 / 0.0` speeds, unchanged relative multipliers, and exact 1.30× former moving speeds;
- whole-cycle Hopper and fixed-delta slide displacement;
- unchanged 0.55/0.75/1.30-second hop phase timing and Healyzard immobility across heal intervals;
- exact Snake 0.5-second stun, 0.3-second transfer, and resumed 0.624-unit/s movement;
- Hopper/Heavy/Snake swept projectile hits at 30 Hz and 0.08-second steps, plus defender contact/emergency and boundary breach;
- actual overlay state for exact victory/defeat title, subtitle, score/restart copy, and unchanged 3.0-second reveal boundary.

## Full validation

Godot `4.7.2.stable.official.ed1daf0bf`, all passing:

- P001 smoke — PASS.
- P002 gameplay logic — PASS (66 checks).
- P003 progression/magazine — PASS (73 checks).
- P004 lane combat — PASS (42 checks).
- P005 survival — PASS (63 checks).
- P006 platform QA — PASS (69 checks).
- P007 playtest revision — PASS (53 checks).
- P008 gamefeel/SFX — PASS (84 checks).
- P009 Zuma rollback — PASS (46 checks).
- P010 staged cascade — PASS (162 checks).
- P011 segment stress — PASS (16,485 checks; seed `5011CAFE`, 2,400 operations).
- P012 forward insertion — PASS (366 checks).
- P013 shooter preview/mask — PASS (50 checks).
- P014 causal rollback/feed — PASS (289 checks).
- P015 gravity/finite enemies — PASS (524 checks).
- P016 speed/retained-history compatibility — PASS (76 checks).
- P017 offscreen-left reentry — PASS (352 checks).
- P018 enemy death/victory delay — PASS (41 checks).
- P019 typed roster/spawning — PASS (117 checks).
- P020 special enemy abilities — PASS (67 checks).
- P021 Web menu/export — PASS (46 checks).
- P023 enemy speed/victory copy — PASS (38 checks).
- `git diff --check` — PASS.

Bounded native gameplay startup and forced Web-menu startup both passed at `960×540`, `1280×720`, `1600×720`, and `2400×1080`; all eight runs were intentionally stopped after three seconds (exit 124). The sandbox's recurring denial for `user://logs/godot.log` is harmless.

## Refreshed Web build

Executed:

```sh
./scripts/build_web.sh
```

The installed matching `4.7.2.stable` single-thread Web templates produced a real Compatibility-renderer build. Refreshed ignored local artifacts:

| File | Bytes |
|---|---:|
| `exports/web/index.html` | 5,447 |
| `exports/web/index.js` | 279,815 |
| `exports/web/index.wasm` | 39,514,754 |
| `exports/web/index.pck` | 345,804 |
| `exports/web/index.audio.worklet.js` | 7,298 |
| `exports/web/index.audio.position.worklet.js` | 2,973 |
| `exports/web/index.png` | 21,443 |
| `exports/web/index.icon.png` | 5,700 |
| `exports/web/index.apple-touch-icon.png` | 11,944 |

`exports/lane-ball-shooter-web.zip` contains exactly those nine files at archive root.

SHA-256: `08a8d52201b1d3fd03c983267bd54659a5350db109a07bc31e6f09526e5dfccb`

The complete artifact set was served temporarily on loopback port 8766 (8765 remains occupied by an unrelated local service). Every asset returned HTTP 200 with correct HTML, JavaScript, `application/wasm`, PCK `application/octet-stream`, and PNG MIME types. The server was stopped after verification. `exports/` remains gitignored and no compiled output is committed.

The exporter printed the known environment warnings for absent Android build-tools, sandbox socket creation, and denied editor-settings writes; Web export itself completed successfully.

## Manual verification

1. Compare a fresh Web run with the prior build: Hopper, Heavy, and Snake should traverse 30% faster, while Healyzard remains fixed at its rear support position.
2. Shoot moving enemies at different hop/slide phases; confirm hits, HP, Heavy durability, Snake stun/lane transfer, Healyzard pulse, emergency clear, and breach still behave normally.
3. Clear all 32 enemies. After the unchanged three-second presentation delay, verify WAVE CLEARED says exactly `All enemies neutralized`; defeat still says `The lane was breached` immediately.
4. Recheck Web START GAME → YES fullscreen and NO windowed paths. P023 does not alter the menu or browser gesture handling.

## Limitations

- Relative difficulty and perceived speed still require user playtesting in the interactive Web build.
- No Mintbase deployment, firewall work, persistent server, or P022 hosting action was performed.
