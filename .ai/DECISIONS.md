# Lane Ball Shooter — Gameplay/Technical Decisions

Status: prototype design baseline, updated with second desktop playtest changes 2026-10-25 (P008). Later playtest decisions supersede conflicting earlier prototype tuning. Parameters labeled "initial" are playtest values; mechanics are authoritative until changed via task mailbox.

## Game premise
A 2D Zuma-like colored-ball chain across the **top** supplies attacks for **four horizontal 3D combat lanes** below. Colored defender characters stand at the left side of each combat lane; enemies hop leftward from the right. The player matches balls in the upper chain by firing vertically from a bottom shooter to cause the correspondingly colored defender to fire 3D projectiles rightward. Endless survival/high score for prototype.

## Rendering/format
- One Godot 4 GDScript project, Compatibility renderer for Web, Android landscape export; baseline landscape 16:9, adapt layout to other landscape aspect ratios.
- Upper ball chain, bottom horizontally sliding shooter, magazine, fever/score/pause: **2D**.
- Combat battlefield: **3D primitive geometry** (cylinders, cubes, spheres/capsules), four fixed horizontal lanes; slightly elevated, fixed orthographic camera; minimalist look inspired by Thronefall, but no copied assets.
- Enemies advance left using logical 1D positions per lane **only during airborne hop travel**, with a grounded no-movement dwell between jumps. 3D arc/squash/stretch must follow the same hop phase; shadow stays on ground; neither airborne nor grounded state grants invulnerability.
- Defenders stationary unless attacking, knocked down, or reviving. All four begin equivalent mechanically apart from color/symbol. Projectiles travel from defender to right; implement hits against enemies in matching lane.

## Color and shape identification
Four ball/team identities: RED (circle/dot), BLUE (square), YELLOW (triangle), GREEN (diamond); these pairings are defaults and can be tuned. Use distinct symbols **as well as** adjustable palettes to support color-blind accessibility. Ball, defender, lane indicator, and magazine identities must agree. Keep all palette/symbol definitions in one shared data source. Later add palette options if not in first task.

## 2D shooter and magazine
- Shooter bottom region, slides **horizontally only**, fires **straight up**, no angle control.
- Desktop/Web: mouse X controls shooter; left click fires; right click or Space swaps magazine.
- Android: finger press/drag in the play area moves shooter X; release fires. A tap on the magazine swap control does **not** fire. Handle multi-touch input ownership robustly; optional second-finger swap is not required.
- Persistent visible magazine shared by desktop/mobile: **LOADED ball | swap icon | NEXT ball**. Swap exchanges loaded and next identities immediately and also changes displayed shooter ball; no resource cost/cooldown. After fire, old next becomes loaded, a fresh next is generated.
- Thin vertical aim guide is helpful but should not obstruct gameplay.
- **Player-fired ball reaches upper chain in ~0.20 seconds from launch regardless of viewport height.** This is vertical shot travel, not the chain's horizontal scroll speed. Fire cooldown stays ~0.4s. Missing shots do not insert or trigger a hit SFX.
- Initial shooter cooldown: ~0.4 seconds; test/tune later.

