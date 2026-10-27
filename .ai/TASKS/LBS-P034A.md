# COMPLETED IMPLEMENTATION — LBS-P034A: 3D actor sprite baking

**Status:** CODEX COMPLETE / TECHNICAL REVIEW PASS (2026-10-27); user visual acceptance of art/animation direction is pending. No next task was activated.

**Source commit:** https://github.com/Shikirashi/lane-ball-shooter/commit/5dbd70842a5df420c467f0113f057f742eb287b2

**CI:** https://github.com/Shikirashi/lane-ball-shooter/actions/runs/40544273523 — completed SUCCESS.

**Outputs:** Eight real transparent 512×512 actor masters (4 enemies + 4 colored defenders), `assets/sprites/baked/contact_sheet.png`, pivot metadata, CLI Godot baker, isolated 2D squash/stretch preview. Existing Web/Android gameplay remains 3D. Codex handoff reports all 24 local suites passed; GitHub CI succeeded. Technical source and visual contact-sheet inspection found no blocking issues. Animated preview not independently viewed; user reviews artistic quality before any P034B migration.

---

## Original P034A execution request (preserved)

# ACTIVE CODEX TASK — LBS-P034A: Bake existing 3D actors into transparent 2D sprites

**Status:** ACTIVE — USER REQUESTED the Godot/Codex 3D-to-2D sprite capture experiment (2026-10-27). **This phase is an asset/visual proof of concept, NOT authorization for the live 2D gameplay migration.**

## Objective and reason

The user proposes making Ball Battalion visually 2D: retain the recognizable models that are currently constructed from Godot 3D primitives, render them into real transparent PNGs with Godot, and ultimately draw the entire battlefield in 2D UI/Sprite2D with deliberately cartoony squash/stretch movement. The user specifically wants to see actual baked captures before committing to a full replacement.

Deliver a repeatable, source-accurate sprite baker and an inspectable, separate 2D preview scene. Preserve the existing playable Web/Android game in this phase. **P033 control updates, P028 balance instrumentation and P034B live 2D migration are not active.**

## Authoritative sources and invariants

Read `AGENTS.md`, `.ai/PROTOCOL.md`, `.ai/DECISIONS.md`, `.ai/TASK_LEDGER.md`, `.ai/BALL_BATTALION_ROADMAP.md`, this file and existing tests. Inspect:
- `scripts/world/lane_actor.gd`: `_create_enemy_visual()`, `_build_defender()`, `_update_enemy_visual()`, feedback/death and current lighting/camera pose.
- `scripts/world/battlefield.gd`: `_build_camera()`, `_build_environment()`, lane spacing and current ortho viewpoint.
- `scripts/world/enemy_types.gd`, `scripts/world/primitive_factory.gd`, `scripts/team_data.gd`.

The source meshes are authoritative. Preserve Hopper's two orange decorative horns; Heavy width/orange; tall yellow Sickle Snake; small green Healyzard; and each red/blue/yellow/green defender. Do not reinterpret their designs, use external/AI-generated art, or replace them with approximate new artwork.

## Authorized deliverables

1. **Automated reproducible capture.** Add a documented Godot 4.7.2 GDScript export/bake entrypoint (and optional shell wrapper) that runs via CLI without manual GUI actions. Render a **separate 3D actor in a transparent `SubViewport`**, fixed orthographic camera/perspective matching the currently seen game models, using compatible lighting/materials. Wait for an actual rendered frame (e.g., `RenderingServer.frame_post_draw`) before capturing `viewport.get_texture().get_image()` and saving real RGBA PNG files. Do not scrape screenshots and remove the background by guessing/chroma key. Choose sane, consistent reference resolution (suggest 512x512 masters) and preserve pivots / consistent visual scale, with padding to avoid clipping.
2. **Initial output assets:** bake all **four enemies** (Hopper, Heavy, Sickle Snake, Healyzard) and all **four defender colors** in their normal standing/resting states, as eight separately usable transparently backed PNG images. The shared underlying model-building implementation should be reused or safely extracted: avoid manually duplicating model geometry in the baker. If necessary, perform a minimal non-behavioral refactor and verify gameplay remains unchanged. Treat floor/shadows separately; don't bake a rectangular opaque floor into character sprites.
3. **Inspectability:** produce one contact sheet (checkerboard for visualization only; individual PNG alpha stays transparent), and a separate launchable **2D preview scene** with drawn 2D horizontal lane floors/stripes, the baked actor sprites, and an illustrative loop of goofy scaling/bobbing: Hopper spring/hop, Heavy horizontal squash, Sickle Snake elastic wiggle, Healyzard pulse, defender recoil/knockdown demonstration if straightforward. Use `Sprite2D`/`Control`/2D transforms, not 3D viewport rendering at preview runtime. Keep this preview strictly isolated from `scenes/main.tscn`, normal startup, gameplay input and public builds until visual approval.
4. **Validation:** verify each PNG exists, has sensible dimensions, contains **real transparent pixels** at corners/outside silhouette and nontransparent colored actor pixels inside, is neither empty/black nor a copied flat screenshot, and can be loaded into a Sprite2D. Verify clean alpha edges/check for halos. Add bounded automated tests for asset presence/alpha/pivot/preview wiring and preserve **all existing P001–P023** regression suites. Document if graphics capture cannot run in a genuine headless/no-GPU context; rendering to file may require an offscreen OpenGL display such as an existing X display or Xvfb. Do not claim a successful PNG bake from Godot's dummy headless renderer. Do not install GUI applications, modify system-wide settings, or use sudo without permission.
5. **Handoff:** update `README.md` briefly with the repeatable bake/preview commands. In `.ai/CODEX_HANDOFF.md`, list actual PNG paths/contact-sheet preview, Godot/rendering environment and verification commands/results, and any unrendered state/effect requiring future sprite treatment. Commit and push verified source/assets/tests/handoff.

## Explicit exclusions

- **Do not** replace the live Battlefield, LaneActor, 3D camera, 3D projectiles or live gameplay with a new 2D renderer in this phase. No live input/control, UI framing, balance, random seed, spawn, physics, hit detection, scene boot or combat changes.
- No new art, textures downloaded from outside the repo, shaders requiring Forward+, AI-generated sprite approximations, store assets, packaging/title/package/APK signing changes, public portfolio changes or release publishing.
- Do not update ChatGPT-owned `.ai/TASK.md`, `.ai/TASK_LEDGER.md`, or `.ai/DECISIONS.md`. Do not automatically activate P034B or P033.
- Preserve uncommitted user work. No force-push, destructive reset/clean, or overwrite of secret signing files. Prefer a separate temporary worktree if required for clean export.

## Completion checks

- Eight visually recognizable, nonempty RGBA PNG actor captures exported by Godot with true transparency and source-identical colors/forms.
- Re-run generator deterministically; document whether files are byte-identical under the same Godot/toolchain.
- Standalone all-2D preview shows the captures, consistent alignment/relative sizes and sample squash/stretch animations.
- Existing game and its Web/Android identities unchanged; P001–P023 tests pass (or precise and honest blocker supplied).
- Handoff includes clear review instructions and a screenshot/contact-sheet for user approval before **separately scoped P034B**, which would replace the runtime 3D visuals with an actual 2D Battlefield view while reusing the logical combat models.

After pushing, **STOP**; user/ChatGPT will review art and decide whether to proceed to full conversion.
