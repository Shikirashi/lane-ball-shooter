# LBS-P028AR — Completed fixed-X projectile simulation correction

**Implementation commit:** `78b535bf104f0f701f37c5480e0c0d2770495de0` (2026-10-27). **Technical review:** PASS by ChatGPT after inspecting `BalanceLab.advance_chain_with_fixed_shot`, scenario integration, fixed-X/moving-target tests, and regenerated 500-seed/25-scenario data. **CI:** https://github.com/Shikirashi/lane-ball-shooter/actions/runs/40571348733 — subsequently completed SUCCESS, including test/build and portfolio publication; Codex reports all 29 local suites PASS and 38 dedicated P028A test assertions. Do not claim complete CI/deploy success until verified.

**Corrected report:** `analysis/reports/p028a/REPORT.md`; machine-readable `baseline.json`, `comparison.csv`, `scenario_summary.csv` (schema 2). Fixed launch X and impact after chain advancement replace invalid UID-homing. For standard basic-matcher baseline: 148 arrivals, 128 successful insertions (86.5% hit), 20 misses; generated GREEN 25.251%, length-7 runs 4% of runs/9.43% of generated balls. In two-seed speed sensitivity, baseline fixed-X hit rates for 102/120/140/160 px/s: 88.5%/87.0%/82.8%/84.5%; **not** a substitute for human phone testing. No change to shipped settings.

**Remaining QA:** GitHub CI final conclusion, native Android playtests, human feel at candidate speeds and run weights. **P028B is NOT ACTIVE**; no production balance change has been approved.

---

## Original P028AR task and preceding P028A task scope (historical)

# ACTIVE CODEX CORRECTION — LBS-P028AR: Remove simulated homing shots; rerun P028A analysis

**Status:** ACTIVE — technical review of P028A implementation `6564001acfc2bea58c327bbe874553c0e347a73c` found a material simulation-fidelity defect (2026-10-27). Only this correction, test/report regeneration and handoff are authorized. **DO NOT activate P028B gameplay tuning**, change any production game balance, or implement unrelated roadmap tasks.

## Confirmed discrepancy (must fix)

The **real** `ShooterView.launch()` in `scripts/ui/shooter_view.gd` stores a fixed launch X (the shooter position) in `shot.start`; during its 0.20-second flight, `shot.position.x` remains exactly `start.x`. On arrival, `main.gd` calls `ChainModel.try_insert_shot(identity, screen_x - chain_view.position.x)` at **that fixed X**, with current physical chain collisions.

But the P028A simulator in `scripts/analysis/balance_lab.gd` currently records `pending_shot = {identity, target_uid, remaining}` and **at shot impact** calls `chain._ball_index_by_uid(target_uid)` and `impact = target.display_x - 1.0` to determine contact. This is an impossible **mid-flight homing/target teleport**: the bot's horizontal shot axis moves to track whichever ball it targeted. It biases hit rate and makes speed comparisons especially overoptimistic. The P028A report's **500-seed generation counts/run distribution remain valid**, but 25 small live-simulation cases and the report's speed/usable-policy conclusions need regeneration/qualification.

## Required correction

