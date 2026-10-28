# Ball Battalion — Product Direction and Development Roadmap

**Written:** 2026-10-27  
**Status:** P034A/B/C implemented, Web CI green; user likes the new 2D/crystal visuals. **P033 `294ddae` and corrected shader-free P033R `f08ee3d` IMPLEMENTED, technically reviewed PASS**; includes mobile/desktop controls, halved enemy HP and red hit feedback; **P028A/P028AR completed and technically reviewed** (`6564001` / `78b535b`); **P028B-EXP and P028B-EXPR COMPLETE** (`ca73b4b` / `0f15616`); **mild-only P028B Web playtest LIVE** (`7f2d096`, CI `40598952476`), no active Codex task; further tuning / P029–P032 NOT ACTIVE; Android physical QA pending.  
**Repository/project:** `Shikirashi/lane-ball-shooter`, historically named *Lane Ball Shooter*.  
**Authoritative implementation status:** Consult `.ai/TASK.md`, `.ai/DECISIONS.md`, `.ai/CODEX_HANDOFF.md`, the source and current tests before making code changes.

> **User-confirmed decision:** The game's intended public name is **Ball Battalion**. The old *Lane Ball Shooter* repo/project name remains in place for now. **Do not automatically rename paths, packages, Godot identifiers, URLs, APK signing identity, deployed assets or existing releases.** Plan and test a deliberate branding migration when appropriate.
>
> Most of this document records **proposals, not permission to implement them**. P034B was authorized and implemented in `b802096`, with actual 2D live gameplay screenshots committed for SSH review; that narrow follow-up P034C has been **implemented and technically reviewed**; **P033 is now the single active Codex task**. User playtest feedback and Android QA remain pending. All other phases are NOT active.

## 1. Product concept

A small, complete, replayable, mobile-friendly Web/Android arcade game combining:
- A horizontally flowing, Zuma-like **2D colored ball chain** and bottom shooter.
- Four fixed **3D defender lanes**, each corresponding to a ball color.
- Matches that make the corresponding defender attack approaching enemies.
- Tactical urgency, readable enemy identities, satisfying match/cascade feedback, quick finite encounters, and replayable level progression.

The game is already meaningfully playable; **polish and progression should take precedence over inventing a new core loop**. Asset cost should remain near zero through existing primitive 3D meshes, procedural SFX, UI drawing and selectively hand-made lightweight art.

### Current rules/constraints worth preserving

Cross-check details against code and the canonical `.ai/DECISIONS.md`; this is a summary, not a replacement:
- Four shared teams: RED/dot, BLUE/square, YELLOW/triangle, GREEN/diamond, via `scripts/team_data.gd`.
- Shooter magazine uses a four-color shuffled bag (`scripts/magazine_state.gd`); loaded + next can be swapped.
- Top-chain **fresh feeder** uses weighted same-color runs, allowing lengths 1–7 and long pre-existing sequences. Player insertion is required to initiate matching; noncausal spawns/joins must **not** clear automatically.
- Match size increases **score**, not direct attack damage/tier. Consecutive matches within the combo window advance attack tiers/FEVER; retain the existing distinction.
- The offscreen-left balls persist as physical chain members; rollback is causal and must not be replaced by teleporting/discarding them. Conveyor speed currently 102 px/s, shot travel around 0.20s.
- Enemy roster: Hopper, Heavy, Sickle Snake, Healyzard. Current finite baseline: **8 scheduled enemies per lane, 32 total**, with victory and game-over handling.
- Global Sickle Snake maximum one alive; 15-second cooldown after neutralization; on nonfatal hit it pauses and can change to an adjacent lane. Healyzards heal eligible same-lane units on their *existing* implemented interval; don't silently rewrite enemy behavior.
- The project targets Godot 4.7.2, Compatibility renderer, responsive 16:9 landscape Web + Android. P027 Android APK exists but **physical phone QA remained pending** at last handoff.
- No external asset/network dependency is required for gameplay. Retain reproducible deterministic/headless regression tests.

## 2. Name, voice and mascot

### Locked name

**BALL BATTALION** — preferred/final public-facing game title per user's instruction. Avoid re-opening the earlier name brainstorm (Marblefront, Ball Battalion, Marble Mayday, etc.) unless the user explicitly requests it.

Possible tagline, **not final**: **"Match the balls. Command the battalion."**

**Batta + lion** is the proposed core pun: Japanese `バッタ` (`batta`) commonly means grasshopper and can include locust; `BattaLion` reads close to *battalion*. Treat *BattaLion* as an **optional mascot name/stylization**, NOT a replacement game title.

### Mascot explorations (all concepts, none approved as final art)

1. **Preferred exploration: BattaLion hybrid.** A small, friendly, highly readable grasshopper/locust–lion with big jumping hind legs, round fluffy lion mane, short antennae, a compact body, expressive face, and possibly a ball/tuft-shaped tail. Its silhouette should work in tiny icons and short UI celebrations.
2. **Alternative: Batta + Lion duo.** A grasshopper recruit and lion commander. Easier to distinguish as two characters but more characters/assets to maintain.
3. **Minimal emblem:** A round mane/circular ball with tiny antennae and jumping legs; suitable as a logo/icon before any full mascot model exists.

Art direction: colorful, charming, playful/tactically urgent, readable on phones, not grim military realism. Try rough sketches/primitive mockups before committing to elaborate modeling. A celebratory mascot can appear on the title screen, victory screen, level milestones, and store artwork without new gameplay systems.

**Potential conflict to resolve:** The game already has a hostile enemy called *Hopper*. A friendly grasshopper-like mascot must be unmistakably distinct (e.g. mane, friendly eyes, uniform/banner, different silhouette and color arrangement), not mistaken for the enemy. Do not replace team colors/symbols or existing defenders with the mascot.

Before publishing publicly, perform a store/title/trademark/visual-similarity check. Title availability is NOT verified by this document.

