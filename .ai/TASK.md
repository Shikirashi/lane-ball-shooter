# ACTIVE TASK: LBS-P014 — Restore causal Zuma rollback while preserving smooth masked right-edge entry

**Status:** READY FOR CODEX
**Branch:** master
**User playtest:** P013 made incoming balls slide smoothly into view, but MATCH-CREATED gap closure now looks broken. The LEFT/front balls continue left as though still being pushed, while incoming RIGHT-side balls emerge at normal speed and then accelerate LEFT individually after becoming visible. They end up filling the interior gap from behind, rather than the existing front section moving backward/right as one group.
**Baseline:** P013 implementation `11816ab`, handoff `0ebdd23` (source-reviewed). Preserve P011 authoritative segments, P012 insertion-push LEFT, P013 visual masking and shooter preview.
**Read:** `AGENTS.md`, `.ai/PROTOCOL.md`, `.ai/DECISIONS.md`, `.ai/TASK_LEDGER.md`, this task, `.ai/CODEX_HANDOFF.md`.

## Visual contract — three independent types of motion

Conveyor flows RIGHT -> LEFT at exactly 34 px/s. Screen order is [LEFT/front/exit] ... [RIGHT/back/entrance].

**A. Normal feed:** New/fresh and cached balls originate completely outside the RIGHT clip edge, moving LEFT with the conveyor. They may join the existing trailing train by physically catching up only under a deliberate FEED policy, but **must not race through the interior in isolated single-ball spurts**, and **must not act as the mechanism closing a player-cleared gap**.

**B. Shot insertion:** Inserting a fired ball pushes the connected LEFT/front prefix LEFT by one slot (P012). Right/back suffix does not get shoved RIGHT. The shot settles 0.05s, then the initial player-caused match can clear.

**C. Player-caused match gap:** If clearing a middle group exposes surviving sections on both sides, the section **immediately LEFT/front of the gap reverses RIGHT toward the existing RIGHT/back section**, accelerating as one rigid train. The right/back section continues its ordinary LEFT progress and must not receive special >34 px/s left catch-up for this causal gap. No amount of new fresh-ball generation should substitute for this forward-section rollback. When the exposed ends actually touch at exact ball spacing, merge; matching boundary colors can cascade only then.

Example:
```
Normal:     [R R] [Y Y Y] [B B]    ←34
Clear Y:    [R R]     gap   [B B]
WRONG:  ←34 [R R]     gap   [B B] ←(fast new balls from right)
RIGHT:      [R R] →→→ gap ←34 [B B]
Contact:          [R R][B B]      (merge; cascade only if the ends match)
```
If exposed ends are RED 2+2, trigger one later RED x4 cascade only AFTER physical contact. A RED 2 / YELLOW 2 / RED 2 shot scenario must still sequence: insertion, 0.05s yellow pop, visible front-red reverse, physical collision, red x4 pop.

## Required root-cause investigation (do BEFORE patching)

Inspect current `scripts/chain_model.gd`, particularly:
- `_remove_group` handling middle, segment-extremity and whole-segment clears and how it assigns `GapType.CAUSAL` and gap IDs;
- `_integrate_segments` and whether the actual left/front segment is assigned motor travel; how FEED catch-up interacts with CAUSAL motors in neighboring gaps;
- `_solve_non_overlap` and whether it accidentally erases or blocks the causal motor or shifts its right endpoint;
- `_process_contacts` and whether an unrelated FEED merge can erase/convert a CAUSAL edge;
- `_segment_has_fully_entered` gating, `_feed_right_edge`, `_admit_on_right` and offscreen staging; check whether new balls appear as isolated FEED segments with accelerated post-entry motion rather than connecting naturally.
- P011–P013 tests and manual settings; existing stress tests show zero overlap, which does **not** verify intended direction or segment-level velocities.

Instrument deterministic per-segment movement: before/after anchor, velocity relative to normal -34 px/s, segment ID, members count, left/right gap type and ID. Add bounded F3 diagnostics for **CAUSAL motor count, FEED motor count and actual reverse X displacement**, not merely non-overlap.

## Implementation requirements

