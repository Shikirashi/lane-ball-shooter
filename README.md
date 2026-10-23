# Lane Ball Shooter

A hybrid 2D/3D lane-defense game prototype in **Godot 4 / GDScript**, targeting Web and Android (landscape).

- 2D Zuma-like moving ball chain, shooter and two-ball swap magazine.
- Four 3D horizontal combat lanes with primitive defenders and hopping enemies.
- Matches activate same-color defender attacks; successive matches build combo/fever.
- Balls exiting left are cached for re-entry; defenders have an emergency lane clear and require matching-color revival.

## Codex development mailbox
This repository uses a shared mailbox: read [AGENTS.md](AGENTS.md) first, then `.ai/PROTOCOL.md`, `.ai/DECISIONS.md`, `.ai/TASK_LEDGER.md`, and the current `.ai/TASK.md`. Codex implements the active task and writes `.ai/CODEX_HANDOFF.md`.

The initial commit includes coordination and specification only; Codex creates the Godot project as task LBS-P001.
