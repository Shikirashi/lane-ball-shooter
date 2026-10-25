#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
setup_script="$repo_dir/scripts/setup_android_toolchain.sh"

bash -n "$setup_script"
grep -q '4.7.2-stable_export_templates.tpz' "$setup_script"
grep -q 'f298490b8d44d934be425a5a65a51bf15f422428b229a06a6e11d9ffea248011' "$setup_script"
grep -q 'OpenJDK17U-jdk_x64_linux_hotspot_17.0.21_9.tar.gz' "$setup_script"
grep -q '8b9b611d917e3dfd8419d3566b5949226f69b052fed7e109c1368add1dfe8711' "$setup_script"
grep -q '"build-tools;35.0.1" "platforms;android-35"' "$setup_script"
grep -q 'No existing Android SDK license receipt' "$setup_script"

if grep -Eq '(^|[[:space:]])sudo([[:space:]]|$)|yes[[:space:]]*\|' "$setup_script"; then
	echo "Toolchain setup must not use sudo or pipe automatic license acceptance." >&2
	exit 1
fi

echo "Android toolchain setup policy tests passed."
