# Configuration and runtime data

The shell ships read-only `titonium.settings/v7` defaults at `config/defaults/settings.json` and its
schema at `config/schemas/settings.schema.json`. V7 contains locale, appearance, reduced motion,
global hidden application IDs, Spotlight transition, Bar/workspace, Dock, Notification, Clock and
Audio amplification preferences.

`Preferences.qml` reads shipped defaults with `Quickshell.shellPath()` and optional runtime state
with `Quickshell.dataPath("settings.json")`. `PreferencesValidator.project()` selects supported
fields into a fresh object. Historical runtime files remain readable, but retired fields do not
enter live state and are never rewritten merely by starting the shell.

V6 projects to V7 in memory. If the source is not already V7 with a Dock subtree, the optional
legacy `Quickshell.dataPath("dock.json")` v1 document supplies `visibilityMode` and normalized,
case-insensitive `pinnedIds`. A valid V7 Dock subtree always wins over conflicting legacy data.
Startup never rewrites or removes either file; only an explicit Settings Apply or a narrow runtime
preference action writes `settings.json`, using atomic writes. The legacy file remains available
for rollback.

Clipboard history uses `Quickshell.dataPath("clipboard-history.json")` and `FileView.atomicWrites`.
No runtime document belongs in Git.

When a new module genuinely needs configuration:

1. Add only its stable user preference to defaults/schema.
2. Extend the projection with a safe fallback and range/type normalization.
3. Add a projection test for valid, missing and historical input.
4. Persist through a Core/Service owner, never a view.

Unknown or malformed runtime input must fall back without crashing or destructively rewriting the
user's file. Settings preview is memory-only: Cancel discards it, while Apply is the only UI action
that persists the complete projected V7 document.
