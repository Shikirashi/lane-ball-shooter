# ACTIVE TASK: LBS-P001 — Godot foundation and hybrid prototype screen

**State:** READY FOR CODEX
**Repository:** Shikirashi/lane-ball-shooter (`master`)
**Owner:** Codex implementation; ChatGPT retains task/decision governance.
**Scope:** Build the first *running* Godot scene and input/UI foundation. Do not skip ahead into complete Zuma matching or defender combat.
**Read before starting:** `AGENTS.md`, `.ai/PROTOCOL.md`, `.ai/DECISIONS.md`, `.ai/TASK_LEDGER.md`.

## Objective
Create a fresh Godot 4.x **GDScript** project (target user's Godot 4.7.2) using the **Compatibility** renderer, with a convincing functional hybrid 2D/3D prototype shell for the planned Web+Android landscape game. The repo currently has docs only. Use pure procedural 3D primitive meshes and 2D Godot UI drawing; no external art or assets, no Blender, no editor/mouse automation.

## Required screen
1. Landscape 16:9 reference size (e.g. 1280x720), responsive enough for wide landscape phone and browser window widths. Use sensible anchors/containers/stretch settings; do not assume exactly one window resolution.
2. **2D top:** One visible horizontal ball lane, drawn with a short sample train of colored balls, distinct shape symbols and a leftward direction indicator. Make the sample chain visibly move left or use a controllable dummy stream; this is explicitly a *visual placeholder*, NOT production matching/rollover mechanics (P002).
3. **3D center:** Four clearly separated horizontal combat lanes, one fixed 3D defender at the left edge of each lane, simple 3D enemies entering/waiting at the right and visibly hopping left. The camera must be **orthographic**, fixed and slightly elevated, while keeping the four lanes aligned horizontally on the screen. Models are spheres/cylinders/cubes/capsules with flat, lightweight materials; no external files. Reuse a tiny set of primitive helpers/packed scenes rather than duplicating excessive code. Distinct lane/team color+symbol cues; enemies contrasting neutral/dark geometry. Hopping should be cosmetic (procedural arc and landing motion), with logical X position separate from model vertical displacement; no navigation or rigid body physics.
4. **2D bottom:** One shooter graphic sliding left-right on a fixed horizontal baseline and currently showing its loaded ball (color AND symbol). It always fires **straight upward**. It should be apparent visually when a shot was fired (a moving 2D projectile is sufficient, even though match collision is deferred).
5. **2D magazine:** Persistent `LOADED | [SWAP ICON] | NEXT` display shared by desktop and mobile, showing color AND shape for both slots. Clicking/tapping middle swap icon exchanges loaded and next identities *and updates the shooter graphic* from one authoritative magazine state. Swapping has no cooldown or cost. After firing, previous NEXT becomes LOADED and newly generated ball becomes NEXT. Put controls outside the shooter drag track if practical.
6. **2D HUD:** Simple score display, combo count and fever bar (placeholders are explicitly labelled or visually zero/inactive until P003). Optional pause/help icon if functional; do not add dead buttons.
7. Include a minimal title / documentation appropriate for the screen but prioritize legible play space on small phones. Four team identities defined centrally (e.g. red circle, blue square, yellow triangle, green diamond) rather than hardcoding mismatched color cases.

## Input contract
- Desktop/Web: mouse movement controls shooter X, left mouse click fires, right click or Space swaps.
- Android/touch: a touch that **begins on the playfield** can drag left/right to control shooter; on release, fire once. A touch on the swap button swaps ONLY; it must never fire on release. Don't require two-finger controls.
- During projectile flight/mouse or touch inputs, keep loaded/magazine state synchronized; avoid double-firing from touch emulation and a GUI button press.
- Reject shooting when on cooldown (initial target ~0.4 s). Multiple pending shots should have their ball type locked when launched.
- Mouse clicks on the swap button must not also trigger fire (proper input consumption/region handling).
- Keep a single method for shoot and a single method for swap; both input types use them.

## Implementation structure (choose exact paths sensibly)
- Godot project with a default/main scene that runs immediately on opening the project.
- Clear separation of game controller, 3D battlefield/lane actors, 2D ball/symbol rendering, shooter/magazine state, and HUD.
- Rendering composition may use a dedicated SubViewport for the central 3D area or a 3D scene with CanvasLayer over it, but the center battlefield must stay inside its visual region with no unexpected overlapping top/bottom UI.
- Use placeholder deterministic sample content, not full game rule simulation.
- Keep input and layout code simple and reusable for future P002–P006 tasks. No plugin dependencies.
- Document controls, how to run project and what is intentionally deferred in README.

## Acceptance criteria / verification
- [ ] Godot launches the default scene without parse errors or missing resources.
- [ ] Four distinct 3D defender lanes render, with enemy primitives visibly hopping toward the left.
- [ ] Top 2D ball chain and bottom 2D shooter plus magazine appear in correct order.
- [ ] Shooter follows mouse X; left click launches a vertical sample shot.
- [ ] Right click/Space OR clicking swap icon swaps loaded/next; magazine and shooter visuals immediately match.
- [ ] Touch dragging controls shooter and touch release fires once; tapping swap does not fire.
- [ ] Sample 16:9 and wider landscape layouts do not crop essential controls.
- [ ] Project uses GDScript, Compatibility renderer, 3D primitives only; no external assets.
- [ ] If Godot binary is available: run a **bounded** headless parse/smoke test and fix warnings/errors reasonably; if unavailable, document exactly what was not run.
- [ ] Code changes + concise `.ai/CODEX_HANDOFF.md` report committed/pushed on tracked branch.

## Out of scope (explicitly future tasks)
- Real chain insertion/collision, matching, cascades, cache and re-entry: **P002**.
- Scoring algorithms, combo progression and actual fever logic: **P003**.
- Combat HP, real match-triggered attacks, projectiles hitting enemies: **P004**.
- Defender knockdown/revival, emergency discharge, game over: **P005**.
- Full Web/Android export presets and device QA: **P006**.
These mechanics are documented in `.ai/DECISIONS.md` for architectural awareness, not authorization to implement everything now.

## Handoff
Update only `.ai/CODEX_HANDOFF.md` with status (COMPLETE/PARTIAL/BLOCKED), branch/commit, significant files, tests, manual playtest procedure, limitations and next task suggestions. Push the commit, **then stop** for ChatGPT review. Do not edit this task or the ledger.
