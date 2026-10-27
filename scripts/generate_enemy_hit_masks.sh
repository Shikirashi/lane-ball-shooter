#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
godot_binary="${GODOT_BIN:-godot}"

"$godot_binary" --headless --path "$repo_dir" --script res://tools/generate_enemy_hit_masks.gd
