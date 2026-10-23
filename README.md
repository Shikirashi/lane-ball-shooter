# Lane Ball Shooter

A hybrid 2D/3D lane-defense game prototype in **Godot 4 / GDScript**, targeting Web and Android (landscape).

- 2D Zuma-like moving ball chain, shooter and two-ball swap magazine.
- Four 3D horizontal combat lanes with primitive defenders and hopping enemies.
- Matches activate same-color defender attacks; successive matches build combo/fever.
- Balls exiting left are cached for re-entry; defenders have an emergency lane clear and require matching-color revival.

## Codex development mailbox
This repository uses a shared mailbox: read [AGENTS.md](AGENTS.md) first, then `.ai/PROTOCOL.md`, `.ai/DECISIONS.md`, `.ai/TASK_LEDGER.md`, and the current `.ai/TASK.md`. Codex implements the active task and writes `.ai/CODEX_HANDOFF.md`.

## Run the prototype

Open the folder in Godot 4.x and run the project, or launch it from a terminal:

```sh
godot --path .
```

The project uses GDScript and the Compatibility renderer. All visuals are created with Godot drawing APIs and primitive 3D meshes; there are no external assets or add-ons.

Controls:

- Move the mouse horizontally to position the shooter; left-click in the playfield to fire.
- Right-click or press Space to swap the loaded and next balls.
- On touch devices, press and drag in the playfield, then release to fire once. Tap the magazine's center swap control to swap without firing.
- Press F3 to show or hide the P002 chain/cache diagnostics.
- After a lane breach, press R or use the on-screen RESTART button to begin a fresh run.

The top lane is a functional ordered chain: a shot must horizontally overlap a visible ball to insert beside it, contiguous physical groups of three or more clear, and newly connected groups cascade. Balls that leave on the left enter a FIFO cache and return from the right after matches or when the visible stream empties. Returned groups visibly catch up before becoming adjacent to a distant train.

Matches award score and advance the three-second combo window through tiers 1–3; the fourth consecutive timely match activates FEVER. The HUD meter drains in real time, while score persists through timeout. Magazine colors come from a fair four-color shuffle bag.

Each match also makes its matching 3D defender fire a one-, two-, or three-projectile burst according to the locked combo tier. Primitive enemies spawn independently, hop left, display HP pips, take same-lane projectile damage, and burst apart at zero HP.

When an enemy reaches an active defender, that defender falls and spends its one emergency discharge to clear the lane. The charge is once per run. A down defender needs two separate matches of its own color to revive; those matches still score and build combo but launch no attack. Later knockdowns do not clear enemies. Any live enemy crossing the far-left boundary ends the run immediately, freezes gameplay, preserves the final score, and offers a clean restart.
