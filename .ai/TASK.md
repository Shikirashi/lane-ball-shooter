# ACTIVE TASK: LBS-P011 — Full-width shooting and authoritative segment-based Zuma conveyor rebuild

**Status:** READY FOR CODEX
**Branch:** master
**Priority:** User playtest after P010: chain improvements feel better, but quick consecutive matches sometimes cause OVERLAPPING balls; bottom-right magazine blocks aiming at rightmost balls; BLUE and GREEN lane colors look too similar.
**Baseline:** P010 implementation `891ad0d`, handoff `80020c0`; P010 accepted. Do not introduce new features or alter established balance.
**Read first:** `AGENTS.md`, `.ai/PROTOCOL.md`, `.ai/DECISIONS.md`, `.ai/TASK_LEDGER.md`, `.ai/CODEX_HANDOFF.md`, this task.
**External design references (principles, not a license to copy source code):**
- https://forums.unrealengine.com/t/zuma-like-mechanic/480176 — ordered slots/indices and animated movement instead of per-ball physics.
- https://gamedev.net/forums/topic/430465-about-zuma-like-game/ — separate contiguous chain lists that join on physical contact.
- https://codesmith.jamie.ly/post/zuma-clone/ — ordered/deterministic event updates and state debug/testing.
- https://www.udemy.com/course/create-an-epic-2d-mobile-tile-matching-game-with-unity/ — topics include landing balls, moving sections back and repeated clear cycles.
These are independent examples of Zuma-inspired implementation patterns, NOT exact official Zuma source.

## Central acceptance invariant

At every completed simulation event/substep, for each neighboring pair of **live** balls in sorted screen order:
- IDs are unique, color/UID order is deterministic and unchanged except legitimate insertion/removal/left rollover/right feed;
- logical positions must be finite and strictly increasing: `x[i+1] > x[i]`;
- no two balls overlap: `x[i+1]-x[i] >= MIN_PHYSICAL_SPACING` (use actual chain ball diameter if appropriate; baseline `spacing=58, radius=22`, so require >= 44 px physical diameter, and normal connected segment spacing = 58 px; small explicit epsilon permitted);
- within an *intact connected segment*, exact adjacent center spacing must be the configured `spacing` (within epsilon);
- the **rendered** `display_x` coordinates must obey non-overlap too (no cosmetic/interpolation overlaps, especially during insertion settling);
- no ball may warp/snap through another or change ordered neighbors without a legitimate insertion or removal.
Test these INVARIANTS after every tiny timestep/event, not only at end of tests.

## A. Refactor chain to authoritative segments, not independent per-ball position patching

Current `ChainModel` has `balls:Array[Dictionary]`, `x/display_x`, `_shift_logical_positions`, `_close_disconnected_gaps`, `_update_rollbacks`, `pending_insertions`, `rollback_gaps` and `_feed_right_edge`; independent movement mechanisms interact under rapid shots and have produced actual visual ball overlap in user's playtest.

Reimplement its internal representation as **ordered connected segments** (each with contiguous persistent ball UIDs/colors and an anchor/base path X plus shared direction/velocity or phase). A ball's center X is derived from its segment anchor plus relative index * spacing. Segments can move differently across gaps; a segment is internally rigid. Use one authoritative source for both simulation and drawing: a derived read-only flattened snapshot `balls` if existing `BallChainView`/tests depend on it, but never make independent per-ball x movement the master of physics.

