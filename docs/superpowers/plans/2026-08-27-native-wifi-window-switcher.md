# Native Wi-Fi and Window Switcher Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver native Wi-Fi and a shared-window-source Window Switcher in one verified batch.

**Architecture:** Wi-Fi is an independent `Quickshell.Networking` service/view slice. Window Switcher first centralizes native Hyprland toplevel ownership, then lets Dock and Switcher consume immutable shared descriptors. App composition, i18n, IPC, bindings and live gates integrate both only after their domain checks pass.

**Tech Stack:** Quickshell 0.3.1, Qt/QML, JavaScript, Hyprland Lua bindings.

**Spec:** `docs/superpowers/specs/2026-08-27-native-wifi-window-switcher-design.md`

## Global Constraints

- Runtime is pure QML/JS: no `Process`, `execDetached`, `nmcli`, `hyprctl`, polling timer, Python or Go backend.
- Titonium surfaces and exclusive zones remain DP-1-only; DP-3 remains available to another shell.
- Spotlight, Input Method and their bindings remain behaviorally unchanged.
- UI never owns native platform objects, persistence or secrets.
- Automated acceptance is read-only for network mutation and window activation.
- No glass, blur, gradient, shader, `MultiEffect` or infinite animation.

---

### Task 1: Native Wi-Fi domain and service

**Files:**
- Create: `Titonium/Services/Network/WifiRules.js`
- Create: `Titonium/Services/Network/NetworkService.qml`
- Create: `Titonium/Services/Network/qmldir`
- Create: `scripts/check_wifi_rules.js`
- Create: `scripts/check_wifi.py`

**Interfaces:**
- Produces normalized `available`, `wifiEnabled`, `wifiHardwareEnabled`, `scanning`, `connectedName`, `networks`, `stateKey`.
- Produces narrow intents `setWifiEnabled(bool)`, `setScanning(bool)`, `connect(id)`, `connectWithPassword(id, password)`, `disconnect(id)`, `forget(id)`, `snapshot()`.

- [ ] Write Node fixtures for duplicate SSIDs, connected/known precedence, signal/name ordering, security/state keys and descriptor secrecy; run them and observe RED.
- [ ] Implement pure projection and icon rules; run fixtures GREEN.
- [ ] Write the architecture gate requiring the sole native import, lexical re-lookup and forbidden runtime dependencies; observe RED.
- [ ] Implement the singleton adapter with bounded warnings and secret-free snapshot; run Wi-Fi and full static checks GREEN.

### Task 2: Wi-Fi popup and Bar button

**Files:**
- Create: `Titonium/Overlays/Network/NetworkPopupCoordinator.qml`
- Create: `Titonium/Overlays/Network/NetworkPopupSurface.qml`
- Create: `Titonium/Overlays/Network/WifiNetworkRow.qml`
- Create: `Titonium/Overlays/Network/qmldir`
- Modify: `Titonium/Bar/islands/ConnectivityPill.qml`
- Test: `scripts/check_wifi.py`

**Interfaces:**
- Consumes Task 1 normalized state/intents.
- Produces `NetworkPopupCoordinator.open/toggle/close` and a lazy SurfaceManager descriptor.

- [ ] Add failing presentation contracts for uniform Bar control, DP-1 routed coordinator, static groups, view-local password and scanner lifecycle.
- [ ] Implement the minimal popup and row; discard password on close/change/submit and disable scanning on destruction.
- [ ] Run Wi-Fi, Bar, qmllint and full static gates GREEN.

### Task 3: Shared native window ownership

**Files:**
- Create: `Titonium/Services/Hyprland/WindowRules.js`
- Create: `Titonium/Services/Hyprland/WindowRegistry.js`
- Modify: `Titonium/Services/Hyprland/HyprlandService.qml`
- Modify: `Titonium/Services/Dock/DockService.qml`
- Modify: `scripts/check_dock.py`
- Create: `scripts/check_windows.js`

**Interfaces:**
- Produces immutable `HyprlandService.windows` and narrow `activateWindow(id)`, `closeWindow(id)`.
- Dock continues to expose its existing grouped `items` and operations unchanged.

- [ ] Add RED fixtures for stable descriptors, app-id fallback, MRU inputs and raw-object rejection.
- [ ] Implement the private registry and sole native listener in HyprlandService.
- [ ] Refactor Dock to consume descriptors/actions without changing its public contract.
- [ ] Run Windows, Dock and protected gates GREEN.

### Task 4: Window Switcher model and surface

**Files:**
- Create: `Titonium/Services/WindowSwitcher/WindowSwitcherRules.js`
- Create: `Titonium/Services/WindowSwitcher/WindowSwitcherService.qml`
- Create: `Titonium/Services/WindowSwitcher/qmldir`
- Create: `Titonium/Overlays/WindowSwitcher/WindowSwitcherSurface.qml`
- Create: `Titonium/Overlays/WindowSwitcher/WindowSwitcherTile.qml`
- Create: `Titonium/Overlays/WindowSwitcher/qmldir`
- Create: `scripts/check_window_switcher_rules.js`
- Create: `scripts/check_window_switcher.py`

**Interfaces:**
- Consumes `HyprlandService.windows/activateWindow(id)`.
- Produces `begin(direction)`, `next()`, `previous()`, `accept()`, `cancel()`, `snapshot()` and lazy overlay state.

- [ ] Add RED fixtures for minimized filtering, active-first MRU, wrap, stale selection and empty close.
- [ ] Implement the model with selected id only; run rules GREEN.
- [ ] Add RED surface contracts for icon/title list, focus/lifecycle and forbidden effects/raw objects.
- [ ] Implement the solid lazy overlay and run Switcher/full static gates GREEN.

### Task 5: Composition, IPC, i18n and bindings

**Files:**
- Modify: `Titonium/App.qml`
- Modify: `config/i18n/en.json`
- Modify: `config/i18n/vi.json`
- Modify: `scripts/check.sh`
- Create: `scripts/wifi_acceptance.sh`
- Create: `scripts/window_switcher_acceptance.sh`
- Modify: `scripts/protected_acceptance.sh`
- Modify: `/home/cole/.config/hypr/hyprland.lua`
- Modify: `/home/cole/Projects/titonium-hyprland/config/hypr/hyprland.lua`

**Interfaces:**
- Adds read-only Wi-Fi IPC `state/popup/closePopup/popupState`.
- Adds Window Switcher IPC `next/previous/accept/close/state`; automated acceptance never calls `accept`.

- [ ] Add failing integration gates for IPC shape, mutual exclusion, locale parity and direct-path bindings.
- [ ] Compose both slices and register all checks; run static gates GREEN.
- [ ] Replace the disabled legacy submap blocks in both Hyprland copies with direct path bindings and Super-release accept; verify config errors are empty.
- [ ] Run foreground smoke, focused read-only acceptance and protected acceptance; restore exactly one Titonium daemon on DP-1.
- [ ] Record manual Wi-Fi mutation and Switcher accept/release checkpoints without marking them automatically complete.

