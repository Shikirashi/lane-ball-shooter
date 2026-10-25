# Lane Ball Shooter — USER PLAYTEST AFTER P018 / NO ACTIVE CODEX TASK

**Status:** WAITING FOR USER PLAYTEST
**Branch:** `master`
**P018 implementation:** `b2e91fb` (source/handoff reviewed and accepted; graphical/device QA pending). Codex reports all P001–P018 Godot 4.7.2 headless tests PASS including 41 new P018 checks and P011 16,485 stress assertions. Historic `LBS` prefix is internal task naming only.

## Newly added — final enemy death presentation

- Every enemy neutralization (standard projectile kill, tier-3 two-lane wipe or one-time emergency clear) emits a typed `enemy_neutralized(uid,x,cause)` event before victory evaluation; LaneActor transfers the existing enemy body/shadow into a temporary death actor before normal visual sync can destroy it.
- Enemy death VFX: explosion core and eight sparks, followed by original enemy tipping sideways to about 85 degrees and fading with shadow/helmet/eyes/pips. Cosmetic actors clean up after 1.0 second, and continue updating after the combat model freezes. No longer leave defeated enemy meshes frozen under WAVE CLEARED.
- Synthesized `enemy_death` sound (~0.38s pop/crunch) plays on each removal via existing voice pool, retaining mute and restart.
- Authoritative victory still occurs immediately when all 32 scheduled enemy spawns are resolved and zero live enemies remain. Main immediately locks controls/chain/enemy logic while allowing enemy-death cosmetics and sound to continue. **WAVE CLEARED + final score + RESTART appear 3.0 seconds AFTER the last kill**, not immediately.
- GAME OVER on breach remains immediate; restarting during the pending 3s countdown cancels it and clears all death VFX/SFX and old corpse meshes. Defeat takes priority during authoritative evaluation.

## Manual playtest priorities
```sh
cd ~/Documents/GitHub/laneballshooter
git pull --ff-only
godot --path .
```
1. Kill a single enemy; verify **actual 3D enemy body** explodes briefly, falls sideways to horizontal then fades, accompanied by a distinctive short death sound; nothing remains standing or frozen.
2. Tier-3 mass kill and emergency defender clear: all removed enemies have individual death animations/cues without excessive sound density or lag.
3. Last (32nd) enemy neutralized: enemy death VFX completes, normal gameplay freezes immediately, **no WAVE CLEARED overlay for 3s**; after 3.0s reveal WAVE CLEARED with correct final score and restart, no standing defeated enemies.
4. Separately trigger a real breach; GAME OVER still immediate. Test restart after victory and defeat (and via debug/code during pending victory) to ensure no delayed ghost overlay or effects.
5. P017 physical LEFT offscreen continuation/reentry under gravity, 102px/s conveyor, 0.05s shot match settle, mobile/web landscape remain unaffected.

## QA scope and caveats
Codex reports Godot headless PASS on P001–P018 and bounded startup at 960x540,1280x720,1600x720,2400x1080. Source/handoff reviewed, but neither local graphical/audio nor Android/Web export has been independently performed; actual perceived visuals/sound still require user playtesting.

**Codex: STOP.** No active new task. Do not self-advance P019. Only ChatGPT posts future task when user requests.
