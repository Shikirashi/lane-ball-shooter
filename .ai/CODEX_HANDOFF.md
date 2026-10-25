# Codex Handoff — LBS-P024 automatic Web build and portfolio publication

**Status:** IMPLEMENTED; LIVE DEPLOYMENT BLOCKED AT REQUIRED CREDENTIAL CHECKPOINT

**Branch:** `master`

**Public URL retained:** [https://shikirashi.github.io/lane-ball-shooter/](https://shikirashi.github.io/lane-ball-shooter/)

P024 source automation is complete, but the game repository has no Actions secrets. Per the task's security boundary, Codex did not create a token, grant repository access, or install a credential. The existing accepted P026 portfolio release remains live and unchanged. No gameplay balance, Mintbase service, Tailscale setting, ChatGPT-owned mailbox file, or existing portfolio page was changed.

## Existing hosting configuration inspected

- Portfolio repository: `Shikirashi/Shikirashi.github.io`, `master`, clean and synchronized locally at P026 commit `e087383653bac3e459f92e1acedc558f485a0b2a` before P024 work.
- GitHub Pages: legacy branch publication from `master` `/`, status `built`, public with HTTPS enforced.
- Existing Pages run `40239268461` succeeded for `e087383`; the nine-file game lives only at `lane-ball-shooter/` and root `.nojekyll` is present.
- Portfolio Actions are enabled. The game repository had zero Actions secrets at inspection time.

This supports the least disruptive mechanism: an Actions workflow in the game repository makes one normal, non-force portfolio commit containing only the nested game files. The existing Pages branch publisher then deploys the whole portfolio normally. It avoids changing Pages mode, replacing the portfolio root, using Git LFS, or introducing a second workflow into the portfolio repository.

## Implementation

`.github/workflows/publish-web.yml`:

- runs on trusted `master` pushes except mailbox/README/license/legacy-host-only changes, plus manual `workflow_dispatch`;
- uses GitHub-hosted Ubuntu and immutable SHAs for checkout, cache, upload-artifact and download-artifact Actions;
- installs official Godot 4.7.2 Standard Linux and export templates from fixed upstream URLs after SHA-256 verification (`cadd3204...` executable archive, `f298490b...` template archive);
- runs every discovered top-level GDScript test, builds a fresh single-threaded Compatibility release from the exact checked-out commit, validates exactly nine files and uploads a 14-day reusable artifact;
- serializes production jobs and rechecks remote game `master` immediately before publishing, so a superseded build cannot overwrite a newer source release;
- stops at an explicit error when `PORTFOLIO_PUBLISH_TOKEN` is absent;
- checks out current portfolio `master`, rejects unexpected target content, stages only `lane-ball-shooter/`, commits the game source SHA and pushes normally;
- waits for the public PCK hash to change, then verifies all nine HTTPS files byte-for-byte and checks MIME types;
- starts headless Chrome and requires `window.isSecureContext`, title `Lane Ball Shooter`, one nonempty canvas, and removal of Godot's HTML loader.

Supporting scripts under `scripts/ci/` provide pinned Godot installation, full regression execution, exact release validation, guarded portfolio staging, isolated success/failure tests, public byte/MIME polling, and no-GUI browser startup verification. Generated Web binaries remain ignored in the game repository.

The failure path is production-safe: tests and export precede portfolio checkout; an invalid/missing release is rejected before mutation; unexpected target files or changes outside `lane-ball-shooter/` abort; a missing token aborts; a concurrent unrelated portfolio push causes a normal non-fast-forward failure. In all cases the prior Pages branch remains untouched. Rollback is a normal `git revert <deployment-commit>` in the portfolio repository, retaining audit history.

## Required one-time user setup — minimum permission

Create a fine-grained personal access token with:

1. Resource owner `Shikirashi`.
2. Access to only `Shikirashi/Shikirashi.github.io`.
3. Repository permission **Contents: Read and write**; no Actions, Pages, Administration, organization or account permissions.
4. A chosen expiration/rotation policy.

Add it to `Shikirashi/lane-ball-shooter` as an Actions repository secret named exactly `PORTFOLIO_PUBLISH_TOKEN`. Do not send the token through chat or store it in either repository. Then manually dispatch `publish-web.yml` on `master`. This setup is required before an end-to-end automatic portfolio commit can be demonstrated; P024 must not be described as live until that run succeeds.

## Local validation

Godot `4.7.2.stable.official.ed1daf0bf`:

- Full P001–P023 run via `./scripts/ci/run_regression_tests.sh`: **all 23 suites passed**. Counts: P002 66, P003 73, P004 43, P005 63, P006 69, P007 55, P008 84, P009 46, P010 162, P011 stress 16,485, P012 366, P013 50, P014 289, P015 524, P016 76, P017 352, P018 41, P019 117, P020 67, P021 46, P022 48, P023 38; P001 smoke passed.
- `./scripts/build_web.sh`: PASS; produced nine runtime files and ignored ZIP. Local dry-run ZIP SHA-256 `0eb6566f102d989be1af0f4fea07f3abdb42cba43301d33a13dff465b14078a3`.
- `validate_web_release.sh`: PASS for names, nonempty data, WASM/PCK/PNG magic, and nested relative references.
- `test_publish_automation.sh`: PASS; preserved root and another demo byte-for-byte, changed only the game folder, and proved a missing PCK is rejected while a clean simulated portfolio stays unchanged.
- Shell syntax for all CI scripts and Node syntax for the browser verifier: PASS.
- Existing public P026 release: all nine HTTPS files returned 200 with expected MIME and byte-exact content.
- Browser verifier against the existing public URL: PASS — secure context, `Lane Ball Shooter`, one 1280-wide canvas, loader removed after runtime startup.

Known nonfatal local Godot export warnings were the sandboxed editor TCP/settings and unavailable Android build-tools messages; the Web export completed and validated. Pre-existing local `project.godot`, `scenes/main.tscn`, and untracked `.uid` changes remain unstaged and untouched.

## Operational commands

After the secret is installed:

```sh
gh workflow run publish-web.yml --repo Shikirashi/lane-ball-shooter --ref master
gh run watch --repo Shikirashi/lane-ball-shooter
```

Rollback a published build without force-pushing:

```sh
git -C ../Shikirashi.github.io pull --ff-only
git -C ../Shikirashi.github.io revert <portfolio-deployment-commit>
git -C ../Shikirashi.github.io push origin master
```

The workflow run triggered by the P024 source commit is expected to prove the clean hosted build/test path and then fail at the intentional missing-secret checkpoint. Record its run URL/result after push; production must remain at portfolio `e087383` until the user grants the narrow credential and reruns it.
