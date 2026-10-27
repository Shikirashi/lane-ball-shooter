# LBS-P033R — Solid-red enemy hit silhouettes (P033 final correction)

**Implementation:** COMPLETE — Codex commit `f08ee3df7c8952eeb284af4e43e85b1f24cdf478` (2026-10-27). Parent task P033 controls/HP completed in `294ddae627f46b7dce13f50dcd2006277776ae81`.

**Technical review:** PASS. Independently examined modified `LaneActor`, derived mask generator, full-alpha automated tests and actual Godot-rendered standard/wide/comparison captures. No blocking issue found; old shader deleted, unhit enemies render with unchanged materials, four exact-alpha red overlays fade over 0.16s, death/Snake/restart/healing all accounted for. Codex reports **28 passing regression suites**, 41 dedicated P033R checks and deterministic PNG regeneration. Web CI `40561363700` fully completed SUCCESS, including test/build, portfolio publication and public browser verification.

**Assets:** `assets/sprites/hit_masks/enemy_*_hit.png`. **Review images:** `assets/previews/p033_controls_hit_flash_1280x720.png`, `assets/previews/p033_controls_settings_1600x720.png`, `assets/previews/p033r_hit_overlay_comparison_1280x512.png`.

**Remaining QA:** hands-on Android multi-touch/Side mode, real device visuals/performance, and player feedback on difficulty. Earlier signed Android v0.1.0 APK not rebuilt by P033/P033R. P028A balancing laboratory remains a proposal; not authorized by this completion.

---

## Original P033R correction and P033 implementation scope (preserved)

# ACTIVE CODEX CORRECTION — LBS-P033R: Solid-red silhouette overlay for enemy damage (NO hit shader)

**Status:** ACTIVE — user-approved change of approach, 2026-10-27. This **supersedes the earlier P033R shader-repair instructions**. The main P033 controls/HP work is already implemented in commit `294ddae627f46b7dce13f50dcd2006277776ae81`. **Only the damage-flash visual correction and its tests/screenshots are active.** Do not start P028, P029+, new mobile functionality or APK release.

## Latest user design decision (authoritative)

> "Maybe instead of using a shader to change the colour into red, just overlay the same shape on top of the existing enemy sprite, but it's just completely all red."

**Implement exactly that, not a corrected tint shader.** Keep each original P034A Godot-baked enemy PNG and its usual `Sprite2D` rendering completely unchanged. Create an additional 2D **solid bright-red silhouette sprite** that duplicates the enemy's exact shape/alpha and lies on top of the base sprite. Show the red silhouette at full strength immediately when that enemy takes a real damaging hit; fade/remove it over the established 0.16-second hit-feedback period. It must also work on *lethal* hits through the first 0.16 seconds of the current one-second death/tumble/fade presentation. The underlying undamaged enemy sprite remains completely unmodified and therefore keeps original colors/alpha and details.

## Reason for correction

Existing P033 uses a `canvas_item` hit shader whose `texture(TEXTURE, UV) * COLOR` expression incorrectly re-applies texture/alpha, darkening **undamaged** enemies. The user chose to **eliminate that shader-based color-changing technique entirely**, not repair it. Do not add a different per-fragment shader to accomplish the red silhouette. A simple `modulate = Color.RED` of the original multicolored texture is **NOT** equivalent (multiplication cannot turn green/dark pixels bright red). We need a new red image made from the **source alpha mask**.

## Exact narrowly scoped deliverables

