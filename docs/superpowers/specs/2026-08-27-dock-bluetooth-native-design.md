# Titonium native Dock + Bluetooth design

**Date:** 2026-08-27  
**Status:** Proposed for implementation  
**Runtime target:** Quickshell 0.3.1 on Hyprland, Titonium surfaces restricted to `DP-1`

## Intent

Deliver one coordinated milestone containing:

1. the remaining 32px Audio popup geometry correction;
2. a bottom-centered Dock inspired by Ambxst's interaction and lifecycle patterns;
3. a native Bluetooth service, Bar state and device popup using `Quickshell.Bluetooth`.

The milestone stays pure QML/JavaScript at runtime. It adds no Go, Python, shell helper, external
daemon, `Process`, raw `hyprctl`, `bluetoothctl`, `wpctl`, polling loop or Hyprland configuration
change. Spotlight, Input Method, protected keybindings and the `DP-1`-only screen policy remain
unchanged.

## Reference and provenance

The Dock studies these Ambxst files and concepts:

- `modules/dock/Dock.qml`: screen-scoped `PanelWindow`, hitbox mask and conditional reservation;
- `modules/dock/DockContent.qml`: bottom-edge reveal, pinned/auto-hide state, bounded slide/fade;
- `modules/dock/DockAppButton.qml`: grouped running applications and per-app interaction.

Ambxst is AGPL-3.0 and depends on its own `axctl`, `Config`, `GlobalStates`, shaders and unified
panel. Titonium will not copy those files or their global architecture. It will independently
implement only the approved interaction grammar behind Titonium-owned services, theme tokens and
screen/surface contracts. The implementation documentation records the upstream repository URL,
revision inspected, license and exact files.

Bluetooth is based on the installed Quickshell 0.3.1 native module. `Bluetooth`,
`BluetoothAdapter` and `BluetoothDevice` provide adapter power/discovery, device state, battery,
connect/disconnect, pair/cancel and forget operations over BlueZ. Titonium does not add its own
DBus or CLI adapter.

## Locked decisions

### Screen ownership

- Dock, Bluetooth popup and every new transient surface exist only on `ScreenPolicy.screens`, which
  currently contains `DP-1` only.
- Titonium creates no Dock window, popup host or exclusive zone on `DP-3`.
- If `DP-1` disconnects, the Dock is destroyed and transient state closes. Reconnecting `DP-1`
  recreates the Dock reactively.
- A request made while `DP-3` is focused routes to `DP-1` through `ScreenRouter`; it never creates a
  Titonium surface on `DP-3`.

### Audio prerequisite

- Remove the redundant `ColumnLayout.anchors.margins` from `AudioPopupSurface` and rely on
  `Panel.padding`, or otherwise prove both layers are included exactly once.
- Add a geometry-oriented fixture that computes the fixed region, stream region and outer padding,
  preventing the 32px undercount found by final review.
- Re-run the Audio static and read-only live acceptance before Dock/Bluetooth integration.

### Dock behavior

- Position: bottom center of `DP-1` only.
- Presentation: solid Neutral Utility surface, no blur, shader, `MultiEffect`, gradient, glow or
  infinite animation.
- Default dimensions: 56 logical px body, 40px application icons, 8px outside margin and 6px item
  spacing. Hover uses a bounded 1.12 scale and 4px lift with `Motion.fast`; reduced motion makes
  those transitions immediate.
- Default visibility: auto-hide when the active workspace contains a window; remain visible on an
  empty workspace; reveal from a 4px bottom-edge hit region. Fullscreen follows the same explicit
  edge reveal and never polls pointer position.
- A pin control keeps the Dock visible. Only pinned-open mode reserves `56 + 8 = 64` logical px;
  auto-hidden mode has exclusive zone 0.
- The window mask contains only the revealed Dock and its bottom-edge reveal region. The rest of
  the screen remains click-through.
- The first item is an Arch/Applications button that opens the existing Spotlight Applications
  scope on `DP-1`.
- Application items merge persisted pins with running Hyprland toplevel groups. Pinned order is
  stable; unpinned running groups follow first-seen session order and do not reshuffle on focus.
- One item represents one desktop application and contains zero or more live toplevels. It exposes
  app id, name, icon, running count, active, urgent and pinned state; raw toplevel objects never
  leave `DockService`.
- Left click focuses the active/first window when running and launches the desktop entry otherwise.
  Repeated clicks cycle the group's windows. Middle click launches a new instance.
- Right click opens a lightweight item menu with New Window, Pin/Unpin and Close Active Window.
  Close targets one known toplevel only and is never exposed through IPC or automated acceptance.
- Running applications show one semantic indicator; urgent applications use the semantic warning
  state. Tooltips show the full application name and running-window count.
