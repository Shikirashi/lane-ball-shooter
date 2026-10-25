# Lane Ball Shooter — USER PLAYTEST AFTER P016 / NO ACTIVE CODEX TASK

**Status:** WAITING FOR USER PLAYTEST
**Branch:** `master`
**P016 implementation:** `ed0b3cf` (source and handoff reviewed). All P001–P016 headless suites reported passing, including P016 72 checks and P011 16,485 stress checks. User graphical review is still required.
**Workflow:** Only ChatGPT activates future coding tasks; Codex must STOP. Historical `LBS-P...` prefix is an internal identifier, not branding.

## Implemented and pending visual check

- Conveyor SOURCE-SUPPORTED segment speed is **102 px/s** (3× previous 34). Fired shots still travel vertically in 0.20 seconds, insertion settles 0.05 seconds, shooter cooldown 0.40 seconds, and P015 unsupported-group gravity uses 60/900/420 px/s units.
- Every whole ball that exits beyond LEFT edge adds its identity ONCE to a canonical FIFO `cache`. It is automatically eligible to re-enter offscreen RIGHT without a match or manual `return_cached()`.
- The feeder prioritizes up to **three queued FIFO colors, then one new weighted fresh color**; a match's legacy `return_cached()` call cannot schedule a duplicate. The user should observe automatic re-entry even when not shooting. Existing mask and 24 auto-live ball limit remain.
- F3 diagnostics now include `Q` cache count, `P` eligible cache count, `X` total fully-left exits, `A` automatic returns admitted and `F` total fresh generated. `X = total_cache_returned + Q` should hold; `I0` expected.
- P015 infinite ball supply, virtual-gravity reconnection and player-causal-only cascade logic, plus finite 8/lane (32 total) enemy encounter and WAVE CLEARED victory, remain unchanged.
- **Accepted design trade-off:** Because every exited color is recycled forever while fresh colors are continually added, an infinite-duration run can accumulate a growing color-identity FIFO queue. Monitor memory at long durations; don't silently discard colors without authorization.

## Suggested manual playtest

```sh
cd ~/Documents/GitHub/laneballshooter
git pull --ff-only
godot --path .
```

1. Watch the top chain move at 102 px/s. Newly generated and cached balls should reveal smoothly through the right-edge clip; no sudden speed changes or overlaps.
2. **Do not shoot.** Observe several balls exit fully on the LEFT and verify their colors eventually reappear offscreen RIGHT in FIFO exit order. F3 `X` and `A` both increase; `Q/P` agree. If returns seem lost, report screenshot/video and F3 counters.
3. Fire quickly, create multiple gaps, and verify every unsupported segment still accelerates RIGHT under virtual gravity; insertion still pushes earlier balls LEFT. Cascade only after player-caused reconnection. Check F3 `I0`.
4. Complete or lose the finite encounter: 32 enemies across 4 lanes, victory `WAVE CLEARED` with score and restart, or `GAME OVER` on breach. Terminal state freezes stream; restart resets counters, FIFO, progression and enemy quotas.
5. Touch/Web/Android exports remain separately unverified; no physical-device QA was run.

## Completion summary

Codex reports all P001–P016 Godot 4.7.2 headless suites PASS, including P016 72 checks; P011 16,485 stress checks. Startup passed at 960x540, 1280x720, 1600x720 and 2400x1080. Visual acceptance of 3× speed and return timing remains outstanding.
