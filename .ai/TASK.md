# LBS-UI-001 — Hide visible defender charge/status labels

**Branch-local active task: `ui/lbs-remove-defender-status-labels`.** This is a user-requested isolated UI fix, not the active `LBS-P040` Android release task on `master`. Do NOT replace or rewrite the production release task, its source SHA, signed APK, Web build, package settings or protected signing identity.

## User request

Remove the text near each defender, e.g. "RED ACTIVE CHARGE" and corresponding team/status variants, from **actual Ball Battalion gameplay** as well as its portfolio screenshot. Do not change lane mechanics, charge crystals, knockdown, revival or attack behavior. This is a presentation-only removal; the photo branch will be recaptured from the same UI source change.

## Implementation

- `scripts/world/lane_actor.gd` creates a `LaneStatus` label. Hide this label in the single creation path, `_build_defender`, with `_status_label.visible = false`. Keep the node and `_last_status_key` for existing `p034c_charge_crystal_test.gd` compatibility. Crucially, retain `_update_status_visual()`'s charge crystal syncing and sprite self-modulation. No gameplay scripts/match logic altered.
- Focused `tests/p041_defender_status_hidden_test.gd` asserts all four lanes hide text during initialization, re-layout, down-state and reset, while charge crystal still displays.
- On Mintbase with Godot, run `godot --headless --editor --path . --quit`, `godot --headless --path . --script res://tests/p041_defender_status_hidden_test.gd`, then `./scripts/ci/run_regression_tests.sh`. Validate a genuine renderer gameplay screenshot without LaneStatus text (the photo branch has the deterministic fixture).
- Commit/push verified branch changes only; **do not merge/cherry-pick into `master` or republish Web/APK while `LBS-P040` is in flight**. After tests pass, report exact commit and prepare for separately authorized integration to production. If anything fails, report and correct first.
- The existing approved green ball composition is unaffected except that old LaneStatus text will disappear in the newly rendered photo. Avoid retouching the PNG; it must be a real Godot capture.