1. **Fixed-X shots:** At the moment a named policy chooses to fire, resolve **one immutable horizontal shot X** in chain-local coordinates, store it on `pending_shot` with identity and 0.20-second remaining flight. At impact, use ONLY that stored X in the actual `ChainModel.try_insert_shot()`; never seek target UID/x again. A `target_uid` may remain purely for reporting identity and whether the originally aimed ball drifted, but may NOT affect the projectile trajectory, hit decision or impact_x. Do not silently snap to the nearest ball by UID or telekinetically swap target location. Respect gameplay shot cooldown (0.4s), real collision radius, color loaded/next and actual match progression.
2. **Choose aiming policy explicitly:** The basic bot can aim at the target ball's *current x at launch* or use a clearly documented **one-time predictive lead** from current chain speed and known 0.2-second travel, e.g. `aim_x = target_x - chain.speed * SHOT_FLIGHT_TIME`, clamped to the actual shooter's reachable chain-local X range if available. **Either is acceptable as long as no aim changes mid-flight.** Ideally compare a naïve current-X bot versus idealized fixed-lead bot to characterize player reaction/accuracy without pretending humans have perfect anticipation; optional if bounded. Avoid using future simulation/next RNG state to select X. A real prediction may miss due to gravity rollback; record that rather than correcting midflight. Name policy and limitations in report.
3. **Correct time sequencing:** Advance the chain to shot arrival **before** resolving the shot at that time slice, or precisely split the timestep at projectile impact so a shot with remaining 0.05s within a 0.1s step impacts after physical chain movement of 0.05s. Current simulator processes insertion **before** `chain.advance(dt)`, producing stale-space timing. Preserve legitimate insertion settling, match event handling and authoritative enemy/chain state updates; keep fixed simulation step and report any frame discretization.
4. **Tests:** Update/add focused `tests/p028a_balance_lab_test.gd` assertions proving (a) shot launch X stays constant even if the target moves/matches/leaves screen, (b) collisions/misses are determined exclusively by actual chain state at that immutable X, (c) no free matches/HP damage, (d) cooldown/flight survive different `--step` values; (e) seeded full scenarios remain reproducible. Add a deliberately moving target fixture that **fails with previous homing behavior**. Do not weaken existing 29-suites regression or P008 test. Verify original 500-seed GREEN generation shares and baseline run-length histogram are unchanged.
5. **Rerun authentic reports:** `./scripts/analyze_balance.sh --smoke`, full documented 500-seed/25-scenario run and a second deterministic run, `./scripts/ci/run_regression_tests.sh`, Web validation as appropriate. **Replace** `analysis/reports/p028a/REPORT.md`, `baseline.json`, `scenario_summary.csv` and `comparison.csv` with corrected measured results. Document actual misses, nonmatched insertions, bot optimism/limitations and changed win rates, speed effect on true fixed shot x, seed counts, runtime. Avoid stale 'every bot wins' or success assertions from old data. A true baseline vs experiment comparison must use comparable seeds and **same fixed-X rules**.
6. **Interpretation safeguards:** Make it explicit that adjacent pairs are only *potential* opportunities, not guaranteed real shot/match success; GREEN generator percentages do not prove human usefulness. Do not recommend live feed acceleration solely because a bot with predictive fixed aim scores more: higher speed also tightens human touch aiming. If the already-too-perfect bot still wins 100% at current HP 3/6/3/3, report this and reserve tuning decisions for a future human playtest. Compare metrics with sample size caveat (two scenario seeds per speed/weights cell).
7. **Safety:** `ChainModel` optional per-instance run weights seam is already introduced; do not modify production defaults (`DEFAULT_SPEED = 102`, `FRESH_RUN_LENGTH_WEIGHTS = [20,30,18,13,9,6,4]`), colors, HP 3/6/3/3, full gameplay, spawning, animations, touch controls, assets, Android APK signing or release version. Avoid destructive Git operations or touching user-local uncommitted project/scene files. No sudo/GUI automation/deployment edits. Codex owns harness/tests/report/README/`.ai/CODEX_HANDOFF.md`; DO NOT edit ChatGPT-owned `AGENTS.md`, `.ai/TASK.md`, `.ai/TASK_LEDGER.md`, `.ai/DECISIONS.md`, `.ai/BALL_BATTALION_ROADMAP.md` or `.ai/PROTOCOL.md`.
8. **Finish:** Update handoff with precise correction, actual Godot version/test commands, new comparison table and fidelity limits; commit and push implementation/results to `master`, then **STOP**. The user/ChatGPT will review the rerun before closing P028A or authorizing any P028B.

---

## Original P028A request (implemented in `6564001`; HISTORICAL except above correction)

# ACTIVE CODEX TASK — LBS-P028A: Deterministic gameplay balancing laboratory (AUDIT ONLY)

**Status:** ACTIVE — user approved continuing to the next previously proposed phase on 2026-10-27, after P033/P033R review. This is the **ONLY** active task. Build and execute a reproducible Godot-driven experimental analysis; **do not change the shipped game's balance**, turn on threat-aware generation, implement P028B tuning, or advance to P029–P032.

## Motivation / questions

The player observed perceived GREEN scarcity and frustrating availability of matching colors, even though the magazine uses four-color bags and the chain feeder shuffles one of each run color per bag. The player also wants to explore:
- Current run lengths 1–7 with weights `[20,30,18,13,9,6,4]` seemingly create too many massive clusters; hypothesis that **length 3 common, length 5 rare, length 7 very rare** feels better (example **experimental only** weights `[12,30,40,10,5,2,1]`).
- Experiment with faster conveyor (current **102 px/s**, candidate 120, 140, 160), knowing balls physically exit LEFT and offscreen-left history is retained, not teleported.
- Future very subtle color preference for lanes with the most urgent enemies, based on **time-to-danger/defender** rather than simple distance, but avoid guaranteed helpful ammo or removing challenge. This is P028B design territory, NOT approved for runtime yet.
- Enemy pressure after P033 HP reduction: **Hopper=3, Heavy=6, Sickle Snake=3, Healyzard=3**. Actual spawn weights / Snake cooldown, healer pulse and attack rules must be reflected in analysis.

