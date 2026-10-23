# ACTIVE TASK: LBS-P005 — Defender knockdown, emergency discharge, revival, breach and restart

**State:** READY FOR CODEX
**Branch:** `master`
**Prerequisites:** P001–P004 reviewed and accepted. P004 implementation `99dbfdb`, handoff `ae1557b`.
**Read in order:** `AGENTS.md`, `.ai/PROTOCOL.md`, `.ai/DECISIONS.md`, `.ai/TASK_LEDGER.md`, this `.ai/TASK.md`.

## Objective
Complete the core **endless survival** loop: when an enemy touches its lane's active defender, knock that defender down; a **once-per-lane-per-run emergency discharge** clears the lane on its first knockdown; while down the player must make **two successful matches of the defender's color** to revive it; if **any enemy crosses the leftmost combat-lane boundary**, the game immediately ends. Implement game-over display and restart. Keep primitive 3D visuals, 2D shooter/ball chain, score, combo/fever, FIFO cache and input working.

## Authoritative behavior
1. **Defender states**: ACTIVE and DOWN, per color lane. Each lane has `emergency_available` (true at start, permanently false after first use) and `revival_progress` (0..2). Defenders are NEVER permanently removed. No passive recovery timer.
2. **First enemy contact**: When an enemy reaches/crosses the defender's logical X (`LaneCombatModel.DEFENDER_X`) while defender ACTIVE, immediately set DOWN; if this lane's charge remains, **consume exactly one emergency charge and eliminate ALL currently alive enemies in that lane**, not just the contacting one. Other lanes remain unaffected. Defender remains DOWN. Provide a distinct, lightweight, code-only 3D discharge wave/burst and an obvious prone/knocked-down defender pose; no external effects/assets.
3. **Later contacts**: After revival, the charge is still spent. The next enemy touching the active defender knocks it DOWN again, but **does not** clear the lane. Any enemies can continue moving left through/past the downed defender; the defender must be revived manually.
4. **Revival**: While DOWN, each **separate valid match event** of that defender's color contributes +1 point to its revival (default required 2, exposed as a tuning constant). Each match STILL contributes normally to P003 score/combo/fever. The match is used for revival **instead of launching normal projectiles**, including the finishing match. When the requirement is reached, return to ACTIVE, reset revival counter, keep emergency spent. No automatic revival and no revival by other colors. Cascades of the matching color count as distinct match events.
5. **On revival**: distinct simple 3D revival flash/pose transition. To avoid impossible immediate re-knockdown or an already-passed enemy being unhittable, apply **one small nonlethal repel** to enemies that are within or behind the defender (push them to a safe X *ahead/right* of the defender). Do not kill them, regenerate the emergency charge, globally wipe enemies, or repeatedly push enemies each frame. If an enemy has ALREADY crossed the leftmost boundary, game over must have taken precedence and cannot be reversed.
6. **Breach loss**: If **any enemy crosses the combat LEFT_BOUNDARY** while alive, game over immediately regardless of defender state, emergency charge, other lanes or score. This is the **sole game-over rule**; balls crossing the top lane are FIFO cached with no penalty or life loss. P004's temporary `enemy_recycled` behavior must be replaced with explicit breach detection/event. Remove breached enemy safely or freeze its position for game-over display; do not silently recycle without ending game.
7. **Ordering / frame rates**: Prevent missing a defender touch due to a large delta. If an enemy crosses both `DEFENDER_X` and `LEFT_BOUNDARY` within one long update, with an ACTIVE defender and charge still ready, handle first contact and discharge BEFORE concluding a breach; with a DOWN defender or no relevant protection, an enemy crossing the boundary triggers loss. Handle multiple simultaneous enemies and bursts without duplicate discharge/revival or multiple game-over signals.
8. **Game over state**: Keep last score on screen and show clear centered `GAME OVER` overlay (and optionally run survival seconds). Stop ALL live gameplay simulation/input processing: spawning, enemy/projectile movement, matching, ball chain motion, shooter shots, swapping, combo decay, and pending state changes. Provide an obvious **RESTART** click/touch button plus keyboard R. Restart creates a clean fresh run: four ACTIVE defenders, all 4 charges ready, zero revival, new enemies, score 0, combo/fever cleared, ball chain/cache reset, loaded+next magazine reset, no leftover projectiles/VFX/input ownership. Use scene reload or a well-tested reset method.
9. **Status UI**: Display per-lane emergency-charge readiness/spent and downed defender's revival progress (e.g. `0/2`, `1/2`) visibly, legibly and consistently with each colored defender. Prefer clear 3D lane markers/status or small 2D overlay aligned to lanes; support symbol + color (not color alone), and unobtrusive feedback for discharge and revive. Do not bury critical state in F3 debug readouts.
10. **Tuning**: Default required matches 2. Preserve P004 enemy 2 HP, speeds and spawn pacing unless tuning is needed to make recoveries playable; expose knobs for emergency visuals, revival pulse distance, and contacts. Document any changed defaults. Avoid unlimited combat-history arrays for an endless run if a small bounded diagnostics buffer is easy; otherwise document deferral to P006.

