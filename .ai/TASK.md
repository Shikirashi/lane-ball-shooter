# ACTIVE TASK: LBS-P018 — Enemy defeat SFX/VFX and 3-second victory presentation delay

**Status:** READY FOR CODEX
**Branch:** `master`
**User request (2026-10-25):** Screenshot shows **WAVE CLEARED** while several enemy meshes are still visibly standing on the battlefield, despite zero remaining enemies in the combat model. Add a distinct ENEMY DEATH SFX and proper ENEMY DEATH VFX (small explosion, enemy tumbles onto its side horizontally, then fades away). Wait **exactly 3.0 seconds after the last enemy is neutralized** before showing the WAVE CLEARED overlay so the player can see the final deaths play out. User has approved the P017 offscreen-LEFT return system and faster 102 px/s conveyor; do not change those.
**Baseline:** P017 implementation `f2fa832` and reviewed mailbox commit `1945b55`.
**Read:** `AGENTS.md`, `.ai/PROTOCOL.md`, `.ai/DECISIONS.md`, `.ai/TASK_LEDGER.md`, this task, latest `.ai/CODEX_HANDOFF.md`, and existing tests. Code-only Godot 4.7.2 GDScript Compatibility targeting Web/Android landscape. Do not use GUI automation without user request.

## Confirmed root cause

- `LaneCombatModel._damage_enemy` removes defeated enemy from `enemies`, emits `enemy_killed(uid,x)`, then `encounter_state_changed`. Tier-3 clear similarly removes enemies and emits `enemy_killed` per victim; emergency discharge empties `enemies` but does NOT emit those individual `enemy_killed` events.
- `Battlefield._on_encounter_state_changed` can synchronously call `_evaluate_terminal_state` and emit `encounter_cleared` in the SAME call chain as the final kill, when all four quotas exhausted and live enemy count zero.
- `Main._on_encounter_cleared` immediately sets `_game_over = true` and shows WAVE CLEARED overlay. `Battlefield` sets all lane combat models `game_over=true`.
- `LaneActor._process` currently calls `combat_model.update(delta)` then **returns early when `combat_model.game_over`**. That early return prevents `_sync_visuals()` from removing enemy meshes no longer represented by the combat model, and prevents `_update_death_effects` from advancing. Thus the screenshot's enemy meshes can remain visible in a frozen state even though the combat model has zero live enemies.
- `LaneActor._on_enemy_killed` currently only spawns 3 small orange sparks that shrink over 0.32s; there is no enemy corpse/tumble/fade, and `SfxManager` has no `enemy_death` cue.

Fix BOTH cosmetic lifecycle and overlay sequencing, not merely hiding enemy sprites upon WAVE CLEARED.

## A. Death VFX: explosion, horizontal fall, fade

- Whenever ANY combat enemy is neutralized and disappears logically, capture its existing `_enemy_visuals[uid]` (root/body/helmet/eyes/HP pips/shadow) BEFORE it can be cleaned by `_sync_visuals`; transition it to one transient **death actor**, distinct from the live enemy dictionary. The live model stops collision/movement immediately, while its 3D visual remains for the death animation. Do not leave standing ghost enemies.
- Visually animate the actual enemy body: (1) brief explosive hit flash/sparks/dust expanding outward at enemy's x, (2) enemy tilts/falls onto its SIDE horizontally (approximately 75–90° rotation about a suitable Z axis; no clipping through ground), optionally a small knockback/bounce, (3) body/shadow become transparent and fade completely. Suggested total duration **0.8–1.2 seconds**. Keep proportions and existing primitive look. Real 3D mesh descendants and individual material overrides need transparency setup (`StandardMaterial3D.transparency`, per-instance albedo alpha), not just scaling to zero; avoid modifying shared materials unintentionally. No permanent meshes, duplicate corpses, uncollected shadow/pips or resurrected living visuals.
- At most ONE death animation and ONE death cue per enemy UID. Death actors continue advancing during terminal victory and GAME OVER states as needed; `LaneActor._process` must still call visual sync/cleanup and advance death VFX when the combat model stops. Do not update logical movement/allow extra attacks after terminal.
- **Include all enemy-removal pathways:** ordinary tier-1/2 projectile kills, tier-3 mass wipe (including both adjacent lanes), and emergency defender discharge. Emergency clearing does not currently emit `enemy_killed`, and `total_killed` has meaning distinct from `total_emergency_cleared`; introduce an explicit visual/neutralization signal or equivalent to animate each removed UID while preserving both accounting categories and encounter progress. Don't animate live enemies as dead during a breach or simple knockdown.
- At tier-3 group clears and emergency wipes, several simultaneous enemies can die: VFX should remain efficient (primitive meshes/no per-frame particle physics), and audio polyphony should be controlled so overlapping deaths don't blast the listener or steal critical victory/defeat cues.

