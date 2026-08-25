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
Milestone 0 defines version 1 and intentionally does not import legacy settings.