**Question:** When does the player actually lack a visible, matchable, usable color for a threatened lane, why does it happen, and how sensitive is this to runs, conveyor throughput, and strategies?

## Authoritative baseline / prerequisites

Read `AGENTS.md`, `.ai/PROTOCOL.md`, `.ai/DECISIONS.md`, `.ai/TASK_LEDGER.md`, `.ai/BALL_BATTALION_ROADMAP.md`, current `.ai/TASK.md`, and `.ai/CODEX_HANDOFF.md` before editing. Inspect:
- `scripts/chain_model.gd`: `SEED_PATTERN` (12 original starter balls), `fresh_identity_counts` vs `total_fresh_generated`, 4-color run bag, `FRESH_RUN_LENGTH_WEIGHTS`, `_draw_fresh_identity()`, per-step physics, visible balls `balls`, `event_log`, insertion and matching, off-left physically retained history, `set_fresh_seed()`.
- `scripts/magazine_state.gd`: independent 4-ball shuffle bag; `draw_count`, `generated_history`, swap behavior, `consume_loaded()`.
- `scripts/match_progression.gd`: 3-ball matches, combo/tier and real attack dispatch.
- `scripts/world/lane_combat_model.gd`, `scripts/world/battlefield.gd`: global finite spawn director, individual enemy times/HP, Snake uniqueness/stun/transfer, Healyzard pulse, breach, victory, projectile swept collision, random seeds (`set_attack_rng_seed`, `set_spawn_rng_seed`, `set_snake_direction_rng_seed`), virtual time order.
- `scripts/main.gd`: real event ordering and shot travel latency/cooldown; `tests/p008_gamefeel_sfx_test.gd`, P011 stress, P019/P020/P022, P033/P033R and full regression script.

Historical stale text in `.ai/DECISIONS.md` may mention a 3D live battlefield or legacy FIFO cache; newest P017–P034 and actual code supersede it. **Do not accidentally reintroduce FIFO recycling, off-left removal, artificial old-state autopops, or spawn rule changes.**

## Required deliverables

### 1. Noninteractive Godot 4.7.2 CLI balancing harness

Add `scripts/analysis/` and/or `tools/` GDScript entrypoints plus shell wrapper `scripts/analyze_balance.sh`, providing documented bounded options: `--smoke`, `--seeds N`, `--seed-start N`, `--duration S`, `--step S`, `--output path`, and clear scenario/policy selection. Parse safely in a Godot `--headless --script` invocation. Deterministic, repeatable with fixed seed tuples; no rendering, SFX, display/GUI, Web publishing, Android tooling or network required.

Prefer using **actual production `ChainModel`, `MagazineState`, `MatchProgression`, `LaneCombatModel` and the authentic global `Battlefield` director**. The Battlefield is a `Control` but should run with Godot's headless renderer and no screenshots; if instantiating it in `SceneTree` for simulation, avoid visual per-frame overhead and unintended double `_process`. Simulate logical time deliberately with explicit update ordering matching production as closely as possible, and document fidelity exceptions. Do NOT write a Python or GDScript mathematical lookalike as the **authoritative** gameplay simulator. Do not create a second, divergent implementation of enemy spawning or physical gap/match handling. If extracting a pure shared gameplay director is truly necessary, minimize refactor and prove existing behavior unchanged; prefer read-only harness access first.

**Bounded workloads:** default generator-only deterministic sweep with ~**500** diverse seeds, e.g. 200–400 incoming balls per seed, affordable on local dev/CI; separately ~**20–30** real physical/gameplay scenario seeds of ~90–180 simulated seconds max, with explicit `--smoke` running <=3 scenario seeds, ≤30 seconds per case and tight test runtime. Adjust full default count down only if measured performance demands it; honestly record count. Fail cleanly on time/step limits. Avoid unbounded model history or multi-minute per-seed runs; sample in bounded intervals and trim *analysis-only* logs rather than mutating authoritative offscreen history.

### 2. Measurement layers — carefully distinguished

