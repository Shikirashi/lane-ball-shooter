# Lane Ball Shooter

A fully 2D lane-defense game prototype in **Godot 4 / GDScript**, targeting Web and Android (landscape).

- 2D Zuma-like moving ball chain, shooter-mounted two-ball ammunition preview and compact swap control.
- Four responsive 2D combat lanes with baked defenders, animated enemies and procedural effects.
- Matches activate same-color defender attacks; successive matches build combo/fever.
- Balls remain physically simulated beyond the left edge and can roll back into view after a match; defenders have an emergency lane clear and require matching-color revival.
- Defeated enemies burst, tumble sideways and fade before the delayed victory presentation.

## Codex development mailbox
This repository uses a shared mailbox: read [AGENTS.md](AGENTS.md) first, then `.ai/PROTOCOL.md`, `.ai/DECISIONS.md`, `.ai/TASK_LEDGER.md`, and the current `.ai/TASK.md`. Codex implements the active task and writes `.ai/CODEX_HANDOFF.md`.

## Run the prototype

Open the folder in Godot 4.x and run the project, or launch it from a terminal:

```sh
godot --path .
```

The project uses GDScript and the Compatibility renderer. Live gameplay uses Godot 2D drawing plus transparent sprites baked from the project's original procedural character models; there are no external assets or add-ons.

## P034A–P034C sprite bake and live 2D battlefield

The live battlefield is entirely `Control`/`Node2D`/`Sprite2D`; ordinary startup creates no `SubViewport`, `Camera3D`, `WorldEnvironment` or 3D character/projectile node. It uses the eight authentic transparent 512×512 RGBA masters baked in P034A from the original procedural meshes and materials: four enemy types and the red, blue, yellow and green defenders. The original factory and baker remain available only to regenerate those source-faithful assets.

Run the baker from a real graphical rendering environment with Godot 4.7.2 Compatibility rendering:

```sh
./scripts/bake_actor_sprites.sh
```

It waits for completed rendered frames from a transparent 4×-MSAA `SubViewport`, then writes the individual PNGs, grounded pivot/alpha-bound metadata, and the checkerboard review sheet at `assets/sprites/baked/contact_sheet.png`. The wrapper deliberately refuses an environment with neither `DISPLAY` nor `WAYLAND_DISPLAY`; Godot's dummy headless renderer is not a valid capture result. On a CI machine, provide a safe offscreen OpenGL display such as an already-installed Xvfb service.

P034C removes the old yellow `ChargeOrb` from the procedural defender source and genuinely rebakes all four defender masters without it. The live battlefield adds a separate faceted diamond crystal behind each defender, tinted to that lane's team color. Its authoritative one-use emergency discharge hides the intact crystal and emits seven short-lived spinning/fading shards; revival does not restore it, while a run restart does. The defender sprite remains at its original full color in both `CHARGE` and `SPENT` states.

Launch the isolated, pure-2D squash/stretch study with:

```sh
godot --path . res://scenes/previews/p034a_sprite_preview.tscn
```

The isolated P034A preview remains available for studying the masters, but gameplay now uses the same PNGs and grounded pivots directly. `LaneCombatModel` and the existing `Battlefield` director remain authoritative: the 2D renderer follows their world-X positions, hop phases, Snake transfers, hit/death state, projectiles, quotas and victory timing without a parallel rules engine. Hopper squash/hop, Heavy weight, Snake wiggle/row transfer and Healyzard idle/glow are lightweight visual deformation only.

Generate the required real-renderer gameplay review captures with:

```sh
./scripts/capture_p034b_gameplay.sh
```

This CLI-only command requires an existing `DISPLAY` or `WAYLAND_DISPLAY`, runs Godot 4.7.2 with the Compatibility renderer, waits for completed rendered frames, and writes `assets/previews/p034b_gameplay_1280x720.png` plus `assets/previews/p034b_gameplay_1600x720.png`. Both committed captures show the real `main.tscn` runtime with deterministic enemies/effects—not a mockup. The normal game itself contains no capture viewport.

Regenerate the P034C intact/spent and mid-shatter review evidence with:

```sh
./scripts/capture_p034c_crystals.sh
```

It writes `assets/previews/p034c_crystal_states_1280x720.png` and `assets/previews/p034c_crystal_shatter_1600x720.png` from real deterministic gameplay state. Its `SubViewport` is capture-only and is never created by ordinary gameplay.

Native desktop and Android builds enter gameplay immediately. The Web export instead boots to a dark `LANE BALL SHOOTER` menu without constructing the gameplay scene or advancing its simulation. `START GAME` opens the exact prompt `Play in fullscreen?`: `YES` requests browser fullscreen directly from that button press and then starts the game, while `NO` starts in the page canvas without requesting fullscreen. A browser may deny fullscreen; gameplay still starts normally. Escape/browser fullscreen exit uses the normal responsive resize path. For desktop-only menu preview, run `godot --path . -- --web-menu-preview`.

