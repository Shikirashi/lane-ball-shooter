# Codex Handoff — LBS-P003

**Status:** COMPLETE

**Branch:** `master`

**Implementation commit:** `aa65950` (`Implement P003 scoring combo and fever`)

**Mailbox:** remains on LBS-P003; task/ledger/decision/protocol files were not changed.

## Implemented

- Added independent deterministic `MatchProgression` state for persistent score, consecutive-match combo, tiers 1–3, fever from match four onward, and the three-second decay window.
- Wired `ChainModel.match_completed` directly into progression. Every normal/cascade emission produces one copied structured result containing identity, group size, combo count, locked tier, fever flag, and awarded points for P004/P005 consumers.
- Implemented score formula `100 + 50 × (group_size - 3)` with no combo/fever multiplier or miss/rollover/timeout penalties.
- Defined exactly 3.0 seconds elapsed as expired. Timeout clears combo/tier/fever and the meter while preserving score; the next match restarts at combo/tier 1. Same-frame cascades advance in signal order without relying on wall-clock time.
- Rebuilt `HudView` as a live responsive score/combo/tier/fever display with a ticking meter and distinct pulsing fever palette. Match feedback shows color, true group size, points, and locked tier/FEVER.
- P002 visible/cache diagnostics now default hidden and toggle with F3.
- Replaced arbitrary magazine generation with a deterministic-seed Fisher–Yates four-color shuffle bag. Initial LOADED/NEXT are bag draws; swap draws nothing; every accepted shot draws exactly one new NEXT, including misses. Cross-bag duplicates are allowed naturally.
- Preserved P001 input/3D presentation and all accepted P002 shot-contact, connected-segment adjacency, cascade, and FIFO recycling behavior.

## Validation

Engine: `Godot 4.7.2.stable.official.ed1daf0bf`.

- `godot --headless --path . --script res://tests/headless_smoke.gd` — `P001 headless smoke: PASS`.
- `godot --headless --path . --script res://tests/p002_logic_test.gd` — `P002 gameplay logic: PASS (59 checks)`.
- `godot --headless --path . --script res://tests/p003_logic_test.gd` — `P003 progression and magazine: PASS (72 checks)`.
- P001 smoke at `--resolution 960x540` and `--resolution 1600x720` — PASS at both responsive widths (default 1280×720 also passed).
- `godot --headless --path . --quit-after 120` — clean bounded runtime startup.
- `git diff --check` — PASS before implementation commit.

P003 coverage includes all five timely combo states; fever activation/sustain; 3/4/5/7-ball scoring; same-tick cascade order; one-event large groups; near-3s and exact-3s timing; score persistence; post-timeout restart; full structured results; genuine chain→progression→HUD flow; no scoring from misses, rollovers, or repaints; three complete shuffle bags; no-draw swaps; and exactly-one-draw shots including a miss.

Validation used isolated `/tmp` XDG data/config/cache directories.

## Manual playtest

1. Run `godot --path .`. Use mouse X + left-click (or touch drag/release) to insert balls; right-click, Space, or the magazine button swaps LOADED/NEXT. F3 toggles chain/cache diagnostics.
2. Complete a three-ball match. Confirm `SCORE 000100`, `COMBO x1`, `TIER 1`, a full blue window meter, and matching `+100` feedback.
3. Complete further matches less than three seconds apart. The second shows tier 2, third tier 3, and fourth changes the HUD to distinct orange FEVER. Fifth and later timely matches remain tier 3/FEVER.
4. Let the meter fully drain. Combo returns to zero/READY while score remains; the next match starts tier 1. Exactly 3.0 seconds is intentionally treated as expired.
5. Create a four/five-ball group and confirm it produces one combo step but awards 150/200 points. A cascade should produce a separate step/result for each cleared group.
6. Fire into empty space and confirm the magazine advances once but score/combo do not. Verify recycled FIFO balls, physical-gap behavior, and the four hopping 3D lanes remain intact.

## Known limitations / scope

- P003 records attack-ready match results but does not fire defender projectiles or modify enemies; that begins in P004.
- Fever is presentation/progression only and deliberately has no damage or score multiplier.
- The generator seed is deterministic for reproducible prototype runs; fairness comes from one of each identity per bag, not forced duplicate avoidance.
- No knockdown/revival/loss or export/device QA was added.