- Maintain stable ordered UIDs and identities, deterministic reset and test setup; current public APIs (`try_insert_shot`, `advance`, `return_cached`, `set_test_state`, `identities`, signals and run counters) should remain or be adapted with explicit compatibility wrappers. Tests should assert semantics rather than private data structures.
- All motion (34 px/s normal forward, backward segment recoil, per-gap contact, incoming feeder and cached returns) goes through ONE prioritized deterministic segment integration system and ONE non-overlap/contact constraint solver. Do NOT tack on special per-ball left/right shifts after updating segments. No magic corrective teleport or hidden overlap masking.
- Separate logical segment spacing from transitional insertion visual interpolation: insertion at contact can push an entire adjacent segment coherently to make a new slot; it must not draw a temporary ball atop its neighbor. Move/push an entire affected subchain as required, preserve ordering and nonoverlap at each frame. Provide pleasant ~0.05s settle without violating physical constraints. A shot that contacts a moving segment during rollback must be inserted correctly.
- Valid gaps remain true distance separations. Distinguish causal player-cleared gaps from noncausal feeder/cache gaps with explicit typed segment-edge metadata (or equivalent). Do NOT globally scan unrelated 3+/7+ naturally spawned runs.
- Middle clear splits segment and visibly leaves hole. The forward/LEFT segment reverses RIGHT and accelerates with P010 constants (initial 60 px/s, acceleration 900 px/s², cap 420 px/s), while trailing/RIGHT segment follows normal 34 px/s forward motion. It must not be moved LEFT extra to fill the hole. The front segment translates as one rigid unit; any multiple pending rollback motors do not cause two conflicting movements of the same ball.
- Physical contact at exactly spacing merges appropriate segments, conserving UID/color order. If contacting ends have same identity AND gap is causally connected to a player-initiated clear, trigger one deferred local cascade (true entire group size); otherwise merge without auto-clear. Multiple cascades may recursively split/merge with correct delayed staging; no same-time premature cascade.
- Keep insertion semantics: fired shot arriving at top becomes a real ball in the train; starts exactly **0.05s** simulated settle time; only then check locally for the player's initial >=3. A different-color/missed shot must not clear unrelated naturally pre-existing runs. Two concurrent pending settles must not fire duplicate matches.
- Deterministic event-driven temporal solver: process earliest settle expiration, rollback contact, left rollover, right feeder admission, and other concurrent events in a documented stable order. Use bounded substeps (or exact event times) that avoid tunneling and keep results stable at 30/60/120Hz and 1 large frame delta. If game-over freezes simulation, pending events freeze. Restart clears all segments, gaps, velocities, pending insertion timers, and diagnostics.
- Collision hit detection must use ACTUAL rendered location (consistent with logical state); shooter stays 0.20s travel, normal cooldown 0.4s. Physical dimensions must not be misrepresented by a giant hit tolerance allowing nonphysical overlap; clarify existing `DEFAULT_SHOT_RADIUS` contact tolerance separately.
- Do NOT solve problems by deleting balls silently, reordering cached colors, or forcing arbitrary max 1 match per frame. Rapid simultaneous matches are expected gameplay.

## B. Integrate perpetual right feeder and FIFO returns directly into segment dynamics

- Both fresh weighted same-color runs and cached FIFO returns enter through **one well-defined right-edge admission interface**, attached to trailing/RIGHT segment or forming a new incoming segment at safe physical spacing. Never inject a fresh/recycled ball into a gap opened in the middle by a player clear.
- Preserve P008 color run-length weights [20,30,18,13,9,6,4] for lengths 1..7, naturally possible 4–7+ same-color groups and all four identities; initial seed similarly clustered. Existing naturally generated 3+/7+ groups MUST remain until player-created match/cascade.
- Preserve indefinite lifetime generation, bounded simultaneous live population (24 cap unless stronger justified bound), no ever-growing invisible right-hand ball backlog, no forever-empty chain, normal FIFO exit-left cache, cache-return batch requests after matches, fresh admission interleaving and exact FIFO return order. The cache may legitimately grow linearly for unreturned balls; don't discard it.
- Handle live chain+segments going off-left without resorting to per-ball clipping of segments that changes positions for remaining balls.
- Ensure each newly admitted ball has exact legal spacing to neighbors even when rightmost segment is reversing/recoiling or changing size; defer admission until physical room exists. Document how entrance and collision constraints coordinate.
- Add bounded diagnostics for segment count, gap type, max concurrent event count, min logical/display spacing, and any invariant violation. F3 toggle remains functional and useful.

