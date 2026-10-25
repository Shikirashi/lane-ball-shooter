# Lane Ball Shooter — PLAYTEST AFTER P010 / NO ACTIVE CODEX TASK

**Status:** WAITING FOR USER PLAYTEST
**Branch:** `master`
**Completed implementation:** P001–P010 source-reviewed, including P010 staged cascades (code `891ad0d`, handoff `80020c0`).
**Historical task prefix:** `LBS` is an internal historical ID only, NOT a confirmed game title/brand. Keep old IDs intact for traceability; future prefixes/name can be chosen with the user.

## What to test next
1. `cd ~/Documents/GitHub/laneballshooter && git pull --ff-only && godot --path .`.
2. Arrange RED RED / YELLOW YELLOW / RED RED and fire YELLOW. It visibly inserts; waits **0.05s**; yellows pop; left red pair accelerates backward together; four reds pop ONLY after physical contact, with separate sounds/score/defender attacks.
3. Try 4–7+ natural runs, varied color endpoints, a second shot during rollback, FIFO cache reentry, multiple cascades, fever, knockdown/revival, breach/restart and SFX/mute.
4. Report actual gamefeel and visual defects. No subsequent implementation task is authorized yet.

## Locked balance
- Top conveyor `34 px/s`.
- Player shot time to conveyor `0.20s`, cooldown `0.4s`.
- Enemy average speed `0.24 world units/s` via airborne hops only.
- Chain insertion settle `0.05s`; rollback motor initial `60 px/s`, acceleration `900 px/s²`, cap `420 px/s`.
- Right-edge perpetual weighted same-color fresh runs, FIFO cached returns, color/shape IDs, tier-1/2/3 attacks, revival, survival and procedural SFX.

## Codex instructions
**STOP.** Do not self-start another task or rename old task IDs. ChatGPT will post a focused task based on the next user playtest.

## QA scope
Codex reports P001–P010 headless suites passing, including P010 190 checks and bounded startup at three landscape sizes. Graphical hands-on playtest and Web/Android artifacts/audio hardware QA remain pending.
