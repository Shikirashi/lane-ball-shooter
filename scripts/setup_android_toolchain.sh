#!/usr/bin/env bash
set -euo pipefail

readonly template_version="4.7.2.stable"
readonly template_archive="Godot_v4.7.2-stable_export_templates.tpz"
readonly template_sha256="f298490b8d44d934be425a5a65a51bf15f422428b229a06a6e11d9ffea248011"
readonly template_url="https://github.com/godotengine/godot/releases/download/4.7.2-stable/$template_archive"

readonly jdk_archive="OpenJDK17U-jdk_x64_linux_hotspot_17.0.21_9.tar.gz"
readonly jdk_sha256="8b9b611d917e3dfd8419d3566b5949226f69b052fed7e109c1368add1dfe8711"
readonly jdk_url="https://github.com/adoptium/temurin17-binaries/releases/download/jdk-17.0.21%2B9/$jdk_archive"

readonly cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/lane-ball-shooter/android-toolchain"
readonly install_root="${XDG_DATA_HOME:-$HOME/.local/share}/lane-ball-shooter/toolchains"
readonly jdk_dir="$install_root/temurin-17.0.21+9"
readonly template_dir="$HOME/.local/share/godot/export_templates/$template_version"
readonly sdk_root="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/Android/Sdk}}"

if [[ "$(id -u)" -eq 0 ]]; then
	echo "Run this installer as the normal user, not as root." >&2
	exit 1
fi

for required_tool in curl sha256sum tar unzip find install mktemp; do
	command -v "$required_tool" >/dev/null || {
		echo "Missing prerequisite: $required_tool" >&2
		exit 1
	}
done

mkdir -p "$cache_dir" "$install_root" "$template_dir"

download_verified() {
	local url="$1"
	local filename="$2"
	local expected_sha="$3"
	local destination="$cache_dir/$filename"
	if [[ ! -f "$destination" ]]; then
		curl --fail --location --retry 4 --retry-all-errors \
			--output "$destination.part" "$url"
		mv "$destination.part" "$destination"
	fi
	printf '%s  %s\n' "$expected_sha" "$destination" | sha256sum --check --status || {
		echo "Checksum mismatch: $destination" >&2
		exit 1
	}
}

download_verified "$jdk_url" "$jdk_archive" "$jdk_sha256"
if [[ ! -x "$jdk_dir/bin/javac" ]]; then
	if [[ -e "$jdk_dir" ]]; then
		echo "Refusing to replace incomplete JDK directory: $jdk_dir" >&2
		exit 1
	fi
	jdk_staging="$(mktemp -d "$install_root/.temurin-17.XXXXXX")"
	trap 'rm -rf "${jdk_staging:-}" "${template_staging:-}"' EXIT
	tar -xzf "$cache_dir/$jdk_archive" --strip-components=1 -C "$jdk_staging"
	"$jdk_staging/bin/java" -version
	"$jdk_staging/bin/javac" -version
	mv "$jdk_staging" "$jdk_dir"
	jdk_staging=""
fi

download_verified "$template_url" "$template_archive" "$template_sha256"
template_staging="$(mktemp -d "$install_root/.godot-android-templates.XXXXXX")"
trap 'rm -rf "${jdk_staging:-}" "${template_staging:-}"' EXIT
unzip -q "$cache_dir/$template_archive" \
	'templates/android_debug.apk' \
	'templates/android_release.apk' \
	-d "$template_staging"
for template_name in android_debug.apk android_release.apk; do
	install -m 0644 "$template_staging/templates/$template_name" \
		"$template_dir/$template_name.new"
	mv "$template_dir/$template_name.new" "$template_dir/$template_name"
done
rm -rf "$template_staging"
template_staging=""

echo "Installed JDK: $jdk_dir"
echo "Installed Android export templates without modifying Web templates: $template_dir"

sdkmanager="$sdk_root/cmdline-tools/latest/bin/sdkmanager"
license_file="$sdk_root/licenses/android-sdk-license"
if [[ ! -x "$sdkmanager" ]]; then
	echo "Android command-line tools are not installed at $sdkmanager." >&2
	echo "Review and accept Google's Android SDK terms yourself, install the command-line tools there, then rerun this script." >&2
	exit 3
fi
if [[ ! -s "$license_file" ]]; then
	echo "No existing Android SDK license receipt was found at $license_file." >&2
	echo "This script will not accept licenses. Review them yourself with sdkmanager --licenses, then rerun." >&2
	exit 3
fi

JAVA_HOME="$jdk_dir" "$sdkmanager" --sdk_root="$sdk_root" \
	"platform-tools" "build-tools;35.0.1" "platforms;android-35" </dev/null

for sdk_tool in \
	"$sdk_root/platform-tools/adb" \
	"$sdk_root/build-tools/35.0.1/apksigner" \
	"$sdk_root/build-tools/35.0.1/aapt" \
	"$sdk_root/build-tools/35.0.1/zipalign" \
	"$sdk_root/platforms/android-35/android.jar"; do
	[[ -e "$sdk_tool" ]] || {
		echo "Required Android SDK component is missing: $sdk_tool" >&2
		exit 1
	}
done

echo "Android SDK 35 toolchain verified at $sdk_root"
printf 'Use JAVA_HOME=%q ANDROID_HOME=%q for Android exports.\n' "$jdk_dir" "$sdk_root"