## B. Enemy death SFX

- Extend existing synthesized PCM cue system in `scripts/audio/sfx_manager.gd` with `enemy_death`: short satisfying hit/explosion/pop/crunch (approximately 0.25–0.45 s), distinct from `attack`, `knockdown`, and `match`; bounded PCM peak and envelope, avoid clipping. Maintain mute, voice pool, restart and active-count behavior; no external audio asset required.
- Route death events through a single unambiguous path (`LaneActor` → `Battlefield` → `Main` or direct `LaneCombatModel` signal forwarding), so each UID gets exactly one death SFX request. The final kill SFX MUST be allowed to play before gameplay audio is disabled. For multi-kills, consider volume scaling/concurrency limiter while leaving per-UID event/counter audit possible; don't skip ordinary single kills.
- Test actual SFX clip duration/peak, variant lookup, `play_counts`/`request_counts`, mute and resetting. Keep existing SFX intact.

## C. Three-second win delay

- The authoritative victory condition REMAINS: all four lane spawn quotas exhausted, no live enemies anywhere, and no concurrent terminal breach. The victory event should still be emitted ONCE as soon as final enemy is neutralized. But **Main must wait 3.0 seconds of active, deterministic game time between that terminal neutralization and the WAVE CLEARED overlay becoming visible**.
- Begin a single explicit `victory_pending`/presentation countdown of 3.0 s on receipt of `Battlefield.encounter_cleared`. Immediately lock normal gameplay for the pending interval: no shooting/swapping, no chain motion, no new combat/projectiles/enemy spawns, no score changes, no new loss after victory was confirmed. The background can remain visually displayed; do NOT draw the WAVE CLEARED overlay at start.
- Allow live SceneTree visual processing of defeat sparks/corpses through the entire 3-second interval, even though combat model updates are frozen. The last death body must fully fall and fade **before** the WAVE CLEARED overlay arrives, so no standing enemies remain on victory screen.
- At countdown expiry, display the existing `WAVE CLEARED` with final score and `RESTART [R]`. Treat `_victory` and `_game_over` semantics carefully: existing logic/tests use them to freeze game; a distinct `_victory_pending` state may be necessary for UI timing. Avoid toggling gameplay audio disabled before the last `enemy_death` plays; stop gameplay audio only when safe, not prematurely.
- If final neutralization comes from a tier-3 two-lane wipe or emergency discharge, require all visual removals for THAT event to have been scheduled **before** (or independently of) countdown/overlay; ensure no race where last enemy visual is left standing. A previous death VFX can run concurrently with new combat, but terminal freeze must not interrupt its cleanup.
- **Defeat always takes priority if a breach and final elimination occur in the same simulation step**, per P015. GAME OVER should remain immediate with no 3-second wait; do not accidentally show WAVE CLEARED three seconds after a defeat. If any plausible loss arrives while victory pending, cancel the pending timer and route to GAME OVER, unless the authoritative model has already irrevocably won: document precedence consistently.
- Restart from either terminal state resets countdown, death actors/VFX, overlays, audio, enemy quotas (8/lane = 32), HUD, chain and pending shots. No stale delayed callbacks, double victory overlays, duplicate SFX, zombie corpse nodes or old timer firing after restart. Prefer a delta-driven timer/state machine over a detached `await create_timer(3.0)` that could fire post-restart.
- Optional subtle "wave cleared" transition cue at t=3 is fine, but the user's two requested features come first. Do not introduce new screens, tween library/dependencies, or unrelated changes.

