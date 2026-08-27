# Native Wi-Fi and Window Switcher Design

## Scope

This batch delivers two independent capabilities in one integration cycle: a native Quickshell
Networking Wi-Fi popup and an icon/title Window Switcher. Both remain DP-1-only, pure QML/JS,
event-driven, solid Neutral Utility surfaces, and compatible with protected Spotlight/Input Method.

The user explicitly approved proceeding past the previous Wi-Fi manual-checkpoint deferral and
restoring Window Switcher bindings after focused acceptance passes.

## Wi-Fi

`NetworkService` is the sole importer of `Quickshell.Networking`. It projects immutable, secret-free
network descriptors and re-resolves native networks at every mutation. `WifiRules` deduplicates by
SSID (connected wins, otherwise strongest), sorts connected/known/signal/name deterministically,
and supplies semantic signal/security/state keys.

The public contract exposes availability, radio/hardware/scanning state, connected SSID, normalized
networks, and narrow `setWifiEnabled`, `setScanning`, `connect`, `connectWithPassword`, `disconnect`
and `forget` intents. Passwords stay view-local and never enter snapshots, logs, persistence or IPC.
Scanner state is enabled only while the lazy popup owns `SurfaceManager`; there is no timer or poller.

The connectivity Wi-Fi button replaces its disabled placeholder. Its popup uses fixed Connected,
Known and Available headings, an inline password prompt for unknown secured networks, and the same
DP-1 OverlayHost lifecycle as Audio/Bluetooth. Automated IPC is read-only: state and popup lifecycle.

## Shared window source and Window Switcher

`HyprlandService` becomes the sole Titonium owner of `Hyprland.toplevels` observation. A private
registry retains native objects; public descriptors contain only stable id, appId, title, icon,
active, urgent and minimized fields. Dock consumes descriptors and narrow window actions rather than
raw toplevels. No feature view can access native window objects.

`WindowSwitcherService` consumes the shared descriptors, filters minimized windows, maintains MRU
order with the active window first, stores only `selectedId`, wraps next/previous selection, and
re-resolves the selected id through `HyprlandService.activateWindow(id)` on accept. Empty lists close
safely and disappearing selected windows select the next valid item.

`WindowSwitcherSurface` is a lazy `SurfaceManager` overlay on DP-1 with exclusive focus while open.
It presents a bounded horizontal icon/title list; live screencopy, glass, shader and MultiEffect are
deferred. Hover selects, click accepts, outside click/Escape cancels, and Enter accepts.

The restored Hyprland flow uses direct `qs -p /home/cole/Projects/titonium ipc call window-switcher`
bindings. Super+Tab and Super+Shift+Tab cycle; releasing either Super key calls accept. No submap and
no QML command is required, so cancel cannot strand keyboard state.

## Testing and safety

Pure Node fixtures cover Wi-Fi normalization and switcher ordering/selection. Static gates enforce
single native import/ownership, no raw object escape, no commands, no polling, no effects, i18n
parity and lazy surface composition. Focused live acceptance may inspect state and exercise popup/
selection/cancel lifecycle but must not connect networks, send passwords, forget networks or accept
a window. Manual review owns those mutations and verifies Super-release focus behavior.