Controls:

- Move the mouse horizontally to position the shooter; left-click in the playfield to fire.
- Right-click or press Space to swap the loaded and next balls.
- On touch devices, press and drag in the playfield, then release to fire once. Tap the circular two-arrow HUD control to swap without firing.
- Press F3 to show or hide live ball/segment/gap diagnostics, including retained-left count/position, active population, unsupported segments, gravity speed/displacement, fresh generation and invariant violations.
- Press M to mute or unmute procedural sound effects.
- After a lane breach or cleared wave, press R or use the on-screen RESTART button to begin a fresh run.

The layout targets landscape screens and has automated coverage at 960×540, 1280×720, 1600×720 and 2400×1080. Native safe-area information is used when the platform supplies it; Web falls back to the browser canvas with an additional logical edge margin. The four balanced lane rows fill the area from two pixels below the conveyor to just above the shooter muzzle, and their authoritative world-X span uses 5.5% internal side margins. The shooter track spans the chain's full safe width with symmetric 24-pixel edge margins, so both edge balls are targetable. The large loaded ball and a smaller symbol-bearing NEXT ball travel together on the shooter. The old magazine panel is replaced by one circular 56×56 two-arrow swap control in the upper-right safe HUD, completely outside the firing playfield.

Player-fired balls cross from their launch position to the upper lane in 0.20 seconds at every supported landscape height. Each shot locks its launch X and identity, while the 0.4-second firing cooldown remains unchanged.

The top lane is a functional ordered chain moving right-to-left at 102 pixels/second. This P016 playtest speed is three times the former 34 px/s baseline; it does not change the 0.20-second vertical shot, enemy movement or virtual-gravity tuning. The chain's authoritative physics state is an ordered list of rigid connected segments: each segment owns one anchor plus persistent UID/color members at exact 58-pixel slots. The `balls` array consumed by drawing is derived from those anchors rather than moved independently. Gap edges hold real distance and stable left/right segment IDs; their CAUSAL/FEED type records whether a later reconnection may cascade, but no longer selects a movement motor. One deterministic integration/constraint pass moves segments and clamps contact before any merge. Logical and rendered neighbors therefore remain ordered and non-overlapping through rapid insertions, simultaneous falls, feed arrivals and cascades.

A shot must horizontally overlap a visible ball using the physical 22-pixel chain radius plus the projectile's 12-pixel radius. On contact, an accepted shot becomes a real UID-addressed member immediately. Because the conveyor flows right-to-left, insertion opens one legal slot by pushing the existing LEFT/front prefix exactly 58 pixels LEFT in the normal flow direction; the old RIGHT/trailing suffix remains at its world X and is never shoved backward. At a typed segment seam, every preceding segment receives the same leftward slot displacement, preserving the FEED/CAUSAL gap's identity, width and segment state. A short scale-in supplies visual settling without changing authoritative center spacing. Its player-caused match check waits exactly 0.05 seconds of gameplay simulation time, so the completed group remains visible before its first pop. During those 50 ms the stable UID is drawn exactly once by an unmasked insertion overlay; at settlement it transfers atomically to the conveyor-only clipped layer. Loaded, next and traveling shot visuals remain owned by the unmasked shooter layer. The insert/plop cue occurs at contact; match scoring, combo progression, defender response and match SFX occur only when that delayed check actually removes a group.

A successful clear preserves the removed balls' spatial gap. Conveyor motion uses one virtual-gravity rule for every gap: the rightmost source-connected segment is the pusher-driven train and moves LEFT at 102 px/s, while every unsupported segment to its left falls RIGHT as a whole rigid group, starting at 60 px/s, accelerating at 900 px/s² and capping at 420 px/s. On contact, support propagates from right to left and the merged train resumes normal conveyor motion. The non-overlap solver clamps every contact at exact spacing, so even simultaneous gaps cannot compress or pass balls through one another. CAUSAL contacts are resolved before unrelated FEED contacts; only a player-caused edge may turn matching contact colors into a cascade and emit a later match event. A FEED reconnection physically closes by the same gravity but never auto-matches. Simulation is event-bounded at settle deadlines and subdivided to at most 1/60 second, preserving insert → pause → initial pop → gravity fall → contact cascade order even for a larger update.

Gravity is universal, but matching remains player-causal rather than a passive board scan. The independent fresh feeder intentionally builds same-color runs using weights of 20%, 30%, 18%, 13%, 9%, 6% and 4% for lengths 1 through 7. Pairs are common and runs of four to seven are valid, but pre-existing groups never clear merely because they spawn, move or make noncausal contact. Only a matching player insertion starts a clear and its causally linked physical cascades. The magazine remains a separate fair four-color shuffle bag.

