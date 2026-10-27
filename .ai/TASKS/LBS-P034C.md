# LBS-P034C — completed charge crystal revision

**Implementation:** COMPLETE — code/assets commit `16347b377d044702c7748a94ebb53f8bce435e57`; handoff `04d6075a3b8af9f7625a0a0e1956a089f8a6de98` (2026-10-27).

**Review:** Source, authentic rebaked sprite images, crystal state screenshot, shatter screenshot and new tests reviewed. No blocking technical defect found; seven tiny shards may need aesthetic playtest for motion readability. Codex reports **26 local regression suites PASSED**, P034C 85 checks; GitHub CI build/test job PASSED for Actions run `40555144242`. Portfolio publication subsequently verified successful: GitHub Actions run `40555144242` completed SUCCESS. Human motion and physical Android QA still pending.

**Screenshots:** `assets/previews/p034c_crystal_states_1280x720.png` and `assets/previews/p034c_crystal_shatter_1600x720.png`. Re-baked orb-free defender sprites/contact sheet under `assets/sprites/baked/`.

**Excluded still:** P033 touchscreen/desktop controls, P028 color and speed balancing, branding/release APK changes. Signing identity not modified.

---

## Original scope

# ACTIVE CODEX TASK — LBS-P034C: Remove baked charge orb; add 2D diamond charge crystal and shatter

**Status:** ACTIVE — user explicitly requested visual replacement (2026-10-27). This is the **ONLY active Codex task**. The P034B live 2D battlefield and P034A true-transparency sprite-baking pipeline already exist; preserve them. Do not start P033 controls or P028 balancing.

## User's design request

> "There's a strange yellow sphere behind the defenders ... remove the yellow sphere from the 3D model of the defenders, retake the image snapshots, then add the diamond crystal behind each of the defenders. This will act as the charge thing. When spent, it simply shatters and disappears."

The old sphere is **`ChargeOrb`** in `scripts/world/actor_visual_factory.gd`, part of P034A's captured transparent defender PNGs. P034B currently has an unused `SpentChargeCover` polygon and dims the *whole* baked defender when emergency charge is spent. Remove both workarounds: the **defender stays at full normal color**; only its **independent charge crystal** shatters/vanishes.

## Confirmed gameplay semantics — do NOT modify

- `LaneCombatModel.emergency_available` is one-time per defender **per run**, initially true. It switches to false only in `_discharge_emergency()`, which emits `emergency_discharged(identity, cleared_count)`.
- A knocked-down defender may revive from subsequent matches, but this does **not** restore its emergency charge. Shattered crystal must remain absent after revival. Only `reset_run()` restores charge/new intact crystal.
- Existing combat, emergency clear kills/accounting, health/speed/spawns, SFX, victory delay and control mechanics remain unchanged. No asset-driven gameplay logic.

## Deliverables

