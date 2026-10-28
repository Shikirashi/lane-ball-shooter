#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
godot_binary="${GODOT_BIN:-godot}"

if [[ -z "${DISPLAY:-}" && -z "${WAYLAND_DISPLAY:-}" ]]; then
	echo "P037 Android UI capture requires a real graphical renderer." >&2
	exit 1
fi

"$godot_binary" --path "$repo_dir" --audio-driver Dummy --rendering-method gl_compatibility \
	--script res://tools/capture_p037_android_ui.gd
