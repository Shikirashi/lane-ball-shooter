# ACTIVE TASK: LBS-P013 — Shooter-mounted next-ball preview, compact touch swap, smooth masked conveyor entry

**Status:** READY FOR CODEX — P012 has been source-reviewed and accepted
**Branch:** master
**Dependency:** P012 insertion-direction correction `412b18e`, handoff `198d7cb`, reviewed and accepted; existing P011 segment-authoritative chain architecture.
**Intent:** User-proposed presentation/UX polish after P012 push review. Keep all mechanics identical. Separate shot visuals from conveyor-only clipping and make next ammunition visible beside the current shot.

## A. Shooter-mounted loaded/next display

- On the shooter itself, draw **current LOADED** ball in its existing large position, and **NEXT** ball directly below it at a clearly smaller size (e.g., 7–10px radius, with miniature identity symbol). This must stay attached to moving shooter X at all viewport widths, including edges, and stay within the safe viewport/bottom region.
- After firing, immediately update both the loaded-ball visual and smaller next-ball preview using the actual `MagazineState` (never generate a second preview or invent colors). After swapping, exchange both, instant synchronization; proper original four color identities and shape markers.
- Replace the old large loaded/next/swap HUD panel with a **single recognizable circular two-arrow swap icon** as the touch control. Keep the touch target at least 56x56 logical px. It can sit in a safe screen corner (recommended upper-right HUD if not over score or conveyor); its clickable region must NOT intercept any pointer/touch intended to move or fire from the full-width playfield.
- `Space` / right mouse button retain swap action; swap during live play makes one swap SFX and no shot, cooldown unaffected; no swap on game over. Finger touch release on button must not produce synthetic duplicate shooting. Multi-touch ownership must remain correct.
- Ensure `Main._on_magazine_changed` feeds both current and next identities to `ShooterView`; remove redundant old large magazine ball graphics. The touch button may be housed in a minimal `MagazineView` or standalone control; avoid unused text/panel allocations. Keep code/UI responsive at 960x540, 1280x720, 1600x720, 2400x1080, phone landscape safe areas.

## B. Physically enter the conveyor offscreen rather than pop at the boundary

Current `ChainModel._feed_right_edge` waits until enough room is open and admits newly generated/right-recycled balls at the right-side entry position close to `lane_width - radius`, so they suddenly appear in the conveyor. Correct this by spawning fresh or FIFO returned balls **completely offscreen to the RIGHT** at an X center >= `lane_width + radius + ENTRY_MARGIN` (small tuneable margin). Then have them advance continuously LEFT into visible space at normal chain speed, with no snapping/teleportation to the entry position.

- Maintain the single authoritative P011 segment topology, fixed spacing, P012 forward insertion direction, physical contact/FEED edges, 24 auto-live ball cap (or documented equally bounded offscreen staging), sorted unique UIDs and no overlaps. The entrance should be a logical continuation of the stream or a typed FEED segment, not an unrelated rendering-only fake.
- Unbounded *lifetime* generation remains, but do not queue an unbounded number of offscreen balls. Only admit an offscreen ball if a legal slot exists relative to all existing rightmost balls; never allow ball centers to overlap because of admission/catch-up.
- Ensure infinite feeder still replenishes through matches, left rollover and complete clear. If no visible balls exist, new entries should enter promptly and naturally, but not jump/teleport onscreen. Preserve finite time until next ball and continuous look.
- Cached FIFO returns must enter from the same offscreen-right staging point, preserving RED/GREEN/BLUE order and existing fair fresh interleaving and request quota. Existing P008 weighted color runs unchanged. Offscreen-right balls are NOT subject to left rollover before they appear.
- **Important geometry:** Since a ball is radius 22px, a center at `lane_width + radius + margin` starts with its ENTIRE CIRCLE beyond the clip boundary. If there is already a rightmost ball beyond the boundary (or in entry transit), the next spawn position must be at least `spacing` behind it, but scheduling must avoid a constantly growing invisible right backlog.
- Manage large delta and low FPS without sudden popping after crossing edge; interpolate using real physical positions derived from segments.

## C. Conveyor-only visual mask (clipping boundary)

