# Codex Handoff — LBS-P026 public GitHub Pages release

**Status:** COMPLETE

**Game branch:** `master`

**Accepted gameplay/build source:** `cca99baba7805dd05c358c70ffa105aecc75efdc` (`Rebalance enemy HP and projectile tiers`)

**Portfolio release commit:** `e087383653bac3e459f92e1acedc558f485a0b2a` (`Publish Lane Ball Shooter Web build`)

**Public URL:** [https://shikirashi.github.io/lane-ball-shooter/](https://shikirashi.github.io/lane-ball-shooter/)

The mailbox remains on LBS-P026. ChatGPT-owned task, decision, ledger, and protocol files were not edited. P024 automation and Tailscale Serve were not configured.

## Publication

- Pulled both repositories with `git pull --ff-only` and verified their `master` branches and GitHub remotes.
- Used the accepted P022 release already present on Mintbase and confirmed it was byte-identical to the ignored `exports/web/` build before publication.
- Replaced only `lane-ball-shooter/` in `Shikirashi/Shikirashi.github.io`. The existing site root, `.nojekyll`, and every other portfolio page were preserved.
- Removed the folder's placeholder `.gitkeep` and committed exactly the nine actual Godot runtime files listed below.
- Confirmed `index.wasm` and `index.pck` are normal Git blobs with no LFS filter or pointer content.
- Pushed portfolio `master`; GitHub Pages workflow run `40239268461` completed successfully for commit `e087383`.

| Runtime file | Bytes | SHA-256 |
|---|---:|---|
| `index.html` | 5,447 | `6b94a111a6c79b5811b9d43a6e73bf7c5be40b8ecaeafab72c4e1d7bfd3c18a7` |
| `index.js` | 279,815 | `33c94cb3175f3333b82e2a3be5e8e86f77986f0aa2042b1631f6367a4e5bb6ba` |
| `index.wasm` | 39,514,754 | `fc74679e3b97f76878947fcd4fbe1268cbfa6188182a2e33bbc3f5dc9bfa57d0` |
| `index.pck` | 357,672 | `887b08c77b71283a388836c054294042cc84ff755852d38c9de5e039634ce619` |
| `index.audio.worklet.js` | 7,298 | `5b476a9c9ce642c0ee4256436d1bc31d9c38f868aca0f9a8e2a57c18d2dec2a3` |
| `index.audio.position.worklet.js` | 2,973 | `be33985bc7160d6bf9646f259cd86b259cd67b02ccb297ee5c44f8ac84327bc8` |
| `index.png` | 21,443 | `3cb4495c0b98dfbe4b663cbf2b6836473572339beb66d902367893162a70be0e` |
| `index.icon.png` | 5,700 | `ad3c35ad0facf487c618204bd98db543034fc95224eadc7f08c7a9ff38d5b3b5` |
| `index.apple-touch-icon.png` | 11,944 | `01d4f63e525941e06ce74f5187dad030d20a8d52a07ce365ae4e94af97a3b1f5` |

The accepted P022 archive SHA-256 remains `5711dbb5341d6546e564e96ab059801cf8df389687687942b583cc392b2749d4` and its PCK hash matches the published file above. The archive and release manifest were not published because P026 authorizes only the nine browser runtime files.

## Verification

- Before commit, served the nested portfolio checkout over loopback HTTP. All nine paths returned 200 with correct HTML, JavaScript, WASM, PCK, and PNG MIME types; downloaded WASM/PCK hashes matched the source release.
- After Pages deployment, all nine public HTTPS paths returned 200. Every downloaded byte count and SHA-256 matched the table above.
- `http://shikirashi.github.io/lane-ball-shooter/` returned 301 to the requested HTTPS game path.
- Headless Google Chrome loaded the public HTTPS release through the Godot/WebGL splash at both 1280×720 and 1920×1080. In a persistent 1280×720 session after 12 seconds, the page reported `isSecureContext == true`, title `Lane Ball Shooter`, one live canvas, and no remaining HTML loader/status element, confirming runtime handoff beyond the splash.
- P021 Web menu/export regression passed all 46 checks. P022 HP/penetrating-attacks regression executed directly from the published build's local PCK and passed all 48 checks. The recurring sandbox denial for `user://logs/godot.log` was nonfatal.
- Headless canvas pixels are not DOM text, and repository rules prohibit GUI/mouse automation, so visual interaction with `LANE BALL SHOOTER`, fullscreen YES/NO behavior, sound, and gameplay still require ordinary browser QA.
- The portfolio repository was clean and exactly synchronized with `origin/master` after its push.

No gameplay source changed in P026, so the already accepted P001–P023 regression results and exact P022 build remain authoritative. P026 adds publication verification rather than rebuilding or modifying the binary.

## Hosting disposition

The preferred player endpoint is now the public GitHub Pages HTTPS URL. The prior Mintbase release and its user service were left intact, but its plain-HTTP tailnet URL is retained only as a legacy/private source because modern browser security checks can reject it. No Tailscale Serve, Funnel, firewall, DNS, or P024 automation changes were made.

For a later manually approved release, rebuild with `./scripts/build_web.sh`, validate all nine files, pull the portfolio repository, replace only `lane-ball-shooter/`, inspect the staged paths and hashes, then commit/push portfolio `master` and wait for its Pages workflow. P024 may automate that cross-repository sequence later; it remains inactive.