## 3. P028 — Color distribution audit and targeted fix (FIRST priority)

### Why the apparent green shortage is plausible, but not yet confirmed

The user reports **GREEN seems to appear least often** during play. Do not assume this means a green bias in the source RNG; inspect the actual distribution at the point the player sees it.

Verified in `scripts/chain_model.gd` and `scripts/magazine_state.gd`:
- **Magazine:** each fresh four-color bag contains one of each team identity; thus generated ammo is exactly balanced by four draws, but shorter sequences and what happens after swap/shoot can look different.
- **Fresh chain feeder:** uses a shuffled bag containing one of each *run color*, with **run-length weights** `[20, 30, 18, 13, 9, 6, 4]` (lengths 1–7). So each four-run cycle balances **run count**, not **ball count**: one color may be assigned length 1 while another gets length 7. A short segment can be substantially imbalanced, even when long-run expectation is similar.
- **Fixed seeds:** current chain and magazine generators start with fixed default seeds for reproducibility. New games can repeat the same sequence, making perceived biases recurring. There is also a fixed starting pattern containing four GREEN balls, so the initial pattern by itself is not evidence of green suppression.
- **Existing P008 test:** checks reproducibility, run distribution and all four colors in a sequence of 1,200 plus a maximum-minus-minimum tolerance of fewer than 100 generated balls. That does **not** guarantee fairness in a typical short encounter or among visible/available/matchable balls.
- Visibility also depends on the conveyor's physical state, matches, offscreen retention, and rates of entry/exit. Observed green scarcity may be in the **visible chain**, even if fresh-generation totals are balanced.

### Diagnostic phase, BEFORE modifying randomness

Add bounded, deterministic instrumentation/tests to distinguish:
1. **Fresh chain generated** per color (total, per 25/50/100-ball window, and seed).
2. **Visible chain** per color sampled over game time, and **match opportunities** per color (e.g. adjacent compatible groups).
3. **Magazine generated/loaded/fired** per color; account for swap and player action.
4. **Matches by color** and enemy pressure by lane to catch gameplay-driven unevenness.
5. **Starvation:** maximum number of generated balls and longest elapsed gameplay time between usable appearances of each color.
6. Seed sensitivity: representative runs and **hundreds of deterministic seeds**; record mean, worst windows, tails, not just one 1,200-ball pass.

Keep diagnostics optional/off in normal play, reusable by headless tests. Provide a short audit report identifying whether there is a *generator* bias, a *window variance* problem, a *perceived visibility* problem, or an interaction with actual gameplay.

### Candidate correction (only if audit supports it)

Favor balancing **ball counts in recent windows**, not only number of runs. Possible implementation: select the next run color using deficit from a rolling target after accounting for prospective run length; apply caps/soft weighting rather than hard forced sequences. Explore bounded drought protection and avoiding absurdly long absence for a defender in peril. Preserve: four colors, color/symbol mapping, same-color runs up to seven, pre-existing groups that never auto-pop, finite game fairness, offscreen physics, magazine swap behavior.

Do **not** simply raise GREEN's base probability until the cause is established. Do **not** make magazine colors perfectly track currently matchable chain colors without explicit design approval; that changes game difficulty.

**Acceptance proposal:** reproducible before/after distribution tables, per-color drought metrics and seed sweeps, all existing P001–P023 regression tests passing, no changed chain physics or match semantics, and manual playtest explicitly answering "does green still feel scarce?" Numeric fairness tolerances must be agreed after viewing baseline data, not invented here.

## 4. P029 — Data-driven level framework

Current gameplay has a fixed finite encounter. Generalize to a `LevelDefinition`/data asset (JSON or Godot Resources; choose deliberately) that can define at least:
- Stable level ID/order and display label.
- Initial enemy counts, total budgets and per-lane allocation.
- Enemy type eligibility/weights or an authored schedule.
- Spawn pace/interval and optional archetype modifiers.
- Level and generation seeds, with deterministic retries.
- Victory/failure criteria **without** breaking the existing finite encounter.
- Optional level-specific instruction/title and score thresholds.

Keep old 32-enemy encounter as a selectable regression/baseline level. Don't retune global enemy logic by accident. Add save data (completed/unlocked levels, best score/medals if adopted) with versioning and safe handling of missing or obsolete level IDs. Changes must be testable headlessly.

Enemy restrictions stay authoritative across levels: global single Snake, cooldown, transfer, Healyzard healing, max five live enemies per lane, and lane/slot spawn limits. A level cannot silently request a configuration that deadlocks or violates enemy rules.

**Acceptance proposal:** at least three hand-specified distinct levels load, finish, retry deterministically, unlock/save/reload, and preserve old baseline combat tests.

## 5. P030 — Generator + difficulty system, without 100 handmade levels

**Goal:** Build a repeatable, tunable library of good encounters, not 100 random piles of enemies. Use **curated early levels** to teach mechanics and **seeded generated later levels** for inexpensive scale.

First illustrative ten levels — **subject to actual playtest**:

| Level | Intent | Suggested introduction (NOT implemented) |
|---|---|---|
| 1 | Learn aim/match/defender response | 4 Hoppers |
| 2 | Learn all lanes | 8 Hoppers |
| 3 | Learn chains/large matches | 12 Hoppers |
| 4 | Tank prioritization | Hoppers + 2 Heavies |
| 5 | First mixed check | About 16 enemies |
| 6 | Adjacent-lane mobility | Hoppers + 1 Sickle Snake |
| 7 | Cross-lane pressure | About 20 mixed enemies |
| 8 | Support target priority | Hoppers + 1 Healyzard |
| 9 | Combine abilities | About 24 mixed |
| 10 | First gauntlet | About 32 mixed |

Do not assume player skill or survivability at these counts. The player has already encountered all archetypes in the current prototype; this sequence describes a **proposed onboarding campaign**, not a claim about the existing game.

