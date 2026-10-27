# Ball Battalion — Product Direction and Development Roadmap

**Written:** 2026-10-27  
**Status:** P034A and P034B implemented (P034B commit `b802096`, CI `40548949659` SUCCESS); **P034C implemented** (`16347b3`; technical review pass) for rebaked orb-free defender sprites and one-use 2D charge crystals. **No active Codex task.** Player 2D visual acceptance and Android QA pending. P028–P033 remain proposed, not active.  
**Repository/project:** `Shikirashi/lane-ball-shooter`, historically named *Lane Ball Shooter*.  
**Authoritative implementation status:** Consult `.ai/TASK.md`, `.ai/DECISIONS.md`, `.ai/CODEX_HANDOFF.md`, the source and current tests before making code changes.

> **User-confirmed decision:** The game's intended public name is **Ball Battalion**. The old *Lane Ball Shooter* repo/project name remains in place for now. **Do not automatically rename paths, packages, Godot identifiers, URLs, APK signing identity, deployed assets or existing releases.** Plan and test a deliberate branding migration when appropriate.
>
> Most of this document records **proposals, not permission to implement them**. P034B was authorized and implemented in `b802096`, with actual 2D live gameplay screenshots committed for SSH review; that narrow follow-up P034C has been **implemented and technically reviewed**; no current active task. User playtest feedback and Android QA remain pending. All other phases are NOT active.

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

P034C delivered genuine re-baked PNGs, state/shatter **real Godot-rendered gameplay screenshots** and passing full local regression. Source/asset review pass, human visual QA pending. Archive: `.ai/TASKS/LBS-P034C.md`. P033/P028 not active; no Android release changes.
