#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
release_dir="${1:-$repo_dir/exports/web}"
test_root="$(mktemp -d "${TMPDIR:-/tmp}/lane-ball-shooter-publish-test.XXXXXX")"
trap 'rm -rf "$test_root"' EXIT

portfolio_dir="$test_root/portfolio"
mkdir -p "$portfolio_dir/lane-ball-shooter" "$portfolio_dir/existing-demo"
git -C "$portfolio_dir" init -q -b master
git -C "$portfolio_dir" config user.name "CI Test"
git -C "$portfolio_dir" config user.email "ci-test@example.invalid"
printf '%s\n' '<h1>Portfolio home</h1>' > "$portfolio_dir/index.html"
printf '%s\n' '<h1>Existing demo</h1>' > "$portfolio_dir/existing-demo/index.html"
printf '%s\n' 'placeholder' > "$portfolio_dir/lane-ball-shooter/.gitkeep"
git -C "$portfolio_dir" add .
git -C "$portfolio_dir" commit -q -m baseline
home_before="$(sha256sum "$portfolio_dir/index.html" "$portfolio_dir/existing-demo/index.html")"

"$repo_dir/scripts/ci/publish_portfolio_release.sh" "$release_dir" "$portfolio_dir" "test-source-sha"
home_after="$(sha256sum "$portfolio_dir/index.html" "$portfolio_dir/existing-demo/index.html")"
[[ "$home_before" == "$home_after" ]]
if git -C "$portfolio_dir" status --porcelain=v1 --untracked-files=all | cut -c4- | grep -Ev '^lane-ball-shooter/' | grep -q .; then
	echo "Publication test changed a path outside lane-ball-shooter/." >&2
	exit 1
fi
"$repo_dir/scripts/ci/validate_web_release.sh" "$portfolio_dir/lane-ball-shooter"

broken_release="$test_root/broken-release"
cp -a "$release_dir" "$broken_release"
rm "$broken_release/index.pck"
if "$repo_dir/scripts/ci/validate_web_release.sh" "$broken_release" >/dev/null 2>&1; then
	echo "Incomplete release unexpectedly passed validation." >&2
	exit 1
fi

failure_portfolio="$test_root/failure-portfolio"
git clone -q "$portfolio_dir" "$failure_portfolio"
if "$repo_dir/scripts/ci/publish_portfolio_release.sh" \
	"$broken_release" "$failure_portfolio" "broken-source" >/dev/null 2>&1; then
	echo "Incomplete release unexpectedly reached portfolio staging." >&2
	exit 1
fi
[[ -z "$(git -C "$failure_portfolio" status --porcelain=v1 --untracked-files=all)" ]]

printf 'Publication safety and failure-path tests passed.\n'