Campaign scaling proposal: **levels 1–10 tutorial/onboarding; 11–30 curated combinations; 31–100 generated with review; every tenth level a memorable milestone.** Launch target is **30 polished levels**, expand toward 100 based on reception; "hundreds" is a possible future content scale, not a current deliverable.

Suggested generator architecture:
- Hand-authored **encounter archetypes**: Heavy Assault, Snake Rush, Healer Escort, Staggered Waves, Mixed Gauntlet.
- Budget-based composition choosing totals, pressure/timing, lane asymmetry, special enemies and limited combinations. Avoid crude perpetual HP inflation; keep baseline enemy identities meaningful.
- Deterministic seed derived from stable `level_id + campaign_version`, not from changing real-world time.
- Validation for enemy cap/cooldown, spawn and lane constraints, finite completion, reasonable clear durations, and excessive pressure.
- Simulation/stress tests can flag pathological spawn states, but cannot alone prove levels are *fun* or possible for real players; require playtesting and progression telemetry.

**Acceptance proposal:** reproducible generated schedule for each level seed, validation tools, representative difficulty curves and human review of key generated levels; new generator does not secretly alter combat/chain fundamentals.

## 6. P031 — Campaign player flow

- Main menu and level selection that remains responsive in Web/Android landscape.
- Completed/unlocked indicators, current level, **NEXT LEVEL**, retry, pause and restart flow.
- Best score and optional three-star result if thresholds can be fair and clearly explained; stars are a **proposal**, not a settled rule.
- Save progress locally, no account/network requirement; consider reset/backup and future compatibility.
- Keep each session compact; don't make the player grind an extremely lengthy level merely to advance.

Avoid massive progression/permanent upgrade trees in the first commercial release. Optional endless survival/challenge mode could reuse the level framework **after** the curated campaign works.

## 7. P032 — Presentation, QA, release polish

Prioritize:
- Chain readability and color/symbol accessibility; mobile legibility with several enemies active.
- Audio mix, shot impact and matches, defender attacks, enemy death, win/fail overlays and satisfying yet brief transitions.
- Title/start screen branded **Ball Battalion**, mascot/logo only once an approved design exists.
- Real Android landscape testing: installing the existing signed APK, touch-to-aim-and-release, swap hitbox, mute/audio, resolution/safe areas/notches, pause/background/resume, heat/performance and restart.
- Web release check and CI compatibility; current Web pipeline exists. Don't presume Android APK auto-updates or portfolio cards follow a rename.
- Iterative real-player tests of first-time comprehension, win/loss rates and where players quit.
- Update app name, splash art, export/package metadata, portfolio and releases **only as an explicitly scoped follow-up**, preserving keystore/signing identity and compatibility/upgrades where possible.

## 8. Business and production constraints

- The user considered switching to Roblox and lacks a budget for cosmetics/assets; existing playable Godot project is a smaller execution risk than building an unrelated game. This does **not** guarantee revenue.
- Target a polished, distinctive compact casual game with primitive/procedural assets. Resist adding new enemy types, a sprawling cosmetics economy, or monetization until first-level engagement and replayability have been validated.
- Distribution, pricing, ads/IAP and Roblox port are **not decided**. No dark-pattern monetization implied. Monetization research can follow an actual audience.
- We should not buy/commission large art assets merely to test an early build. Mascot experiments can start with simple vectors/primitives; refine only if it improves recognition.

## 9. Proposed task order and non-goals

| Proposed task | Status | Main deliverable |
|---|---|---|
| LBS-P028 | **PROPOSED — NOT ACTIVE** | Color audit, causal diagnosis, targeted fairness fix with seed tests |
| LBS-P029 | **PROPOSED — NOT ACTIVE** | Data-driven level definitions, deterministic encounters, persistent progression foundation |
| LBS-P030 | **PROPOSED — NOT ACTIVE** | Level archetypes, budget generator, difficulty validation, first curated stages |
| LBS-P031 | **PROPOSED — NOT ACTIVE** | Level-select/next/retry/save/result UI; optional medals |
| LBS-P032 | **PROPOSED — NOT ACTIVE** | Branding/mascot experiment and polish; actual mobile/Web acceptance testing |

All five are proposals requiring separately scoped authorization. **Do not activate all five at once.** Actual tasks might need to be split further for review, especially fairness audit vs fix, and level framework vs persistence.

### Immediate next move when user asks to continue

1. **Preserve current no-active-task state** until the user starts a new task.
2. Review the current tree/tests, especially `scripts/chain_model.gd`, `scripts/magazine_state.gd`, `tests/p008_gamefeel_sfx_test.gd`, and `.ai/DECISIONS.md`.
3. Draft one narrow P028 task: instrument/report distribution **before** redesigning the generator. Use fixed seeds and explain green visibility vs actual generation. Obtain explicit approval for tuning before modifying gameplay rules.
4. Maintain the user-confirmed **Ball Battalion** name and retain exploratory **BattaLion** mascot concept. Avoid silent package/URL renames.

## 10. Decisions vs open questions

**Decided by the user**
- Public-facing name: **Ball Battalion**.
- Continue improving the existing Lane Ball Shooter project rather than restart from scratch.
- Color distribution (especially green) deserves attention.
- Explore the *batta + lion* Japanese wordplay for a mascot/theme.

**Recommendations; user has not signed off implementation details**
- P028–P032 sequencing, exact fairness algorithm/tolerances and random-seed policy.
- 30 curated launch levels / eventual 100 generated levels, ten-level teaching example and milestone cadence.
- Saved progression format, stars and optional endless mode.
- Mascot hybrid vs duo vs emblem, character design, placement, tagline.
- Monetization, app-store launch, platform-specific renames.

