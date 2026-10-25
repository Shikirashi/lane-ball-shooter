#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
apk_path="$repo_dir/exports/android/lane-ball-shooter.apk"
template="$HOME/.local/share/godot/export_templates/4.7.2.stable/android_release.apk"

require_env() {
	local variable_name="$1"
	if [[ -z "${!variable_name:-}" ]]; then
		echo "Required environment variable is unset: $variable_name" >&2
		exit 1
	fi
}

for variable_name in \
	GODOT_ANDROID_KEYSTORE_RELEASE_PATH \
	GODOT_ANDROID_KEYSTORE_RELEASE_USER \
	GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD; do
	require_env "$variable_name"
done

if [[ ! -e "$GODOT_ANDROID_KEYSTORE_RELEASE_PATH" ]]; then
	echo "Release keystore does not exist: $GODOT_ANDROID_KEYSTORE_RELEASE_PATH" >&2
	exit 1
fi
keystore_path="$(realpath "$GODOT_ANDROID_KEYSTORE_RELEASE_PATH")"
export GODOT_ANDROID_KEYSTORE_RELEASE_PATH="$keystore_path"
case "$keystore_path" in
	"$repo_dir"/*)
		echo "The release keystore must be stored outside the repository." >&2
		exit 1
		;;
esac
if [[ ! -r "$keystore_path" ]]; then
	echo "Release keystore is not readable: $keystore_path" >&2
	exit 1
fi
if [[ "${keystore_path##*/}" == "debug.keystore" || "$GODOT_ANDROID_KEYSTORE_RELEASE_USER" == "androiddebugkey" ]]; then
	echo "Refusing Android debug signing credentials." >&2
	exit 1
fi

command -v godot >/dev/null || {
	echo "Godot is not on PATH." >&2
	exit 1
}
if [[ -n "$(git -C "$repo_dir" status --porcelain)" ]]; then
	echo "Refusing a release export from a dirty worktree; commit or safely set aside all changes first." >&2
	exit 1
fi
godot_version="$(godot --version)"
[[ "$godot_version" == 4.7.2.* ]] || {
	echo "Godot 4.7.2 is required; found $godot_version." >&2
	exit 1
}
if [[ ! -s "$template" ]]; then
	echo "Missing matching Godot Android release template: $template" >&2
	exit 1
fi

sdk_root="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}"
if [[ -z "$sdk_root" || ! -d "$sdk_root" ]]; then
	echo "Set ANDROID_HOME (or ANDROID_SDK_ROOT) to the configured Android SDK." >&2
	exit 1
fi
if [[ -z "${JAVA_HOME:-}" || ! -x "$JAVA_HOME/bin/keytool" ]]; then
	echo "Set JAVA_HOME to the JDK configured in Godot." >&2
	exit 1
fi

if ! "$JAVA_HOME/bin/keytool" -list \
	-keystore "$keystore_path" \
	-storepass:env GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD \
	-alias "$GODOT_ANDROID_KEYSTORE_RELEASE_USER" >/dev/null; then
	echo "Release keystore validation failed; verify path, alias, and password." >&2
	exit 1
fi

mkdir -p "$(dirname "$apk_path")"
rm -f "$apk_path"
echo "Exporting release-signed ARM64 APK with Godot 4.7.2..."
godot --headless --path "$repo_dir" --export-release "Android Release" "$apk_path"
ANDROID_HOME="$sdk_root" "$repo_dir/scripts/verify_android_release.sh" "$apk_path"
