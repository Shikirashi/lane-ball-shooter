# NO ACTIVE CODEX TASK — Awaiting Android device playtest

**Status:** P024 and P027 are COMPLETE for software delivery; P027's physical Android device acceptance remains PENDING (no device attached during Codex release). Do not start new source changes without an explicit follow-up from the user.

## Latest published releases

- **Web:** https://shikirashi.github.io/lane-ball-shooter/ — automated build/test and GitHub Pages cross-repo publishing GREEN on game Actions run `40246262499`. Portfolio Pages deployment `40246539248` succeeded after the homepage card change. The scoped publishing token is already configured; no further credential setup needed.
- **Android native APK:** https://github.com/Shikirashi/lane-ball-shooter/releases/download/android-v0.1.0/lane-ball-shooter-android.apk — published release `android-v0.1.0`, anchored to source commit `0e77dbdeadcab4fce4f4b3bf054d721ef479c5bf`, 26,807,776-byte ARM64 APK, GitHub SHA256 `cf390a1abbbbe3e8e937710e46a32aede297ddf43c0c41507d29549e8450ea26`. Codex validated the release signature, package metadata, ABI, permissions and asset download. Its private signing JKS and credentials were backed up to root-protected `/var/backups/lane-ball-shooter/` as the user confirmed.
- **Portfolio Android card:** https://shikirashi.github.io/ — portfolio commit `94c5e77` adds only one Lane Ball Shooter Mobile DOWNLOAD APK card, card CSS and actual-game screenshot; Pages `40246539248` succeeded and unrelated cards/Web files were retained.

## Outstanding user-only QA

On an actual ARM64 Android 7+ phone, download/install the APK (allow that source to install if prompted), start the game, verify landscape orientation, drag/release to shoot, SWAP button, sound, victory/restart and smooth performance. Note any notch/safe-area or touch bugs. Report the device model, Android version and issues to ChatGPT; create a narrow regression/fix task only if needed. Native Android had **not** been device-playtested at the last Codex handoff; do not claim otherwise.

## Task history

- P024 COMPLETE: `.ai/TASKS/LBS-P024.md`.
- P027 RELEASED, Android physical QA PENDING: `.ai/TASKS/LBS-P027.md`.
- Codex last handoff `.ai/CODEX_HANDOFF.md` documents local signing and APK validation.

**Safety:** Do not expose/recreate signing secrets, overwrite user-local Godot changes, alter existing portfolio content, or change game balance without a separate task. Future APK releases must keep the same signing identity, increment Android version code and publish a new release asset; GitHub APK sideloads do not auto-update.
