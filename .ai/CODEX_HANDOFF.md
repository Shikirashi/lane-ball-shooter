# Codex Handoff — LBS-P002 Revision

**Status:** COMPLETE

**Branch:** `master`

**Revision implementation commit:** `1fe4d5b` (`Fix P002 shot contact and recycled gaps`)

**Mailbox:** remains on the P002 revision; task/ledger/decision/protocol files were not changed.

## Review corrections

### P002-R1 — physical shot contact

- Replaced unconditional nearest-gap insertion with `ChainModel.try_insert_shot()`.
- A projectile now inserts only when its X overlaps a rendered ball's current `display_x`. The documented effective tolerance is 34 px: the configured 22 px chain-ball radius plus the shooter's 12 px projectile radius.
- A hit inserts immediately before or after the contacted ball and can create only one ball. A miss changes no chain, cache, or match state; the already-fired magazine ball remains consumed and cooldown/input behavior is unchanged.
- Contact follows the continuously updated rendered position while the train moves or closes a visual gap.

### P002-R2 — physical adjacency across recycled gaps

- Matching, group expansion, and cascade boundaries now require neighboring logical positions to be within the configured adjacency tolerance; array neighbors separated by a recycled gap are not a match group.
- Returned FIFO batches still spawn at the right boundary in their original order. A disconnected right segment catches up at a bounded 120 px/s relative speed and stops at normal 58 px spacing before becoming adjacent.
- Insert/open-space and match/gap-close shifts affect only the relevant connected segment. Distant segments are not teleported, overlapped, or pulled into a cascade.
- Existing empty-stream recovery, partial return, population bounds, match-event ordering, P001 inputs, and 3D presentation are preserved.

## Validation

Engine: `Godot 4.7.2.stable.official.ed1daf0bf`.

- `godot --headless --path . --script res://tests/p002_logic_test.gd` — `P002 gameplay logic: PASS (59 checks)`.
- `godot --headless --path . --script res://tests/headless_smoke.gd` — `P001 headless smoke: PASS`.
- P001 smoke with `--resolution 1600x720` — PASS.
- `godot --headless --path . --quit-after 120` — clean bounded runtime startup.
- `git diff --check` — PASS before commit.

The expanded P002 suite specifically verifies far-left/far-right misses, no miss-side state changes, magazine consumption without refund/double-consumption, legitimate overlap insertion, moving-train contact, single insertion, disconnected same-color non-matching, bounded physical reconnection, matching after reconnection, and RED/GREEN/BLUE FIFO order. All original seed, threshold, large-group, cascade, cache, empty recovery, continuity, and shot-pipeline coverage remains.

Validation used isolated `/tmp` XDG data/config/cache directories.

## Manual verification

1. Run `godot --path .`. Let the train remain on the right and fire from the far-left side: the projectile should disappear at lane height, consume its magazine ball, and leave `VISIBLE`, `CACHE`, and match counters unchanged.
2. Fire with the aim guide overlapping a moving ball: one ball should insert beside that contact. Firing into a wide empty gap should miss.
3. Let balls begin rolling into `CACHE`, then complete a match. The returned batch should enter at the far right in FIFO order and visibly travel faster while a wide gap exists; it must not match same-colored balls across that gap.
4. Once the returned group reaches normal spacing, subsequent contact insertions may match/cascade across the now-connected boundary.
5. Recheck mouse/touch firing, right-click/Space and button swapping, responsive layout, and the four hopping 3D lanes.

## Known limitations / scope

- Contact is deliberately a simple one-dimensional horizontal overlap at the fixed lane crossing, appropriate for the straight-line P002 shooter; there are no physics bodies.
- The 1.25× spacing adjacency tolerance allows small numerical/layout variation, while recycled gaps begin substantially beyond it. Catch-up and closure rates remain playtest constants.
- Score/combo/fever, combat, knockdown/loss, and export/device work remain deferred to P003–P006.
