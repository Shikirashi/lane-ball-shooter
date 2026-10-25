#!/usr/bin/env bash
set -euo pipefail

usage() {
	printf 'Usage: %s deploy <web-dir> <release-id> [deploy-root]\n' "$0"
	printf '       %s rollback [deploy-root]\n' "$0"
}

mode="${1:-}"
default_root="${LBS_WEB_DEPLOY_ROOT:-$HOME/srv/lane-ball-shooter-web}"

atomic_link() {
	local target="$1"
	local link_path="$2"
	local temporary_link="${link_path}.new.$$"
	ln -s "$target" "$temporary_link"
	mv -Tf "$temporary_link" "$link_path"
}

if [[ "$mode" == "rollback" ]]; then
	deploy_root="${2:-$default_root}"
	current_link="$deploy_root/current"
	previous_link="$deploy_root/previous"
	[[ -L "$current_link" && -L "$previous_link" ]] || {
		printf 'Rollback requires both %s and %s symlinks.\n' "$current_link" "$previous_link" >&2
		exit 1
	}
	current_target="$(readlink "$current_link")"
	previous_target="$(readlink "$previous_link")"
	[[ -d "$deploy_root/$previous_target" ]] || {
		printf 'Previous release target is missing: %s\n' "$previous_target" >&2
		exit 1
	}
	atomic_link "$previous_target" "$current_link"
	atomic_link "$current_target" "$previous_link"
	printf 'Rolled back current to %s; previous now points to %s\n' "$previous_target" "$current_target"
	exit 0
fi

if [[ "$mode" != "deploy" || $# -lt 3 || $# -gt 4 ]]; then
	usage >&2
	exit 2
fi

source_dir="${2%/}"
release_id="$3"
deploy_root="${4:-$default_root}"

[[ "$release_id" =~ ^[A-Za-z0-9._-]+$ ]] || {
	printf 'Release ID may contain only letters, digits, dot, underscore and hyphen.\n' >&2
	exit 2
}
[[ -d "$source_dir" ]] || {
	printf 'Web export directory does not exist: %s\n' "$source_dir" >&2
	exit 1
}

required_files=(
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
for required_file in "${required_files[@]}"; do
	[[ -s "$source_dir/$required_file" ]] || {
		printf 'Missing or empty required Web runtime file: %s\n' "$required_file" >&2
		exit 1
	}
done

releases_dir="$deploy_root/releases"
release_dir="$releases_dir/$release_id"
mkdir -p "$releases_dir"
[[ ! -e "$release_dir" ]] || {
	printf 'Release already exists and will not be overwritten: %s\n' "$release_dir" >&2
	exit 1
}

stage_dir="$(mktemp -d "$releases_dir/.stage.XXXXXX")"
cleanup() {
	if [[ -n "${stage_dir:-}" && -d "$stage_dir" ]]; then
		rm -rf -- "$stage_dir"
	fi
}
trap cleanup EXIT

for required_file in "${required_files[@]}"; do
	cp -p "$source_dir/$required_file" "$stage_dir/$required_file"
done

{
	printf 'release_id=%s\n' "$release_id"
	printf 'source_revision=%s\n' "${LBS_SOURCE_REVISION:-unknown}"
	printf 'created_utc=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
	printf 'archive_sha256=%s\n' "${LBS_ARCHIVE_SHA256:-not-supplied}"
	printf '\nfiles:\n'
	(cd "$stage_dir" && sha256sum "${required_files[@]}")
} > "$stage_dir/release-manifest.txt"

mv "$stage_dir" "$release_dir"
stage_dir=""

current_link="$deploy_root/current"
previous_link="$deploy_root/previous"
if [[ -L "$current_link" ]]; then
	old_target="$(readlink "$current_link")"
	if [[ -d "$deploy_root/$old_target" ]]; then
		atomic_link "$old_target" "$previous_link"
	fi
fi
atomic_link "releases/$release_id" "$current_link"
printf 'Promoted release %s at %s\n' "$release_id" "$current_link"