Collect per color (TeamData RED/BLUE/YELLOW/GREEN) and per deterministic seed:
- **Starting preset colors vs freshly feeder-generated** counts/percentages separately. `total_fresh_generated` includes the seed pattern; `fresh_identity_counts` counts only actual weighted-run generator calls. Include direct run-color frequency, run-length histogram, generated-ball totals and 25/50/100 incoming-ball rolling-window imbalances, worst windows, p50/p95/drought streaks in number of *freshly generated balls*.
- **Actually visible physical balls** on the upper conveyor: classify `ChainModel.balls` by x and radius relative to current `lane_width`, with left/right clipped states reported separately (off-left history remains real). Time-weighted visible counts/coverage, longest simulated time with no visible instance per color, newly entering colors; distinguish per-time occupancy from incoming generator frequencies, and **do not count invisible physical history as available**.
- **Match opportunities:** per color count/report exact adjacent same-color pairs/groups and, when feasible, a **realistic shot insertion opportunity** using actual `ChainModel.try_insert_shot()` with a *cloned simulation state or non-mutating exact matching geometry* (document precise definition). **Never conflate** presence of 3+ preexisting balls with an automatically popped match: live rules require player insertion. Include loaded/next magazine availability and cooldown/travel time when classifying a *usable* response. If perfect opportunity classification is not feasible in P028A, report explicitly separate lower/upper-bound proxies and label them **proxies**, not guaranteed matches.
- **Magazine:** generated colors, currently loaded/next, actual **fired** colors, swap count and per-color firing opportunities; never equate bag generation to shots or shot hits.
- **Combat:** real enemy spawning by type/lane, currently threatening lane(s), enemy distance/speed and time-to-defender estimates (caveat Hopper jumps, Snake transfer/stun and stationary healer). Record count/time below multiple urgency thresholds, damage dealt, kills, healer pulses, emergency discharges, defender knockdowns/revivals/breaches, finite win/loss/timeout outcomes and enemy survival pressure, match attacks by color/tier, and starved threatened lanes.
- **Starvation:** fresh-ball drought, empty visible-color interval, missing *actual achievable* matchable opportunity interval and missed defense window due to ammo/chain mismatch are distinct statistics. Report worst per-seed and percentile spread with reasons. Include Green vs other three comparison to diagnose the original anecdote.

### 3. Clearly limited automated player policies

Provide reproducible, **named** policies:
- `observe_only`: NO shots or swaps; isolates chain and enemy arrival/visual supply. This is not a gameplay performance baseline (losing is expected).
- At least one **bounded plausible scripted play** policy (`basic_matcher`) that respects input cooldown **0.4s**, projectile flight time **0.20s**, magazine loading/swapping and real chain insertion/matching. Use a deterministic rational choice of matching shot placements based on visible collision geometry rather than inventing automatic attacks. It may be imperfect: document heuristics, response time and expected misses. Where meaningful report missed shot and nonmatched insertions as well as match events.
- Ideally a second policy `threat_priority` or `best_case_matcher` that prefers colors whose lanes face near-term danger. Only include if it can be implemented without changing production rule code; make it explicit that bots do NOT predict human behavior, and do not optimize for a misleading 100% win rate. If expensive, deliver robust observe-only and basic matcher first, list others as later extensions.
- All attacks must be consequences of actual chain matching feeding `MatchProgression.register_match` and real `Battlefield.handle_match`; NO fake free player matches and NO arbitrary model HP deductions to make metrics attractive. For every scripted scenario, report if it uses complete combat or a narrower causal baseline.

### 4. Test-only scenario / candidate probes, ZERO shipped balance change

Produce a baseline comparison and **isolated test-only what-if** probes, with paired seeds and equivalent policy/encounter schedules wherever feasible:
- Conveyor speed **102** (production), **120**, **140**, **160** px/s, one at a time. Modifying only a harness-owned `ChainModel.speed` is permitted and not a production default change.
- Original chain weights **[20,30,18,13,9,6,4]** vs proposed exploratory **[12,30,40,10,5,2,1]**, focusing on **3 common / 5 rare / 7 very rare**, while keeping 1/2/4/6 lengths available. A sandbox-only injectable per-instance weights parameter or a derived test-time generator component may be used if it preserves exact production baseline and exposes a clear proof the default is unchanged. Avoid hardcoding alternate global weights or modifying shipping generator RNG sequence. If legitimate weighted override cannot be safely done during P028A, report baseline run histogram and record alternate weights as a structured P028B experiment **without falsifying a simulated result**.
- **Threat-aware color bias remains an unimplemented concept** for P028B. P028A may measure threat/availability correlation and propose a bounded candidate algorithm/cap in the report, but **DO NOT implement a threat-sensitive feeder in production or pretend it is simulated using independent random numbers with different behavior**. Future fairness vs rescue/tension trade-off must be evaluated separately.