The conveyor is physically continuous beyond both viewport edges. A ball crossing LEFT is not removed, cached, teleported or recreated: its original UID, color, order, spacing and signed world position remain in the authoritative rigid segment at `x < 0`. It stays clipped while wholly outside the lane. If a later player match opens a gap to that section's RIGHT, the same unsupported group accelerates RIGHT under virtual gravity and progressively reappears through the LEFT mask before reconnecting. If no physical gap removes its right-side support, the hidden connected train simply continues LEFT; an unrelated event does not summon it to the boundary. Hidden balls cannot be targeted by player shots.

The right feeder now creates only NEW weighted-run colors. Each fresh center begins at `lane_width + radius + 4`, placing its entire 22-pixel-radius circle beyond RIGHT, then enters at 102 px/s through the conveyor-only mask. Event-bound admission keeps 30/60/120 fps and larger deltas deterministic. The automatic cap of 24 applies only to balls whose circles have not fully cleared LEFT, including the single right entrant; retained left history does not starve fresh generation. Total logical history can therefore grow during a very long no-match run. Storage and snapshot validation are linear in retained balls, while movement/contact work remains segment-based; balls are deliberately never discarded merely for distance. FEED contact never initiates a match.

The canonical palette is shared by balls, magazine/shooter, lane stripes, defenders and projectiles. BLUE is a saturated `#3677E8` and GREEN an emerald `#37C45A`; neutralized battlefield ambient light preserves that distinction. DOT/SQUARE/TRIANGLE/DIAMOND symbols and enlarged lane status labels remain the redundant non-color identity channel.

Matches award score and advance the three-second combo window through tiers 1–3; the fourth consecutive timely match activates FEVER. The HUD meter drains in real time, while score persists through timeout. Magazine colors come from a fair four-color shuffle bag.

Each match also activates its matching 2D defender using the tier locked at match time. Tier 1 fires one ordinary projectile for exactly 1 damage and stops at the first enemy it touches. Tier 2 fires one penetrating projectile that deals 1 damage once to every enemy it physically passes in the matched lane. Tier 3 and FEVER fire one wide penetrating wave across the matched lane plus one adjacent lane selected once at launch; each encountered enemy takes 1 damage once. Middle lanes choose either neighbor with a separately seeded 50/50 attack RNG, while edge lanes have only one valid neighbor. Every penetrating projectile keeps a set of immutable global spawn IDs, so overlap across frames—and a Sickle Snake transferring between both targeted lanes—cannot cause a second hit from the same attack. Enemies which spawn behind a wave after it has passed are unaffected. A down origin defender still receives revival progress instead of attacking.

Enemy HP is logical and intentionally has no bar, pip, number or health-driven sprite. The baked 2D roster shares one authoritative `EnemyTypes` definition:

| Enemy | HP | Movement | Baked 2D appearance |
|---|---:|---|---|
| Hopper | 6 | Original grounded pause/airborne hop averaging 0.312 units/s | Original gray silhouette with exactly two permanent orange top horns |
| Heavy | 12 | Continuous ground slide at 0.2184 units/s (0.7×) | Wider dark-orange Hopper construction, no horns |
| Sickle Snake | 6 | Continuous ground slide at 0.624 units/s (2×) | Taller strong-yellow construction, no horns |
| Healyzard | 6 | Stationary in a reserved rear support slot | Green 0.7-scale construction, no horns |

Only Hopper receives hop height and landing squash; projectile collision uses the matching piecewise-hop, constant-slide or stationary swept model. All variants remain hittable throughout their movement, retain ordinary hit flash and use the existing explosion, sideways fall, fade and death cue. Healyzards use distinct rear X slots so multiple supports do not overlap each other or the right-edge entrance, and their presence does not stop normal spawns.

P023 raises the single authoritative moving-enemy baseline by 30%, from 0.24 to 0.312 units/s. Heavy and Sickle Snake retain their 0.7× and 2× multipliers, while Healyzard remains at zero. Hopper's 0.55-second grounded dwell and 0.75-second airborne phase are unchanged; only horizontal travel during the airborne phase is faster.

Live-game spawning is directed once at Battlefield level with a separately seeded/reseeded RNG. Base type weights are Hopper 50%, Heavy 20%, Sickle Snake 20% and Healyzard 10%, including the four initial enemies. At most one Sickle Snake may live across all four lanes. After it is neutralized by projectile, tier-3 or emergency clear, another becomes eligible exactly 15 gameplay seconds later. While Snake is ineligible it is removed from the draw and the remaining original weights renormalize to 50:20:10; therefore a finite 32-enemy encounter is not guaranteed to exhibit the raw base percentages. Spawn IDs are globally unique while combat/visual UIDs remain stable within their lane.