## Upper moving chain + cache
- One straight horizontal visible lane with **68 px/s** top-chain conveyor motion, unaffected by the P008 faster fired projectile. Balls insert on impact as in Zuma.
- **P008 fresh feeder favors same-color consecutive runs** of 2, with occasional 4–7 consecutive balls; e.g. seven GREEN in a row is valid. These already-connected groups are **never cleared automatically** on spawn, movement, cache return or connection; a player-triggered successful insertion starts matching and then physical cascades. No unrelated seeded group should vanish just because a shot hits elsewhere. Only the top-chain FRESH feeder adopts this biased generator; magazine remains a four-color shuffle bag.
- A successful match = group of >=3 **adjacent balls of one identity**, removed as one match event. After removal, close gap; if it reveals adjacent groups of >=3, cascade until stable.
- Larger groups grant extra **score only**, not stronger attacks.
- Balls crossing the screen's **left boundary are NOT destroyed and NOT penalized**: cache them in FIFO order. Successful matches request cached returns from the **right** (initial batch size 3), admitted when spacing allows. The conveyor also has a **continuous independent source of fresh balls at the right edge**, indefinitely throughout the run—not just on total chain exhaustion. Space pending cache returns among fresh balls without violating FIFO or blocking the new stream. Never strand an empty board or build an offscreen-right backlog.
- Requirement is to preserve the original visible left-to-right order of cached subsequences when fully restored, **not reverse them inadvertently when inserting at the right**. Implement and test explicit order examples. (FIFO exit from left plus FIFO spawn from right preserves visual order.)
- **Unbounded fresh generation over lifetime is required**, but bounded simultaneously live/offscreen-right balls and non-overlapping spacing are required too. The cache retains legitimate exits without silently dropping them; avoid runaway per-frame work and document linear cache storage, if applicable. Shot balls add to chain. Feed pacing/population are playtest parameters.
- For v0.1 do not assess score or lives penalties on rollover.

## Attack progression / fever
- A valid match triggers the matching active defender's attack, or counts toward its revival when down.
- Combo starts at first successful match. Each subsequent match within **3 seconds of the previous match** advances the chain:
  - 1st match = tier 1
  - 2nd = tier 2
  - 3rd = tier 3
  - 4th = **FEVER** (tier-3-or-better current attack and distinct fever visuals)
  - further on-time matches sustain fever; timeout resets next match to tier 1.
- Fever bar drains over the 3-second window and refills with each successful match. Attack strength determined at **match time**, not projectile impact.
- Chain reactions: provisional prototype rule is that **each distinct group cleared** counts as its own match/combo step, even when resolved in one shot. Report playtest implications.
- Playtest revision **P007 attack tiers**: tier 1 = one ordinary projectile for **1 damage** (standard enemy **2 HP**, two hits to kill); tier 2 = two spaced projectiles each dealing **2 damage** (each hit kills a fresh standard enemy); tier 3 and FEVER = **instant lethal clear of all currently living enemies on the matched defender's lane plus ONE randomly selected adjacent lane**, with edge lanes choosing their only neighbor. Tier 3 replaces the earlier three-projectile burst. A match for a DOWN defender still advances revival rather than doing any attack. Larger match counts never affect tier.
- Active defender fires immediately on color match even if lane is empty (attack can be wasted).

## Enemy combat, knockdown, recovery, loss
- Basic enemies spawn on right and move left **only by hops**, with stationary grounded intervals; multiple can coexist per lane. **P008 enemy average travel speed is halved from 0.48 to 0.24 world units/s**, preserving the existing hop/ground timing and swept contact detection. Basic enemies have **2 HP**, tier-1 projectile hits deal 1 and tier-2 projectile hits deal 2. Tier-3 area clearing affects exactly the matched lane and one adjacent lane when its origin defender is ACTIVE; does not spend emergency charges.
- When an enemy touches an **active** defender, knock the defender down.
- Each lane has an **emergency discharge** available **once per run**. On its first defender knockdown, automatically kill all enemies currently on that lane. The charge never refreshes.
- Later knockdowns still incapacitate the defender, but do **not** clear enemies.
- No automatic revival; while down, complete **2 separate matches** of the defender's associated ball identity to revive. Matching while down contributes to combo/fever and revival rather than launching ordinary attacks. Revival progress survives between matches; reset when revived or newly downed.
- When reviving, restore ability to intercept. A small repelling wave on revival may push back enemies that passed the defender but have not yet escaped; it must not mimic another full lane wipe.
- If **any enemy crosses the left boundary of any combat lane**, game over immediately. This is the only prototype losing condition. Balls escaping the top lane are cached and do not cause defeat.
- Emergency-charge availability and revival progress must be legible by lane.

