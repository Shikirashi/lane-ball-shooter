# QUEUED (NOT ACTIVE) — LBS-P038: Native Android main/pause/controls + monochrome v0.3.0 APK and portfolio refresh

**Status:** QUEUED. **Do not execute until P036 theme and P037 Android menus/guide are implemented, visually reviewed by ChatGPT and then P038 explicitly becomes the ONLY active task in `.ai/TASK.md`.** User authorized eventual Android release along with their 2026-10-28 menus/theme request; do not prematurely ship an incomplete APK.

## Objective

Publish an installable, same-signer, same-package release-signed **Android versionName `0.3.0`, versionCode `3`** containing BOTH (1) all Web/Android black-white UI chrome and (2) Android PLAY/CONTROLS main menu, accurate screenshot-based illustrated Classic/Side control guide and native pause flow from P037. Existing app ID `com.shikirashi.laneballshooter`, Android v0.1.0/v0.2.0 release assets, original protected keystore and backups preserved. On portfolio `Shikirashi/Shikirashi.github.io`, refresh the **existing one Android mobile download card** from immutable `android-v0.2.0` to the verified `android-v0.3.0` asset, update visible version label. No duplicate, no unrelated portfolio modifications; keep the nine-file playable Web game.

## Build and verification

- Follow P035's successful protected-toolchain/clean isolated checkout workflow documented in `.ai/TASKS/LBS-P035.md`, `scripts/build_android.sh`, `scripts/verify_android_release.sh`, `export_presets.cfg` and `scripts/ci/test_android_release_scaffolding.sh`. Same v0.1/v0.2 app signer SHA256 `796f2c679d962a8195ebf1a38d959002829561dfd26d2dae86e52ccdec7224fc`; **DO NOT regenerate keys** or touch the user's signing backups. Preserve correct JDK17, Android SDK, Godot 4.7.2 exact templates, ABI arm64-v8a only, landscape, original app package, absence of dangerous permissions and debuggable flag.
- Update BOTH Debug and Release Android preset version name/code to **0.3.0/3**, adapt strict existing static tests/verifier, run 31+ GDScript suites including P036/P037 new tests, clean export into ignored `exports/android`; verify `apksigner` v2/v3 signing, old/new public certificate fingerprint, zipalign, aapt manifest package/version, arm64, no unexpected permissions, deterministic SHA256/size, manual phone QA only on specifically authorized/connected device.
- Create public GitHub Release `android-v0.3.0` from **exact source SHA** with verified binary `lane-ball-shooter-android.apk`; keep v0.1/v0.2 tags/releases intact. Include release notes for new native menu/pause/control explanations, monochrome theme, user-approved mild bias, devices/QA limitations, SHA256, size and compatibility. Verify public binary bytes match build, HTTP download works, no fake links.
- Update only existing portfolio Android `apk-card` href and version caption in root `index.html`, after APK exists; preserve all other items, image, CSS, JS and Web directory; verify Pages run `SUCCESS`, actual public homepage link, downloadable APK hash, and currently playable Web boot/renderer after P036/P037.
- Update README and Codex handoff with commands, signature comparison, SHA256, Pages commit and run, Web status, package/version and pending physical Android install. Preserve all developer-local uncommitted project/scene/UID files. Do not work with Play Store, Web CI credentials, new signing key, gameplay balance, level design or branding. P038 completion is not a request for app auto-updates.
- Commit/push, STOP; ChatGPT will review. Codex must not modify ChatGPT-owned `AGENTS.md`, `.ai/TASK.md`, `.ai/TASK_LEDGER.md`, `.ai/DECISIONS.md`, roadmap or queued task archive.

## Exit gate

Same-signed version 0.3.0 with all P036/P037 UI, public validated Android APK plus existing portfolio download updated and verified, Web unchanged/working, automated tests PASS, physical phone QA honestly pending unless actually tested.
