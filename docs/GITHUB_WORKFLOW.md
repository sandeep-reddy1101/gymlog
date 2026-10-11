# GitHub workflow

Canonical repository: [sandeep-reddy1101/gymlog](https://github.com/sandeep-reddy1101/gymlog).

The local project and GitHub repository represent the same app. The first import preserves the current iPhone and Watch implementation, tests, approved branding, requirements, setup guidance and design proposals. The latest UI proposals are not integrated into the app.

## Ongoing work

1. Check local changes and fetch remote changes before starting.
2. Implement the requested change and update relevant requirements/documentation.
3. Run checks appropriate to the change. For app changes, use `swift test`, `zsh Scripts/verify.sh` and the unsigned simulator build below.
4. Commit a coherent change and push it. Substantial app changes use a feature branch and pull request; merging requires user approval. Small documentation fixes can go directly to main.
5. Confirm the remote commit and review the GitHub Actions result. Report failures or pending checks honestly.

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer zsh Scripts/verify.sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project LiftLog.xcodeproj -scheme 'Lift Log' \
  -configuration Debug -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build
```

The per-command developer path is useful when the Mac's default toolchain points to Command Line Tools. No global Xcode setting must be changed for these checks.

## Automated checks

`.github/workflows/ci.yml` runs on main pushes, pull requests and manual dispatch. It runs the core XCTest suite, the source/project validation script and an unsigned iPhone simulator build with the embedded Watch app. The workflow needs only read access to repository contents and no Apple signing secrets. Physical Watch pairing, permissions, sensor delivery and native usability still require device testing.

No branch-protection rules, visibility changes or license selection are made by the initial setup. Workflow execution depends on the repository's GitHub Actions settings and available runner allowance. This document does not claim a successful remote CI run.

## What stays local

Build caches, Xcode user settings, signing exports, `.env` files, device diagnostic bundles/logs and local databases are ignored. Workout backups and Health exports must never be staged even if their filenames are not covered by an ignore rule. Inspect the staged diff before every push.

Shared bundle identifiers and team configuration remain so the existing phone installation is not accidentally changed. Git commits use the GitHub username and a GitHub noreply address locally when no author identity is already configured; no global identity is changed.

## Design history

See [design previews](designs/README.md). Earlier rejected motion experiments remain in `output/visual-previews` as historical review material; they are not approved app assets or current design recommendations. Requirements record which proposals are pending and which decisions are approved.
