#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
godot_binary="${GODOT_BIN:-godot}"
mapfile -t test_files < <(find "$repo_dir/tests" -maxdepth 1 -type f -name '*.gd' -printf '%f\n' | sort)

if [[ ${#test_files[@]} -eq 0 ]]; then
	echo "No GDScript regression suites were found." >&2
	exit 1
fi

printf 'Godot: '
"$godot_binary" --version
for test_file in "${test_files[@]}"; do
	printf '\n==> %s\n' "$test_file"
	"$godot_binary" --headless --path "$repo_dir" --script "res://tests/$test_file"
done
printf '\nAll %d regression suites passed.\n' "${#test_files[@]}"