- No live window thumbnail, drag reordering, minimize animation, MPRIS or settings page is included
  in this milestone.

### Dock persistence

- `DockStore` is the only Dock persistence owner and uses `FileView` outside the repository at
  `Quickshell.dataPath("dock.json")`.
- Shipped `config/defaults/dock.json` uses schema `titonium.dock/v1` with:

```json
{
  "$schema": "titonium.dock/v1",
  "schemaVersion": 1,
  "pinnedIds": [],
  "pinnedOpen": false,
  "autoHide": true
}
```

- An empty initial pin list is intentional: the Applications button is always usable and running
  applications can be pinned from their item menu. No distribution-specific desktop IDs are
  shipped.
- Projection accepts non-empty string IDs, removes duplicates while preserving order and retains
  IDs whose desktop entry is temporarily unavailable. Unknown pins stay hidden until their desktop
  entry returns, preventing a package upgrade or removable application from erasing user intent.
- Writes use `FileView.setText()` with the repository's atomic-write contract. Invalid runtime JSON
  falls back to shipped defaults and logs one bounded warning. Tests prove Apply-like writes touch
  only the data directory and leave Git and Hyprland configuration unchanged.

### Dock architecture

```text
App
└── DockHost ── Variants(ScreenPolicy.screens)
    └── DockWindow (PanelWindow + mask/exclusive-zone lifecycle)
        └── DockSurface
            ├── Applications trigger
            ├── DockAppButton × DockService.items
            └── Pin control

DockSurface ──read/intent──> DockService ──> Hyprland.toplevels + ApplicationService
                              └────────────> DockStore
```

- `DockRules.js` owns pure grouping, stable ordering, visibility and click-cycle decisions.
- `DockService.qml` is the only Dock owner of Hyprland toplevel objects and exposes normalized
  immutable descriptors plus narrow intent methods.
- `DockStore.qml` owns the runtime pin order and pinned-open/auto-hide values.
- Dock UI owns no `Process`, `FileView`, raw compositor dispatch or persistence.

### Bluetooth behavior

- The existing diagnostic Bluetooth glyph becomes a real state-aware button inside the final
  connectivity pill. Wi-Fi remains diagnostic in this milestone.
- Bar states: unavailable, powered off, powered on, scanning and connected count. Accessible text
  includes state and connected-device count.
- Clicking the button opens a lazy Bluetooth popup through `SurfaceManager` and the existing
  `OverlayHost`; opening it closes Audio, Spotlight and Center Notch through the shared transient
  ownership rule.
- Popup header contains adapter name, power switch and scan control. Power and scan are disabled
  when no adapter exists.
- Device sections are Connected, Paired and Available. Empty sections collapse; the popup height is
  content-driven and capped by available `DP-1` height.
- Device rows show icon, name, connection/pairing state and battery percentage when available.
- Row actions are state-derived: Connect, Disconnect, Pair, Cancel Pairing and Forget. Forget uses
  an inline two-step confirmation and never runs from IPC.
- Sorting is deterministic: connected first, pairing second, paired third, available last; within a
  section sort case-insensitively by name and then address.
- Turning the adapter off closes discovery and leaves a safe empty/unavailable view. Adapter or
  BlueZ absence never crashes the shell and never triggers an external service-management command.
- The native API's pairing support is used as-is. Devices requiring an authentication agent that
  the installed module/system does not provide may fail gracefully; Titonium will not add a custom
  agent or CLI fallback in this milestone.

### Bluetooth architecture

```text
ConnectivityPill / BluetoothPopupSurface
                  └──read/intent──> BluetoothService
                                      └── Quickshell.Bluetooth / BlueZ

BluetoothPopupCoordinator ──> SurfaceManager ──> OverlayHost Loader(DP-1 owner only)
```

- `BluetoothRules.js` owns pure device normalization, grouping, sorting and accessible state.
- `BluetoothService.qml` is the sole importer of `Quickshell.Bluetooth`. It retains native adapter
  and device objects privately, exposes normalized descriptors and relooks up a native device by
  address before every mutation.
- Mutation methods return `false` for missing/stale adapters or devices and log bounded warnings.
- Bluetooth IPC is read-only: `state()`, `popup()`, `closePopup()` and `popupState()`. It exposes no
  power, scan, connect, disconnect, pair, cancel or forget endpoint.

## Surface coordination

- Dock is a persistent edge surface and does not use `SurfaceManager`.
- Dock item menus and the Bluetooth popup are transient descriptors owned by `SurfaceManager` and
  rendered by the existing `OverlayHost`. Only one exclusive-focus transient surface may exist
  across Titonium.
