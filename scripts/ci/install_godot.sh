#!/usr/bin/env bash
set -euo pipefail

readonly godot_version="4.7.2-stable"
readonly template_version="4.7.2.stable"
readonly godot_archive="Godot_v4.7.2-stable_linux.x86_64.zip"
readonly template_archive="Godot_v4.7.2-stable_export_templates.tpz"
readonly godot_sha256="cadd3204e728a35d3f13adb7fd0d7902636b79f6b95c40c265eb73b6c35329e4"
readonly template_sha256="f298490b8d44d934be425a5a65a51bf15f422428b229a06a6e11d9ffea248011"
readonly release_base="https://github.com/godotengine/godot/releases/download/${godot_version}"

cache_dir="${GODOT_DOWNLOAD_CACHE:-${RUNNER_TEMP:-/tmp}/lane-ball-shooter-godot-downloads}"
install_dir="${RUNNER_TEMP:-/tmp}/lane-ball-shooter-godot"
template_dir="${HOME}/.local/share/godot/export_templates/${template_version}"
mkdir -p "$cache_dir" "$install_dir" "$template_dir"

download_and_verify() {
	local filename="$1"
	local expected_sha="$2"
	local destination="$cache_dir/$filename"
	if [[ ! -f "$destination" ]]; then
		curl --fail --location --retry 4 --retry-all-errors \
			--output "$destination" "$release_base/$filename"
	fi
	printf '%s  %s\n' "$expected_sha" "$destination" | sha256sum --check --status || {
		echo "Checksum mismatch for $filename" >&2
		exit 1
	}
}

download_and_verify "$godot_archive" "$godot_sha256"
download_and_verify "$template_archive" "$template_sha256"

unzip -q -o "$cache_dir/$godot_archive" -d "$install_dir"
godot_binary="$(find "$install_dir" -maxdepth 1 -type f -name 'Godot*_linux.x86_64' -print -quit)"
if [[ -z "$godot_binary" ]]; then
	echo "Godot executable was not found after extraction." >&2
	exit 1
fi
chmod +x "$godot_binary"
ln -sf "$godot_binary" "$install_dir/godot"

template_staging="$(mktemp -d "${RUNNER_TEMP:-/tmp}/lane-ball-shooter-templates.XXXXXX")"
trap 'rm -rf "$template_staging"' EXIT
unzip -q "$cache_dir/$template_archive" -d "$template_staging"
if [[ ! -f "$template_staging/templates/web_nothreads_release.zip" ]]; then
	echo "The official template archive lacks web_nothreads_release.zip." >&2
	exit 1
fi
find "$template_dir" -mindepth 1 -maxdepth 1 -delete
cp -a "$template_staging/templates/." "$template_dir/"

if [[ -n "${GITHUB_PATH:-}" ]]; then
	printf '%s\n' "$install_dir" >> "$GITHUB_PATH"
fi
"$install_dir/godot" --version
printf 'Installed Web template: %s\n' "$template_dir/web_nothreads_release.zip"