After a nonfatal hit, Sickle Snake stops immediately for exactly 0.5 simulation seconds, then transfers to a randomly selected adjacent lane. Edge lanes can only move inward; middle lanes use a separately seeded 50/50 direction RNG. If the preferred neighbor already has five enemies, Snake tries its other adjacent neighbor or waits motionless until capacity opens. Logical ownership switches atomically at transfer start, while its existing sprite slides smoothly between lane rows over 0.3 seconds and remains targetable in the destination. Its immutable global spawn ID, X, HP, original quota charge and global occupancy remain unchanged; only a collision-safe destination-local UID is remapped.

Each Healyzard owns an independent 15-second simulation timer. Every pulse targets all other non-Healyzard enemies currently in its lane, restores one HP up to each target's own maximum, and emits an event even when zero HP is restored. It never heals itself, another Healyzard or another lane. A reusable `Sprite2D` behind each healer displays a soft generated yellow radial gradient for 0.85 seconds, expanding and fading to its transparent circumference without external artwork or a new sound cue.

Each lane has a configurable encounter budget, initially eight enemy spawns including its starting enemy: 32 scheduled enemies overall. A full lane defers its remaining quota instead of consuming it, and no lane spawns a ninth enemy. The HUD reports neutralized enemies against the scheduled total. When an enemy reaches an active defender, that defender falls and spends its one emergency discharge to clear the lane instantly, regardless of the enemies' remaining HP. This one-use emergency is intentionally separate from the nonlethal tier-3 wave. A down defender needs two separate matches of its own color to revive; those matches still score and build combo but launch no attack. Later knockdowns do not clear enemies. Any live enemy crossing the far-left boundary ends the run immediately and shows GAME OVER. Every projectile or emergency neutralization transfers the actual enemy sprite into a one-second cosmetic actor: a small 2D explosion and sparks lead into a roughly 85-degree sideways fall, then body and shadow fade completely. Logical collision ends immediately, while this visual layer continues updating even after combat freezes.

Once all four spawn budgets are exhausted and all remaining enemies are neutralized, authoritative victory immediately freezes shooting, swapping, chain motion, combat, spawning, attacks and scoring. WAVE CLEARED remains hidden for exactly 3.0 seconds of deterministic game time so the last death animation and synthesized cue can finish, then displays `All enemies neutralized`, the final score and restart control. A breach still shows GAME OVER immediately with `The lane was breached`. Restart cancels any pending victory countdown and removes transient death actors.

Eight soft-arcade SFX are synthesized in memory as 22.05 kHz, mono, 16-bit PCM: shoot, successful insert, swap, match, tier-aware defender attack, knockdown, revival, and a distinct 0.38-second enemy-death explosion/pop/crunch. They use short sine/triangle tones with gentle envelopes, a -15 dB playback level, a 0.28 PCM peak cap, and a bounded ten-voice stealing pool that controls multi-kill polyphony. The neutralization event is emitted once per enemy before terminal victory can disable gameplay audio, including tier-3 and emergency groups. No audio files, plugins, or runtime dependencies are required. Headless runs generate and validate the clips but skip device playback; actual timbre and loudness still require listening on desktop, Web, and Android.

## Export

The committed `export_presets.cfg` contains `Web`, `Android Debug`, and `Android Release` presets. Install the **Godot 4.7.2 Standard** export templates matching the editor build before exporting. Mono templates do not satisfy this GDScript editor's template lookup.

Web export, packaging, and local serving:

```sh
./scripts/build_web.sh
python3 -m http.server 8765 --bind 127.0.0.1 --directory exports/web
```

The build helper runs the equivalent export command `godot --headless --path . --export-release "Web" exports/web/index.html`, verifies the HTML/WASM/PCK set, and creates `exports/lane-ball-shooter-web.zip`. The ZIP root contains `index.html` and all companion runtime files, with no extra `web/` directory. Both `exports/web/` and the ZIP are local ignored build artifacts and are deliberately not committed.

Open `http://127.0.0.1:8765/`. Do not open `index.html` directly with a `file://` URL: WASM/PCK loading requires an HTTP server. The preset uses Godot's single-threaded Web template and Compatibility renderer, so cross-origin-isolation headers are not required. A current browser with WebAssembly and WebGL 2 is required; fullscreen remains subject to browser/OS user-gesture policy. The game has no remote URLs or runtime network dependency.

### Public GitHub Pages release

