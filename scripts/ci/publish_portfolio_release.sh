#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 3 ]]; then
	echo "Usage: $0 WEB_RELEASE_DIRECTORY PORTFOLIO_REPOSITORY SOURCE_SHA" >&2
	exit 2
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
release_dir="$(realpath "$1")"
portfolio_dir="$(git -C "$2" rev-parse --show-toplevel)"
source_sha="$3"
target_rel="lane-ball-shooter"
target_dir="$portfolio_dir/$target_rel"
readonly runtime_files=(
	index.html
	index.js
	index.wasm
	index.pck
	index.audio.worklet.js
	index.audio.position.worklet.js
	index.png
	index.icon.png
	index.apple-touch-icon.png
)

"$script_dir/validate_web_release.sh" "$release_dir"
if [[ -n "$(git -C "$portfolio_dir" status --porcelain=v1 --untracked-files=all)" ]]; then
	echo "Portfolio checkout must be clean before staging a release." >&2
	exit 1
fi

mkdir -p "$target_dir"
mapfile -t existing_files < <(find "$target_dir" -mindepth 1 -maxdepth 1 -printf '%f\n' | sort)
for existing_file in "${existing_files[@]}"; do
	case "$existing_file" in
		.gitkeep|index.html|index.js|index.wasm|index.pck|index.audio.worklet.js|index.audio.position.worklet.js|index.png|index.icon.png|index.apple-touch-icon.png)
			;;
		*)
			echo "Refusing to replace unexpected portfolio file: $target_rel/$existing_file" >&2
			exit 1
			;;
	esac
done

for runtime_file in "${runtime_files[@]}"; do
	install -m 0644 "$release_dir/$runtime_file" "$target_dir/$runtime_file"
done
if [[ -f "$target_dir/.gitkeep" ]]; then
	rm "$target_dir/.gitkeep"
fi
"$script_dir/validate_web_release.sh" "$target_dir"

while IFS= read -r status_line; do
	[[ -z "$status_line" ]] && continue
	changed_path="${status_line:3}"
	if [[ "$changed_path" != "$target_rel/"* ]]; then
		echo "Refusing publication because it changed another portfolio path: $changed_path" >&2
		exit 1
	fi
done < <(git -C "$portfolio_dir" status --porcelain=v1 --untracked-files=all)

printf 'Prepared portfolio release from game source %s\n' "$source_sha"
git -C "$portfolio_dir" status --short -- "$target_rel"
