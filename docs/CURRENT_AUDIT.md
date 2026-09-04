# Current source audit — 2026-09-03

This document records the repository-wide cleanup after the Bluetooth, Active Window and animation
batches were produced by several AI assistants. It describes the current working tree, not a
historical release tag.

## Result

- `./scripts/check.sh` passes, including JSON/i18n validation, pure rule fixtures, architecture
  boundaries and `qmllint` with the repository allowlist.
- Every shipped QML component has a runtime reference after removing the retired Bar `Clock`,
  Center rail/activity card and unreachable Monitoring/Tools/Session presentation trees.
- The obsolete `Services/Keyboard` singleton remains deleted; no source reference points to it.
  Keyboard observation is owned by the protected Input Method path and focused feature handlers.
- The superseded Overview/Notification Center view tree and its unused imports were removed.
- An unrelated Antigravity Electron `package.json` and a one-off interactive ten-popup script were
  removed from the project root. The supported approval tests remain
  `check_agent_approval.js` and `check_agent_approval_bridge.py`.
- Whitespace validation is clean (`git diff --check`).

## Current runtime ownership

- `App.qml` is a thin composition root for Bar, Dock, transient overlays, Audio OSD, notification
  toasts, Settings and Agent Approval. Activation, cross-surface routing, the Bluetooth–Audio
  bridge and IPC adapters live in dedicated `Orchestration` and `Ipc` modules without changing
  public IPC targets or result strings.
- `Bar` owns Start and End hitboxes plus an inert true-center reservation; `CenterPillWindow` owns
  the Dynamic Island visual and input geometry in every state. Clock is not rendered; time remains part
  of the Overview weather card and the `use24Hour` preference is still meaningful there.
- Dynamic Island is a top-attached, single-silhouette morph from compact/satellite into a context banner
  or an expanded canvas. The previous Overview and Notification-history presentation is retired;
  Notification Center will be rebuilt later. System Monitor remains detached.
- Bluetooth uses the native Quickshell service and a narrow service/view boundary. Audio handoff is
  coordinated through semantic signals; views do not own native Bluetooth objects.
- Clipboard formatting and preview extraction live behind the Clipboard service plus pure helper
  rules. Native notification history remains service-owned, but currently has no Center route.
- The Center pig is a user-configurable idle animation. Its drawing implementation is currently
  shared with the `demos/dancing_pig` visual fixture; this intentional dependency should be moved
  into a production-owned component if the demo is retired later.

## Remaining review risks

- `qmllint` still reports the documented Quickshell `PanelWindow` metadata warnings and known
  native-type/signal metadata warnings listed in `scripts/qmllint_allowlist.txt`. They are accepted
  compatibility warnings, not newly introduced unused-variable findings.
- The working tree contains a large, mixed, uncommitted batch. Keep future commits capability-sized
  so Bluetooth, Center/Active Window, animation, Clipboard and Agent Approval can be reverted and
  reviewed independently.
- Foreground/live acceptance can affect the currently running shell. Run the focused scripts in
  `docs/TESTING.md` and complete visual checks on `DP-1` before treating the batch as released.

## Required regression commands

```bash
./scripts/check.sh
git diff --check
./scripts/smoke.sh
./scripts/protected_acceptance.sh
./scripts/center_notch_acceptance.sh
./scripts/bluetooth_acceptance.sh
hyprctl configerrors
```

The acceptance scripts must not mutate real Bluetooth pairing/power state, launch real
applications, or overwrite clipboard contents.
