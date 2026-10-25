# Codex Handoff — LBS-P027 Android APK release and portfolio card

**Status:** COMPLETE; PHYSICAL-DEVICE QA PENDING

**Branch:** `master`

## Published release

- GitHub Release: [android-v0.1.0](https://github.com/Shikirashi/lane-ball-shooter/releases/tag/android-v0.1.0)
- Direct asset: [lane-ball-shooter-android.apk](https://github.com/Shikirashi/lane-ball-shooter/releases/download/android-v0.1.0/lane-ball-shooter-android.apk)
- Source commit: `0e77dbdeadcab4fce4f4b3bf054d721ef479c5bf`
- Package/version: `com.shikirashi.laneballshooter`, `0.1.0`, version code `1`
- ABI: `arm64-v8a` only
- Minimum/target SDK: 24 / 36
- APK size: 26,807,776 bytes
- APK SHA-256: `cf390a1abbbbe3e8e937710e46a32aede297ddf43c0c41507d29549e8450ea26`
- Certificate SHA-256: `796f2c679d962a8195ebf1a38d959002829561dfd26d2dae86e52ccdec7224fc`

The APK was exported from a fresh isolated clone of exact source commit `0e77dbd`, not the dirty developer checkout. Godot 4.7.2 used the existing backed-up JKS and protected environment; no signing key was generated or replaced. The release uses APK signature schemes v2 and v3, one 4096-bit RSA signer, is non-debuggable, requests no runtime permissions reported by `aapt`, is zip-aligned, has only the two expected ARM64 native libraries, and declares landscape activity orientation. Downloading the public versioned asset reproduced the exact hash, size and signing certificate.

No Android device was connected. Installation, native startup, landscape controls, audio, restart and performance checks are accurately marked pending rather than claimed.

## Source changes

- `3a2d212` fixes the Chrome profile cleanup race in `scripts/ci/verify_browser_startup.mjs`: it waits for Chrome exit, applies bounded TERM/KILL fallback, then retries safe removal. Secure context, exact title, one nonzero canvas and loader-removal assertions are unchanged.
- `0e77dbd` enables ETC2/ASTC imports required by Godot Android export. Only this new setting was staged; pre-existing user changes in `project.godot` remain uncommitted.
- Godot's user-local Java SDK setting now points at the existing Temurin 17 toolchain; Android SDK remains `/home/shiki/Android/Sdk`.
- README records the immutable APK URL, hashes, source/version/device support and upgrade/signing limitations.

## Portfolio publication

- Portfolio commit: `94c5e77a19ee3c9cf1411bb2f08d763ce8ffc15b` on `Shikirashi/Shikirashi.github.io/master`.
- Pages run: [40246539248](https://github.com/Shikirashi/Shikirashi.github.io/actions/runs/40246539248), successful.
- Added exactly one `item mobile col-sm-6 col-md-4 col-lg-4 mb-4` card inside the existing grid.
- Card uses the immutable versioned APK URL, accessible label/alt text, a visible `DOWNLOAD APK` badge, hover styling and keyboard `:focus-visible` treatment.
- `assets/img/laneBallShooter.png` is a 900×506 crop of an actual current gameplay frame captured from the public Godot game with headless Chrome. Public and committed image SHA-256 values match: `ed59c954aa79d053cf9a452057e62c32f82b95835bdd53dafd632c8f3dde2ba7`.
- All previous cards and nested Web runtime files were preserved. A concurrent P024 nested-Web deployment was rebased underneath the card commit rather than overwritten.

## Validation

- Full local P001–P023 suite: **all 23 passed**, including P011's 16,485-check deterministic stress test.
- Release build and `scripts/verify_android_release.sh`: **PASS**.
- `apksigner verify --verbose --print-certs`: **PASS**, v2/v3, expected certificate.
- `aapt dump badging/xmltree`: expected package/version, SDK 24/36, ARM64-only, landscape, no debuggable flag or listed runtime permissions.
- Public asset download: HTTP attachment, expected APK MIME, exact 26,807,776-byte size/hash/signature.
- Browser verifier local live-HTTPS run: strict assertions **PASS** and no new temporary Chrome profile remained.
- P024 hosted run [40246262499](https://github.com/Shikirashi/lane-ball-shooter/actions/runs/40246262499): **SUCCESS**, confirming the cleanup-race repair in CI.
- Portfolio Pages run `40246539248`: **SUCCESS**; public card markup and byte-identical thumbnail verified over HTTPS.
- Physical Android test: **PENDING — no connected device**.

The backed-up release key and credentials remain outside Git. Existing `project.godot`, `scenes/main.tscn` and `.uid` working files remain preserved. Stop after P027; do not advance the mailbox.
