# Lane Ball Shooter — Gameplay/Technical Decisions

Status: prototype design baseline, 2026-10-24. Parameters labeled "initial" are playtest values; mechanics are authoritative until changed via task mailbox.

## Game premise
A 2D Zuma-like colored-ball chain across the **top** supplies attacks for **four horizontal 3D combat lanes** below. Colored defender characters stand at the left side of each combat lane; enemies hop leftward from the right. The player matches balls in the upper chain by firing vertically from a bottom shooter to cause the correspondingly colored defender to fire 3D projectiles rightward. Endless survival/high score for prototype.

## Rendering/format
- One Godot 4 GDScript project, Compatibility renderer for Web, Android landscape export; baseline landscape 16:9, adapt layout to other landscape aspect ratios.
- Upper ball chain, bottom horizontally sliding shooter, magazine, fever/score/pause: **2D**.
- Combat battlefield: **3D primitive geometry** (cylinders, cubes, spheres/capsules), four fixed horizontal lanes; slightly elevated, fixed orthographic camera; minimalist look inspired by Thronefall, but no copied assets.
- Enemies advance left using logical 1D positions per lane; animation hops/jumps (smooth arc, squash/stretch, shadow remains on floor); jumping is cosmetic and must **not** accidentally make basic enemies invulnerable.
- Defenders stationary unless attacking, knocked down, or reviving. All four begin equivalent mechanically apart from color/symbol. Projectiles travel from defender to right; implement hits against enemies in matching lane.

## Color and shape identification
Four ball/team identities: RED (circle/dot), BLUE (square), YELLOW (triangle), GREEN (diamond); these pairings are defaults and can be tuned. Use distinct symbols **as well as** adjustable palettes to support color-blind accessibility. Ball, defender, lane indicator, and magazine identities must agree. Keep all palette/symbol definitions in one shared data source. Later add palette options if not in first task.

## 2D shooter and magazine
- Shooter bottom region, slides **horizontally only**, fires **straight up**, no angle control.
- Desktop/Web: mouse X controls shooter; left click fires; right click or Space swaps magazine.
- Android: finger press/drag in the play area moves shooter X; release fires. A tap on the magazine swap control does **not** fire. Handle multi-touch input ownership robustly; optional second-finger swap is not required.
- Persistent visible magazine shared by desktop/mobile: **LOADED ball | swap icon | NEXT ball**. Swap exchanges loaded and next identities immediately and also changes displayed shooter ball; no resource cost/cooldown. After fire, old next becomes loaded, a fresh next is generated.
- Thin vertical aim guide is helpful but should not obstruct gameplay.
- Initial shooter cooldown: ~0.4 seconds; test/tune later.

## Upper moving chain + cache
- One straight horizontal visible lane; chain travels right-to-left, and balls insert into the moving sequence on impact as in Zuma.
- A successful match = group of >=3 **adjacent balls of one identity**, removed as one match event. After removal, close gap; if it reveals adjacent groups of >=3, cascade until stable.
- Larger groups grant extra **score only**, not stronger attacks.
- Balls crossing the screen's **left boundary are NOT destroyed and NOT penalized**: cache them in memory, preserving their relative order. Successful matches re-introduce a small batch (initial tuning suggestion: 3) from the **right**. If all visible balls are cleared or roll off, cached balls must reenter automatically; never leave the board permanently empty/stuck. If cache and visible chain both empty, the generator seeds the stream.
- Requirement is to preserve the original visible left-to-right order of cached subsequences when fully restored, **not reverse them inadvertently when inserting at the right**. Implement and test explicit order examples. (FIFO exit from left plus FIFO spawn from right preserves visual order.)
- Avoid infinite unbounded automatic spawning: limit replenishment by total chain+cached population. Shot balls add to chain. Exact maximum/counts to tune.
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
- Initial attack tiers for prototype: tier 1 = 1 projectile, tier 2 = 2, tier 3/fever = 3. Larger match counts never affect tier; add a unique fever bonus only after playtesting.
- Active defender fires immediately on color match even if lane is empty (attack can be wasted).

## Enemy combat, knockdown, recovery, loss
- Basic enemies spawn on right, hop towards left; multiple can coexist per lane. Enemies have health; defender projectiles deal damage. Initial enemies and projectiles identical across lanes.
- When an enemy touches an **active** defender, knock the defender down.
- Each lane has an **emergency discharge** available **once per run**. On its first defender knockdown, automatically kill all enemies currently on that lane. The charge never refreshes.
- Later knockdowns still incapacitate the defender, but do **not** clear enemies.
- No automatic revival; while down, complete **2 separate matches** of the defender's associated ball identity to revive. Matching while down contributes to combo/fever and revival rather than launching ordinary attacks. Revival progress survives between matches; reset when revived or newly downed.
- When reviving, restore ability to intercept. A small repelling wave on revival may push back enemies that passed the defender but have not yet escaped; it must not mimic another full lane wipe.
- If **any enemy crosses the left boundary of any combat lane**, game over immediately. This is the only prototype losing condition. Balls escaping the top lane are cached and do not cause defeat.
- Emergency-charge availability and revival progress must be legible by lane.

## Starting balance and prototype scope
- Four lanes/colors, three-ball match threshold, three-second combo/fever window, two matches to revive, one emergency discharge per lane.
- Use adjustable debug constants for chain speed, refill count/population, enemy spawn rate, enemy speed, enemy HP, projectile speed/damage, cooldown and revival requirement.
- Placeholder primitives, flat materials, no external models/SFX needed. Later work: dramatic effects, special enemies, distinct character abilities, accessibility palette menus, audio, richer fever effects.
- Web and Android export validation is a later mailbox task; do not block core development on Android SDK setup.

## Items deliberately open for playtesting
- Exact ball stream generator/bag algorithm and cache refill pacing.
- Exact score calculation and score scaling for large matches.
- Precise enemy speeds, spawns, damage/HP, projectile physics, fever bonus.
- Enemy visual styles, emergency discharge VFX, palette variants.

If necessary, implement conservative and configurable defaults and report decisions; do not invent fundamentally different gameplay.
