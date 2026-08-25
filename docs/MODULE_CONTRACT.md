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

## Failure behavior

Missing registry entries and invalid node content render `DiagnosticWidget` with a concise
message. Sibling nodes continue to render. Errors are logged with node and screen IDs.

