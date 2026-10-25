#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
web_dir="$repo_dir/exports/web"
archive="$repo_dir/exports/lane-ball-shooter-web.zip"

mkdir -p "$web_dir"
# Clear only the dedicated ignored output directory so stale runtime/import
# sidecars cannot enter the next archive or be scanned back into its own PCK.
find "$web_dir" -mindepth 1 -maxdepth 1 -delete
godot --headless --path "$repo_dir" --export-release "Web" "$web_dir/index.html"

if [[ ! -f "$web_dir/index.html" ]] || ! find "$web_dir" -maxdepth 1 -type f -name '*.wasm' -print -quit | grep -q . || ! find "$web_dir" -maxdepth 1 -type f -name '*.pck' -print -quit | grep -q .; then
	echo "Web export is incomplete: expected index.html, .wasm and .pck files." >&2
	exit 1
fi

rm -f "$archive"
(
	cd "$web_dir"
	zip -q -r "$archive" .
)
echo "Created $archive"