### Sources checked 2026-10-27
- Repository current source: `scripts/chain_model.gd`, `scripts/magazine_state.gd`, `scripts/team_data.gd`, `README.md`, `tests/p008_gamefeel_sfx_test.gd`, `.ai/CODEX_HANDOFF.md`.
- Japanese `バッタ` dictionary sense: https://dictionary.cambridge.org/ja/dictionary/japanese-english/%E3%83%90%E3%83%83%E3%82%BF .

## 11. 2026-10-27 addendum — P033 controls and P034 staged 2D presentation

P034A was implemented in `5dbd708`, CI `40544273523` SUCCESS, and technically reviewed. User chose to proceed directly to P034B despite being remote over SSH and unable to inspect the animated Godot preview. **P034B is implemented (technical review passed)**; P028/P033 remain proposed, not active.

- **P033 — mobile/desktop controls (proposed, NOT ACTIVE):** Android Classic direct drag/release with second-finger swap; move shooter up for a comfortable bottom finger space; change ammo preview to horizontal (large loaded ball centered on shooter, small NEXT beside it with edge-safe placement); hide original Android swap button. Android Side mode: 1:2:1 horizontal split with one 25% edge acting as relative laptop-style trackpad, opposite 25% edge split vertically (top=swap tap, bottom=shoot tap), mirrored for selected handedness, remembered settings. Desktop/Web left-click to shoot and right-click to swap across the non-interactive gameplay canvas including conveyor, with real UI buttons preserving input precedence.
- **P034A — visual baking proof of concept (IMPLEMENTED; user visual QA pending):** render the real procedurally constructed Godot 3D actor meshes (four enemies + four colored defenders) into genuine transparent PNGs with orthographic camera/lighting; add reproducible baker, contact sheet and isolated 2D preview with goofy squash/stretch. Do NOT change the playable game, camera, combat, input, platform builds, balance or old 3D scene yet. Archived task: `.ai/TASKS/LBS-P034A.md`.
- **P034B — runtime 2D migration (IMPLEMENTED: `.ai/TASKS/LBS-P034B.md`):** use genuine P034A sprites to replace all live 3D presentation with 2D rendered lane floors, defenders, enemies, projectiles, shadows and cartoon effects while keeping authoritative combat and spawn logic. Fit top/bottom rows to current conveyor and shooter layout, respecting future P033 adjustments; 4–7% side margins, not 25% blank columns. Preserve P001–P023 and P034A regression coverage. **Remote QA delivered:** actual Godot-rendered full-game screenshots at 1280x720 and 1600x720 are committed, reviewed; Web CI fully SUCCESS, hands-on motion/device acceptance pending. Do not implement P033/P028 or modify already published Android identity.

## 12. P034C — Charge-crystal visual revision (IMPLEMENTED, 2026-10-27)

User wants no strange yellow sphere in the defender art: **remove old 3D `ChargeOrb` from `ActorVisualFactory`; rebake genuine Godot transparent defender PNGs**, retaining all other source model details. Add **separate 2D faceted diamond crystals**, each matching its defender's lane color, positioned visibly behind and slightly rearward of the character. When `LaneCombatModel.emergency_discharged` occurs, crystal breaks into several spinning/fading shards, then disappears. Charge does **not** replenish on defender revival; only restart restores the intact crystal. Never dim entire defender to represent spent charge; keep status `CHARGE`/`SPENT`.

P034C delivered genuine re-baked PNGs, state/shatter **real Godot-rendered gameplay screenshots** and passing full local regression and successful Web CI/publication (`40555144242`). Source/asset review pass, human visual QA pending. Archive: `.ai/TASKS/LBS-P034C.md`. P033/P028 not active; no Android release changes.

## 13. P033 approved — thumb-friendly touch / full-canvas desktop + modest easing (ACTIVE, 2026-10-27)

The user approves **P033** after liking the P034C crystal visual result but finding gameplay too difficult. They explicitly requested *both* the HP halving and strong Minecraft-style enemy red hit feedback **folded into P033**, rather than separate tasks. Authoritative scope: `.ai/TASK.md`.

- **HP:** Hopper 6→**3**, Heavy 12→**6**, Sickle Snake 6→**3**, Healyzard 6→**3**. Old P022 HP values superseded, but all projectile and enemy abilities, damage, time and spawn rules unchanged. Healer +1/15s still capped to new max.
- **Hit readability:** existing 0.16s `hit_flash` must produce bright obvious red tint on ALL four enemies, including the originally green Healyzard and yellow Sickle Snake. Lethal hits flash into death tumble/fade, no global shared sprite tint.
- **Classic on Android:** primary touch anywhere on noninteractive canvas aims with absolute X; primary release shoots, second finger down swaps once without firing or stealing primary. Hide old dedicated swap button on Android.
- **Side on Android:** 1:2:1 horizontal zones, one quarter as **relative movement trackpad**, opposite quarter vertically split upper swap/lower shoot, center 50% remains visuals. User can choose left/right handed mapping. Save settings; trackpad release must not fire.
- **Shooter/magazine:** raise shooter ~80–100 reference logical px at 1280×720 for thumb clearance, preserve 2D row framing; main ammo stays larger and centered on shooter, next is smaller and alongside, flips edge-safe if needed.
- **Desktop/Web:** left-click to shoot anywhere except genuinely interactive UI, including conveyor; right click anywhere noninteractive swaps. A minimal settings gear/panel must not forward clicks to gameplay.
- **Testing:** full regression + proper HP/assertion updates, simulated touch IDs, actual gameplay screenshot capture for SSH review, CI Web build/auto-publish. Android release still historical v0.1.0; no signed APK update or signing-key operations in P033.

**P028A automated balancing laboratory remains NOT ACTIVE.** No chain/run weights, feed speed, magazine, enemy spawn probability/frequency, level campaign, branding or APK release change is authorized by P033.

## 14. P033R — damage-shader review correction (ACTIVE, 2026-10-27)

