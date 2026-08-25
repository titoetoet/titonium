# Configuration and migrations

## Files

- `config/defaults/settings.json`: shipped application defaults.
- `config/defaults/layout.json`: shipped composition defaults.
- `config/schemas/*.schema.json`: documented public schemas.
- Titonium data directory: atomically written runtime overrides.
- Titonium state directory: ephemeral UI/session state only.

The source tree is always read-only at runtime.

## Loading

Defaults must validate. A runtime file is accepted only when its schema version and structure
are valid. Invalid JSON, duplicate node IDs or unknown node kinds reject the entire runtime
document and retain the last valid/default state.

## Transactions

`beginPreview()` copies committed state into preview state. `patch(path, value)` changes only
preview state. `apply()` validates, atomically persists and promotes preview state. `cancel()`
restores preview from committed state without writing.

## Migrations

Every persisted document has integer `schemaVersion`. Future migrations are pure transforms
from version N to N+1, run before validation. Never silently reinterpret an existing field.
Settings schema v2 owns a dedicated `appearance` subtree. The pure v1→v2 migration preserves
locale, accessibility and module state, maps the retired foundation theme to
`titonium-neutral`, and never persists until the user applies a transaction.

`restoreAppearance()` replaces only preview appearance state with shipped defaults. It always
selects Neutral Utility dark/comfortable with empty overrides. Locale, accessibility, module
state and the separate layout document remain untouched; Apply persists and Cancel rolls back.
