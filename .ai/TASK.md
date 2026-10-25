# Lane Ball Shooter — USER PLAYTEST AFTER P013 / NO ACTIVE CODEX TASK

**Status:** WAITING FOR USER PLAYTEST
**Branch:** `master`
**Accepted implementation:** P001–P013 source/handoff reviewed. P013 implementation `11816ab`, handoff `0ebdd23`. All automated suites reportedly passing. This is NOT a completed graphical/mobile playtest.

## Check next
Pull `master` and run the project locally:
```sh
cd ~/Documents/GitHub/laneballshooter
git pull --ff-only
godot --path .
```

- At left/right shooter extremes verify loaded ball and small NEXT ball below it; swapping via the circular upper-right touch target exchanges both without shooting and does not obstruct gameplay.
- Watch the right edge: fresh and cached balls should travel in from **fully outside** the lane, revealed progressively by the conveyor-only rectangular clip mask; nothing should pop on at once.
- Check a ball in flight and a 50ms settling inserted ball remain unmasked, then switch once to clipped conveyor artwork after settlement, without ghost/duplicate/blink.
- Stress rapid consecutive matches, FIFO returns, late feeder admission and accelerating rigid rollback; watch for overlapping sprites (F3: zero invariant violations), chain jitter or input failure.
- Recheck locked settings: 34 px/s conveyor, 0.20s fired-ball flight, 0.05s insertion settle, 0.24 world units/s enemy hops, P012 push-left insert, combo/fever and SFX.
- Web/Android real exports/touch/audio checks still pending configured platform toolchains.

## Codex rule
No active implementation task. Do not self-start P014, change historical `LBS` IDs or modify task ledger. Wait for ChatGPT to post user-requested changes.

## Reported validation
Codex reports all P001–P013 suites passing (P013 50 checks), with P011's 16,258-check stress and headless startups at 960x540, 1280x720, 1600x720 and 2400x1080. This is source/handoff review, NOT graphical acceptance.
