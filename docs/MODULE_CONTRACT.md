# Module and composition contract

## Layout node kinds

Every node has a unique non-empty `id` and one of these `type` values:

- `widget`: resolves `widgetType` through `WidgetRegistry`; optional `props` and `panel`.
- `group`: recursively lays out `children`; supports `orientation`, `spacing` and `surface`.
- `panel`: declares lazily rendered transient content in `child`.
- `tabs`: owns `pages`, each with an ID, translation key and child node.
- `spacer`: consumes available space or an explicit logical size.

The MenuBar document contains `screens.default.slots.start|center|end`. A screen-name object
may override any of those slots.

## Widget contract

All registry widgets derive from `WidgetBase` and receive:

- `node`: the validated widget node.
- `screen`: the current `ShellScreen`.
- `context`: host context such as slot and density.

They emit:

- `actionRequested(action, payload)` for domain actions.
- `surfaceRequested(descriptor)` for a panel/popup request.
- `surfaceCloseRequested()` to close the surface they own.

Widgets expose implicit size and accessibility metadata. They do not expose an `expanded`
property for the MenuBar to manage.

MenuBar feature widgets are vertical modules. Each folder owns a small state-only model and a
`WidgetBase` UI; compositor/service bindings live in a named Platform adapter. Registry types
currently include `menubar.workspaces`, `menubar.active-window`, `menubar.input-method` and
`menubar.clock` and `menubar.launcher`.
Workspace and running-app activation are routed exclusively through
`Platform.Hyprland.HyprlandAdapter`.

Active Window is a running-app task strip immediately adjacent to Workspaces. Its model groups
non-minimized Wayland toplevels by app ID, resolves desktop metadata through
`Platform.Applications.ApplicationCatalog`, and preserves stable discovery order. Inactive apps
render as compact icons; the active app alone expands to its current title. There is no timer,
`hyprctl` process, or compositor query in the model/UI.

Clock owns one shared `SystemClock` at minute precision for the MenuBar. Clicking it lazily creates
an analog-clock panel with a seconds-precision clock; closing the surface destroys that tree, so
there is no seconds update at idle. Calendar/Lunar remain separate assets reserved for the future
Notification Center. Lunar conversion is pure stateless JavaScript fixed to Vietnam UTC+7 and
must retain its fixture tests.

Spotlight owns the keyboard-first application and clipboard surface. It categorizes desktop
entries from `Foundation.ApplicationVisibilityStore.visibleApplications`, renders a fixed 5×4
browse grid with occupancy indicators, and keeps query results and clipboard content as separate
lazy branches. Settings alone reads `allApplications` so hidden installed apps remain recoverable.
Desktop discovery, icon resolution and execution remain behind
`Platform.Applications.ApplicationCatalog`; a disappearing entry fails safely.

The compact Arch Menu owns the MenuBar trigger, grouped action dropdown, About surface and local
confirmation sheet for session actions. Selecting Settings closes or replaces the dropdown with
the standalone `SettingsCenter`; it does not host Settings pages, which remain owned by
`SettingsWorkspace`.

Transient surfaces that must dismiss when focus moves to another monitor declare
`closeOnMonitorChange: true`. `OverlayHost` observes monitor-focus events through the Hyprland
adapter, without polling or compositor commands.

Session actions are explicit Platform capabilities. The compact Arch Menu shows each implemented
session action and requires a second confirmation gesture before dispatch. Its confirmation stays
open until the Platform adapter reports meaningful success and shows a localized failure otherwise.
Automated tests use injected lifecycle events only; they never execute lock, logout, suspend,
hibernate, reboot or poweroff.

Settings pages never own persisted state. `SettingsCenter` is the sole Settings host and embeds
the reusable `SettingsWorkspace`, which projects `ConfigStore.previewState` and mutates it only
through typed `patch()` paths. SettingsCenter begins one preview transaction; Apply commits
atomically, while Cancel, Escape, outside click, IPC close and surface replacement all rollback.
Theme metadata shown by UI comes from validated theme documents, not duplicated catalog labels.

Panel metrics live in the versioned layout document: `menubar.height`, `padding` and `spacing`.
They preview live on all outputs, including the layer-shell exclusive zone. Frame configuration
lives under `settings.modules.frame`, remains disabled by default and is reset independently.

## Failure behavior

Missing registry entries and invalid node content render `DiagnosticWidget` with a concise
message. Sibling nodes continue to render. Errors are logged with node and screen IDs.
