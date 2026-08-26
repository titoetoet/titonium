# Architecture

## Goals

Titonium separates declarative composition, visual policy, application state and OS access.
The composition root may assemble modules, but a module never reaches through UI objects to
control another module.

## Dependency direction

```text
App + Surfaces
      |
Modules + Composition
      |
Design + Foundation
      |
Platform
```

- `App` owns startup and health IPC.
- `Surfaces` owns Wayland windows and lazy overlay hosts.
- `Composition` interprets versioned layout nodes and resolves widget types.
- `Modules` are vertical features with their own UI/model boundary.
- `Design` contains semantic tokens, controls and material surfaces.
- `Foundation` contains configuration, localization, logging and global coordination state.
- `Platform` is the only layer allowed to execute commands or bind directly to compositor and
  hardware APIs.

Quickshell exposes local modules through its root-relative `qs` namespace, so their runtime
URIs are `qs.Titonium.*`. `Titonium` remains the project namespace and no legacy
`ColeShell.*` URI is used.

## Runtime flow

1. `shell.qml` creates `AppShell` and fixes Titonium data/state directories.
2. `ConfigStore` loads shipped defaults and optional runtime overrides.
3. Invalid runtime data is rejected; shipped defaults remain active.
4. `MenuBarHost` creates one lightweight surface for each `Quickshell.screens` entry.
5. `LayoutRenderer` recursively renders the selected screen layout.
6. `WidgetRegistry` maps a `widgetType` to one QML URL.
7. Widget actions travel through signals or `SurfaceCoordinator`, never sibling IDs.

Spotlight, Arch Menu and Settings are distinct transient flows. Spotlight owns keyboard-first
application and clipboard discovery; the compact Arch Menu owns the MenuBar dropdown and
confirmed session actions; Settings opens the standalone `SettingsCenter` surface. Arch Menu
Settings activation replaces the dropdown with SettingsCenter, whose reusable
`SettingsWorkspace` owns Settings content and preview controls.

## Multi-monitor policy

All sizes are logical pixels. The default layout applies to every output; an exact output-name
override replaces individual slots. Heavy overlay content is instantiated only for the active
target screen via `Loader.active`.

## State ownership

- `ConfigStore.committedState` is the last applied state.
- `ConfigStore.previewState` is the state currently rendered.
- `SurfaceCoordinator` is the only owner of transient surface state.
- Transient descriptors declare keyboard focus intent; `OverlayHost` translates the supported
  `exclusive` policy to layer-shell focus and otherwise remains non-focusable.
- Descriptor and screen values remain live-bound to an already loaded transient item. A
  descriptor marked `cancelPreviewOnClose` rolls back its ConfigStore preview when closed or
  replaced, including closure paths that bypass the surface UI.
- Module services own feature data; UI is a projection of that data.

## MenuBar platform boundaries

`Platform.Hyprland.HyprlandAdapter` projects compositor workspaces and focused-window state;
workspace activation is its only mutation. `Platform.Input.FcitxAdapter` observes Fcitx through
its StatusNotifier item, so engine changes are signal-driven and require no command or timer.
Feature models translate those platform values into semantic UI state. MenuBar QML never imports
Hyprland, ToplevelManager or SystemTray directly.

`Platform.Applications.ApplicationCatalog` is the sole desktop-entry boundary. It projects
visible entries into immutable UI records, resolves theme icons and launches only through
`DesktopEntry.execute()`. Spotlight UI never parses an Exec string or spawns a fallback command.

`Foundation.ApplicationVisibilityStore` preserves that raw installed catalog as `allApplications`
for Settings and exposes preview-aware `visibleApplications` to every application picker. Hidden
IDs remain global configuration; launch requests still cross only through `ApplicationCatalog`.

`Modules.Frame` is absent from the window tree unless `modules.frame.enabled` is true. When
enabled, it creates one bottom-layer, empty-input-region surface per screen and renders only a
semantic Rectangle border. Canvas, effects and repaint loops are forbidden.
