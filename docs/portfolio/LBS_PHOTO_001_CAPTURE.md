# LBS-PHOTO-001 capture record

Status: draft screenshots for user/ChatGPT review. No candidate is approved or published.

## Source and isolation

- Branch: `portfolio/lbs-photo-001`
- Starting source: `e42f76ca5b25dc35545c55ba412dbf78763e2bf0`
- Engine: Godot `4.7.2.stable.official.ed1daf0bf`
- Renderer: `gl_compatibility`, Mesa OpenGL 4.6 on AMD Radeon RX 6700 XT
- Production entry remains unchanged. The capture tool instantiates `scenes/main.tscn` inside a `SubViewport`; no production scene, gameplay script, export preset, Android version/signing file, or Web publication file is modified.

## Deterministic capture fixture

Run from the repository root on a host with `DISPLAY` or `WAYLAND_DISPLAY`:

```sh
scripts/capture_lbs_photo_001.sh
```

The default command creates the current second-pass native 1600x900 PNG. Pass
`--originals` to reproduce the three preserved first-pass PNGs. For each candidate it:

- stages an explicit static conveyor identity sequence through `ChainModel.set_test_state()`;
- clears automatic spawns and places fixed real Hopper, Heavy, Sickle Snake, and Healyzard actors in all four lanes;
- disables battlefield, lane, chain, shooter, and root processing before capture;
- inserts one authentic `ShooterView` ball at a fixed ratio of its real 0.20-second upward path;
- draws a capture-only 64-pixel vertical afterimage beneath that ball; and
- uses fixed HUD values and the existing shooter loaded/next visuals.

No timing, input, combat progression, enemy damage, or live projectile launch is required.

## Review images and mechanical validation

| File | Dimensions | Bytes | SHA-256 |
| --- | ---: | ---: | --- |
| `ball_battalion_photo_001_a.png` | 1600x900 RGBA | 91,651 | `aa39b427c2f3d1bea2518ddecbab6378678b97d8cf8c5ff8ce1743d9cd712997` |
| `ball_battalion_photo_001_b.png` | 1600x900 RGBA | 91,477 | `bb4d5990d5203814e7d28030fbce957053fe8e751a822f3b43125aa22b0738d7` |
| `ball_battalion_photo_001_c.png` | 1600x900 RGBA | 91,125 | `e709b91c04a7fbd241dfd78275b140d3979bfef71ab7bd96f57ce2b0df645a07` |
| `ball_battalion_photo_001_c_large_01.png` | 1600x900 RGBA | 91,623 | `a0571db7b97235f956f9c08dfa038e33da9bd25f3526a53c30e8bfc5fbf6b725` |

Tracked review directory: `docs/portfolio/review/lbs_photo_001/`.

Mechanical checks used `file`, ImageMagick `identify`, and `sha256sum`. All files decode as non-interlaced 8-bit RGBA PNGs, have 16:9 dimensions, contain 6,867–6,911 colors, and have nonzero mean/standard deviation. A second complete Godot render produced byte-identical hashes. The revised C differs from original C only within a mechanically trimmed 51x87-pixel region. No subjective composition evaluation or hero selection was performed.

## Verification

```sh
godot --headless --path . --script res://tests/lbs_photo_001_capture_test.gd
scripts/ci/run_regression_tests.sh
```

- Capture isolation: PASS, 14 checks.
- Full repository regression: PASS, 37 suites.
- Graphical capture: PASS, one revised genuine Compatibility-renderer screenshot; three originals preserved unchanged.
- Physical Android/device QA: not applicable to this capture-only branch; P040 release work was not touched.

The portfolio website was not modified or published.

## Human review / second-pass request — 1 November 2026

The user prefers existing `ball_battalion_photo_001_c.png` (green shot / black background), but the **in-flight ball is too small**. That is consistent with production `ShooterView` drawing airborne shots at 12-px radius vs 19-px loaded balls. The follow-up is a capture-only visual enlargement (~22–26-px radius) with the same green diamond, short green trail, unchanged original C staging. Never change runtime shot mechanics/size. Make 1–2 new `c_large_` real renders, push tracked binary PNGs and await user/ChatGPT approval; no changes to `master` or publication.

Second pass delivered `ball_battalion_photo_001_c_large_01.png` with a tools-only 24-px airborne overlay at candidate C's unchanged projectile center. The overlay uses the existing GREEN palette and `TeamData.draw_symbol` diamond. It covers the frozen authentic 12-px shot without changing `ShooterView`; the loaded shooter ball remains the normal 19 px. The default capture now writes only this second-pass file, preventing accidental overwrites of A/B/C, while `--originals` retains first-pass reproducibility.

## External visual review of enlarged C candidate — 1 November 2026

- Verified photo commit `9fedd062b11d8186c68015df7cedcf301c9f6815` and handoff `a56017093fb28e919a49d31d6fd483bf652ca337`. `ball_battalion_photo_001_c_large_01.png` is GitHub-accessible and was visually opened.
- ChatGPT's review: **strong improvement**. The 24-pixel-radius green airborne ball and diamond are unmistakable against the black gameplay background, with a subtle static upward trail and no unwanted framing change. This is the **recommended Ball Battalion portfolio photo**, **pending explicit user approval**.
- One unrelated publication consideration: screenshot's existing UI header reads **LANE BALL SHOOTER**, the older working title, not **Ball Battalion**. This is a factual note for the user's later decision; do not silently replace or falsely label the image, and do not alter production UI as part of the photo task.
- The screenshot remains a staged real-engine frame, not a recorded live match. Neither this review nor its documentation authorizes deployment or merging photo tooling to `master`.

## Final user approval — 1 November 2026

The user directly approved **[ball_battalion_photo_001_c_large_01.png](https://github.com/Shikirashi/lane-ball-shooter/blob/9fedd062b11d8186c68015df7cedcf301c9f6815/docs/portfolio/review/lbs_photo_001/ball_battalion_photo_001_c_large_01.png)**. This image, and only this screenshot from the approved photo session, is the selected final Ball Battalion portfolio photo. **Photo approval: COMPLETE.** The screenshot's legacy `LANE BALL SHOOTER` header remains unedited and accepted as photographed. The regular engine/projectile visuals, Android release work, and `master` branch remain unchanged. The screenshot may be used on the Projects page, but this does not constitute authorization to publish the entire website redesign on the main homepage.