P033 was pushed as `294ddae` with Android Classic/Side controls, raised horizontal magazine, 3/6/3/3 HP, and strong red hit shader. Source and real P033 screenshot review detected **a shader defect**: in Godot 4 CanvasItem fragment code, `COLOR` already includes `TEXTURE`, so `texture(TEXTURE, UV) * COLOR` incorrectly squares color and alpha of undamaged enemy sprites. Correct the shader to use already-textured `COLOR`, maintain vivid per-hit red and lethal flash, and add real-rendered pixel comparison tests and refreshed screenshots. **P033R delivered as `f08ee3d`, reviewed PASS; no active Codex task.** P028A remains proposed; do not alter controls, HP, game data, branding or releases in P033R.

## 15. P033R visual approach revised (ACTIVE, 2026-10-27)

User chose **shader-free solid-red silhouette overlay** in place of the earlier proposed red-color shader correction. Generate derivative 2D red mask textures from the exact alpha of all four existing enemy PNGs; add an aligned red `Sprite2D` overlay to live enemy actors; show it on real damage, fade over 0.16s, support lethal corpse animation, Snake transfers, and preserve unhit original image unchanged. Remove P033's flawed shader entirely and verify alpha/brightness through actual Godot rendering and per-pixel mask tests. Only this P033R is active in `.ai/TASK.md`; the prior P033R shader-fix instructions and historical P033 shader decisions are superseded. All controls and enemy HP 3/6/3/3 stay as delivered; P028A remains inactive.

## 16. P033R accepted and P028A next proposed (2026-10-27)

P033R's four exact-alpha red silhouette sprites were implemented as `f08ee3d` with shader removal, 0.16s hit/death feedback, original colors, and Godot-rendered before/after previews. Review found no blocker; Codex reports 28 full suites PASS. **No active task.** P028A deterministic balancing laboratory remains proposed and awaits authorization, while native Android touch/visual QA is pending. Scope history archived in `.ai/TASKS/LBS-P033R.md`.

## 17. P028A audit approved — instrument first, balance second (2026-10-27)

After reviewing the corrected P033R visual results, the user said to continue. **P028A is the ONE ACTIVE CODEX TASK**: build/execute a repeatable Godot 4.7.2 headless balancing laboratory using actual production chain, magazine, match progression, spawn director/combat models where applicable. It must produce fresh/color/run/rolling-window droughts, *visible* chain availability (without mistaking offscreen retained balls for usable ones), matchable ammo and scripted action results, lane danger, per-seed statistics, JSON/CSV and a human-readable causal report. Use deterministic 500-ish generator seeds and a bounded practical subset of real gameplay scenarios, with performance and policy limitations reported honestly. P028A is **analysis only**.

For experiments only (not production): current conveyor 102px/s vs 120/140/160; original run weights `[20,30,18,13,9,6,4]` vs hypothetical `[12,30,40,10,5,2,1]`. Threat-aware next-run color bias is a FUTURE hypothesis: log time-to-danger/defensive starvation but do NOT ship a dynamic assistance algorithm now. Current enemy HP 3/6/3/3, physics, shooter, red hit feedback, emergency crystals, and source art remain unchanged.

On handoff, inspect real data and jointly decide narrow **P028B** adjustments. Do not auto-activate it, P029 levels/campaign, P032 mascot/branding, or an Android APK upgrade.

## 18. P028A review correction P028AR (ACTIVE, 2026-10-27)

The initial reproducible Godot lab/500-seed report was delivered in `6564001`. GREEN generation ~25.251% and seven-ball runs ~9.43% of generated balls look valid. **However the automated player incorrectly aimed at the target ball's latest x at arrival**, while real shots hold their launch X during flight; and the chain had not yet advanced through the impact step. This biases perfect aim, human-comparison and conveyor speed sensitivity outcomes. **Only P028AR corrective task now ACTIVE**: fixed X, correct time ordering, reproducible tests and regenerate reports. No production chain speed/weights/HP/visual changes; P028B cannot be approved until corrected analysis is reviewed.

## 19. P028A / P028AR completed and reviewed (2026-10-27)

P028AR `78b535b` fixed the analysis bot's unrealistic UID-homing and impact step order: shots have immutable launch X, real `ChainModel` physics advances to impact, and authentic misses/off-target hits are counted. Reviewed corrected lab, new 38-check test, and CSV/JSON/Markdown report; Codex reports all 29 Godot test suites passing, GitHub CI `40571348733` completed SUCCESS with test/build and portfolio publication. No playable-game parameter was changed.

**Actionable data:** GREEN 25.251% of baseline-generated balls across 500 seeds, so no intrinsic Green penalty; 7-ball clusters only 4% of runs but 9.43% of emitted balls; experimental shorter-run weights substantially reduce long clusters. Two paired test cases per speed: baseline fixed-X hit rates 88.5% (102), 87.0% (120), 82.8% (140), 84.5% (160). A quicker chain supplies opportunities but makes aimed shots less reliable; automated perfect-knowledge bot still wins and cannot establish human difficulty. **P028B remains PROPOSED/INACTIVE.** Discuss whether to prioritize a smaller run-length distribution before any speed or threat-aware assistance changes; phone playtesting preferred.

## 20. P028B-EXP — Threat-aware color generation: offline experiment authorized (2026-10-27)

After corrected P028A results, user chose to **test out threat-aware generation next**, *not* ship a runtime change. The **ONE ACTIVE task** is `LBS-P028B-EXP`: opt-in, per-instance Godot simulation only. Test baseline plus three bounded strengths of priority for colors whose enemy lanes have the smallest estimated time-to-defender. Reorder **remaining legal colors in the existing four-color run bag**, preserving long-run distribution, baseline seed sequence when disabled, physics, fixed-X shot accuracy and authentic enemy pressure. Do not boost GREEN unconditionally (500-seed normal GREEN supply was 25.251%).

