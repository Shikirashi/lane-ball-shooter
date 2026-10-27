#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
godot_binary="${GODOT_BIN:-godot}"

if [[ -z "${DISPLAY:-}" && -z "${WAYLAND_DISPLAY:-}" ]]; then
	echo "P034A baking needs a real graphical rendering environment (DISPLAY or WAYLAND_DISPLAY)." >&2
	echo "Use an existing display or run under an available offscreen X server; do not use Godot's dummy headless renderer." >&2
	exit 1
fi

"$godot_binary" --path "$repo_dir" --audio-driver Dummy --rendering-method gl_compatibility \
	--script res://tools/bake_actor_sprites.gd
