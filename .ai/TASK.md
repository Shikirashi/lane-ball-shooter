# Lane Ball Shooter — USER PLAYTEST AFTER P015 / NO ACTIVE CODEX TASK

**Status:** WAITING FOR USER PLAYTEST
**Branch:** `master`
**Implementation:** P001–P015 source/handoff reviewed. P015 implementation and handoff in `3d2623e`. Godot 4.7.2 headless suites reported passing. Graphical/mobile acceptance remains to be done.
**Historical IDs:** `LBS-P...` is only the internal task prefix, not game branding.

## Newly implemented in P015

- The rightmost/source-connected rigid segment moves LEFT at 34 px/s. Every unsupported left segment falls RIGHT under virtual gravity, accelerating 60→420 px/s (acceleration 900 px/s²); even noncausal FEED gaps eventually close. Gap metadata still determines whether an actual physical reconnection can trigger a player-caused cascade; natural 3–7+ runs never spontaneously clear.
- Fresh and cached balls still enter indefinitely from offscreen RIGHT through the conveyor-only mask. The existing P012 front-push LEFT insertion, 0.05s staged match, FIFO rollover/cache and 0.20s projectile travel remain.
- Each of four enemy lanes gets **8 total spawns**, including its initial enemy; at most 5 coexist per lane. 32 total enemies in the encounter. When all quotas are exhausted and no enemies remain, the player wins (`WAVE CLEARED`, final score, restart). Enemy breach still loses, even on a terminal race. Unlimited balls remain until win/loss.
- HUD shows enemy neutralizations out of 32. New gravity F3 diagnostics: `U` unsupported groups, `G` gap count, `V` fastest gravity speed, `D` reverse displacement, `I` geometry violations (zero expected).

## Manual playtest priorities

1. `cd ~/Documents/GitHub/laneballshooter && git pull --ff-only && godot --path .`.
2. Make several matches quickly while fresh/FIFO balls enter. Formerly stuck two-yellow/five-yellow separated groups should fall back together naturally. Watch whole-group motion, no overlap, no permanent gaps, no feeder pop-in or abrupt sprinting. F3 should remain `I0`.
3. Confirm noncausal joins of 3+ equal colors do NOT self-clear, whereas RED 2 / YELLOW 2 / RED 2 + YELLOW produces yellow x3 after 50 ms and delayed red x4 cascade after contact.
4. Verify 8 enemies maximum total lifetime spawned in each lane, 32 overall, without another spawn after quota exhausted. The 5 simultaneous cap is independent. Kill/clear all to see WAVE CLEARED, final score and RESTART; verify all state resets. Confirm a terminal breach still shows GAME OVER.
5. Check the effect of gravity when a separated fresh or FIFO batch joins the existing stream; flag any unexpected jerks/whole-train reversal near the right edge. Shooter preview, swap, SFX and four colored lanes should remain usable.
6. Web/Android export artifacts, physical touch, audio and performance QA are still pending actual toolchains/devices.

## QA scope

Codex reports all P001–P015 Godot headless suites PASS, including P015's 587 checks and P011's 16,493 stress assertions, plus 960×540, 1280×720, 1600×720, 2400×1080 bounded startup. Source/handoff reviewed; not independently executed as a graphical app.

**Codex: STOP.** No active coding task. Don't invent P016, change historical IDs or self-advance the ledger. Wait for ChatGPT to post a user-requested follow-up based on actual playtest.
