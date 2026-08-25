# Testing

## Static checks

`scripts/check.sh` performs JSON validation, architecture policy checks and `qmllint`.
Quickshell-specific lint warnings may be narrowly allowlisted in
`scripts/qmllint_allowlist.txt` with an adjacent explanation. Quickshell 0.3.1 currently
marks `PanelWindow` uncreatable in lint metadata even though it is the documented runtime
layer-shell window type, so the foreground smoke test covers that narrow exception. Errors,
missing members and duplicate IDs are never allowlisted.

## Runtime smoke test

`scripts/smoke.sh` starts the project in the foreground for a bounded interval, captures the
log and fails on QML errors, type errors, duplicate IDs or missing members. It must observe
`Configuration Loaded`.

`scripts/runtime_acceptance.sh` temporarily installs isolated runtime-layout fixtures,
verifies invalid data falls back and unknown widget types render through the diagnostic
component, then restores the previous runtime layout exactly.

Theme acceptance additionally verifies the settings v1→v2 migration, appearance-only restore,
Neutral Utility solid policy, Gallery open/close IPC and unchanged hashes for both Hyprland
configuration copies. Gallery content must disappear from the scene when its Loader is inactive.

## Manual acceptance

- One MenuBar appears on DP-1 and DP-3.
- Each output reserves exactly 40 logical pixels at the top.
- Labels remain readable at scale 1.0 and 1.5.
- Invalid runtime configuration falls back to defaults.
- An unknown registry type renders a diagnostic item without crashing.
- Applying settings does not modify the repository.
- `hyprctl configerrors` is empty.
- Neutral Utility resolves to `solid` in both dark and light previews.
- Restore returns to dark while preserving locale, accessibility, modules and layout.
- Gallery opens only on its requested screen and closes without leaving preview state active.