## C. Remove right-bottom swap obstruction; give the shooter FULL horizontal range

The problem is confirmed in `scripts/responsive_layout.gd`:
`magazine_rect` reserves 280–340px at bottom right and `track_right = magazine_rect.position.x - 24.0`. The shooter never reaches the far right of the conveyor.

- **MANDATORY:** Shooter should be able to move across the whole accessible chain X range, including hitting the rightmost chain balls. The shooter track must span safe chain coordinates (subject only to small symmetric edge margins for ball radius/safe area), not stop at magazine. A shot from either track extreme should be able to hit respective near-edge chain targets.
- Move the swap/magazine UI to a compact overlay or upper HUD/centered location that does NOT cover the actual shooter travel track or steal taps on the rightmost balls. Preferred: a **small but finger-friendly (~56x56px minimum)** swap button in an otherwise unused HUD corner/above central battlefield, with small separate loaded/next indicators near it; or a compact nonblocking floating control outside the shot release/playfield region. On 960×540 and narrow/mobile landscape, no collisions with score/fever, chain, battlefield status, safe cutouts, restart overlay. Use one shared responsive layout function, not per-device hardcoding.
- Keep loaded and next identities visible and color+shape marked, swap affordance obvious. Space/right click and touch tap on swap remain available and fire no shot. Touch-release shooting from extreme-right and extreme-left playfield still works once; no GUI click leakage/double shot.
- Prevent magazine UI from blocking drag initiation, travel or shot targeting even if visuals overlap the bottom area. Practical target >=44 logical px with 56 preferred, safe-area compliant.
- Don't redesign entire game or make shooter 2D X aim offset from actual conveyor physical X unintentionally. Ensure chain view origin/width and shooter track mapping remain coherent at 960×540, 1280×720, 1600×720, 2400×1080.

## D. Tests first / reproduction

Add `tests/p011_segment_chain_stress_test.gd` plus input/layout tests if appropriate:
1. Construct several known chains, make fast shots (including two or more within active 50ms settle/gap rollback), and force 2–4 interleaved cascades and fresh/cache admission. After EACH substep/events assert strictly ordered unique UIDs, gap-aware spacing >= physical diameter, rigid internal segment spacing and rendered positions not overlapping. Provide reproducible seeded sequence that would make old implementation overlap if possible.
2. A [RED,RED][YELLOW,YELLOW][RED,RED] with inserted YELLOW at contact: 0–49ms no pop; yellow size3 at t>=50ms; left red segment accelerates BACKWARD to right as a unit; only at red-to-red physical contact later does size4 red cascade. Check correct event timestamps, combo score (100+150), SFX routing and defender attacks.
3. User fires immediately after one match and again while rollback active; inserting exactly at seam/boundary, at a moving exposed endpoint, or into two isolated segments doesn't duplicate/lose UID, corrupt ordering or leave gaps permanently stuck.
4. Multiple separately closing gaps, chained cascades, long seven+ run clears, full clear, empty recovery, left-edge rollover during rollback, late right-feed admission, mismatched-color contact (merge but not auto-pop), and arbitrary mid-animation restart.
5. Simulate at least thousands of seeded matches/insertions/rollovers, varying simulated frame delta 1/30, 1/60, 1/120 and a few long deltas, with robust independent invariants on every step, bounded visible objects and no runaway O(time-since-start) loop. Tests should be fast and deterministic; document seed and reproduce method for failures.
6. P011 layout: track spans nearly full chain width and its left/right limits align with first/last targetable balls; swap target at least 56x56 or documented equivalent; loaded/next visible; touch and GUI swap events don't shoot or steal board drags; F3, R, M and restart remain.
7. Rerun P001–P010 headless suites, adapting old private-internal assertions only where refactor changes representation while preserving gameplay behavior. Do NOT delete important regression checks, match semantics, FIFO, score, tier3, down/revival, audio or 0.05s settle.
8. Verify bounded headless starts at 960x540, 1280x720, 1600x720 and 2400x1080; `git diff --check`, no binary export artifacts/secrets.