1. **Red silhouette textures derived from source alpha:** For each of the four `assets/sprites/baked/enemy_*.png`, generate a matching 512x512 transparent texture in which the RGB of every nontransparent pixel is solid vivid red and each pixel's alpha **exactly equals the original** (including antialiased edges). Use a documented, reproducible Godot CLI/asset-generation script that processes original `Image` alpha. Either commit four derived red-mask PNGs under a clear `assets/sprites/hit_masks/` path, or implement a genuinely shared, bounded one-time texture cache derived from the sources (not per-hit or per-enemy pixel processing). **Prefer committed derived PNGs** to avoid image-processing stalls on Android. No new 3D render, no changes to the source enemy art, no fake rectangular backgrounds, no image-gen, no third-party assets. If committing masks, include generation command in README; make rebuild deterministic.
2. **Layering and positioning:** `LaneActor._create_enemy_visual` adds a separate `Sprite2D` red-overlay above the normal enemy sprite, initially fully transparent/hidden. It must reuse the exact pivot, offset, texture scale/filtering, and parent transforms of the existing actor so that hopping, Heavy movement, Snake cross-lane transfers, Healyzard idle squash/stretch and any flips/rotations never cause a doubled ghost outline. Keep the shadow, healing aura, and all other VFX ordered correctly. Do not tint or alter the base sprite. Prefer storing overlay reference in the existing per-enemy visual dictionary and transferring it with the same visual object on Snake lane changes.
3. **Hit effect:** On real `LaneCombatModel._damage_enemy` updating `enemy.hit_flash`, reveal that enemy's silhouette at opaque bright red immediately; reduce its overlay opacity as the current 0.16s timer decreases. Repeat hits reset the effect without allocating new nodes/textures. Unhit enemies have no visible overlay at all. Match existing authoritative damage and HP numbers **3/6/3/3**. Healyzard healing must not trigger a damage flash.
4. **Lethal hits/death:** Current neutralization code directly starts a death visual/corpse. Ensure its red silhouette is active at death start (for projectile kills), fades over roughly 0.16 sec, and then remains hidden while the authentic base sprite continues normal one-second tumble/fade. Death cleanup disposes overlay with base nodes. For emergency lane clear where no damage event occurred, do not misleadingly invent a red damage flash unless previously present; distinguish from actual damage. Keep all existing SFX, hit feedback, discharge crystals, tier-3 routing, victory delay and terminal priorities.
5. **Delete old hit shader implementation** (`HIT_FLASH_SHADER`, per-enemy `ShaderMaterial`, `flash_strength` updates). Do not leave an invisible shader attached to original sprites. Change only specific P033 test assertions that expected shader parameters into overlay state/texture/alpha assertions; maintain HP, input and all other gameplay testing.
6. **Strong verification:** Add a deterministic test that opens all **four** source PNGs and generated red masks and compares per-pixel alpha (sample ALL 512x512 pixels, or an equivalent exact byte comparison) with red RGB for visible pixels. This should fail if any green/yellow enemy remains too dark due to tint multiplication. Use a real Godot Compatibility-renderer capture comparing unhit enemy versus original source image and active red-overlay enemy; ensure undamaged RGB and silhouette match accurately and active overlay is unmistakably red at full strength with clean transparent edges. Test repeated hits, fade, lethal corpse, Healyzard heal and Snake transfer, no new masks on each hit, no stale overlays after reset. Rerun full `./scripts/ci/run_regression_tests.sh`, Web build/validation, `./scripts/capture_p033_gameplay.sh`, update its existing actual-Godot screenshots and, if practical, add a focused unhit/hit comparison screenshot under `assets/previews/`.
7. **Handoff:** Update `README.md` with mask generation/repro commands and `.ai/CODEX_HANDOFF.md` with correction result, regenerated images and screenshot paths, test outcomes, SHA/branch and unresolved physical Android QA. Commit/push narrow tested changes to tracked branch, stop.

## Strict exclusions

- Do **NOT** redo P033's Android Classic/Side touch controls, shooter lift, horizontal loaded/next magazine, control-settings UI or full-canvas mouse clicks.
- Do **NOT** change enemy HP **3/6/3/3**, projectile damage, Snake behavior, Healyzard healing, enemy spawn timing/weights, color generator, conveyor speed, win/loss, gameplay audio or emergency charge-crystal visuals.
- Do **NOT** modify original `assets/sprites/baked/enemy_*.png` or defender sprites. Red masks are additive derived assets only.
- No new Web publishing workflow changes, Android signed release/APK, signing secret access, app rename or portfolio edits; preserve uncommitted user-local files. No force push, sudo, unrelated toolchain installation or GUI automation.
- Codex must not edit ChatGPT-owned `AGENTS.md`, `.ai/TASK.md`, `.ai/TASK_LEDGER.md`, `.ai/DECISIONS.md`, `.ai/PROTOCOL.md` or `.ai/BALL_BATTALION_ROADMAP.md`.

**Stop after P033R.** We will inspect the refreshed real rendered screenshots and tests before closing P033. P028A's balancing laboratory remains proposed, NOT ACTIVE.

---

## Original P033 scope — already implemented in 294ddae (historical reference only)

# ACTIVE CODEX TASK — LBS-P033: Mobile control modes, shooter ergonomics, easier enemies and vivid hit flashes

