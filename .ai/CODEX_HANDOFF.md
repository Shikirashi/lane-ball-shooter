# Codex Handoff — LBS-P007

**Status:** COMPLETE

**Branch:** `master`

**Implementation commit:** `ab5359f` (`Implement P007 playtest revisions`)

**Mailbox:** remains on LBS-P007; task/ledger/decision/protocol files were not changed.

## Implemented

- Doubled `ChainModel.DEFAULT_SPEED` from 34 to 68 px/s with unchanged delta-based movement.
- Added an independent deterministic four-color shuffle-bag feeder. It admits fresh balls only into physically open right-edge slots, runs for the lifetime of the session, keeps live balls capped by `max_auto_population`, and never builds an offscreen-right node backlog.
- Preserved FIFO rollover without deletion. Match requests become pending cache-return quota; returns drain in FIFO batches as slots open, with a fresh ball scheduled between return batches so neither source starves. Legitimate unreturned exits remain linear cache storage by design. Restart clears cache, pending quota, bag state, counters and ball IDs.
- Tier 1 remains one locked 1-damage projectile against standard 2-HP enemies. Tier 2 remains a two-shot spaced burst, with each projectile locked to 2 damage at creation. Tier 3/FEVER creates no ordinary projectile.
- Centralized tier-3 resolution in `Battlefield`: the origin plus exactly one seeded-RNG-selected adjacent lane are cleared immediately, with correct edge neighbors, bounded metadata history (`origin_lane`, `adjacent_lane`, targets and actual kill count), and primitive wave feedback on both lanes. Clears do not spend emergency charges or alter defenders. DOWN-origin revival takes precedence.
- Replaced constant enemy translation/cosmetic bounce with a 0.55 s grounded dwell plus 0.75 s airborne hop. Air speed is derived so full cycles still average 0.48 world units/s. Logical X, visual height/squash/shadow and piecewise swept projectile collision share the same hop phase. Large-step defender-contact/emergency/breach ordering remains intact.
- Updated only superseded P004/P005 expectations, added `tests/p007_playtest_revision_test.gd` (49 checks), and updated README mechanics/test/playtest documentation.

## Validation

Engine: `Godot 4.7.2.stable.official.ed1daf0bf`.

- `godot --headless --path . --script res://tests/headless_smoke.gd` — P001 PASS.
- `godot --headless --path . --script res://tests/p002_logic_test.gd` — P002 PASS (59 checks).
- `godot --headless --path . --script res://tests/p003_logic_test.gd` — P003 PASS (72 checks).
- `godot --headless --path . --script res://tests/p004_combat_test.gd` — P004 PASS (42 checks).
- `godot --headless --path . --script res://tests/p005_survival_test.gd` — P005 PASS (63 checks).
- `godot --headless --path . --script res://tests/p006_platform_qa_test.gd` — P006 PASS (66 checks).
- `godot --headless --path . --script res://tests/p007_playtest_revision_test.gd` — P007 PASS (49 checks).
- `godot --headless --path . --resolution 1280x720 --quit-after 5` — exit 0.
- `godot --headless --path . --resolution 1600x720 --quit-after 5` — exit 0.
- `git diff --check` / staged diff check — PASS.

Every Godot invocation printed a non-fatal sandbox diagnostic because `user://logs` was not writable. All suites and both bounded startups returned exit 0 with no script/runtime failures. No Web/Android artifact export or physical-device playtest was repeated; P006 documented the missing templates/SDK components.

## Manual playtest

1. Watch the upper chain for several minutes: it should move at 68 px/s and keep receiving normally spaced fresh balls without becoming permanently empty. F3 shows bounded live population and FIFO cache growth.
2. Make matches while rollover cache exists. Confirm requested balls return from the right in original FIFO order while fresh balls continue to appear, with no distant-gap match.
3. Against fresh 2-HP enemies, verify tier 1 needs two hits, while either tier-2 projectile kills and the second can hit the next enemy.
4. Trigger tier 3 and FEVER from every color. Edge lanes must clear their sole neighbor; either inner neighbor may be chosen. Confirm both targeted lanes flash, other lanes remain alive, and emergency-charge indicators do not change.
5. Down a defender and produce tier-3-valued matches of its color: the first advances revival, the second revives, and neither clears enemies. The next active tier-3 match should clear normally.
6. Watch enemies pause fully on the ground, jump left, land, and pause again. Recheck first-contact emergency clear, later knockdown, terminal breach and clean restart.

## Notes / assumptions

- Right-edge scheduling uses up to the configured three-return batch followed by at least one fresh ball when both sources are pending. Simultaneous live balls are bounded; cached exits are never silently discarded and therefore use linear memory over a no-return survival run.
- Initial enemies use deterministic per-lane/per-enemy hop staggering; restart resets IDs and reproduces the initial phases. Tier-3 neighbor RNG varies in normal play and resets to its run seed on restart; tests inject explicit seeds.
- A pre-existing local `project.godot` edit was preserved and intentionally excluded from the P007 implementation commit.
