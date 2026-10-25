# Codex Handoff — LBS-P027 Android release and portfolio download card

**Status:** SAFE SCAFFOLDING COMPLETE; RELEASE BLOCKED BY REQUIRED SIGNING/TOOLCHAIN CHECKPOINT

**Branch:** `master`

P027 cannot safely publish an APK on this workstation yet. No approved Android release keystore exists, the configured Android SDK path is absent, Android build-tools (`apksigner`, `aapt`, `zipalign`) are unavailable, and the installed Godot 4.7.2 template directory contains only Web templates. Per the task, no keystore was generated without approval, no unsigned/debug-signed APK was published, no GitHub Release was created, and no portfolio card/dead link was added.

## Implemented scaffolding

- Added a separate `Android Release` preset while preserving the Web and `Android Debug` presets. It exports only ARM64 to `exports/android/lane-ball-shooter.apk`, uses package `com.shikirashi.laneballshooter`, version name `0.1.0`, version code `1`, release signing, landscape project configuration and Compatibility rendering. Signing fields remain empty in source.
- Added `scripts/build_android.sh`. It requires Godot 4.7.2, the matching official Android release template, configured Android SDK/JDK, a clean source tree and the three documented Godot release-signing environment variables. It rejects absent/in-repository/debug keys and never prints the password.
- Added `scripts/verify_android_release.sh`. It runs `apksigner`, `aapt` and `zipalign`; rejects invalid/debug signatures, debuggable packages, wrong package/version, non-ARM64 ABIs, missing minimum SDK and sensitive permissions; then prints SHA-256 and size.
- Added `scripts/ci/test_android_release_scaffolding.sh`, covering the scoped release preset, package/version/ABI/signing configuration, landscape/Compatibility settings, empty committed secret fields and fail-closed behavior without signing credentials.
- Extended `.gitignore` for JKS/keystore/PKCS#12 key containers. APK/AAB/build output was already ignored.
- Updated README with exact secure setup/build/publication steps, sideload/upgrade limitations and the honest blocked status.
- Verified `.github/workflows/publish-web.yml` and `scripts/ci/publish_portfolio_release.sh` have no diff. P024's missing `PORTFOLIO_PUBLISH_TOKEN` was not configured or otherwise touched.

## Required user action

1. Install the official Godot 4.7.2 Standard Android export template so `~/.local/share/godot/export_templates/4.7.2.stable/android_release.apk` exists.
2. Install/configure an Android SDK with platform-tools, a supported platform and build-tools providing `apksigner`, `aapt` and `zipalign`; configure the same Android SDK and JDK paths in Godot.
3. Either authorize an existing dedicated release key or create one interactively outside both repositories. The README gives a no-password-on-command-line `keytool` command. Back up the key and password securely; Godot currently requires matching key/store passwords. Never paste the secret into chat.
4. Set `ANDROID_HOME`, `JAVA_HOME`, `GODOT_ANDROID_KEYSTORE_RELEASE_PATH`, `GODOT_ANDROID_KEYSTORE_RELEASE_USER` and `GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD` locally, then run `./scripts/build_android.sh` from a clean checkout.
5. Connect an ARM64 Android device and validate install/startup, landscape layout, shooting, swap, SFX, restart and performance. No device is currently attached.

After these prerequisites exist, publish only the verified bytes as GitHub Release asset `lane-ball-shooter-android.apk` on a non-prerelease release. Record the source commit, version/code, SHA-256, ARM64 restriction and sideload warning. Confirm the release download byte-for-byte before adding `assets/img/laneBallShooter.png` and the requested `item mobile ...` card to the portfolio. The intended stable link is `https://github.com/Shikirashi/lane-ball-shooter/releases/latest/download/lane-ball-shooter-android.apk`, but it must not be presented until it resolves to the verified asset.

GitHub CLI is authenticated with repository release permission, so no additional GitHub credential appears necessary once the APK exists. This does not substitute for the missing Android signing identity and is separate from P024's unconfigured cross-repository token.

## Validation

- Godot `4.7.2.stable.official.ed1daf0bf` full regression run: **all 23 P001–P023 suites passed**, including the P011 16,485-check stress suite.
- Android scaffolding test: **PASS**.
- Shell syntax for all three new scripts: **PASS**.
- `git diff --check`: **PASS**.
- P024 workflow/publisher unchanged check: **PASS**.
- ADB device query: daemon started, **zero devices attached**; on-device QA remains pending.
- Release build/signature/badging/hash: **BLOCKED**, because the signing key, SDK/build-tools and Android export template are absent.
- Portfolio repository `Shikirashi/Shikirashi.github.io`: `master` clean and current; no files changed, so there is no portfolio commit. Existing cards and all nine Web runtime files remain untouched.
- GitHub Release/download test and Pages card/touch/keyboard/filter checks: **BLOCKED** until the verified APK exists. There is no release tag, asset URL, APK hash or APK byte size to report.

Pre-existing user modifications to `project.godot`, `scenes/main.tscn` and untracked Godot `.uid` files were preserved and excluded from the P027 commit. ChatGPT-owned mailbox documents were not edited. Stop at P027; do not advance the mailbox.