- Opening Spotlight, Center Notch, Audio or Bluetooth closes the previous transient owner.
- Outside click and Escape close Bluetooth and Dock item menus. Closing unloads the heavy tree.
- The Dock remains usable while a transient is open, but opening a Dock item menu first closes any
  other transient.

## i18n and accessibility

- All Dock and Bluetooth strings use namespaced EN/VI keys with locale parity.
- Every icon-only action has a state-aware accessible name.
- Dock keyboard navigation follows visual order; Enter/Space activates, Menu/Shift+F10 opens the
  item menu and Escape closes it.
- Bluetooth rows expose name, state and battery; action controls expose the target device name.
- Focus returns to the invoking Dock/Bluetooth button when its transient closes.
- Reduced motion sets reveal, hover, popup and item transitions to zero duration.

## Performance and failure policy

- No repeating timer, pointer polling, shader, `MultiEffect`, infinite animation or hidden heavy
  tree.
- Dock reacts to native toplevel/model signals. Bluetooth reacts to native adapter/device models.
- Animation changes only opacity, translation and small scale for bounded durations.
- Disconnected/stale objects are relooked up at mutation time; invalid requests fail without QML
  exceptions.
- A missing desktop entry retains a generic icon/name and remains focusable if a window exists.
- Runtime corruption affects only Dock pin state and falls back to defaults; it cannot stop Bar,
  Spotlight, Audio or Bluetooth from loading.

## Testing and acceptance

### Static and pure tests

- Audio geometry fixture fails on double-counted or omitted padding.
- Dock rules fixtures cover merge/deduplication, stable pin/running order, first-seen order, active
  and urgent aggregation, click cycling, visibility and invalid entries.
- Dock persistence fixtures cover schema validation, duplicate removal, temporary unknown-ID
  retention, invalid JSON fallback and repository isolation.
- Bluetooth rules fixtures cover no adapter, powered off, scanning, device grouping/sorting,
  duplicate addresses, battery bounds and stale device lookup.
- Architecture gates enforce sole native-module owners, `ScreenPolicy.screens`, lazy transient
  loading and forbidden runtime dependencies.
- `qmllint` has no new error or warning beyond the existing documented `PanelWindow` metadata
  allowlist.

### Read-only live acceptance

- Stop the daemon using the same shell ID and launch one foreground Titonium instance.
- Verify `Configuration Loaded`, clean rejection patterns, Git cleanliness and unchanged hashes for
  both Hyprland files.
- Dock IPC may expose only state/snapshot for acceptance; it must not launch, focus, close or pin.
- Bluetooth acceptance reads state, opens/closes the popup and verifies mutual exclusion. It must
  not power, scan, pair, connect, disconnect or forget.
- DP-1 owns one Bar and one Dock layer. DP-3 owns no Titonium layer or exclusive zone.
- `hyprctl configerrors` remains empty.

### Manual visual and interaction checkpoint

- First approve the corrected Audio popup geometry.
- Verify Dock scale 1.5 geometry, empty/running/pinned/urgent groups, hover lift, reveal, pin reserve,
  click-through, keyboard navigation and app focus/launch/cycle behavior on DP-1.
- Confirm DP-3 remains available to the separate reference shell.
- Record original Bluetooth power/discovery/device state. Verify unavailable/off/on/scanning states,
  connect/disconnect and one safe pairing flow where supported. Verify confirmation before forget.
- Restore the original Bluetooth power, discovery and connection state after testing.
- Do not start Network/Wi-Fi implementation until this checkpoint is approved.

## Delivery and acceleration strategy

The work is one milestone with reviewable commits. To reduce elapsed time without creating shared
file conflicts:

1. Fix and review the Audio geometry prerequisite sequentially.
2. In parallel, one agent owns only new Dock domain/service/store files and Dock tests, while a
   second agent owns only new Bluetooth domain/service files and Bluetooth tests.
3. Integrate Dock host/view and Bluetooth popup/view sequentially. Shared files (`App.qml`,
   `ConnectivityPill.qml`, i18n, global checks and docs) have one owner at a time.
4. Run per-slice review, one whole-milestone review, full static/live acceptance and then stop for
   the user's visual interaction checkpoint.

Parallel workers never edit the same file, never launch competing Quickshell daemons and never
mutate real audio or Bluetooth state. Only the controller runs host-session acceptance and restores
the single Titonium daemon afterward.

## Non-goals

- No Wi-Fi/Network implementation.
- No MPRIS, window thumbnails, drag-and-drop Dock reordering or minimize effects.
- No Bluetooth codec/profile selection or custom authentication agent.
- No Dock/Bluetooth Settings Center pages in this milestone.
- No glass backend, compositor source modification or Hyprland configuration edit.
- No Titonium surface on DP-3.