## Starting balance and prototype scope
- Four lanes/colors, three-ball match threshold, three-second combo/fever window, two matches to revive, one emergency discharge per lane. Top-chain base speed **68 px/s**, fired vertical ball arrival target **0.20s**, enemies average **0.24 world units/s**, independent perpetual right-edge stream.
- Use adjustable debug constants for chain speed, refill count/population, enemy spawn rate, enemy speed, enemy HP, projectile speed/damage, cooldown and revival requirement.
- Placeholder primitives, flat materials, no external models/SFX needed. Later work: dramatic effects, special enemies, distinct character abilities, accessibility palette menus, audio, richer fever effects.
- Web and Android export validation is a later mailbox task; do not block core development on Android SDK setup.

## Items deliberately open for playtesting
- Exact ball stream generator/bag algorithm and cache refill pacing.
- Exact score calculation and score scaling for large matches.
- Precise enemy speeds, spawns, damage/HP, projectile physics, fever bonus.
- Enemy visual styles, emergency discharge VFX, palette variants.

If necessary, implement conservative and configurable defaults and report decisions; do not invent fundamentally different gameplay.

## P007 user playtest decisions (2026-10-25)
- Faster top conveyor: base speed 68 px/s rather than 34 px/s.
- Ball stream never stops replenishing from the right: ongoing fresh generation even before the board empties, integrated with preserving FIFO left-exit cache. Space/cap pertain to **simultaneous** balls, not cumulative ball generation.
- Tier 1 requires two normal projectile hits for a standard 2-HP enemy. Tier 2 still fires a spaced two-projectile burst, but **each individual tier-2 projectile** kills a standard 2-HP enemy in one hit.
- Tier 3/FEVER is a two-lane instant clear: matched lane plus randomly chosen directly adjacent lane. For top/bottom edge, only one eligible neighbor. No collateral nonadjacent lane or emergency-charge consumption. DOWN origin defender gets revival progress instead; no tier attack.
- Enemies pause on ground, then leap forward only while airborne; average advance roughly as before (0.48 units/s). Gameplay X, swept collisions, hop visuals, defender contact and breach use the same displacement model.
- These decisions supersede any older P002/P004/P005 statements or tests that assume a finite upper ball seed, three ordinary tier-3 projectiles, or constant horizontal enemy speed.

## P008 second playtest decisions (2026-10-25)
- **Do not confuse ball shot speed with chain speed:** the user requested the fired ball reach the top in ~0.20 seconds. Keep the conveyor scrolling horizontally at 68 px/s and the shot firing cooldown at 0.4s.
- Reduce enemy average advance from 0.48 to **0.24 world units/s**, keeping explicit grounded pauses and forward movement only during airborne hops.
- The top fresh-ball generator must intentionally produce **clusters of repeated colors**, including 4–7+ in a row. Suggested tunable run-length weights: 1=20%, 2=30%, 3=18%, 4=13%, 5=9%, 6=6%, 7=4%, with balanced choices of four colors. This supersedes P007's top-stream strict four-color shuffle bag. **Do not** change the fired-ball magazine's separate shuffle bag.
- A pre-existing group of 3+ same-color balls may exist untouched on the conveyor: spawning or merging does **not** automatically clear it. Only a real **player-fired insertion into the corresponding group** initiates clearing (and any locally connected cascades). A 7+same-color group plus a matching shot clears as one larger match event; group size still affects score but not attack tier.
- Add gentle, distinct **procedural SFX** for accepted shoot, successful insert, swap, matching, active defender attack, defender knockdown and defender revive, connected to gameplay signals without duplicate triggering. "Defender dying" means the existing **DOWN** state, not permanent death; the defender can revive. Sounds must be web/android-compatible, rate/voice limited, and ideally mutatable. Headless tests can validate routing/synthesis but human listening remains necessary.
