# Testing

## Static checks

`scripts/check.sh` performs JSON validation, architecture policy checks and `qmllint`.
Quickshell-specific lint warnings may be narrowly allowlisted in the script with an adjacent
explanation. Errors, missing members and duplicate IDs are never allowlisted.

## Runtime smoke test

`scripts/smoke.sh` starts the project in the foreground for a bounded interval, captures the
log and fails on QML errors, type errors, duplicate IDs or missing members. It must observe
`Configuration Loaded`.

## Manual acceptance

- One MenuBar appears on DP-1 and DP-3.
- Each output reserves exactly 40 logical pixels at the top.
- Labels remain readable at scale 1.0 and 1.5.
- Invalid runtime configuration falls back to defaults.
- An unknown registry type renders a diagnostic item without crashing.
- Applying settings does not modify the repository.
- `hyprctl configerrors` is empty.

