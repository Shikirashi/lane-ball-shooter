#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
	echo "Usage: $0 WEB_RELEASE_DIRECTORY PUBLIC_BASE_URL" >&2
	exit 2
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
release_dir="$(realpath "$1")"
base_url="${2%/}"
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

[[ "$base_url" == https://* ]] || {
	echo "Public verification requires an HTTPS URL." >&2
	exit 1
}
"$script_dir/validate_web_release.sh" "$release_dir" >/dev/null
expected_pck_sha="$(sha256sum "$release_dir/index.pck" | cut -d' ' -f1)"
probe_dir="$(mktemp -d "${TMPDIR:-/tmp}/lane-ball-shooter-public-probe.XXXXXX")"
trap 'rm -rf "$probe_dir"' EXIT

ready=false
for attempt in $(seq 1 40); do
	if curl --fail --silent --show-error --location \
		--output "$probe_dir/index.pck" "$base_url/index.pck?release=$expected_pck_sha"; then
		actual_pck_sha="$(sha256sum "$probe_dir/index.pck" | cut -d' ' -f1)"
		if [[ "$actual_pck_sha" == "$expected_pck_sha" ]]; then
			ready=true
			break
		fi
	fi
	echo "Waiting for GitHub Pages release ($attempt/40)..."
	sleep 15
done
if [[ "$ready" != true ]]; then
	echo "Public PCK did not update within ten minutes." >&2
	exit 1
fi

for runtime_file in "${runtime_files[@]}"; do
	headers="$probe_dir/$runtime_file.headers"
	download="$probe_dir/$runtime_file"
	status="$(curl --fail --silent --show-error --location \
		--dump-header "$headers" --output "$download" --write-out '%{http_code}' \
		"$base_url/$runtime_file?release=$expected_pck_sha")"
	[[ "$status" == "200" ]]
	cmp "$release_dir/$runtime_file" "$download"
	content_type="$(awk 'BEGIN { IGNORECASE=1 } /^content-type:/ { gsub("\r", ""); print $2; exit }' "$headers")"
	case "$runtime_file" in
		index.html) [[ "$content_type" == text/html* ]] ;;
		*.js) [[ "$content_type" == application/javascript* || "$content_type" == text/javascript* ]] ;;
		*.wasm) [[ "$content_type" == application/wasm* ]] ;;
		*.pck) [[ "$content_type" == application/octet-stream* ]] ;;
		*.png) [[ "$content_type" == image/png* ]] ;;
	esac
	printf '%s 200 %s %s bytes\n' "$runtime_file" "$content_type" "$(wc -c < "$download")"
done

printf 'All nine public HTTPS assets match the validated release.\n'
