# Gym Log repository workflow

Canonical remote: https://github.com/sandeep-reddy1101/gymlog.git
Primary branch: main.

The user has asked that project changes be maintained and pushed to this repository. For future work in this project:

- Inspect local status and fetch the remote before changing code. Preserve existing work and reconcile remote changes without force pushes or destructive resets.
- Keep app code, tests, requirements, setup instructions and reviewed design proposals in sync. Record approval status accurately; a design preview is not approval to implement it.
- Validate changes appropriately. For app changes, run core tests, Scripts/verify.sh and the relevant unsigned Xcode build. Documentation-only changes do not require rebuilding the app.
- Commit coherent, completed changes and push them to the canonical repository unless the user asks to keep the work local. Use a feature branch / pull request for substantial app changes; small documentation fixes can go directly to main. Do not merge a pull request without user authorization.
- After pushing, verify the remote commit and report any failing or pending CI checks. Do not claim a push succeeded based only on a local commit. If credentials are unavailable, retain the commit and report the exact remaining step.
- Never force-push, rewrite published history, change repository visibility or add a license without explicit authorization.
- Do not commit device diagnostics, user workout/Health data, backups, signing keys, provisioning profiles, access tokens, local Xcode user settings or build products. Respect .gitignore and inspect staged files.
- Preserve the user's signing team and bundle identifiers in the project. They are configuration, not credentials; do not upload private signing material.
- Archive interactive design source and standalone previews in docs/designs so design work is included in version history. The live conversation preview can remain outside the repository.

This is a workflow for work performed in this project, not a background monitoring or scheduled service.