The verified P022 Web build is publicly playable at **[https://shikirashi.github.io/lane-ball-shooter/](https://shikirashi.github.io/lane-ball-shooter/)**. GitHub Pages supplies the trusted HTTPS origin required by current browsers and redirects the matching HTTP URL to HTTPS. The release is stored under `lane-ball-shooter/` on the `master` branch of `Shikirashi/Shikirashi.github.io`; the site's root and its other pages are unchanged.

The published folder contains exactly the nine generated runtime files: `index.html`, `index.js`, `index.wasm`, `index.pck`, both audio worklet scripts, and the three PNG icons/splash images. The WASM and PCK are ordinary Git blobs, not Git LFS pointers. The deployed PCK SHA-256 is `887b08c77b71283a388836c054294042cc84ff755852d38c9de5e039634ce619`, matching the accepted P022 build from source commit `cca99baba7805dd05c358c70ffa105aecc75efdc`.

### Automatic publication setup

`.github/workflows/publish-web.yml` is the source-controlled P024 pipeline. A trusted `master` push containing game, test, build-script or workflow changes runs all 23 GDScript regression suites, downloads checksum-pinned official Godot 4.7.2 binaries/templates, makes a fresh single-threaded Compatibility export, validates exactly nine runtime files and retains that release as a 14-day Actions artifact. Mailbox-only, README-only, license-only and legacy `deploy/` changes do not rebuild the roughly 40 MB Web release. `workflow_dispatch` provides a deliberate maintenance rebuild.

Publication is serialized. Before deployment the job verifies that its game SHA is still current, checks out the portfolio's latest `master`, rejects a dirty checkout or unexpected files in the target folder, stages only `lane-ball-shooter/`, and pushes without force. Failed tests, exports, validation, credentials or non-fast-forward pushes leave the prior public release intact. The final job downloads all nine HTTPS assets byte-for-byte and uses headless Chrome to require a secure live Godot canvas beyond the HTML loader.

Cross-repository pushes require one user-created Actions secret; no credential is committed or generated by this project. Create a fine-grained personal access token with:

- Resource owner: `Shikirashi`.
- Repository access: only `Shikirashi/Shikirashi.github.io`.
- Repository permission: **Contents — Read and write**. Metadata read is implicit; Actions, Pages, Administration and other permissions are not required.
- A suitable expiration, followed by rotation before it expires.

Store it in the `Shikirashi/lane-ball-shooter` repository as an Actions repository secret named exactly `PORTFOLIO_PUBLISH_TOKEN`. Do not paste the token into a command, issue, log, source file, Pages content or chat. The `PORTFOLIO_PUBLISH_TOKEN` secret has now been configured by the repository owner. Cross-repository publication and Pages deployment are verified in Actions run [`40246262499`](https://github.com/Shikirashi/lane-ball-shooter/actions/runs/40246262499), with successful build/test, asset-byte validation, and secure browser startup. These token-creation instructions are retained for future credential rotation or fresh setup.

After adding the secret, start the first authorized release from the game repository's Actions page or with an already authenticated GitHub CLI:

```sh
gh workflow run publish-web.yml --repo Shikirashi/lane-ball-shooter --ref master
gh run watch --repo Shikirashi/lane-ball-shooter
```

Each successful portfolio commit includes the exact game source SHA. Roll back without rewriting history by reverting the unwanted deployment commit in the portfolio repository and pushing `master`; its existing Pages branch workflow will republish the restored nine files:

```sh
git -C ../Shikirashi.github.io pull --ff-only
git -C ../Shikirashi.github.io revert <portfolio-deployment-commit>
git -C ../Shikirashi.github.io push origin master
```

For a local dry run of the same safety checks:

```sh
./scripts/build_web.sh
./scripts/ci/run_regression_tests.sh
./scripts/ci/validate_web_release.sh exports/web
./scripts/ci/test_publish_automation.sh exports/web
```

The portfolio keeps generated binaries as normal Git blobs because Git LFS pointers are not directly playable by Pages. `index.wasm` remains below GitHub's 100 MiB per-file limit, but portfolio history growth should be monitored. A prior known-good build always remains recoverable from portfolio Git history and the build artifact associated with its game workflow run.

### Legacy private Mintbase hosting

The same validated P022 build remains hosted on Mintbase at **`http://100.79.250.8:8770/`**. This is no longer the preferred player URL: its plain-HTTP tailnet origin can be rejected by browser security requirements even though the files themselves are valid. The server still binds only Mintbase's Tailscale address and is not exposed to the LAN or public Internet. P026 did not configure Tailscale Serve, change this service, or touch the unrelated rembg service and its existing 8765/8766 path.

Hosting uses the unprivileged systemd user service `lane-ball-shooter-web.service`, with user lingering enabled for restart persistence. Files live under `~/srv/lane-ball-shooter-web/releases/<release-id>/`; `~/srv/lane-ball-shooter-web/current` is the atomically promoted live symlink and `previous` is populated on the second deployment for one-command rollback. The initial release is `cca99ba-p022`. Its manifest records source commit `cca99ba`, Web archive SHA-256 `5711dbb5341d6546e564e96ab059801cf8df389687687942b583cc392b2749d4`, and PCK SHA-256 `887b08c77b71283a388836c054294042cc84ff755852d38c9de5e039634ce619`.

Build and atomically deploy a later manually approved release:

```sh
./scripts/build_web.sh
archive_sha=$(sha256sum exports/lane-ball-shooter-web.zip | cut -d' ' -f1)
source_revision=$(git rev-parse --short HEAD)
LBS_SOURCE_REVISION="$source_revision" LBS_ARCHIVE_SHA256="$archive_sha" \
  ./scripts/deploy_web_release.sh deploy exports/web "$source_revision" "$HOME/srv/lane-ball-shooter-web"
curl -I http://100.79.250.8:8770/index.wasm
```

The deploy helper refuses incomplete runtime sets and existing release IDs, stages into a new directory, writes per-file hashes, then atomically switches `current` without restarting the static server. It retains the former target as `previous` after the next promotion. Operational commands:

```sh
systemctl --user status lane-ball-shooter-web.service
journalctl --user -u lane-ball-shooter-web.service -n 50 --no-pager
systemctl --user stop lane-ball-shooter-web.service
systemctl --user start lane-ball-shooter-web.service
./scripts/deploy_web_release.sh rollback "$HOME/srv/lane-ball-shooter-web"
```

The committed service template is `deploy/lane-ball-shooter-web.service`; its private bind settings are in `deploy/lane-ball-shooter-web.environment.example` and installed at `~/.config/lane-ball-shooter-web/environment`. This legacy host is outside P024: automatic publication targets GitHub Pages only and never reconfigures or restarts Mintbase.

### Android builds and release signing

The committed presets keep `Android Debug` for local iteration and add a separate `Android Release` preset for the public ARM64 APK. Both use package ID `com.shikirashi.laneballshooter`; release version `0.1.0` has version code `1`. Native Android starts gameplay directly in landscape. Generated APK/AAB files and common keystore formats are ignored by Git.

Debug export requires matching Android templates plus a JDK and Android SDK configured under Godot's Editor Settings (`Java SDK Path` and `Android SDK Path`). The SDK must include `platform-tools`, a supported platform and build-tools. Then run:

```sh
godot --headless --path . --export-debug "Android Debug" exports/android/lane-ball-shooter-debug.apk
adb install -r exports/android/lane-ball-shooter-debug.apk
```

The user-local bootstrap is repeatable:

```sh
./scripts/setup_android_toolchain.sh
```

It downloads checksum-pinned official Godot 4.7.2 templates and Eclipse Temurin JDK 17, stages them under user-owned cache/data directories, and copies only `android_debug.apk` and `android_release.apk` into the existing template directory. It therefore preserves the installed single-threaded Web templates. It then installs exactly `platform-tools`, `build-tools;35.0.1` and `platforms;android-35` only when Google's command-line tools and a pre-existing Android SDK license receipt are present. The script never invokes `sudo`, pipes acceptance into `sdkmanager`, or runs `sdkmanager --licenses`.

Installed local components:

- JDK: `/home/shiki/.local/share/lane-ball-shooter/toolchains/temurin-17.0.21+9`
- Godot templates: `/home/shiki/.local/share/godot/export_templates/4.7.2.stable/android_debug.apk` and `android_release.apk`
- Dedicated release key: `/home/shiki/.local/share/lane-ball-shooter/signing/lane-ball-shooter-release.jks`
- Protected signing environment: `/home/shiki/.local/share/lane-ball-shooter/signing/release-signing.env` (mode `0600`)

The release key was created only after explicit user approval. Its public SHA-256 certificate fingerprint is `79:6F:2C:67:9D:96:2A:81:95:EB:F1:A3:8D:95:90:02:82:95:61:DF:D2:6D:2D:AE:86:E5:2C:CD:EC:72:24:FC`. Back up both signing files securely and together; losing either prevents compatible upgrades. Never paste the environment file into chat or commit it.

The user completed Google's Android SDK license step. The configured SDK at `/home/shiki/Android/Sdk` contains platform-tools, build-tools 35.0.1 and platform android-35; Godot uses that SDK plus the Temurin JDK path above. For future releases, use a clean checkout, load the protected environment, and run the guarded builder:

```sh
source /home/shiki/.local/share/lane-ball-shooter/signing/release-signing.env
./scripts/build_android.sh
```

The builder refuses dirty sources, missing/mismatched Godot templates, in-repository or debug signing keys, and incomplete SDK/JDK setups. It exports `exports/android/lane-ball-shooter.apk`; the verifier then requires a valid non-debug signature, package/version metadata, ARM64-only native code, a declared minimum SDK, zip alignment, no unexpected sensitive permissions, and prints the APK SHA-256 and byte size.

Android `0.1.0` is published as the non-prerelease [`android-v0.1.0`](https://github.com/Shikirashi/lane-ball-shooter/releases/tag/android-v0.1.0) release. [Download the release-signed ARM64 APK](https://github.com/Shikirashi/lane-ball-shooter/releases/download/android-v0.1.0/lane-ball-shooter-android.apk). The exact public asset is 26,807,776 bytes with SHA-256 `cf390a1abbbbe3e8e937710e46a32aede297ddf43c0c41507d29549e8450ea26`; package `com.shikirashi.laneballshooter`, version code `1`, minimum SDK 24, target SDK 36 and source commit `0e77dbdeadcab4fce4f4b3bf054d721ef479c5bf`. Static signature, manifest, permission, alignment and downloaded-byte verification passed. No Android device was attached, so installation, controls, audio and performance QA remain pending.

The portfolio homepage now contains a Mobile-filtered Lane Ball Shooter card with a real gameplay thumbnail and visible `DOWNLOAD APK` affordance linked to that immutable versioned asset. GitHub APK downloads do not auto-update installed copies; later releases must preserve the signing identity and increment `version/code`.

The P024 Web publisher intentionally replaces only `lane-ball-shooter/` in the portfolio repository. It does not build Android, touch the root Android card/thumbnail, or use Android signing credentials. Its credential is configured and run `40246262499` completed successfully after the Chrome verifier began waiting for process exit and retrying temporary-profile cleanup; secure-context, title, live-canvas, dimensions and loader-removal assertions remain unchanged.

## Regression and playtest checklist

Run the automated suites with the installed Godot binary:

```sh
godot --headless --path . --script res://tests/headless_smoke.gd
godot --headless --path . --script res://tests/p002_logic_test.gd
godot --headless --path . --script res://tests/p003_logic_test.gd
godot --headless --path . --script res://tests/p004_combat_test.gd
godot --headless --path . --script res://tests/p005_survival_test.gd
godot --headless --path . --script res://tests/p006_platform_qa_test.gd
godot --headless --path . --script res://tests/p007_playtest_revision_test.gd
godot --headless --path . --script res://tests/p008_gamefeel_sfx_test.gd
godot --headless --path . --script res://tests/p009_zuma_rollback_test.gd
godot --headless --path . --script res://tests/p010_staged_cascade_test.gd
godot --headless --path . --script res://tests/p011_segment_chain_stress_test.gd
godot --headless --path . --script res://tests/p012_forward_insert_test.gd
godot --headless --path . --script res://tests/p013_shooter_preview_mask_test.gd
godot --headless --path . --script res://tests/p014_causal_rollback_feed_test.gd
godot --headless --path . --script res://tests/p015_gravity_finite_enemies_test.gd
godot --headless --path . --script res://tests/p016_speed_auto_recycle_test.gd
godot --headless --path . --script res://tests/p017_offscreen_left_reentry_test.gd
godot --headless --path . --script res://tests/p018_enemy_death_victory_delay_test.gd
godot --headless --path . --script res://tests/p019_enemy_roster_spawning_test.gd
godot --headless --path . --script res://tests/p020_special_enemy_abilities_test.gd
godot --headless --path . --script res://tests/p021_web_menu_export_test.gd
godot --headless --path . --script res://tests/p023_enemy_speed_victory_copy_test.gd
godot --headless --path . --script res://tests/p022_hp_penetrating_attacks_test.gd
godot --headless --path . --script res://tests/p034a_sprite_baking_test.gd
godot --headless --path . --script res://tests/p034b_live_2d_battlefield_test.gd
godot --headless --path . --script res://tests/p034c_charge_crystal_test.gd
# Or run every suite in sorted order:
./scripts/ci/run_regression_tests.sh
```

For a manual end-to-end smoke test:

1. Serve the Web export over HTTP. Confirm only `LANE BALL SHOOTER` and `START GAME` appear before gameplay. Open the prompt and test `NO` windowed, then reload and test `YES` fullscreen; denial must still start the game. Confirm Enter/Space/touch activate focused buttons, no shot leaks through, and exiting fullscreen resizes correctly. Native desktop/Android should still start gameplay directly.
2. Resize through the four target landscape sizes. Confirm the small NEXT ball remains directly below the loaded shooter ball at both track edges, the circular 56×56 swap target stays in the upper HUD, and the shooter reaches both extreme chain targets. Fire from both ends; shots should reach the lane in about 0.20 seconds without the swap control intercepting playfield input.
3. Confirm incoming NEW balls begin completely hidden beyond the right edge and reveal smoothly at 102 px/s, continuing indefinitely with frequent pairs and occasional four-to-seven-ball fresh runs. Track a recognizable group as it disappears LEFT. Clear a group to its RIGHT and confirm those SAME balls—not copies—slide back into view from LEFT under gravity. During an insertion, verify the shot/settling ball is not clipped for 50 ms and then hands cleanly to the masked conveyor with no duplicate or missing frame. Every existing ball to the LEFT/front should nudge LEFT one slot, including hidden members, while every existing ball to the RIGHT/trailing side stays pinned apart from normal elapsed conveyor travel. No insertion should push anything RIGHT.
4. Arrange RED RED / YELLOW YELLOW / RED RED, then insert YELLOW: first observe the insertion push LEFT, hear insert at contact, see a non-overlapping scale-in and all three yellows rest in-chain for 50 ms, then see/hear one yellow pop. Only after that match-created hole exists should the unsupported left red pair fall RIGHT, accelerate without changing internal spacing, physically contact the source-supported trailing reds and produce the later four-red cascade. Also observe a nonmatching FEED gap close without a pop. Repeat with moving seams and concurrent shots; every unsupported group should eventually reconnect and no ball may overlap.
5. On touch hardware, press/drag anywhere across the full playfield and release: exactly one ball should fire. A HUD swap tap must only swap. Starting outside the playfield, canceling a gesture, or releasing after RESTART must not fire.
6. Identify all four enemies: gray hopping 6-HP Hopper with exactly two orange horns, wide orange 12-HP sliding Heavy, tall fast yellow 6-HP Sickle Snake, and small stationary 6-HP green Healyzard at the rear. Damage a Hopper and confirm its horns remain; no type should show HP bars, and no non-Hopper should hop or have horns. Hit a Snake nonfatally: it should stop for 0.5 seconds, then visibly cross to one adjacent non-full lane over about 0.3 seconds before resuming. Confirm only one Snake remains globally and replacement still waits 15 seconds after death.
7. Watch a Healyzard for 15 seconds. Its soft circular yellow glow should appear behind the green body with transparent edges, expand and fade in under one second, while every wounded non-Healyzard in that lane gains exactly one HP. Other healers and enemies in other lanes must not heal.
8. Confirm every defender starts with a small diamond crystal matching its team color behind its rear-left side. Let an enemy touch a defender: it falls, the one-time emergency discharge clears that lane, and only that crystal shatters into several fading pieces. The defender itself must remain fully colored. Make two separate matches of that defender's color to revive it; neither revival match launches an attack and the spent crystal must not return, while the next match attacks normally. Restart must restore all four intact crystals. Confirm a lane stops spawning after its eighth total enemy.
9. Verify tier 1 stops on the first enemy, tier 2 penetrates every enemy it passes in one lane, and tier 3 visibly crosses exactly two adjacent lanes. Each hit must remove only 1 HP and each enemy may be hit once per projectile; a full-health 12-HP Heavy must survive tier 3. Then defeat enemies with projectiles and the emergency discharge. Each removed body should produce a small explosion/sparks, fall sideways until nearly horizontal, fade completely in about one second and play one distinct death pop/crunch; no standing ghost should remain.
10. Clear all 32 scheduled enemies. Confirm chain/combat/input freeze on the final death while WAVE CLEARED stays hidden for three seconds and the last VFX/SFX finish; then confirm the final score and tappable RESTART control appear. Restart and confirm the HUD returns to 00/32 with one weighted initial enemy in each lane. In a separate run, let an enemy breach and confirm GAME OVER remains immediate.
11. Listen for distinct shoot, successful-insert, swap, match, active-attack, knockdown, revival and enemy-death cues. A miss must have shoot but no insert sound; revival 1/2 has no jingle. Press M to confirm mute. Check that fast cascades and multi-kill death sounds remain comfortable.
12. Compare lanes 2 and 4 at 960×540 and 1280×720: BLUE must remain saturated blue and GREEN unmistakably emerald on stripe, defender, projectile and status marker. Verify square versus diamond symbols remain clear. Headless palette-distance tests do not replace this visual check.
13. Repeat touch/swap/audio using browser device emulation, then repeat on a physical Android device after `adb install -r`. Synthetic tests do not replace real browser/notch/multi-touch/audio QA.

For conveyor troubleshooting, enable F3. `L` is the number of fully retained balls beyond LEFT, `X` is the leftmost center position, and `A` is the visible/near-screen/right active population. `U/G` report unsupported segments and physical gaps, `V/D` report rightward gravity speed/displacement, and `F` counts fresh generations. During a no-match run, `L` should grow while `A` stays at or below 24. After an appropriate match, `D` becomes positive and the same hidden balls may cross LEFT back into view. `I` must remain zero.

Gameplay balance is centralized in `ChainModel`, `ShooterView.SHOT_TRAVEL_TIME`, `MatchProgression`, `Main.SHOOT_COOLDOWN`, `SfxManager`, `EnemyTypes`, `Battlefield`'s spawn/transfer directors, and the `LaneCombatModel.DEFAULT_*` constants (chain speed/refill/run weights, 50 ms insertion settle, gravity initial speed/acceleration/cap, shot travel/cooldown, combo window, SFX pool/volume, enemy roster weights/stats, Snake stun/transfer/gate/cooldown, Healyzard pulse interval, concurrent cap/eight-spawn lane budget, and projectile speed/damage). Team identity always uses both the shared color and DOT/SQUARE/TRIANGLE/DIAMOND geometry. An optional user-selectable high-contrast palette remains an accessibility follow-up; it was not added to this conversion because the symbol channel already prevents color-only identification.
