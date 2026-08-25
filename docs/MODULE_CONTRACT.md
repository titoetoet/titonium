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
Workspace activation is the only compositor mutation in this slice and is routed exclusively
through `Platform.Hyprland.HyprlandAdapter`.

Clock owns one shared `SystemClock` at minute precision. Calendar content is a transient tree:
`SurfaceCoordinator` selects its screen, `OverlayHost` supplies that screen's logical size, and
the active Loader creates the 42-day grid only while open. Lunar conversion is pure stateless
JavaScript fixed to Vietnam UTC+7 and must retain its fixture tests.

Launcher creates its catalog model and 24-result application grid only while Dashboard is open.
Search/category filtering is a pure model operation. Desktop discovery, icon resolution and
execution remain behind `Platform.Applications.ApplicationCatalog`; a disappearing entry fails
safely and closes no unrelated surface.

Settings pages never own persisted state. They project `ConfigStore.previewState` and mutate it
only through typed `patch()` paths. SettingsCenter begins one preview transaction; Apply commits
atomically, while Cancel, Escape, outside click, IPC close and surface replacement all rollback.
Theme metadata shown by UI comes from validated theme documents, not duplicated catalog labels.

## Failure behavior

Missing registry entries and invalid node content render `DiagnosticWidget` with a concise
message. Sibling nodes continue to render. Errors are logged with node and screen IDs.