Benchmark over paired real-game scenarios with authentic models and useful urgent episodes, weaker deterministic bot(s) to expose starvation, synthetic pressure traces for sampling mechanics, no-threat ablation, reports of intervention counts, run-to-visibility/useful-match latency, p50/p95 starvation and potential harm to other lanes. Report all-color fairness and caveats of automated players; do not conflate a threatened color appearing in the feeder with successful defensive shots. Output `analysis/reports/p028b_exp`, test-only harness and full regressions. **No alteration to Web/Android live gameplay** and no approval for production P028B, faster feed, shorter run weights or campaign work until results reviewed.

## 21. P028B-EXPR experiment-fidelity correction (ACTIVE, 2026-10-27)

Initial experimental run `ca73b4b` delivered a Godot simulation-only adaptive color selector, 500 paired synthetic seeds and 144 combat scenarios; local 30 regression suites reportedly PASS. But review found an unwanted randomizing confound: the code checks urgency among **all four lanes**, and when a threatened color is exhausted from the current run bag, it still consumes a bias RNG roll and reshuffles remaining **unthreatened** legal colors. The `urgent_exhausted` synthetic case exhibits ~46% such interventions despite no eligible color. **P028B-EXPR is the only active Codex task**: ensure no-eligible-threat returns unchanged baseline choice/no bias RNG, separately track active threat vs eligible threat and exhausted bag, add failing-before-fix tests, regenerate/reinterpret all report artifacts under original seeds. Until then the claimed moderate improvements are provisional. No adaptive generation, speeds, shorter runs, levels or APK changes are approved for shipped gameplay.

## 22. P028B-EXPR reviewed and complete (2026-10-27)

P028B-EXPR `0f15616` removed the ineligible-world-threat confound; when no legal bag color is endangered, exactly the baseline choice is used without additional RNG. Repeated 500 synthetic seed / 144 actual-model trials, all 30 local suites (574 targeted assertions) and GitHub test/build/publication `40580387509` PASS. Report `analysis/reports/p028b_exp/REPORT.md`; archive `.ai/TASKS/LBS-P028B-EXPR.md`.

**Results:** 50,599 no-eligible `urgent_exhausted` synthetic selections, zero unnecessary interventions in each adaptive arm. Mild candidate offers limited summed mean-starvation improvement (-0.27s basic / -1.53s delayed) with some per-color losses (BLUE +0.43s basic, YELLOW +0.05s delayed). Moderate loses +0.65s aggregate under basic; strong loses +0.58s basic / +0.49s delayed. The bots still win every active-play seed; there is no support to ship any adaptive arm without human feedback.

**No Codex task active:** Future mild live A/B, refined run weights, levels and mascot require distinct user approval. Shipped four-color bag, 102 px/s speed, run weights [20,30,18,13,9,6,4], HP 3/6/3/3, control modes and Android v0.1.0 identity unchanged.

## 23. P028B-SHIP-MILD — user-approved Web playtest live (2026-10-27)

At the user's direct request ("enable it on mild setting, deploy, and let me playtest"), ChatGPT connected the existing corrected research `ThreatRunSelector("mild")` to actual `Main` and live `Battlefield` time-to-danger. Run selection uses a +50% maximum relative preference **only for still-legal threatened colors**, respects the existing once-each four-run color bag, preserves baseline no-eligible fallback without RNG draws and repeats, and recreates seeded controller on restart. Additional live integration regression added. Source `7f2d096`; GitHub build-and-publish `40598952476` complete SUCCESS, public Web https://shikirashi.github.io/lane-ball-shooter/ verified.

**Only mild live, as provisional feedback experiment**. Baseline 102 px/s feed, original 1–7 weights, HP 3/6/3/3, game controls and graphics unchanged. Previous Android v0.1.0 APK not rebuilt. Offline experiment remains mixed: mild reduced total bot starvation in paired research but worsened specific colors, and bot win rates are not predictive of phone players. Collect human feedback on responsiveness and whether other colors feel delayed before wider balancing, levels, mascot, renaming or Android release. No active Codex task now.

## 24. Mild-bias human playtest: terminal overlay render-order fix (2026-10-27)

User tried the live mild-color version and judged difficulty **fairer with a mix of hard/easy encounters**. Screenshot showed charge crystals, sprites and an active green projectile undimmed/in front of `WAVE CLEARED` and Restart; user confirmed enemies/projectiles affected too. Root cause was terminal overlay z0 below positive-z 2D actor/effect layers and settings z100. Fixed terminal `GameOverOverlay` at **absolute z200**, over all 2D content, with regression asserting real projectile/crystal and modal hierarchy. Code `91d0712`, test `dc16d93`, CI `40601383350` fully SUCCESS including public publication/browser verification. User visual confirmation still pending. **Mild threat-aware generation remains on** at 102px/s with original weights; no further balancing or campaign work activated.

## 25. P035 Android v0.2.0 signed release + portfolio download refresh (ACTIVE, 2026-10-28 WIB)

User approved the mild threat-aware Web playtest and confirmed the end-screen z-index layering fix, then requested updated Android APK available from the portfolio. **Only active Codex task P035**: take exact current game source and existing protected v0.1 signing key, bump Android code 1→2/name 0.1.0→0.2.0, rebuild clean ARM64 release, verify signer certificate unchanged, manifest/version/permissions/nondebuggable, test all regression suites. Publish new verified GitHub Release tag `android-v0.2.0` and actual `lane-ball-shooter-android.apk` asset; leave v0.1.0 intact. Portfolio already has ONE Mobile download card pointing to `android-v0.1.0`; update its link rather than creating a duplicate; preserve nine-file live Web game, other cards, CSS/JS, and validate Pages/public download. Existing Android SDK/JDK/export templates/keystore created during P027; no key regeneration or secret exposure. Android physical-device acceptance pending unless actually authorized/connected; no Play Store work. Scope and exit gate in `.ai/TASK.md`. No further mild/speed/run-length tuning, levels, campaign, branding or Android app rename authorized.

