# Configuration and runtime data

The skeleton ships one small read-only settings document at `config/defaults/settings.json` and
its schema at `config/schemas/settings.schema.json`. It currently contains only state consumed by
the protected runtime: locale, light/dark mode, reduced motion, global hidden application IDs,
Spotlight transition preferences and 24-hour Clock preference.

`Preferences.qml` reads shipped defaults with `Quickshell.shellPath()` and optional runtime state
with `Quickshell.dataPath("settings.json")`. `PreferencesValidator.project()` selects supported
fields into a fresh object. This means a broader historical v5 runtime file remains readable, but
retired Frame/Audio/Theme/Layout fields do not enter live state and are never rewritten merely by
starting the shell.

Clipboard history uses `Quickshell.dataPath("clipboard-history.json")` and `FileView.atomicWrites`.
No runtime document belongs in Git.

When a new module genuinely needs configuration:

1. Add only its stable user preference to defaults/schema.
2. Extend the projection with a safe fallback and range/type normalization.
3. Add a projection test for valid, missing and historical input.
4. Persist through a Core/Service owner, never a view.

Do not introduce migration machinery until a persisted public schema actually changes. Unknown or
malformed runtime input must fall back without crashing or destructively rewriting the user's file.