The conveyor is currently drawn in `BallChainView` with `clip_contents=true`, but its current control bounds need not equal the actual visual conveyor strip (`lane_rect = Rect2(0,10,size.x,max(56,size.y-14))`). Make a deliberate mask at the visible **conveyor rectangular window** (left/right/top/bottom), using a dedicated clipping parent/subcontrol or appropriate Godot 4 CanvasItem clip mechanism so conveyor balls genuinely appear progressively through the right edge and disappear through the left edge, including their outline/shadow/symbol.

- Mask should affect **ONLY balls which are already part of the conveyor** (admitted chain members after completed insertion), not shooter-loaded ball, shooter-next preview, swap icon, muzzle FX or projectile balls traveling from shooter toward the conveyor.
- Crucial requested exception: balls in the process of being inserted must stay **UNCLIPPED until finished inserting** (the existing 0.05s settling transition). Arrange rendering into separate layers: `ShooterView` owns loaded/next and launched balls, a temporary **unmasked settling/insertion visual** (with stable UID, correct position and life) appears above the conveyor mask for the 50ms settle, and after settle it moves to the clipped conveyor render path, with no one-frame disappearance, duplicate rendering, coordinate mismatch or overlap. During settlement, the physical chain model already owns the ball and reserves its legal slot; the unmasked overlay is a visual rendering classification only.
- If preserving the fired ball throughout travel/insertion involves handing off a visual from shooter to chain, use a clear ownership boundary on first physical contact. Missed fired balls should simply expire as before. Don't leave unmasked ghost balls after match, rollback, gameover, resize, or restart.
- Use a single authoritative model identity/UID and model position for both clipped and unmasked visual; do not fork gameplay state or accidentally double-apply matches. Shot hit/insert/match SFX semantics unchanged. Clip changes must not affect physical collision/hit testing.
- If parent clip layout might clip the unmasked overlay, make it a sibling above the clipped conveyor panel with proper screen-to-local transform; this is important at resized/high-DPI safe-area layouts.
- Preserve proper drawing order and accessibility shapes. No generic full-screen clip affecting shooter or bullets.

## D. Test plan

Create `tests/p013_shooter_preview_mask_test.gd`, update old layout tests only for changes explicitly approved here, run P001–P012 and P013.
1. At all four landscape resolutions and safe-area configurations, loaded main ball tracks shooter X, next-ball preview is beneath it, preview identity changes with fire/swap, and both stay visible on mobile safe areas; swap touch target >=56x56 and unobstructed full-width firing.
2. Swap via UI/Space/right click triggers exactly once with no shot; touch aim/draw/release right/left edge still fires exactly one; game over and restart clear pending visual handoffs.
3. Fresh and FIFO ball identities initially appear with X center > right edge + radius, and a ball progressively becomes visible only as it crosses the right boundary; no whole-circle one-frame pop-in. Check 30/60/120 fps and single large delta results.
4. Render/clip layer behavior: incoming established conveyor balls clipped strictly to lane window; shots in flight, loaded/next balls and pre-settle inserted ball are unaffected. At 49ms insert stays on unmasked overlay, at 50ms it becomes clipped chain member without duplication or frame disappearance. Test coordinate and owner transitions using deterministic state/data checks and practical graphical screenshot/manual QA where available.
5. Offscreen admission never overlaps or violates P011 geometry, including multiple recent rollbacks, repeated P012 forward inserts, matching/cascades, left rollover, requested cache returns, complete clears. No unbounded offscreen population over very long runs.
6. Existing P010 color cascade order and timing, P012 insertion-left push, P011 invariant stress, shooter 0.20s travel, conveyor 34px/s, enemies 0.24, SFX, live combo/fever/revival, swipe/drag and safe areas all preserved.
7. Headless regression P001–P012 and P013 plus bounded startup 960x540/1280x720/1600x720/2400x1080. Report exact results, `git diff --check`, no new external assets, libraries or binaries.

## Finishing notes

Godot 4.7.2 GDScript Compatibility targeting Web and Android landscape. Code-only edits; do NOT take control of the user's GUI. Prefer a small clean HUD and explicit drawing ownership. No new mechanics, arbitrary balance changes, enemy roster, sound changes or branding work.

Now active, after P012 review: update README with shooter ammo preview, swap button and offscreen/mask behavior; update `.ai/CODEX_HANDOFF.md`, run tests, commit/push, STOP. Do not self-advance beyond P013, edit `.ai/TASK_LEDGER.md` or `.ai/DECISIONS.md`.
