# Lane Ball Shooter — USER PLAYTEST AFTER P017 / NO ACTIVE CODEX TASK

**Status:** WAITING FOR USER PLAYTEST
**Branch:** `master`
**P017 implementation:** `f2fa832` (source/handoff reviewed and accepted; graphical/device acceptance still pending). All P001–P017 Godot 4.7.2 headless suites reported passing, including P017 352 checks and P011 16,485 stress assertions.
**Workflow:** Codex STOP. No active task until ChatGPT posts another based on user feedback. Historical `LBS-P...` prefix is only an internal identifier, not game branding.

## Corrected left-side behavior — essential check
- Physical chain extends into NEGATIVE X beyond the LEFT visible boundary. The SAME original UID/color/order balls remain inside authoritative rigid segments beyond x<0; they do not vanish or become a cache entry and are **never recycled through the RIGHT**.
- After a match creates a gap to their RIGHT, the unsupported left/out-of-view section accelerates RIGHT under existing virtual gravity (60 initial /900 accel /420 max), physically crosses LEFT clip and progressively becomes visible again. Unrelated matches need not summon an unrelated group; motion depends on real gap/support geometry.
- New fresh weighted balls continue to be generated from fully offscreen RIGHT at normal 102 px/s. Retained LEFT history is excluded from 24-ball active feeder cap, so the source doesn't starve.
- Player insertion pushes earlier balls LEFT by 58 px, shot travel 0.20s, settle 0.05s, cooldown 0.40s; only CAUSAL contact triggers a cascade; natural FEED contacts do not automatically pop.
- Hidden left balls cannot be hit until visible/partially visible. Conveyor-only mask clips both edges and not the settling shot / shooter UI.
- Finite enemy encounter remains 8 spawns/lane = 32; WAVE CLEARED / GAME OVER and restart are intact.

## Manual visual QA
```sh
cd ~/Documents/GitHub/laneballshooter
git pull --ff-only
godot --path .
```
1. Let a recognizable group go fully LEFT offscreen, then match a group behind/to its RIGHT to create a real gap. Watch the original group reappear gradually FROM LEFT, without teleportation, UID/order/color changes or spacing overlaps. F3: `L` retained-left count, `X` leftmost x, `A` active count, `U/G` unsupported/gaps, `V/D` gravity motion, `F` fresh, `I0` invariant.
2. Do NOT match and observe balls simply passing LEFT while new fresh balls enter RIGHT indefinitely. None of the LEFT-exited balls should be respawned on RIGHT.
3. Multiple rapid matches, cascades, insertion while group offscreen, shooter near left/right screen edge, audio and no ghost shots/ball clipping.
4. Restart clears hidden history. Win/lose freezes simulation and 32-enemy encounter behaves as before.
5. Web/Android physical visual/touch/export QA remains unverified.

## Verified scope and limitation
P017 source, new regression and Codex handoff were reviewed. Codex reports PASS on P001–P017 and bounded startup at 960x540, 1280x720, 1600x720, 2400x1080. These are Codex-reported automated results, not an independent graphical playtest. Retained-left history grows with play duration (no pruning).
