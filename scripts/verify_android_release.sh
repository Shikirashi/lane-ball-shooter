#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
	echo "Usage: $0 PATH_TO_APK" >&2
	exit 2
fi

apk_path="$(realpath "$1")"
if [[ ! -s "$apk_path" ]]; then
	echo "APK is missing or empty: $apk_path" >&2
	exit 1
fi

sdk_root="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}"
if [[ -z "$sdk_root" || ! -d "$sdk_root/build-tools" ]]; then
	echo "Set ANDROID_HOME (or ANDROID_SDK_ROOT) to an Android SDK containing build-tools." >&2
	exit 1
fi

build_tools="$(find "$sdk_root/build-tools" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort -V | tail -n 1)"
if [[ -z "$build_tools" ]]; then
	echo "No Android build-tools installation found under $sdk_root/build-tools." >&2
	exit 1
fi

tool_dir="$sdk_root/build-tools/$build_tools"
for tool_name in apksigner aapt zipalign; do
	if [[ ! -x "$tool_dir/$tool_name" ]]; then
		echo "Required Android tool is missing: $tool_dir/$tool_name" >&2
		exit 1
	fi
done

signer_report="$($tool_dir/apksigner verify --verbose --print-certs "$apk_path")"
printf '%s\n' "$signer_report"
if ! grep -q '^Verifies$' <<<"$signer_report"; then
	echo "APK signature verification did not report success." >&2
	exit 1
fi
if grep -Eqi 'Android Debug|androiddebugkey' <<<"$signer_report"; then
	echo "Refusing an APK signed with an Android debug certificate." >&2
	exit 1
fi

badging="$($tool_dir/aapt dump badging "$apk_path")"
package_line="$(grep -m1 '^package:' <<<"$badging")"
native_line="$(grep -m1 '^native-code:' <<<"$badging" || true)"
sdk_line="$(grep -m1 '^sdkVersion:' <<<"$badging" || true)"
printf '%s\n' "$package_line" "$sdk_line" "$native_line"

grep -q "name='com.shikirashi.laneballshooter'" <<<"$package_line" || {
	echo "Unexpected Android package identifier." >&2
	exit 1
}
grep -q "versionCode='2'" <<<"$package_line" || {
	echo "Unexpected Android version code." >&2
	exit 1
}
grep -q "versionName='0.2.0'" <<<"$package_line" || {
	echo "Unexpected Android version name." >&2
	exit 1
}
[[ "$native_line" == "native-code: 'arm64-v8a'" ]] || {
	echo "APK must contain only the arm64-v8a native ABI." >&2
	exit 1
}
if [[ -z "$sdk_line" ]]; then
	echo "APK does not report a minimum Android SDK version." >&2
	exit 1
fi
if grep -q '^application-debuggable' <<<"$badging"; then
	echo "Refusing a debuggable APK." >&2
	exit 1
fi

"$tool_dir/zipalign" -c -v 4 "$apk_path" >/dev/null

dangerous_permissions='android.permission.(READ_EXTERNAL_STORAGE|WRITE_EXTERNAL_STORAGE|MANAGE_EXTERNAL_STORAGE|CAMERA|RECORD_AUDIO|ACCESS_FINE_LOCATION|ACCESS_COARSE_LOCATION|READ_CONTACTS|WRITE_CONTACTS|READ_SMS|SEND_SMS|READ_PHONE_STATE|CALL_PHONE)'
permissions="$(grep '^uses-permission:' <<<"$badging" || true)"
if [[ -n "$permissions" ]]; then
	printf '%s\n' "$permissions"
fi
if grep -Eq "$dangerous_permissions" <<<"$permissions"; then
	echo "APK requests an unexpected sensitive permission." >&2
	exit 1
fi

sha256sum "$apk_path"
stat --printf='APK size: %s bytes\n' "$apk_path"
echo "Android release verification passed."
