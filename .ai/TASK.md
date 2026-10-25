# Lane Ball Shooter — USER PLAYTEST AFTER P014 / NO ACTIVE CODEX TASK

**Status:** WAITING FOR USER PLAYTEST
**Branch:** `master`
**P014:** Source/handoff reviewed and accepted; implementation `589846c`, handoff `441bdf3`.

## User playtest

Pull master and run:
```sh
cd ~/Documents/GitHub/laneballshooter
git pull --ff-only
godot --path .
```

- After middle match, observe FRONT/LEFT surviving segment accelerating RIGHT as one rigid group toward the gap, while RIGHT/rear group only moves LEFT at normal 34 px/s.
- Incoming fresh and FIFO balls enter smoothly from offscreen right, with **NO** 34→154 px/s speed burst upon becoming visible. Check whether the absence of FEED catch-up leaves noticeable long-term separated groups.
- F3 diagnostics: `MC` active causal motor count, `MF0` no accelerated feed motor, `R` positive reverse movement during rollback, `I0` zero geometry invariant violations.
- Verify [RED RED][YELLOW YELLOW][RED RED] + yellow shot -> 50ms yellow clear -> accelerated front reds reverse -> collision -> later red x4 cascade.
- Repeat with multiple fast matches, mid-rollback shots, cached ball returns, full-width aim, shooter next-ball preview, touch swap, masked right-edge appearance, restart and SFX.
- Preserve 34 px/s conveyor, 0.20s fired shot, 0.05s insert settle, 0.24 world-units/s enemy hops, attack tiers, revival and loss.

## Codex

No active task. Do not self-advance or make speculative changes until ChatGPT posts a new user-authorized task. Historical `LBS` is only an internal prefix, not the game's name.

## Validation

Codex reports P001–P014 suites passing including P014 289 checks and P011 16,258 stress checks, plus bounded startup at 960x540, 1280x720, 1600x720 and 2400x1080. Source/handoff reviewed; hands-on graphical playtest and Web/Android exports/device QA remain pending.