## D. Mandatory regressions

Create `tests/p018_enemy_death_victory_delay_test.gd`:
1. Single projectile kill removes logical enemy immediately yet preserves visual as a death actor. In successive frames: explosion exists; root rotates ~horizontal, lowers to ground, alpha becomes <1 and fades to 0; after <=1.2s old live visual and corpse/shadow/sparks are fully cleaned, with no extra live enemy meshes.
2. Emergency clear and tier-3 two-adjacent-lane wipe each produce exactly one death animation/sound event for EVERY removed UID (with correct lane/x), without altering `total_killed`, `total_emergency_cleared`, and progress semantics.
3. Kill the last scheduled enemy (while all four quotas spent). Confirm authoritative victory event count exactly one, `Main` immediately freezes shooting/chain/combat; WAVE CLEARED overlay **INVISIBLE** at t=0, 1.0, 2.9s; VFX still advance and fully clean despite terminal model state; overlay visible by t=3.0s with correct final score, title and restart. (Use deterministic direct `_process` calls with caveat that actual child cosmetic processing runs through SceneTree; do not double-tick animation.)
4. Last enemy dies by projectile, tier-3, and emergency separately. Event order: death VFX and audible cue scheduled before any audio block and before the delayed overlay. No duplicate win or death events on concurrent same-frame clears.
5. A breach/terminal loss must still show GAME OVER immediately; victory delay never produces a false win. Check reentrant events / one event per enemy UID.
6. Restart during pending interval (through code or restart API, even if UI button is not shown) must cancel countdown; restart after WAVE CLEARED must reset all visuals and audio, not leave stale timers. No shooting or chain advance during pending interval.
7. Verify F3 chain invariant `I0`, untouched 102 px/s source speed, P017 offscreen-left original UID reentry, shot timing, 0.05s settle and normal four-lane enemy encounter.
8. Run full P001–P017 suites (update P015 and any other direct victory-overlay-immediate expectations to match exactly 3s presentation delay but preserve immediate authoritative victory); add P018. Godot headless start bounded at 960x540, 1280x720, 1600x720 and 2400x1080; `git diff --check`, no exports claimed unless actually run.

## Manual QA checklist

1. Play until enemy HP drops to zero: hear distinct pop/explosion; enemy visibly tumbles SIDEWAYS/HORIZONTALLY and fades; no stand-still vanishing and no standing ghost.
2. Use tier-3 and emergency clear to defeat many enemies: each removed body dies correctly; no audio overload.
3. Final enemy dies -> battlefield remains visible **for exactly 3 seconds**, showing death VFX, no WAVE CLEARED UI. Then show WAVE CLEARED with correct score, no enemies/corpses left.
4. Let a remaining enemy breach: immediate GAME OVER remains; restarting clears corpse/VFX/audio.
5. Recheck left offscreen ball rollback, 102 px/s chain, touch controls, right-edge entry and win/defeat.

## Handoff and finish

Update `README.md` to document enemy death animation/cue and 3s win-delay. Update `.ai/CODEX_HANDOFF.md` with exact root cause, signal/event-order design, commands/test counts, manual QA and unverified device/export details. **Commit and push `master`, then STOP.** Do not change ChatGPT-owned `.ai/TASK.md`, `.ai/TASK_LEDGER.md`, `.ai/DECISIONS.md`, `.ai/PROTOCOL.md`, and do not self-activate P019.