1. A matching clear in the middle must create a stable, typed causal gap tied to its actual LEFT and RIGHT surviving segments. Protect this gap and its endpoints through new FEED arrivals, multiple concurrent matches, cascades, insertion and segment merges; never silently degrade it to FEED or lose its motor when a segment becomes empty/rolls off. Use stable segment or endpoint IDs, not indices that go stale. If front section exits completely there is naturally no rollback; handle separately.
2. Make causal motion topologically authoritative: a CAUSAL gap may be closed **only** by the LEFT/front section moving right as a rigid connected segment, plus ordinary baseline movement of both sections. Maintain P010 rollback initial 60 px/s, accel 900 px/s², cap 420 px/s; tests should prove LEFT endpoint's net X actually increases across appropriate step(s), even as global conveyor -34 applies, and that both balls in front section have identical displacement. RIGHT endpoint must show only -34 px/s baseline during this event (unless a separate clearly identified noncausal interaction requires a constraint).
3. A **FEED** edge must never accelerate a single new ball toward a causal gap; offscreen arrivals should be admitted at exact legal spacing to the preceding trailing segment when possible, sharing its rigid motion, not repeatedly creating separated segments that start sprinting individually on becoming fully visible. Where a genuinely separated cached return batch must exist, keep it rigid and bounded with an intentionally separate policy; it cannot collide through, consume or take priority over an active CAUSAL motor. Prefer suppressing or limiting FEED catch-up and using natural 34 px/s entry over an abrupt 120 px/s post-visibility speed jump. Preserve continuous generation and finite visible population; do not starve feeder permanently.
4. When multiple CAUSAL and FEED gaps coexist, causal front rollback receives priority; the non-overlap/contact solver must clamp physical crossing without accidentally reassigning the motion to a right-side FEED train or freezing the genuine rollback. Do not teleport centers, overlap balls, invert UID order, fragment rigid groups into chasing individuals, or create "push from right" compensation.
5. Preserve all other semantics: P012 insert pushes LEFT, P010 0.05s settling and sequential cascades, P011 center spacing=58 and radius=22 non-overlap, P013 whole-ball offscreen entry at right and exact conveyor-only clip (never clip shooter/in-flight/pending insert), P008 run color distribution, FIFO cache and fresh interleaving, 24 auto-live cap, 0.20s shot travel, 0.4s cooldown, enemy 0.24 hopping, combos/tier attacks/revival/gameover and procedural SFX, shooter next preview and circular swap.
6. The goal is a physically and visually correct model. DO NOT hide FEED catch-up behind a fake animation, merely disable all new arrivals, or switch off the mask. Fix the movement system.

## Required tests: `tests/p014_causal_rollback_feed_test.gd`

- **Main regression:** Set front [RED,RED], middle [YELLOW,YELLOW], rear [BLUE,BLUE]; player inserts yellow, before 0.05s no event, then yellow x3 removal. Immediately record front/rear UIDs, positions and CAUSAL edge ID. Over 0.05, 0.1, 0.2s verify front reds translate RIGHT together (positive net X where rollback is active), while rear blues move only -34 px/s baseline, and no new feed contributes to interior gap closure.
- Same-color ends [RED,RED]/[YELLOW,YELLOW]/[RED,RED]: verify yellow event first and red x4 event only AFTER physical contact, at a distinctly later time, with no passive scan.
- With continuous fresh generation enabled and new balls *currently entering masked viewport*, force middle clear. Track identities/UIDs of front pair and its X velocity; ensure rollback persists while new arrivals remain moving at 34 px/s and do not become the causal gap motor.
- Simulate FIFO pending returns and a second CAUSAL gap during first rollback. Each causal motor translates its intended LEFT section as one rigid group; FEED edges and newly admitted return groups never split, displace or cancel it; no invalid gap ID/motor stays stuck.
- Quantify entrant speed BEFORE and AFTER fully visible: continuous fresh entries should be physically smooth, with no instantaneous velocity leap (especially 34 -> 120) unless explicit documented noncausal batch catch-up, which must not appear as sequential single-ball catch-up.
- Insertion during ongoing rollback still pushes preceding balls LEFT (not RIGHT) and does not break the existing causal motor; restart/gameover clean up all transient states.
- Across 30/60/120 FPS and selected large deltas, events, contact time, colors and displacements remain reasonably stable. Check logical/display spacing >=44px, rigid internal 58px, ascending UID positions and all previous P011 invariant guarantees.
- Long 60–120 second stream including many rapid matches, offscreen entrants and cache returns: bounded counts, no gaps stuck forever without a reason, normal arrivals continue, no overlapping or popping balls.
- Run ALL P001–P013 headless regression tests, adjust only assertions genuinely superseded by newly approved FEED behavior, add P014 suite, bounded startup at 960x540, 1280x720, 1600x720, 2400x1080, and `git diff --check`. Report exact pass/fail results and reproduced initial bug before fix if feasible.

## Finish

Update README with causal-versus-feed movement and troubleshooting F3 diagnostics. Update `.ai/CODEX_HANDOFF.md` with actual root cause, changes, test details, residual issues, and a reproducible manual playtest sequence. Commit/push `master`, then STOP. Do not edit `.ai/TASK_LEDGER.md` or `.ai/DECISIONS.md`; do not self-advance P015. ChatGPT will review next "check push".