## 26. P035 Android v0.2.0 and portfolio release complete (2026-10-28 WIB)

P035 finished successfully: non-debug same-signed ARM64 app v0.2.0/code2 `com.shikirashi.laneballshooter`, source/tag `3d08d8e`; public release `android-v0.2.0`, asset SHA256 `d207eda8e5d7a011c9acb7bbf4d81a37238bf9e4b301d4007e6ce6f551f569aa`, 27,472,312 bytes. Existing signing identity preserved (Codex checked against v0.1). P027 v0.1 remains available. Portfolio existing card updated to new download URL/version with exactly two changed lines in commit `f951986`, successful Pages `40605307320`; Web CI `40604815821` SUCCESS. 31 regression suites and APK static checks passed in Codex handoff; release metadata/tag/hash and portfolio diff reviewed. Scope archived `.ai/TASKS/LBS-P035.md`. **No active Codex task.** User must physically install/upgrade and test native Android touch modes, layout, sound and device performance before accepting Android UX. Later levels/branding/other balancing await a new user request.

## 27. Requested minimal black/white shared UI + Android native menus + v0.3.0 update (2026-10-28 WIB)

User requested full removal of navy/purple UI chrome in Web and Android in favor of mostly **WHITE on BLACK** with only semantic accents (four team/ball colors, FEVER/COMBO, dangerous hit effects). Android must show a native **PLAY / CONTROLS MAIN MENU** first and have a true PAUSE MENU. The control picker needs an **actual-game screenshot** illustrating CLASSIC with two fingers (bottom shooter aim/release and second middle-left tap-to-swap) and SIDE with accurately mapped **SLIDE, SHOOT, SWAP** regions respecting handedness. Active scheme is a **raised rounded white-bordered card**, inactive is **plain white text on black**, saved in shared preferences.

Sequenced without overlap: **P036 ACTIVE** — shared palette and Web/gameplay UI chrome plus actual Godot screenshots and CI, task `.ai/TASK.md`; **P037 QUEUED** — Android native main/pause/screenshots guide `.ai/TASKS/LBS-P037.md`; **P038 QUEUED** — after P037, same-signed v0.3.0/code3 downloadable Android APK and portfolio existing card upgrade `.ai/TASKS/LBS-P038.md`. Only ChatGPT activates queued tasks following each reviewed push. Native v0.2.0 remains available; Web currently works and its fullscreen prompt must stay intact. Do not alter mild bias, feed/run-length weights, HP3/6/3/3, all-2D sprites, or protected signing. Further game levels, new name/mascot not yet active.

## 28. P036 theme implemented + deployed; P037 Android menus/guide activated (2026-10-28 WIB)

P036 `0e656e9`, verification `14707d3` COMPLETE. Shared monochrome `UiPalette` covers Web boot, prompt, main gameplay/HUD/controls/lanes/conveyor and topmost win/lose; four ball/team colors, FEVER/COMBO and red hit silhouette remain semantic. Seven actual Godot Compatibility-renderer screenshots committed. Dedicated palette tests 75 PASS, all 32 suites PASS. Game Web CI `40646655273` and Pages `40646877117` SUCCESS, public Web playable. Codex reported inspecting seven images; ChatGPT repository access couldn't decode PNG bytes, but reviewed code/tests/screenshot generator and successful CI.

**P037 is now SOLE ACTIVE Codex task**, in `.ai/TASK.md`: Android native MAIN MENU PLAY/CONTROLS, true PAUSE/RESUME/RESTART/MAIN MENU, Classic two fingertip illustration over real P036 gameplay image with exact instructional labels, Side mirrored SLIDE/SHOOT/SWAP boxes, white-outline raised selected scheme and plain unselected text, state-safe controls/gestures, preserve Web startup. Also clean up legacy navy Godot clear color if safely possible without overwriting local user `project.godot`. P038 native signed v0.3.0/portfolio link remains queued until P037 review. Android current v0.2.0 stays downloadable. No gameplay/speed/HP/run-length alteration.

## 29. P037 native Android menus accepted, P038 signed v0.3.0 activated (2026-10-28 WIB)

Codex implemented Android MAIN MENU PLAY/CONTROLS, screenshot-based Classic two-finger and mirrored Side SLIDE/SHOOT/SWAP visual guide, selected white-bordered raised mode cards, persisted preference and true paused gameplay with RESUME/CONTROLS/confirmed RESTART/MAIN MENU. Committed six real Godot renderer screenshots. P037 source `04039fc`, handoff `120413e`, focused 46 checks PASS, all 33 suites PASS, Web CI `40649322913` and Pages `40649540450` SUCCESS. Real phone QA still pending.

**P038 is NOW ONLY ACTIVE** in `.ai/TASK.md`: version code 3/name 0.3.0 same-app/same-keystore release-signed ARM64 APK, exhaustive static checks and signer continuity, GitHub Release `android-v0.3.0` with actual published APK verified, update exactly the existing portfolio Android card, preserve other cards/Web game/v0.1-v0.2 releases. Android main/pause/control pages are not yet in the downloadable APK before P038. No further gameplay/branding or Play Store tasks authorized.

## 30. P038 revision: retain user-facing Android 0.2.0; add defender-down vibration (2026-10-28 WIB)

User corrected the active release request: **DO NOT label APK 0.3.0**; keep app versionName **0.2.0** while integrating the previously accepted P036/P037 theme, native menus/control guides/pause, and one short **~160ms Android-only phone vibration on actual defender down**. New internal versionCode **3** so same-signed APK updates installed versionCode2; preserve public `android-v0.2.0` release/asset and create distinct `android-v0.2.0-r2` (Revision 2) release. After verifying public APK, point existing portfolio card to revision 2 while displaying 0.2.0. Enable `android.permission.VIBRATE` as Godot export normal permission in Debug/Release, validate manifest and event-gated haptics. No normal-hit rumble, no Web buzz. Preserve old signer/app ID and protected key/backups; no other UI/gamplay balancing changes. **Sole active P038 specification is now `.ai/TASK.md`; all previous P038 v0.3.0 language is historical and superseded.**

