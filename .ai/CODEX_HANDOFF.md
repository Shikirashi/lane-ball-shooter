# Codex Handoff — LBS-P027 Android toolchain continuation

**Status:** PARTIAL / BLOCKED AT USER-ACCEPTED ANDROID SDK LICENSE CHECKPOINT

**Branch:** `master`

P027's user-local JDK, Godot Android templates and explicitly authorized release-signing identity are now installed. The Android SDK packages could not be installed without accepting new Google terms, which this task explicitly prohibited Codex from doing. No APK, GitHub Release, portfolio image/card, or placeholder download URL was created.

## Installed locally

- Eclipse Temurin JDK `17.0.21+9`, including `javac`, at `/home/shiki/.local/share/lane-ball-shooter/toolchains/temurin-17.0.21+9`.
- Official Godot 4.7.2 `android_debug.apk` (127,260,725 bytes) and `android_release.apk` (104,803,333 bytes) under `/home/shiki/.local/share/godot/export_templates/4.7.2.stable/`.
- The pre-existing `web_nothreads_debug.zip` and `web_nothreads_release.zip` were preserved byte-for-byte. Their SHA-256 values remain `08962aef...626a0` and `d3ee2f08...032a0`.
- Dedicated Lane Ball Shooter JKS at `/home/shiki/.local/share/lane-ball-shooter/signing/lane-ball-shooter-release.jks`, created only after the user's explicit approval. Directory mode is `0700`; keystore and credentials are both `0600`.
- Protected environment file at `/home/shiki/.local/share/lane-ball-shooter/signing/release-signing.env`. Its secret was generated randomly and was neither printed nor committed.
- Key alias `lane-ball-shooter`: 4096-bit RSA, SHA256withRSA, valid 2026-10-26 through 2054-03-13. Public certificate SHA-256 fingerprint: `79:6F:2C:67:9D:96:2A:81:95:EB:F1:A3:8D:95:90:02:82:95:61:DF:D2:6D:2D:AE:86:E5:2C:CD:EC:72:24:FC`.

The user must securely back up the JKS and credentials file together. Losing them prevents compatible APK upgrades; neither belongs in Git or chat.

## Repository changes

- Added `scripts/setup_android_toolchain.sh`, pinning and verifying both upstream archives:
  - Godot template archive SHA-256 `f298490b8d44d934be425a5a65a51bf15f422428b229a06a6e11d9ffea248011`.
  - Temurin JDK archive SHA-256 `8b9b611d917e3dfd8419d3566b5949226f69b052fed7e109c1368add1dfe8711`.
- The setup script uses only user-local directories, refuses root, preserves existing template files, installs Android templates atomically, and is idempotent from its verified cache.
- It installs `platform-tools`, `build-tools;35.0.1`, and `platforms;android-35` only when official command-line tools and an existing license receipt are present. It never invokes sudo or automatically accepts licenses.
- Added `scripts/ci/test_android_toolchain_setup.sh` for pinned versions/checksums and no-sudo/no-auto-accept policy.
- Updated README with installed paths, backup warning, certificate fingerprint, exact license checkpoint and post-license commands.
- Existing release preset/build/verifier from `75f0dd7` were not reimplemented. P024 workflow and publisher remain unchanged.

## Required user action

1. Review Google's current Android SDK terms and download/install the official Linux command-line tools so this file exists:
   `/home/shiki/Android/Sdk/cmdline-tools/latest/bin/sdkmanager`
2. Personally accept the applicable licenses:

   ```sh
   /home/shiki/Android/Sdk/cmdline-tools/latest/bin/sdkmanager \
     --sdk_root=/home/shiki/Android/Sdk --licenses
   ```

3. Rerun `./scripts/setup_android_toolchain.sh`. It will install and verify platform-tools, build-tools 35.0.1 and android-35 without piping license answers.
4. Back up `/home/shiki/.local/share/lane-ball-shooter/signing/` to secure offline storage before producing the first public APK.

After that checkpoint, configure Godot's Android SDK and Java SDK paths, export from a separate clean checkout using the protected signing environment, run static APK verification and physical-device QA, and only then publish the release/card. Do not use the dirty developer checkout for a release.

## Validation

- Official archive checksums: **PASS**.
- Temurin `java` and `javac`: **17.0.21**, PASS.
- Release key and public certificate metadata: **PASS**.
- Repeated toolchain setup: **idempotent**, stops with exit 3 at the missing command-line-tools/license checkpoint.
- Existing Web template before/after hashes: **identical**.
- `test_android_toolchain_setup.sh`: **PASS**.
- Existing `test_android_release_scaffolding.sh`: **PASS**.
- Shell syntax and `git diff --check`: **PASS**.
- Full Godot P001–P023 regression suite: **all 23 passed**, including P011's 16,485-check stress test.
- Android SDK/APK/static signature validation: **BLOCKED** until the user completes the license checkpoint.
- Physical Android QA: **PENDING**; no device was attached previously.
- Portfolio repository remains clean and unchanged; all cards and Web runtime files are preserved.

Pre-existing user modifications to `project.godot`, `scenes/main.tscn`, and untracked `.uid` files remain untouched and must not be included in this commit. Stop at P027; do not advance the mailbox.