## Architecture/integration guidance
- Extend `LaneCombatModel` (pure logic, signals for contact/knockdown/discharge/revive/breach) and `LaneActor` (3D visuals), plus `Battlefield` for routing and reporting breaches.
- Source of truth for DOWN/charge/revival must be logical lane state, not animation visibility.
- P003 already emits structured `MatchProgression.match_resolved(result)` and P004 routes through `Battlefield.fire_for_match(result)`: introduce a single centralized `handle_match(result)` path (or similarly clear method) that **either** gives a downed defender revival progress **or** performs the ordinary attack. Prevent a match causing both an attack and a revival point.
- Match scoring/fever must proceed regardless of defender state. Respect locked attack tier/fever at match time. Other lanes' matches cannot revive a different defender.
- P004's swept enemy/projectile hit model must continue working, jumping remains cosmetic; handle deletion while iterating with care.
- Endgame and restart UI must consume mouse/touch properly so a button press or release doesn't fire a shot through it; keyboard R should not interfere with existing Space swap/F3 toggle.
- State transition calls should be idempotent; late queued projectile bursts should not resurrect attacks post-game-over or on DOWN lanes. Existing launched projectiles can resolve until game over; decide whether knockdown removes already launched projectiles, document behavior.

## Deterministic automated tests (required)
Create `tests/p005_survival_test.gd`; keep/run P001–P004 suites.
- All four lanes start ACTIVE, 1 charge each, revival 0.
- First enemy contact triggers exactly one DOWN and exactly one full-lane clear; no other lane changed; score/chain unaffected.
- Multiple simultaneous enemies and a large delta crossing both defender/breach thresholds cannot bypass first-contact discharge.
- With charge spent and revived ACTIVE, next contact produces DOWN with **no second discharge**; incoming enemies remain alive and advance.
- One same-color 3+ match while DOWN increments 1/2 with **no defender projectiles**; second same-color match revives with **no attack**; afterward a normal same-color match launches its expected 1/2/3-shot burst.
- Other-color matches still attack their ACTIVE lane, leave DOWN lane unchanged, and score/combo advance normally. Cascades count as separate revival opportunities; large 5+ matching group still only one revival point.
- Revival pulse moves nearby/passed enemies ahead/right of defender without killing, while an already-breached enemy causes terminal loss.
- An alive enemy crossing LEFT_BOUNDARY with no available protection triggers game over exactly once; all gameplay sim halted and score visible.
- Top ball rollover/cache never causes game over.
- Restart truly resets four lanes, charges, enemies, magazine, chain/cache, score/combo/fever, game-over overlay, and projectile state. No stale signals or duplicate live scene.
- Recheck P004 swept projectile hits, burst counts, enemy multi-target, P003 progression, P002 FIFO/contact/matches, P001 scene and input. Bounded headless runtime at 1280x720 and ideally 1600x720.

## Manual verification
1. Run project, let an enemy reach a defender. That defender falls, its one-time emergency burst clears **only** its lane. The emergency icon should become visibly spent.
2. While down, make two matches of its corresponding color. Watch `0/2 -> 1/2 -> revived`, with normal scoring/combos but no attacks from that lane during recovery.
3. Upon revival, next match of color fires again. Later breach/second contact produces knockdown **without** another emergency wipe.
4. Continue play until a live enemy exits the left edge: immediate game-over overlay freezes game. Test R and touch/click RESTART.
5. Validate the magazine, ball chain, score, combo, F3 debug, 3D projectiles and no top-lane rollover penalty still work.

## Scope restrictions and handoff
- Do not copy PvZ's lawnmower or plant placement. This is an automatic one-use **defender-integrated discharge**, followed by color-match-based revival.
- No automatic defender revive, permanent death, extra lives, per-lane buying, complex hero powers, fever damage bonus, SFX, external models, shaders or export/device QA (P006).
- Update `.ai/CODEX_HANDOFF.md`: P005 status, commits, state machine, how match events are consumed, test commands/results, reproducible manual scenarios, any assumptions/limitations.
- Commit/push normally to `master` then **STOP**. ChatGPT advances P006 after review.
