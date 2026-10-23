# Codex Handoff — LBS-P002

**Status:** COMPLETE

**Branch:** `master`

**Implementation commit:** `0283c6e` (`Implement P002 moving chain and matching`)

**Mailbox:** remains on LBS-P002; task/ledger/decision/protocol files were not changed.

## Implemented

- Replaced the repeating P001 sample train with `ChainModel`, the authoritative ordered state for stable ball IDs, identities, logical X positions, animated display X positions, FIFO cache contents, and match history.
- Added continuous frame-rate-independent leftward movement, a bounded 12-ball deterministic seed containing all four identities and no initial triples, tunable speed/spacing/radius/population/cache constants, and no automatic population growth beyond the configured seed cap.
- Connected the existing locked-identity shooter projectile to the chain lane. It inserts only when crossing the visible lane and chooses the nearest valid ordered gap/end at the recorded impact X.
- Added insertion-local matching for groups of 3+, true-size match events, animated gap closure, and boundary-only cascades in occurrence order. Unrelated pre-existing groups are not globally scanned or removed.
- Added FIFO rollover and right-side return. Each distinct match event requests a three-ball cache batch; an empty visible chain returns up to eight cached balls, while a truly empty chain+cache reseeds.
- Reworked `BallChainView` as a pure model renderer with symbols/colors, short match feedback, and subtle visible/cache/last-match/event counters.
- Preserved the P001 orthographic battlefield, responsive layout, magazine/swap behavior, desktop/touch paths, and 0.4-second cooldown.
- Added `tests/p002_logic_test.gd`; updated README behavior and deferrals.

## Validation

Engine: `Godot 4.7.2.stable.official.ed1daf0bf`.

- `godot --headless --path . --script res://tests/p002_logic_test.gd` — `P002 gameplay logic: PASS (41 checks)`.
- `godot --headless --path . --script res://tests/headless_smoke.gd` — `P001 headless smoke: PASS`.
- P001 smoke with `--resolution 1600x720` — PASS.
- `godot --headless --path . --quit-after 120` — bounded runtime startup completed without warnings/errors.
- `git diff --check` — PASS before implementation commit.

The P002 suite covers bounded/all-color/no-triple seeding, two-versus-three threshold behavior, true-size four-ball events, ordered boundary cascades with an unrelated triple retained, RED/GREEN/BLUE FIFO exit and partial/full return, cached and fresh-seed empty recovery, stable ID/color mapping during sub-spacing movement, and one-time magazine consumption with delayed locked-identity insertion at lane crossing.

Commands used isolated `/tmp` XDG data/config/cache directories. An editor import also completed script registration; this sandbox blocks Godot's optional editor TCP listener, so runtime/test commands are the clean validation source.

## Manual playtest

1. Run `godot --path .`. Confirm the ordered symbol-marked balls move smoothly left above the preserved four 3D lanes without spacing-boundary teleports.
2. The initial magazine is RED loaded / BLUE next. Press Space (or right-click) to load BLUE, place the shooter beneath the adjacent BLUE pair near the right half of the chain, and left-click. The BLUE projectile should remain independent until it reaches the lane, insert between/next to the pair, and clear one BLUE x3 event.
3. Fire away from a same-color pair and confirm a one- or two-ball group remains. Fire into a larger same-color run and confirm one event reports the actual removed size.
4. For deterministic cascade reproduction, run the P002 test command above: its RED insertion clears RED x3, joins and clears GREEN x3 second, and deliberately leaves an unrelated BLUE x3 untouched. In play, the top feedback/counter reports each group as a distinct event when an equivalent arrangement is created.
5. Let the project run without firing. After roughly 18 seconds at default speed, `CACHE` begins increasing as leftmost balls exit with no penalty. Complete a match after cache is nonzero: up to three cached balls return at the right and cache count falls. Let the visible chain fully roll off (roughly 37 seconds from launch) to see automatic FIFO re-entry without a stuck empty board.
6. Recheck mouse movement/left-click, right-click/Space, magazine button, and touch drag/release. The shooter, LOADED, and NEXT visuals must remain synchronized; tapping swap must not fire.

## Assumptions / limitations

- Each distinct cascade match requests its own configurable cache-return batch, consistent with the decision that each cleared group is a separate match event.
- Logical closure is immediate for correct cascading; display X eases toward the new positions at a configurable speed. Removed balls use lightweight text/ring feedback rather than particle effects.
- The debug readout is temporarily always visible for P002 playtesting. P003 may integrate match events into score/combo/fever and replace or hide it.
- No P003 scoring/combo/fever, P004 defender attacks/damage, P005 loss systems, or P006 exports/device QA were implemented.