## Acceptance and finish

- No visible or logical ball overlaps under rapid matching or during any of insertion settling, cascade, rollback, feeder entry and cache return.
- Front-section rollback and theatrical cascades at P010 timing feel the same or better; no premature chain events.
- Full left-to-right shooter aiming range unobstructed; touch-friendly swap available in a location outside the actual firing path.
- Technical implementation materially replaces independent per-ball position adjustments with a coherent authoritative segment/slot representation. Cosmetic hacks that only mask overlapping sprites are NOT acceptable.
- **Locked gameplay balance:** `ChainModel.DEFAULT_SPEED=34.0`, `ShooterView.SHOT_TRAVEL_TIME=0.20`, 0.4s shoot cooldown, `LaneCombatModel.DEFAULT_ENEMY_SPEED=0.24`, 0.05s insert settle, rollback initial=60/accel=900/max=420, existing P008 SFX, match/score/fever/revival and right-edge generation rules.
- GDScript Godot 4.7.2 Compatibility, Web and Android landscape. No new enemy types, graphics assets, audio redesign, export SDK installation, GUI/mouse automation or unrelated features.
- Update README with segment model / reliable rollback and moved swap layout. Update `.ai/CODEX_HANDOFF.md` with architecture, tests/real counts, reproduce seeds, performance/limits and manual QA checklist.
- Commit/push to master and **STOP**. Don't edit `.ai/TASK_LEDGER.md` or `.ai/DECISIONS.md`, don't self-advance P012. ChatGPT will review on "check push".


## E. Fix fourth-lane color identity readability (user screenshot)

User's screenshot shows lane 2 (BLUE) and lane 4 (GREEN) appearing almost identical cyan/turquoise, especially their bright stripes, 3D defender bodies and floor accents. The intended identity order is **RED, BLUE, YELLOW, GREEN** (indices 0,1,2,3), already correctly mapped in `TeamData`, but the final 3D material/lighting output is confusing.

- Fold this into P011 rather than creating a separate task.
- Inspect `scripts/team_data.gd`, `scripts/world/lane_actor.gd`, `scripts/world/battlefield.gd` and procedural `PrimitiveFactory` materials/lighting and `WorldEnvironment`. Preserve identities/order of all lanes, ball colors, magazine loaded/next, projectiles, lane symbols, scoreboard/status. Fix **perceived rendered contrast** and not just source-level numeric equality. Lane 2 must visibly read as a saturated BLUE, lane 4 as unmistakable grassy/emerald GREEN, not both cyan.
- Prefer one canonical palette `TeamData.COLORS` driving every visible matching identity; if lighting/tonemapping makes green cyan, adjust palette/hue and/or neutralized lighting and materials while preserving readable brightness. Suggested starting values: BLUE `#3677E8`, GREEN `#37C45A`; tune against the actual rendered scene for best distinction. Avoid green becoming too dark on navy floors and avoid red/yellow collisions. Don't introduce unrelated palette menus here.
- Preserve color-blind redundancy: BLUE square, GREEN diamond, RED dot, YELLOW triangle on the conveyor, markers, shooter and magazine. Make the lane's distinguishing marker or status label large/clear enough on 960x540 without obstructing enemies.
- Tests: assert team identities remain 0/1/2/3; BLUE/GREEN palette sufficiently distinguishable (including a hue/distance measure not just `blue != green`); all lane stripe, defender and corresponding chain/magazine colors derive from the same team identity; ensure material colors not overwritten by generic teal accents; screenshot/manual verification at 1280x720 and 960x540. Avoid declaring visual QA complete based solely on headless RGB tests.
