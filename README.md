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

The top lane is now a functional ordered chain: a shot must horizontally overlap a visible ball to insert beside it, contiguous physical groups of three or more clear, and newly connected groups cascade. Balls that leave on the left enter a FIFO cache and return from the right after matches or when the visible stream empties. Returned groups visibly catch up before becoming adjacent to a distant train. The small readout on the top lane shows visible/cache counts and the latest match event for P002 testing.

Score/combo/fever progression, combat damage, defender knockdown, and game-over logic remain assigned to P003–P005. The hopping enemies continue to loop as a battlefield presentation placeholder.