1. **Remove original yellow sphere from the real source model:** edit `scripts/world/actor_visual_factory.gd` to eliminate `ChargeOrb` mesh creation and its presence in return dictionaries (update any callers/tests that still reference it). Preserve the genuine 3D defender bodies, visor, launcher, hidden muzzle flash, palette, orthographic bake camera and materials. Do not approximate/silently repaint existing PNGs.
2. **Rebake the genuine transparent PNGs with the existing Godot CLI baker** (`./scripts/bake_actor_sprites.sh`) using its real GPU/OpenGL setup, including all four defender color masters and updated contact sheet, pivot metadata; regenerate all eight if required by the baker. Confirm transparency, recognizable old meshes other than orb, clean alpha and absence of the former isolated yellow sphere. Preserve P034A's deterministic repeat-bake capability. Do not use chroma key, generative imagery or image editing as a substitute for authentic bake.
3. **Add one separate 2D faceted diamond-shaped emergency crystal behind each colored defender** in the **actual live 2D battlefield** (`scripts/world/lane_actor.gd`). Prefer modest-sized, clearly legible procedurally drawn `Polygon2D` facets/outline and subtle glow, color-tinted to each defender's RED/BLUE/YELLOW/GREEN team. Crystal must be visually distinct from the silhouette and from ordinary team markers. Put it at a consistent visible **rear/left, slightly raised** position behind its defender, with z-order behind defender character but not fully obscured; respect responsive layouts, pivot/grounding, defender recoil/knockdown/revival. It may be anchored to the lane rather than rotating with defender when knocked down. No interactive mouse-catching `Control`, no physics/collision role, no external assets. Avoid gratuitous clutter; readable at 960x540 through 2400x1080.
4. **Discharge shatter:** the first actual `emergency_discharged` event triggers an immediately clear crystal break: ~5–8 faceted tinted shards burst/fly/spin/fade in a short, bounded 0.35–0.65 second cosmetic animation; the intact crystal disappears as shards begin. When finished, nothing remains behind defender. Ensure no duplicate shatters on repeated state sync/events; after revival, remains absent. On restart, remove leftover shards and immediately recreate/show intact crystal. If state is loaded/forced directly to `emergency_available=false`, hide crystal reliably without inventing a shatter (unless a genuine discharge event occurred). Do not tint/dim the defender PNG on charge use; maintain the readable existing `CHARGE`/`SPENT` status text. Leave existing separate emergency lane-clear visual and sounds intact.
5. **Automated tests and remote screenshots (mandatory):** Add `tests/p034c_charge_crystal_test.gd` with bounded deterministic tests for source orb removal; no baked isolated yellow orb, transparent PNGs; four team crystal colors/presence/relative position and layering; true one-time shatter triggered by authoritative event; immediate removal, shard lifetime, no fake respawn after revival, reset restores crystal and clears particles; defender full-color when spent; 2D-only normal gameplay; responsive placement including cutout; no visual interception of mouse/touch; retained HP/emergency/revival semantics. Run **all** P001–P023/P034A/P034B/new P034C regression suites. Update *only* stale tests that explicitly assumed `ChargeOrb` or full-defender dimming, without dropping gameplay assertions.
6. **Since user works over SSH:** add repeatable Godot Compatibility-renderer capture of actual NEW live gameplay (not an invented mockup): commit screenshot(s) under `assets/previews/p034c_*.png` showing at least one clearly **intact colored crystal** and one **SPENT defender with no crystal**, ideally also a screenshot capturing **mid-shatter**. Preserve the P034B screenshots as historical baseline rather than overwriting them. Reuse or extend P034B capture infrastructure, use real `RenderingServer.frame_post_draw` and real GPU context, verify screenshot dimensions/nonblank and that the crystal/shards are visibly inspectable in the captured result. If easily feasible, a short animation recording is optional, **not required**. State exact repro commands in README and handoff.
7. **Handoff:** update README briefly with crystal semantics and baked asset regeneration; `.ai/CODEX_HANDOFF.md` must include actual Git commit SHA, changed paths, capture paths, Godot/GPU mode, regression/test commands/results, and any remaining limitations. Verify a fresh Web build/browser as feasible; the existing P024 Web CI auto-publish is expected after code push. Do not alter publishing credentials, existing portfolio card or APK signing.

## Scope / safety

- Strictly visual change to emergency charge indication and rebuilding original source-defender sprite captures. No new enemy artwork, no change to enemies/attack rules, HP, movement, lane framing, matching, shooter/ammo controls, game name, app ID, package version, Android release or portfolio site.
- P033 controls and P028 balance analysis are still **NOT ACTIVE**. P034B is completed; retain genuinely 2D live runtime with **no hidden 3D viewport**. P034A 3D models remain for offline asset baking only.
- Preserve user's uncommitted `project.godot`, `scenes/main.tscn`, generated `.uid` files and all local signing secrets. Inspect working tree; `git pull --ff-only` only if safe. No force push/reset, destructive clean, sudo, GUI automation or mass unrelated edits.
- Codex owns implementation/docs/handoff, but must not edit ChatGPT-owned `AGENTS.md`, `.ai/TASK.md`, `.ai/TASK_LEDGER.md`, `.ai/DECISIONS.md`, `.ai/PROTOCOL.md` or `.ai/BALL_BATTALION_ROADMAP.md`. Follow `AGENTS.md` and `.ai/PROTOCOL.md`.
- If the graphics renderer is unavailable, do not claim real rebaking/capture success; report precise remaining blocker and make safe partial progress only.

**Finish by committing and pushing the verified results + handoff to master, then STOP.** ChatGPT/user will review the new real screenshots and approve the next task separately.
