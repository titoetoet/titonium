# Architecture

Titonium is deliberately a composition of vertical slices around a small stable skeleton.

```text
shell.qml
└── Titonium/App.qml
    ├── Bar/BarHost.qml ── Variants(Quickshell.screens)
    │   └── BarSurface → Bar → widgets
    └── Core/Surfaces/OverlayHost.qml ── Variants(Quickshell.screens)
        └── Loader(active only for SurfaceManager owner)
            └── Overlays/Spotlight

Views ──read──> Services ──adapt──> Quickshell / Hyprland / DBus
  │                  │
  └── Theme/Shared   └── Core Runtime (preferences, i18n, logging)
```

## Screen and window lifecycle

`BarHost` and `OverlayHost` use `Variants` over `Quickshell.screens`. Quickshell creates or
destroys one delegate as outputs appear or disappear; monitor names are never hardcoded.
`ScreenRouter` resolves focused or requested outputs with a first-screen fallback.

Each output always owns one lightweight overlay window, but its feature tree exists only when
`SurfaceManager` has a descriptor for that screen. The manager allows one transient owner across
the shell. Focused-monitor changes close Spotlight to prevent a stranded exclusive-focus window.

## State and presentation

Singleton services expose reactive state once for all consumers:

- `ApplicationService`: DesktopEntries catalog, visibility and launch boundary.
- `ClipboardService`: Quickshell clipboard events and atomic history persistence.
- `HyprlandService`: focused monitor and workspace state/actions.
- `InputMethodService`: event-driven Fcitx SystemTray state.

QML views draw, animate and emit intent. They do not spawn commands, store files or duplicate
system listeners. Pure JavaScript helpers contain searchable/testable domain rules.

## Protected feature flow

IPC in `App.qml` resolves a screen and sends a descriptor to `SurfaceManager`. `OverlayHost`
loads `SpotlightSurface`, binds the current descriptor, and releases it on close. Spotlight reads
Applications and Clipboard services and publishes query/scope state back through the descriptor.

The dependency direction is `App/View → Core + Services + Shared + Theme`. Reverse imports and
feature-to-feature imports are architecture violations.
