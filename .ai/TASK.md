# Lane Ball Shooter — USER PLAYTEST AFTER P020 / NO ACTIVE CODEX TASK

**Status:** WAITING FOR USER PLAYTEST
**Branch:** `master`
**P020 implementation:** `8f37cb8932ff62412a0e86383e647bf666bd29d8` (source/handoff reviewed and accepted; graphical, audio and device QA pending). P019 roster implementation: `eb65018`.
**Workflow:** Codex STOP. No active implementation task until ChatGPT posts the next after user feedback. P001–P020 Godot 4.7.2 headless suites all reported passing by Codex, including P020 67 checks and P011 16,485 stress checks. The tests were not independently rerun here.

## Current enemy roster

- Hopper = original 2HP gray hopping model, 2 orange top horn squares PERMANENT decorative, not health bars.
- Heavy = orange wider Hopper, 4HP, 0.7x sliding.
- Sickle Snake = yellow taller Hopper, 2HP, 2x sliding, after surviving hit freezes exactly 0.5s, crosses to valid adjacent lane with 0.3s 3D visual transition and collision-safe UID remap while preserving original global spawn_id. A full destination makes it try other neighboring lane, or wait. Only ONE living Snake across all lanes, next eligible at least 15 seconds after death.
- Healyzard = green 0.7-scale Hopper at back of lane, stationary, 2HP. Every 15s each healer heals every OTHER non-Healyzard alive on its CURRENT lane +1HP up to max; no healers heal themselves/other healers. Displays yellow circular center glow with radial fade-to-transparent edges BEHIND its body on each pulse, fading within 0.85s.
- Random weighted spawn base 50% Hopper, 20% Heavy, 20% Snake, 10% Healyzard. Snake ineligibility renormalizes other weights. 8 actual spawns per lane, 32 encounter total, five live at most per lane. No HP bars on any enemy. Prior rejected assistant vector drawings are NOT to be used.
- P018 enemy death SFX + explosion/fall/fade, 3s WAVE CLEARED delay after last enemy, immediate GAME OVER and restart stay intact.
- P017 102px/s ball conveyor and original-UID physical return from OFFSCREEN LEFT after causally-created gravity gap stays intact.

## Manual visual QA

```bash
cd ~/Documents/GitHub/laneballshooter
git pull --ff-only
godot --path .
```

1. Observe visible models of all four types; ensure Hopper alone has two permanent orange horns, no HP bars, correct relative sizes/colors and sliding vs hopping.
2. Hit a Snake for 1HP: stops 0.5 seconds; smoothly transitions to valid adjacent lane over ~0.3 seconds; resumes sliding at 2x Hopper after transit. Edge lane chooses inward; another Snake cannot spawn until 15s after this one dies, not after merely being hit.
3. Kill Snake during/after transfer; no duplicate SFX/VFX, invisible lingering copies or extra quota. Confirm no adjacent lane exceeds 5 live enemies.
4. Watch Healyzard's pulse every 15 seconds; a soft YELLOW gradient circle appears BEHIND its body (not opaque or in front), expands and fades in 0.85s. A wounded Heavy/Hopper/Snake in the same lane should receive exactly 1 HP; Healyzards never heal each other or targets in other lanes.
5. Complete 32-enemy encounter; hear and see P018 death animation, wait 3s before WAVE CLEARED; GAME OVER on breach remains immediate. Restart should clean all effects. Review ball conveyor P017 LEFT reentry, fresh RIGHT feeder, shot/magazine/touch, and F3 `I0`.
6. Desktop/Web/Android perceived visuals, actual audio mix, touch and exports have NOT been tested with real devices.

## Verified source scope

P020 source, test and Codex handoff reviewed: `scripts/world/lane_combat_model.gd`, `scripts/world/battlefield.gd`, `scripts/world/lane_actor.gd`, `tests/p020_special_enemy_abilities_test.gd`. Codex reports Godot 4.7.2 headless P001–P020 PASS including P020 67 checks, `git diff --check` PASS, bounded scene starts 960x540/1280x720/1600x720/2400x1080. No independent graphical/device test was performed here.
