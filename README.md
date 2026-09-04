# Titonium

Titonium is a modular Quickshell shell for Hyprland. The runtime is organized as narrow vertical
slices: views render immutable service state, services own native integrations, and heavy surfaces
are created lazily on the assigned output (`DP-1`). Spotlight and Input Method remain protected
baseline features.

## Current UI

- A 44 logical-pixel Bar with five Workspaces, Active Window context, Center attention/activity,
  an always-present Notification Bell, Topbar pin, Wi-Fi, Bluetooth, Audio and Input Method.
- A lazy Center Notch for semantic attention/activity plus an independent top-right history panel
  opened by the Notification Bell. Critical notifications use the Center FIFO banner; history,
  standard actions, per-item dismissal and clear-all belong to the Bell-owned panel.
- Spotlight Applications and Clipboard flows on `Super + Space` and `Super + V`.
- A native Dock, audio popup/OSD, notification toasts, window switcher and transactional Settings.
- An opt-in local Agent Approval surface for supported Antigravity and Codex approval requests
  (`TITONIUM_AGENT_APPROVAL_ENABLED=1`); native approval remains the default.

Titonium creates surfaces only on the configured eligible output and leaves other outputs to their
own shell. Runtime preferences and user data live outside Git.

## Run and verify

```bash
cd /home/cole/Projects/titonium
./scripts/check.sh
./scripts/smoke.sh
./scripts/protected_acceptance.sh
hyprctl configerrors
qs -d -p /home/cole/Projects/titonium
```

Useful read-only or lifecycle IPC calls:

```bash
qs -p /home/cole/Projects/titonium ipc call app status
qs -p /home/cole/Projects/titonium ipc call spotlight toggle
qs -p /home/cole/Projects/titonium ipc call spotlight clipboard
qs -p /home/cole/Projects/titonium ipc call centerNotch open overview
qs -p /home/cole/Projects/titonium ipc call notifications state
qs -p /home/cole/Projects/titonium ipc call audio state
qs -p /home/cole/Projects/titonium ipc call bluetooth state
```

Read [AGENTS.md](AGENTS.md), [the architecture](docs/ARCHITECTURE.md), and
[the testing guide](docs/TESTING.md) before changing a capability.