Maintain exact production colors/symbol mappings, current four-enemy mix, current HP **3/6/3/3**, 15s Snake death cooldown, 15s Healyzard heal, default magazine shuffled bag, run starter preset, tier damage and original 102px/s baseline.

### 5. Reproducible results and actionable conclusion

Commit to `analysis/reports/p028a/` (or similarly named location):
- Human-readable `README.md` or `REPORT.md` with **explicit seeds, scenario counts, time horizons, simulated policy, authentic engine version, step size and limitations**, definitions of each metric, result tables for 4 colors, run lengths, longest drought and p50/p95/worst seeded samples; comparative short-window Green metrics; graph(s) optional if actual numbers support them.
- `baseline.json`, `scenario_summary.csv` and `comparison.csv` (or equivalent portable machine-readable generated outputs), with a **stable documented schema** and a reproducible command; no huge committed per-frame time-series. Include paths/seed provenance and at least one worked worst-seed trace summarizing why a threatened defender lacked response (ammo, match geometry, or truly absent color).
- Conclude separately: (1) whether GREEN is statistically disadvantaged by generation, by visible occupancy, or by actual play; (2) current 7-run share **of runs** vs **of generated balls**; (3) whether 120/140px/s appears worth phone testing; (4) what experiments should go into **P028B**, and explicit metrics/reason for trade-offs. Don't declare player difficulty solved by bot win rate alone; note Android device playtest still pending. No made-up precision or invented victory outcomes.

### 6. Determinism, regression, and guardrails

- Add `tests/p028a_balance_lab_test.gd` with deterministic seed reproducibility, sample report schema, sane counts and conservation across starting/generated/visible/fired definitions, same-seed identical results, different-seed diversity, short window/drought measurement with known handcrafted sequences, time-to-danger conditions for Hopper/Snake/Healer, no fake match action, and default production constants untouched.
- Run `./scripts/ci/run_regression_tests.sh` (currently 28 Godot suites), `./scripts/ci/validate_web_release.sh` as appropriate without requiring Web builds because no gameplay/build files should change, and `./scripts/analyze_balance.sh --smoke` plus bounded representative full report generation. Document performance/runtime/seed counts from actual measurements. Keep CI fast enough for ordinary publishing.
- Read-only telemetry or dependency injection into models is okay **only if production behavior and defaults stay byte-for-byte equivalent for the same seed**, with regression tests proving that. Avoid mutating a singleton/constant to run alternate scenarios; avoid adding in-game menus/debug overlays or platform permissions; absolutely no balancing tweak sneaking into main builds.
- Preserve the P017 physics: balls physically exit LEFT, offscreen history remains, causal gravity rollback and pre-existing groups never auto-pop. No live generator/run weights/speed/seed changes; no automatic helpful colors, spawn frequency or HP changes.
- Protect user uncommitted `project.godot`, `scenes/main.tscn`, local generated UIDs, root-owned keystore/backup, P024 portfolio publisher, latest Android v0.1.0 signing identity. No force push/reset, mass cleanup, sudo, GUI automation, system install or secret handling.
- Codex implementation may edit source/testing, report, `README.md` and `.ai/CODEX_HANDOFF.md`; **MUST NOT** edit ChatGPT-owned `AGENTS.md`, `.ai/TASK.md`, `.ai/TASK_LEDGER.md`, `.ai/DECISIONS.md`, `.ai/PROTOCOL.md` or roadmap. Use existing Godot user-local toolchain.
- Commit/push verifiable generated tools/tests/reports with the handoff marking **COMPLETE/PARTIAL/BLOCKED honestly**, including exact CLI repro commands, seed count, Godot version, code/logic changes, reports, tests, the least representative cases and known simulation fidelity limits. **STOP after P028A; do NOT implement P028B or activate P029+**.

## Exit gate

P028A is successful when Codex has built and **executed** actual Godot-based baseline instrumentation, real seed sweeps and a usable causal report that can inform user decisions on speed/run-length/threat-aware fairness without changing production balance. If deep battle simulation proves too expensive, prioritize **valid truthful incoming/visible/magazine measures and a bounded real-model scripted encounter** rather than inventing statistics or claiming full gameplay when policies are only proxies.