## 31. Android 0.2.0 revision 2 released; phone QA next (2026-10-28 WIB)

P038 revised COMPLETE. Exact source `e1cf9ef`, public tagged `android-v0.2.0-r2` with **versionName 0.2.0 retained**, internal code3 for upgrade, same app package and original protected release signer; downloadable APK **27,845,951 bytes** SHA256 `e614f9c3867bfbfa830bc4e548d48510398649ee22d6e7bbebba05c4476fc3f8`. Previous 0.2.0 and 0.1.0 assets untouched. Includes black-white theme, native PLAY/CONTROLS, illustrated Classic/Side and true Pause, plus **160ms vibration only on a defender knocked down**; VIBRATE normal Android permission, no new dangerous permissions. 34 Godot suites incl. new P038 haptics 16 checks PASS; signed release static verification and old-signer match per Codex. Web CI `40655777347` SUCCESS. Existing single portfolio APK card updated **only its URL/label** (`cc66c6f`), Pages `40656227205` SUCCESS. Archived `.ai/TASKS/LBS-P038-REVISED.md`.

**No active Codex task; phone playtest pending**: install as update over original 0.2.0/code2, check native menu/pause, Classic and mirrored Side guide, real Android Back, notch/safe areas, sound and actual one-pulse defender knockdown vibration. Future balancing, content/levels and branding require separate approval.

## 32. P039 — real Android vibration did not trigger/was not felt; strengthen and instrument (2026-10-28 WIB)

User tested public `android-v0.2.0-r2` on real phone. Native PLAY and illustrated controls are present, but **defender going DOWN (needs revival) caused NO perceived vibration**. User verified notifications do vibrate normally, confirming the motor works. Android notification and app haptic settings are not necessarily identical; do not dismiss observation or assume 160ms duration alone is responsible. P038 haptics automated tests passed but don't prove native Android output.

**P039 NOW SOLE ACTIVE** in `.ai/TASK.md`: real native haptics debugging with Android controls **TEST VIBRATION** button using same native haptic bridge as authoritative defender-down, truthful request feedback, concise logging and VIBRATE manifest verification; stronger single **500ms / 1.0** pulse per actual knockdown; new tests/safe-area screenshots. Release another user-facing **Android 0.2.0** with internal code4 as separate signed `android-v0.2.0-r3` (old v0.2, r2, v0.1 releases untouched) and update existing portfolio link only after checking public binary. No new gameplay changes; phone confirmation remains gate for claiming vibration fixed.

## 33. P039 Android 0.2.0 revision 3 diagnostic published; phone QA pending (2026-10-28 WIB)

P039 COMPLETE and technically reviewed: immutable release `android-v0.2.0-r3`, source `f64320c`, displayed Android versionName 0.2.0/internal code4, original package and protected signer retained. GitHub published APK 27,957,849 bytes, SHA256 `05a626bdcf84e02204aa1a84eb674040a31bad9d6cfc9738a5073b019a1194ad`; v0.1/v0.2/r2 assets preserved. Shared `AndroidHaptics` uses `Input.vibrate_handheld(500,1.0)` from a genuine defender-down event or explicit TEST VIBRATION in Android MAIN MENU CONTROLS and PAUSE CONTROLS, with truthful "VIBRATION REQUEST SENT" and [LBS_HAPTIC] event/native route logs. Android VIBRATE permission verified in signed APK per Codex. P039 45 checks and full 35 suites PASS, Web CI `40661052466` SUCCESS, portfolio existing APK card-only change `30382c0`, Pages `40661561997` SUCCESS.

Real phone outcome **NOT VERIFIED**; user's r2 was silent during defender DOWN despite notifications vibrating. User needs install r3 over r2, test explicit vibration button in both Controls paths and genuine defender knockdown. If button or down fails, capture `adb logcat | grep --line-buffered LBS_HAPTIC` to locate native request/event issue. ChatGPT reviewed source, release tag, GitHub digest/CI/portfolio patch; independent APK byte/signature reread unavailable, Codex verified it. P039 archive `.ai/TASKS/LBS-P039.md`. Codex mailbox **IDLE**, no next task authorized.

## 34. P040 active — enlarged touch targets, two-column Android controls and remove diagnostic haptics button (2026-10-28 WIB)

User now understands their Xiaomi/POCO system Haptic feedback toggle prevented non-notification app vibration; enabling it causes unwanted system-button haptics. **Do NOT alter or bypass the working 500ms defender-down haptic** in this task. User requested eliminating the obsolete **TEST VIBRATION** button/label in Android Main and Pause CONTROLS, enlarging thin touch control choices (target ≥64 logical px effective height, prefer 72–80) and adopting Android landscape **2-column screenshot preview LEFT, control scheme/handedness/BACK buttons RIGHT** to avoid vertical squeeze. Need readable Classic finger/swap/release and mirrored Side SLIDE/SHOOT/SWAP, preserved white rounded raised selected card/unselected plain white, safe-area/viewport resizing, side preference persistence and Android Back/pause. Current `control_guide_view.gd` is VBox with fixed 900px cap and 180x54/126x46 buttons, making scope concrete. 

**Sole active LBS-P040** in `.ai/TASK.md` includes GDScript regression updates (remove P039 assertions requiring TEST button, keep combat haptic coverage), native Godot screenshot evidence, full 35+ suites and Web test, then same-signed public Android **0.2.0** internal code5 separate immutable tag `android-v0.2.0-r4` with existing Android card updated after public release. Preserve original signer, app ID, older release artifacts, Web startup and gameplay. No further tasks authorized.
