#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
	echo "Usage: $0 WEB_RELEASE_DIRECTORY" >&2
	exit 2
fi

release_dir="$(realpath "$1")"
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

if [[ ! -d "$release_dir" ]]; then
	echo "Web release directory does not exist: $release_dir" >&2
	exit 1
fi

mapfile -t actual_files < <(find "$release_dir" -mindepth 1 -maxdepth 1 -printf '%f\n' | sort)
mapfile -t expected_files < <(printf '%s\n' "${runtime_files[@]}" | sort)
if [[ "${actual_files[*]}" != "${expected_files[*]}" ]]; then
	echo "Web release must contain exactly the nine expected runtime files." >&2
	printf 'Expected: %s\n' "${expected_files[*]}" >&2
	printf 'Actual:   %s\n' "${actual_files[*]}" >&2
	exit 1
fi

for runtime_file in "${runtime_files[@]}"; do
	if [[ ! -s "$release_dir/$runtime_file" ]]; then
		echo "Missing or empty runtime file: $runtime_file" >&2
		exit 1
	fi
done

hex_prefix() {
	od -An -tx1 -N4 "$1" | tr -d ' \n'
}

[[ "$(hex_prefix "$release_dir/index.wasm")" == "0061736d" ]] || {
	echo "index.wasm does not have the WebAssembly magic bytes." >&2
	exit 1
}
[[ "$(hex_prefix "$release_dir/index.pck")" == "47445043" ]] || {
	echo "index.pck does not have the Godot pack magic bytes." >&2
	exit 1
}
for png_file in index.png index.icon.png index.apple-touch-icon.png; do
	[[ "$(hex_prefix "$release_dir/$png_file")" == "89504e47" ]] || {
		echo "$png_file does not have the PNG magic bytes." >&2
		exit 1
	}
done

grep -Fq 'src="index.js"' "$release_dir/index.html"
grep -Fq '"index.pck"' "$release_dir/index.html"
grep -Fq '"index.wasm"' "$release_dir/index.html"
grep -Fq 'href="index.icon.png"' "$release_dir/index.html"
grep -Fq 'href="index.apple-touch-icon.png"' "$release_dir/index.html"
grep -Fq 'src="index.png"' "$release_dir/index.html"
if grep -Eq '(src|href)="/index\.' "$release_dir/index.html"; then
	echo "Generated HTML contains a root-relative runtime URL." >&2
	exit 1
fi

printf 'Validated runtime release at %s\n' "$release_dir"
(
	cd "$release_dir"
	sha256sum "${runtime_files[@]}"
)