**Status:** ACTIVE — user explicitly requested "fold into the next task to halve all enemy HP ... heavily tint the enemies sprite red ... Continue" after accepting the P034C visuals (2026-10-27). This is the **ONE AND ONLY** active task. Implement, test, commit/push and stop; do not advance to P028 balancing or P029–P032 content.

## Baseline and precedence

Read `AGENTS.md`, `.ai/PROTOCOL.md`, `.ai/TASK_LEDGER.md`, `.ai/DECISIONS.md`, `.ai/BALL_BATTALION_ROADMAP.md`, `.ai/CODEX_HANDOFF.md` and this task. Inspect the actual current P034C live all-2D project: `scripts/main.gd`, `scripts/ui/shooter_view.gd`, `scripts/ui/magazine_view.gd`, `scripts/ui/hud_view.gd`, `scripts/responsive_layout.gd`, `scripts/world/enemy_types.gd`, `scripts/world/lane_combat_model.gd`, `scripts/world/lane_actor.gd`, relevant `tests/*.gd`, current Web/Android startup/export configuration. P034A/B/C work is delivered and must not be reverted.

The **latest** approved HP values below explicitly supersede P022's old 6/12/6/6 values; update affected fixtures/assertions without weakening combat checks. The input and ergonomic choices below supersede prior touch handling and shooter-magazine placement, but **not** ball-chain physics, tier damage rules, emergency-crystal rules, win condition, enemy motion, weighted spawning or other established mechanics.

The user is SSH-only on Mintbase and requires actual Godot-rendered screenshots in GitHub for remote review.

## A. One explicit difficulty adjustment — HALVE ALL four maximum HP

Canonical enemy maximum/full spawn HP must become exactly:
- **Hopper: 3** (was 6)
- **Heavy: 6** (was 12)
- **Sickle Snake: 3** (was 6)
- **Healyzard: 3** (was 6)

Update `EnemyTypes.MAX_HP`, default/fallback `LaneCombatModel.DEFAULT_ENEMY_HP` and any legitimate duplicated constants/expectations. Ensure normal and directed initial/spawn HP and `max_hp` agree, explicit test fixtures remain correctly clamped, Healyzard's existing **+1 HP/15 seconds** healing still caps at each new canonical maximum, and damaged Snake still stuns/transfers as before. Tier-1 remains exactly 1 damage and stops at first target; tiers 2/3 remain piercing 1 damage **per victim**, with tier 3 sweeping origin + one neighboring lane; emergency crystal still clears its lane one time. **Do not** change projectile damage/count, movement speeds, spawn rate/type weights, 8/lane budget, chain speed, matching, ammo randomness or other difficulty factors. The player judged the game hard and explicitly chose this small HP-only rebalance now; comprehensive P028 balancing still later.

## B. Strong immediate red enemy-on-hit flash, like Minecraft

