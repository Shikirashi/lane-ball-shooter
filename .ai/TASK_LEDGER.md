# Lane Ball Shooter — Task Ledger

Current active task is always `.ai/TASK.md`. Only ChatGPT advances this ledger after reviewing Codex's push/handoff.

| ID | Status | Goal |
|---|---|---|
| LBS-P001 | COMPLETE — accepted; code `6d22352`, handoff `b3e2a4a` | Initialize Godot project; hybrid 2D/3D screen, 4 primitive defender lanes, hopping primitive enemies, responsive HUD, shooter and magazine with synchronized swap visuals |
| LBS-P002 | COMPLETE — initial `0283c6e`, corrected `1fe4d5b`, handoff `b3cf5ed` | Moving Zuma-style 2D chain, vertical shots and insertion, ordered rollover cache/return, matching + cascades |
| LBS-P003 | ACTIVE | Scoring, combo tiers, 3-second window, fourth-match fever, magazine generation and match feedback |
| LBS-P004 | QUEUED | 3D combat projectiles, enemy HP/spawn pacing, matching attacks and lane hit detection |
| LBS-P005 | QUEUED | Defender knockdown, one-time emergency clear, two-match revival, lane breach and game-over/restart |
| LBS-P006 | QUEUED | Web/Android export configuration, mobile touch QA, layout/accessibility refinements, balancing and regression tests |

Dependency order: P001 -> P002 -> P003 -> P004 -> P005 -> P006. The user may request refinements between tasks.
