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

Launcher creates its catalog model and 24-item pages only while Dashboard is open. Its stable
split is one-third identity/navigation and two-thirds search/app pages. A vertical wheel gesture
changes the horizontal page index; search/category changes reset to page one without changing
the overlay dimensions. Launch history is a small atomic state document used to promote the six
most-used apps before the alphabetical catalog; it is not a settings transaction. Desktop
discovery, icon resolution and execution remain behind
`Platform.Applications.ApplicationCatalog`; a disappearing entry fails safely.

Transient surfaces that must dismiss when focus moves to another monitor declare
`closeOnMonitorChange: true`. `OverlayHost` observes monitor-focus events through the Hyprland
adapter, without polling or compositor commands.

Session actions are explicit Platform capabilities. Dashboard shows all supported actions but
requires a second confirmation gesture before dispatch. Automated tests must inspect capability
and UI contracts only; they never execute logout, suspend, hibernate, reboot or poweroff.

Settings pages never own persisted state. They project `ConfigStore.previewState` and mutate it
only through typed `patch()` paths. SettingsCenter begins one preview transaction; Apply commits
atomically, while Cancel, Escape, outside click, IPC close and surface replacement all rollback.
Theme metadata shown by UI comes from validated theme documents, not duplicated catalog labels.

Panel metrics live in the versioned layout document: `menubar.height`, `padding` and `spacing`.
They preview live on all outputs, including the layer-shell exclusive zone. Frame configuration
lives under `settings.modules.frame`, remains disabled by default and is reset independently.

## Failure behavior

Missing registry entries and invalid node content render `DiagnosticWidget` with a concise
message. Sibling nodes continue to render. Errors are logged with node and screen IDs.
