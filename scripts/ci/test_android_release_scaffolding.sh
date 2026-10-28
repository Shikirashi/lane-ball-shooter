#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
preset="$repo_dir/export_presets.cfg"

debug_preset="$(awk '/^\[preset\.1\]$/{capture=1} /^\[preset\.2\]$/{capture=0} capture{print}' "$preset")"
release_preset="$(awk '/^\[preset\.2\]$/{capture=1} capture{print}' "$preset")"
grep -q '^name="Android Debug"$' <<<"$debug_preset"
grep -q '^architectures/arm64-v8a=true$' <<<"$debug_preset"
grep -q '^package/unique_name="com.shikirashi.laneballshooter"$' <<<"$debug_preset"
grep -q '^version/code=4$' <<<"$debug_preset"
grep -q '^version/name="0.2.0"$' <<<"$debug_preset"
grep -q '^permissions/vibrate=true$' <<<"$debug_preset"
grep -q '^name="Android Release"$' <<<"$release_preset"
grep -q '^export_path="exports/android/lane-ball-shooter.apk"$' <<<"$release_preset"
grep -q '^architectures/armeabi-v7a=false$' <<<"$release_preset"
grep -q '^architectures/arm64-v8a=true$' <<<"$release_preset"
grep -q '^architectures/x86=false$' <<<"$release_preset"
grep -q '^architectures/x86_64=false$' <<<"$release_preset"
grep -q '^package/unique_name="com.shikirashi.laneballshooter"$' <<<"$release_preset"
grep -q '^package/signed=true$' <<<"$release_preset"
grep -q '^version/code=4$' <<<"$release_preset"
grep -q '^version/name="0.2.0"$' <<<"$release_preset"
grep -q '^permissions/vibrate=true$' <<<"$release_preset"
grep -q '^keystore/release=""$' <<<"$release_preset"
grep -q '^keystore/release_password=""$' <<<"$release_preset"
grep -q '^window/handheld/orientation=4$' "$repo_dir/project.godot"
grep -q '^renderer/rendering_method.mobile="gl_compatibility"$' "$repo_dir/project.godot"
grep -q "expected_signer_sha256='796f2c679d962a8195ebf1a38d959002829561dfd26d2dae86e52ccdec7224fc'" "$repo_dir/scripts/verify_android_release.sh"
grep -q "android.permission.VIBRATE" "$repo_dir/scripts/verify_android_release.sh"

test_log="$(mktemp)"
trap 'rm -f "$test_log"' EXIT
if env -u GODOT_ANDROID_KEYSTORE_RELEASE_PATH \
	-u GODOT_ANDROID_KEYSTORE_RELEASE_USER \
	-u GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD \
	"$repo_dir/scripts/build_android.sh" >"$test_log" 2>&1; then
	echo "Build unexpectedly proceeded without release signing credentials." >&2
	exit 1
fi
grep -q 'Required environment variable is unset' "$test_log"

echo "Android release scaffolding tests passed."