Currently `LaneCombatModel._damage_enemy()` writes `hit_flash = 0.16`, but `LaneActor._update_enemy_visual()` only subtracts at most 38% of G/B. Replace that subtle tint with a **very strong, unmistakably red flash**, briefly at full strength the instant an enemy actually loses HP, across all 4 enemy colors/shapes. Use ~0.14–0.20 sec as initial duration (retain model's 0.16 seconds unless there is a demonstrated reason to change). Crucial: a pure multiplication tint on a green/yellow sprite often makes it look dark instead of bright red. Implement a light Godot 2D-compatible per-sprite shader/overlay or equivalent **actual red recolor/mix of textured RGB toward red**, preserving alpha, transparent edges and normal material/shading, with individually controllable flash strength (not one global shared flash affecting all enemies). Preserve squash/stretch, hit-flash timer, Healyzard aura, shadows, and no visible HP bars.

- Test normal nonlethal hits, repeat hits refreshing flash, **lethal hits** (the removed enemy's death sprite should visibly flash red before transitioning to its existing tumble/fade), subsequent restoration to normal for survivors, no red tint on healed/unhurt enemies, sprite state after Snake crosses a lane, and no stale tinted sprites after restart.
- The feedback is a visual response to real model damage only. Do not alter incoming damage, armor or gameplay to implement it. Death/corpse flash and fade must coexist; preserve 3-second victory presentation delay.

## C. Android/touch Classic mode (default)

- Classic: first primary finger may **touch and drag anywhere on the noninteractive gameplay screen**, from conveyor to bottom; shooter follows its **absolute X** with normal track clamps. Primary release fires **one shot** subject to existing 0.4s cooldown; canceled touches, UI interactions, game-over or menu interactions cannot fire.
- A **second distinct finger tapping anywhere on the noninteractive screen swaps loaded/next once per down**, without taking aim ownership, firing on release, or causing duplicate swaps/mouse emulation. Keep the primary finger's drag and release firing unaffected. Handle extra fingers, reversed release order, focus loss, restart, modal settings opening, movement between screen regions and multi-touch ID reuse.
- Hide the old dedicated swap button on **Android** (for both touch modes), while preserving desktop/Web controls and any legitimately interactable UI. It may remain in source; do not destroy the feature used elsewhere. Consider mobile touchscreen Web behavior if touch events are exposed, but native Android is the priority.
- Preserve the prior right-click and Space key swap on desktop/Web.

## D. Android/touch Side Control mode (handedness configurable)

- Model the horizontal input regions by **1:2:1** proportions of the usable viewport/safe rect: one outside **25% edge is a relative thumb trackpad** for aim, the center 50% remains primarily visual/nonaction, and the opposite outside 25% is the action zone.
- Side mode trackpad uses **relative horizontal delta**, NOT an absolute mapping of a quarter-width of screen to the entire shooter track. Touch-down leaves shooter X unchanged; dragging moves shooter X incrementally (initial ~1:1 logical-pixel displacement, no acceleration required), clamped to full legal track; several repeated swipes can cover full width. Finger can be dragged beyond the original quarter without unexpectedly losing control. Releasing this finger **does not shoot**. Support simultaneous independent action-region touches.
- The action 25% region is split **vertically into top half = SWAP tap** and **bottom half = SHOOT tap** of available safe gameplay area; one tap performs one corresponding action, no repeats on hold/release. The action-side region mirrors for left/right handedness. Use intuitive default: right-handed = aim on right, actions on left; left-handed = aim on left, actions on right. The opposite ordering is acceptable if user-facing labels and defaults clearly communicate and user can switch sides.
- Ensure a touch entering an action region from the trackpad doesn't trigger an action, and action finger dragging doesn't start moving shooter. Respect cooldown/terminal state and avoid double mouse emulation on Android/Web. Optional faint transient touch affordance if helpful, but do not obscure the battlefield with large panels.

## E. Raised shooter + horizontal loaded/next magazine

- The shooter and track must move **upward**, leaving a meaningful single-finger/thumb resting strip beneath them without covering loaded/next ammo: initial target roughly **80–100 Godot canvas pixels of additional upward lift at a 1280x720 reference**, scaled adaptively for safe rect/aspect; adjust intelligently at 960x540 and 2400x1080 so all four 2D combat rows still fit, no clipping and no blocked ball/track visuals. This represents an ergonomic estimate of `~1 cm` phone-thumb clearance, not a claim of exact physical centimetres from untrusted DPI.
- Keep large loaded ball **exactly centered horizontally on the firing axis** and make the smaller next-ball preview **beside it, at approximately the same Y** (prefer right side normally; flip to left near right screen edge with sensible hysteresis so it doesn't jitter). Ensure both always fully visible inside safe bounds even at shooter track extremes, using shooter offsets/clamping as necessary. Keep identities and shapes from `TeamData`; preserve 0.20s projectile travel and exact shot X.
- Recalculate `ResponsiveLayout` battlefield bottom to terminate just above raised shooter muzzle, keeping top row just below conveyor, proportional four-row 2D framing and 4–7% margins. Use available viewport size and display cutout-safe bounds, including unusually wide screen sizes and actual UI layouts. Avoid introducing overlap between next ball, shooter, lower enemy actors, lane-floor edge, and on-screen settings buttons.

## F. Minimal accessible settings and input priority

- Add a modest, real UI control (e.g. unobtrusive gear in top HUD) that opens a **simple settings panel** with Classic/Side mode and Left/Right handed Side mapping. The user specifically wants the ability to choose. On Android settings are accessible from gameplay, not only a main menu (native Android goes straight to gameplay). Saving in `user://` via `ConfigFile` or equivalent, with safe defaults for fresh install or corrupted/missing settings. Provide a way to close/resume without shooting.
- Prevent the panel, its settings and future real UI buttons from accidentally firing/swapping/moving the shooter. Input precedence: actual `Control` interactive elements consume their events before `main.gd` gameplay. Exclude UI from full-screen gesture zones.
- Make selection/detection **unit-testable without needing an attached Android phone** (e.g. test-injectable mobile input mode/platform flag) so CI on Linux can simulate distinct touch IDs and control mode transitions; don't fake an Android runtime success.

## G. Desktop/Web click anywhere (except interactive UI)

- **Left click anywhere on noninteractive game canvas — including the upper conveyor, outer margins and bottom shooter strip — fires** via existing cooldown; mouse X aims. **Right click anywhere in noninteractive game canvas swaps**. The present `_playfield_rect` filter incorrectly drops clicks above the conveyor; fix that. Do not use OS-level window click-through; this is game canvas event routing.
- Continue normal mouse movement aiming, Space=swap and existing keyboard shortcuts. Future/actual pause/settings controls must intercept clicks and not trigger a shot or swap. Avoid consuming all mouse-button events indiscriminately if it could break the new UI. Preserve existing START GAME/fullscreen flow on Web and Android direct start and don't create touch->mouse duplicate shots.

## H. Regression, visual QA and delivery

- Add `tests/p033_controls_and_enemy_hp_test.gd` (or split into coherent P033 suite files) verifying **all 3/6/3/3 HP canonical/default/directed spawns/heal caps**, actual projectile damage semantics and Snake abilities (don't discard original P022 assertions), the strong **per-enemy** red flash and lethal corpse flash/fade, controls routing/multitouch, swap once, cancellation/release, aim no-teleport relative side drag, independent firing region, hand mirroring, persistent settings load/save, full-canvas desktop clicks and UI prevention, safe area geometry, horizontal magazine visibility, and main no hidden 3D runtime.
- Update old test literals/fixtures tied to old HP 6/12/6/6 **as specifically needed**; preserve test value/coverage of P019/P020/P022/P034B/C tests and P011 stress. Run `./scripts/ci/run_regression_tests.sh` and full relevant Web export/validation, plus Android tooling smoke verification where available. Do not require a real Android device for software completion; clearly document real device QA pending.
- **Required SSH evidence:** commit at least **two new screenshots from actual Godot 2D gameplay**, e.g. 1280x720 and wide, showing raised shooter, large loaded ball, small adjacent next ball, all four combat rows, and ideally one enemy vividly red mid-hit and settings open in separate screenshots. Extend existing `tools/capture_p034c_crystals.gd` pattern or new capture script. Use a genuine GPU renderer and `RenderingServer.frame_post_draw`; do not repaint fixtures using image compositing or substitute stale P034C captures. Screenshot clip/overlap validation important. Documentation must include exact CLI repro commands and snapshot paths for remote review.
- Keep current P034C crystals and true-transparent sprite artwork unmodified; visual change focuses on enemy damage flash and shooter UI. Preserve all authoritative gameplay except exact requested enemy HP halving. Preserve existing Web auto-publish workflow and do not modify credentials, portfolio contents, APK release artifacts, package/version, or keystore. An optional **local unshipped QA Android debug export** is okay if tooling exists, but DO NOT publish or replace the previously release-signed v0.1.0 APK, change release metadata, use secret signing keys, or claim device-tested.
- Update `README.md` and `.ai/CODEX_HANDOFF.md` with implementation summary, input instructions for both modes, changed HP, screenshot links, test commands/results, Web and Android QA status. Commit and push only the verified P033 implementation/handoff to tracked `master` and **STOP**.

## Safety and ownership

Do not disturb user uncommitted edits (`project.godot`, `scenes/main.tscn`, generated UIDs), signing secrets/backups, unrelated Mintbase networking/apps or portfolio repos. No sudo, GUI automation, force push, destructive cleanup or system installation without permission. Codex must not edit ChatGPT-owned `AGENTS.md`, `.ai/TASK.md`, `.ai/TASK_LEDGER.md`, `.ai/DECISIONS.md`, `.ai/PROTOCOL.md`, or `.ai/BALL_BATTALION_ROADMAP.md`. If essential acceptance fails, honestly mark PARTIAL/BLOCKED in handoff rather than claiming completion.

**After pushing, STOP.** User/ChatGPT will inspect Web build and committed visuals, then decide whether to proceed to P028A balance instrumentation.
