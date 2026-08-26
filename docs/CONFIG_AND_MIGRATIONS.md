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

`beginPreview()` copies both committed settings and committed layout into their preview states.
`patch(path, value)` changes settings; `patchLayout(path, value)` changes the separately validated
layout document. `apply()` atomically writes each runtime document and promotes both previews.
`cancel()` restores both previews without writing. `restoreLayout()` is explicit and separate.

## Migrations

Every persisted document has integer `schemaVersion`. Future migrations are pure transforms
from version N to N+1, run before validation. Never silently reinterpret an existing field.
Settings schema v2 owns a dedicated `appearance` subtree. The pure v1→v2 migration preserves
locale, accessibility and module state, maps the retired foundation theme to
`titonium-neutral`, and never persists until the user applies a transaction.

Settings v2→v3 normalized the former Launcher profile and transition fields as an intermediate
migration step. Settings v3→v4 removes `modules.launcher`, creates `modules.spotlight` and carries
forward only `pageTransition` and `transitionDuration`; profile, embedded-Settings and retired
catalog-control fields are discarded. Older documents run each pure step in order and are not
written until Apply.

Settings v4→v5 adds global `applications.hiddenIds` as an empty list while preserving locale,
appearance, accessibility and every module value. Hidden application IDs are unique non-empty
desktop-entry IDs and remain outside module-owned settings.

`restoreAppearance()` replaces only preview appearance state with shipped defaults. It always
selects Neutral Utility dark/comfortable with empty overrides. Locale, accessibility, module
state and the separate layout document remain untouched; Apply persists and Cancel rolls back.
Frame reset changes only `modules.frame`; layout reset changes only the layout document.
