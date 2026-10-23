# ACTIVE TASK: LBS-P003 — Score, combo progression, fever, and live HUD

**State:** READY FOR CODEX
**Branch:** `master`
**Prerequisite:** P001 accepted; P002 accepted after revision commit `1fe4d5b` and handoff `b3cf5ed`.
**First read:** `AGENTS.md`, `.ai/PROTOCOL.md`, `.ai/DECISIONS.md`, `.ai/TASK_LEDGER.md`, then this task.

## Objective
Turn P002's successful match events into **score and consecutive-match combo/fever progression**, visible in a clean responsive HUD. Preserve the correct shot-contact, spatial adjacency and ordered recycling fixes from P002. Keep real 3D damage/combat for P004.

## Required rules (authoritative)
1. **Valid match:** each separate `ChainModel.match_completed(identity, group_size)` emission represents one successful match. Normal and cascade matches count identically; multiple cascade events from one fired shot count as consecutive matches in the order emitted. A group of 4, 5, 7 etc. balls is **one match**, not multiple combos.
2. **Combo timing:** first match begins a chain at combo 1, attack tier 1. The next match **within 3.0 seconds of the previous successful match** advances to combo 2 / tier 2, then combo 3 / tier 3. The **fourth match** within the successive 3-second windows activates FEVER; every later timely match stays in FEVER and at **tier 3** until the chain times out. A longer gap resets to combo 1 on the next successful match. Exactly elapsed 3.0 s can be treated as expired; document and test boundary.
3. **Fever bar:** a 3-second visual decay window that refreshes on **every valid match**, including before fever. Display current combo/tier state legibly; FEVER is distinct (text/highlight/bar visual) from ordinary tier 3. When time expires, bar empties, combo resets to 0 and fever turns off. Score must persist. Do not require the player to shoot rapidly without actually matching.
4. **Score:** larger matching groups grant **only additional score**, never extra tier advances. Start with configurable score formula **100 points for 3 balls + 50 for each ball beyond 3** (3=100, 4=150, 5=200, 7=300); no score penalty for missed shots, rollover/cached balls, empty lanes or fever expiration. Do not add a score multiplier for combo/fever without an explicit later task; scoreboard should still rise as normal in FEVER.
5. **Future combat interface:** emit or provide one well-defined structured result for each match (identity, group size, combo count, tier 1/2/3, fever boolean, points awarded) for P004 combat and P005 revival. The tier/fever must be locked **at match time**, not when future 3D projectiles land. Favor central small independent `RefCounted` progression/scoring module; pure deterministic data, no dependence on render frame when handling same-frame cascades.
6. **Current visuals:** score, combo count, current tier/fever status, and ticking meter should update live and be legible on 16:9 and wider landscape sizes. Do not let title, score, combo, and bar overlap. The top-ball P002 debug overlay can be retained for diagnostics but should not clutter normal gameplay; preferably hide behind a documented debug toggle (e.g. F3) or reposition unobtrusively. Add light short-lived match/FEVER feedback using 2D primitives/text; no sound or external assets.
7. **Magazine ball generation:** replace P001's fixed-seed arbitrary per-shot choice/avoid-duplicate workaround with a transparent configurable **4-color shuffle bag** (one of each identity per bag, reshuffled when empty; deterministic seed permitted for test). Swapping LOADED and NEXT must not change the remaining bag or consume another generated ball. Firing advances NEXT to LOADED and draws exactly one new NEXT, even on a miss; color + symbol remain synced on shooter and magazine. Across bag boundaries, duplicate colors may occur; do not force anti-duplicates at cost of fairness. This generator change is specifically authorized by P003.
8. **Keep placeholder 3D lanes:** no real defender firing, enemy HP, knockdown, win/loss or gameplay-changing fever bonus in P003. Match outcomes are captured for next task; character/projectile work starts P004.

## Implementation / integration
- Wire P002 `match_completed` signal into the match-progression module in `scripts/main.gd`; do not poll or use the debug `event_log` as authoritative integration.
- Expose a simple update(delta) for remaining window, or equivalent deterministic simulation-friendly API; avoid system wall clock and multi-threaded timers.
- Update `HudView` through explicit setters/signals. Keep clean separation between game state and display rendering.
- Keep shooter and magazine UI behavior identical between desktop and touch, respecting input consumption and shot cooldown.
- Do not change P002's collision tolerance, FIFO ordering or gap-closure behavior except to fix a verified regression.
- Consider UI controls at 1280x720, 1600x720 and narrower 960x540 landscape; use dynamic positioning/clamping rather than fixed overlapping labels.
- Simple state/event API should make it straightforward in P004 to map color->defender and tier->number of projectiles.

## Automated tests (required)
Add `tests/p003_logic_test.gd` or equivalent deterministic headless test and run existing P001/P002 suites.
- One 3-ball match awards 100, combo 1, tier 1; another timely match yields combo 2 tier 2, third yields tier 3, fourth yields FEVER; fifth and later timely matches remain fever with tier 3.
- Separate cascades in the same update tick each increment combo once; one larger group increments combo once while awarding its larger size score.
- Timeout 3s resets combo/fever and bar but preserves score; next match after timeout is tier 1; verify near/boundary timing.
- At least one genuine P002 chain insertion/clear event updates the central combo system and HUD; missed shot and cache rollover do **not** award points or alter progression.
- Shuffle-bag draw covers all four identities once per full bag; swaps do not draw; shots draw exactly one next ball, including misses.
- No double-counting from UI repaint, signaling or gap closure.
- Project scene launches headlessly without parse/runtime errors; 1280x720 and 1600x720 P001 layout tests still pass, add 960x540 smoke if feasible.

## Acceptance / handoff
- In a live window, arrange/trigger 3+ color matches: score increments and the timer visibly refills.
- Four consecutive successful matches, each within 3 seconds, produce distinct FEVER state; a delay of over 3 seconds resets to ordinary tier-1.
- A 5-ball group awards more points but doesn't skip attack tiers.
- Match events contain identities/tiers ready for P004; top chain still correctly handles misses, cascades, physical gaps and cached FIFO return.
- Use only Godot built-ins and placeholder art, GDScript/Compatibility.
- Update `.ai/CODEX_HANDOFF.md` (task ID, status, commits, implementation, tests, manual scenario, known caveats); commit and push. **Stop** without self-advancing to P004.

## Out of scope
Any real 3D combat, knockdown, revival, base breach, Android/Web export setup, music, dramatic effects and complex progression systems. Future task P004 will connect matches to primitive defenders.
