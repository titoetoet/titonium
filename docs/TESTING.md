# Testing

## Static gate

`./scripts/check.sh` validates shipped JSON/i18n, protected keybinds, source shape, service and bar
boundaries, preference projection, pure Application/Clipboard/Spotlight behavior and every QML file
with `qmllint`.

The only allowlisted QML warning is Quickshell 0.3.x metadata marking documented `PanelWindow` as
uncreatable. New warnings are failures. UI code is rejected when it owns `Process`, `FileView` or
raw detached execution.

## Runtime gate

Stop any daemon using the same shell ID, then run:

```bash
./scripts/smoke.sh
./scripts/protected_acceptance.sh
hyprctl configerrors
```

Smoke requires `Configuration Loaded` and rejects QML type/load/runtime errors. Protected
acceptance uses IPC to exercise Spotlight scope/query/close transitions, confirms repository
isolation and verifies both Hyprland configuration hashes. It does not launch an application or
write clipboard content.

After passing, restart with `qs -d -p /home/cole/Projects/titonium` and manually verify every output:

- exactly one 40px bar with correct scaling/exclusive zone;
- workspace interaction and input-method state;
- `Super + Space`, typing, Tab/Shift+Tab scopes, category paging and Escape;
- `Super + V`, Clipboard navigation and close;
- unplug/replug or focus another monitor without a stranded overlay.

Every imported module adds a pure fake-driven test, an architecture check and a focused live test
for its own boundary. Never automate power actions, destructive session actions, real application
launch or clipboard writes.
