# Titonium Settings Center V1 Design

**Date:** 2026-08-28

## Objective

Build a DP-1-only standalone Settings Center for Titonium using the existing Neutral Utility
presentation layer and current native module contracts. Settings V1 provides transactional live
preview, Apply and Cancel without restoring the retired configuration, theme-catalog or recursive
layout architecture.

The Settings Center reuses the successful visual structure of the pre-contraction Settings UI
from commit `62f8ba1`, while replacing its `ConfigStore`, `SurfaceCoordinator`, theme catalog and
removed `Design/Controls` dependencies with the current Core, Shared and feature-service
boundaries.

## Locked product decisions

- Settings is a standalone centered surface, nominally `980x700` logical pixels.
- Titonium continues to own DP-1 only. Settings never appears on DP-3.
- Clicking the Topbar Center opens the existing Center Notch.
- The Settings button in the Center Notch rail closes the Notch and opens Settings.
- The Topbar visibility Pin remains immediately to the right of Center, but is a separate
  component, size contribution and input hitbox.
- Center Notch content remains intentionally limited in this milestone. The existing Daily Focus
  action moves into its Overview page so the primary Center click has one consistent meaning.
- Settings V1 includes General, Appearance, Spotlight, Bar, Dock, Notifications, Audio and About.
- Applications visibility remains a section inside Spotlight, not a separate navigation page.
- Dock settings additionally manage its visibility policy and ordered fixed application list.
- The shell remains QML-first. No Go/Python helper, UI-owned `Process`, raw command, Hyprland edit,
  shader, blur, glass or `MultiEffect` is introduced.

## Reuse from the pre-contraction source

The historical source is an implementation reference, not a module to restore wholesale.

### Structure retained

- `SettingsWorkspace.qml`: 64px header, 208px icon-and-label navigation column, divider, lazy page
  Loader and 64px action footer.
- `ApplicationVisibilityList.qml`: searchable reusable application rows with icon, name and
  visibility control.
- `SystemPage.qml`: setting-row composition for locale and reduced motion.
- `SpotlightPage.qml`: transition selector, duration control and embedded application list.
- `ThemePage.qml`: dark/light selection concept only.
- `ConfigStore.qml`: the small transaction concepts of begin-preview, path patch, dirty comparison,
  cancel rollback and atomic persistence.

### Structure rewritten

- The old full-screen dimmed `SettingsCenter` overlay and `SurfaceCoordinator` lifecycle are
  replaced by a dedicated `SettingsHost`, `SettingsWindow` and coordinator.
- Old imports from `Titonium.Design.Controls` become current `Titonium.Shared` controls.
- `ApplicationVisibilityStore` is replaced by current `ApplicationService` plus the preview
  settings state.
- Settings state is reduced to user preferences. It does not own theme resolution, layout
  rendering or module models.

### Structure retired

- Typography, Material, Frame and recursive Panel/Layout pages.
- Theme catalog, density, glass backend and material editor.
- Visualizer, volume-step and unused audio controls.
- The removed `Design/Controls` module. Shared gains only the missing Select and Slider primitives
  required by real settings.

## Window and navigation

```text
+----------------------------------------------------------------+
|  Titonium Settings                                       close |
+------------------+---------------------------------------------+
|  General         |                                             |
|  Appearance      |          Selected page content              |
|  Spotlight       |                                             |
|  Bar             |                                             |
|  Dock            |                                             |
|  Notifications   |                                             |
|  Audio           |                                             |
|                  |                                             |
|  About           |                                             |
+------------------+---------------------------------------------+
|  Dirty/error state                         Cancel       Apply  |
+----------------------------------------------------------------+
```

The navigation uses an icon plus a translated label. About stays at the bottom. Unknown requested
page IDs normalize to General. Only the selected page exists; changing pages unloads the previous
page rather than retaining a stack of heavy views.

`SettingsHost` follows `ScreenPolicy.screens`. Its lightweight DP-1 window keeps its page tree
behind `Loader.active`. Settings, Center Notch and `SurfaceManager` transients are mutually
exclusive. Opening one closes the other. Closing Settings unloads application catalogs and page
content.

## Settings document and migration

Settings V1 promotes the public settings document from v6 to v7:

```json
{
  "$schema": "titonium.settings/v7",
  "schemaVersion": 7,
  "locale": "vi",
  "appearance": {
    "mode": "dark"
  },
  "accessibility": {
    "reducedMotion": false
  },
  "applications": {
    "hiddenIds": []
  },
  "modules": {
    "spotlight": {
      "pageTransition": "slide-fade",
      "transitionDuration": 220
    },
    "bar": {
      "workspaceCount": 5,
      "autoHide": false
    },
    "dock": {
      "visibilityMode": "auto-hide",
      "pinnedIds": []
    },
    "notifications": {
      "toastsEnabled": true,
      "toastDuration": 5000
    },
    "audio": {
      "allowAmplification": false
    },
    "clock": {
      "use24Hour": true
    }
  }
}
```

Clock data remains projected for compatibility but has no visible Settings control while Clock is
absent from the Bar.

The existing `dock.json` v1 is a migration input only when a runtime v7 Dock subtree is absent:

- `pinnedOpen: true` maps to `reserve-space`;
- otherwise `autoHide: false` maps to `always-visible`;
- otherwise the mode is `auto-hide`;
- normalized `pinnedIds` retain their first occurrence and order.

Startup never rewrites or deletes `dock.json`. The file remains available for rollback. The first
explicit Apply writes the complete v7 state atomically to the Quickshell data directory.

## Transaction model

`Preferences.qml` remains the one owner of `settings.json`, but gains a narrowly scoped transaction
model:

- `committedState`: the last successfully loaded or saved v7 projection;
- `previewState`: the current Settings editing session;
- `effectiveState`: preview while a session is active, otherwise committed;
- `beginPreview()`: clones committed state once when Settings opens;
- `patch(path, value)`: creates and validates a projected candidate;
- `apply()`: atomically writes v7, then advances the committed baseline after save success;
- `cancel()`: restores preview from committed state and ends the session;
- `restoreAppearance()`: replaces only `appearance` with shipped Neutral Utility Dark defaults.

Existing convenience properties such as locale, reduced motion, hidden applications, Spotlight
settings and audio amplification read `effectiveState`, so all current consumers react during
preview. The Theme reads the same effective appearance state.

The runtime watcher is disabled during a preview and while a self-write is pending. This prevents
an atomic save event from reloading stale disk state over an authoritative in-memory transition,
the failure mode previously observed by the Dock Pin. Malformed runtime data logs one bounded
warning and falls back to shipped defaults without rewriting the file.

`DockStore` remains the Dock-domain facade but no longer owns a second preference file after v7
migration. Pin, unpin and reorder intents update `modules.dock.pinnedIds` through the Preferences
boundary. Outside an active Settings session, direct Dock Pin/application-menu actions commit
immediately. During Settings preview they update the same preview transaction.

`BarVisibilityState` similarly becomes a narrow facade over `modules.bar.autoHide`. The independent
Topbar Pin toggles that preference, committing immediately outside Settings and patching the active
preview while Settings is open.

## Page contracts

### General

- Locale: Vietnamese or English.
- Reduced Motion.
- No 12/24-hour or lunar setting until a visible Clock consumer returns.

### Appearance

- Dark and Light modes with immediate whole-shell preview.
- Read-only identity: Neutral Utility, solid material.
- Restore Neutral Utility resets Appearance to dark only. It must preserve locale, Bar, Dock and
  every module setting.

### Spotlight

- Page transition: `slide-fade`, `fade` or `none`.
- Transition duration: integer from 0 through 500ms; the control is disabled for `none`.
- Searchable application catalog with a visibility toggle and hidden count.
- Application visibility is global within Titonium and continues to affect Spotlight through
  `ApplicationService`.
- An explicit Dock pin overrides global hiding for the Dock only. A hidden pinned application is
  absent from Spotlight and ordinary catalogs but remains on the Dock. After it is unpinned, it
  does not return as a dynamic running Dock item while it remains globally hidden.
- Opening the page does not preselect or launch an application.

### Bar and Workspaces

- Workspace slot count from 1 through 8, default 5.
- Topbar auto-hide preference.
- Workspaces and Bar visibility react to preview state.
- The Topbar Pin remains a separate Bar component and input region.

### Dock

Dock exposes one mutually exclusive visibility mode:

- `auto-hide`: reveal on edge/hover or when the active workspace has no windows;
- `always-visible`: remain visible as an overlay without reserving space;
- `reserve-space`: remain visible and publish its exclusive zone.

The ordered fixed-application editor provides:

- a searchable current `ApplicationService` catalog;
- add/remove controls;
- drag reorder plus keyboard-accessible move-up/move-down actions;
- an unavailable row for a retained ID whose DesktopEntry no longer exists, allowing removal;
- no launch action from Settings.

Selected applications always appear on the Dock. Their existing green running indicator remains
the execution-state signal. Unselected running applications continue to appear dynamically and
disappear when their last window closes unless their application ID is globally hidden. An
explicit pin remains visible even when that same ID is globally hidden. Icon size, hover scale,
spacing and radius remain Theme/UI constants rather than user preferences.

### Notifications

- Enable or disable toast presentation.
- Toast duration from 2000 through 10000ms.
- Disabling toasts does not stop `NotificationService`, unread state, Bell behavior or bounded
  session history.
- When toasts are disabled, existing toast presentation is cleared and new notifications do not
  enter the toast queue. Re-enabling does not replay stale notifications.
- Notification Center, Do Not Disturb and per-application policy remain deferred service slices.

### Audio

- Allow output amplification above 100%.
- Device selection, volume and mute remain live operations in the Audio popup, not preferences.

### About and Diagnostics

Read-only presentation of shell/settings schema identity, owned screen, runtime settings path and
ready/available snapshots from Preferences, Applications, Audio, Network, Bluetooth and
Notifications. The page performs no polling, command execution or native-object access.

## Center integration

The Topbar Center primary interaction changes from directly opening the Daily Focus file to
requesting Center Notch. The Daily Focus open action moves to Overview. The Center Notch Settings
button emits intent upward to App composition; Bar code does not import the Settings feature.
App closes the Notch and opens Settings for the same eligible screen.

The Topbar Pin is visually adjacent to the Center on its right but is composed as an independent
sibling. Its width does not influence Center content sizing and its hitbox does not open the Notch.

## Close, Apply and failure behavior

- Apply is disabled when the projected preview equals committed state.
- Successful Apply keeps Settings open and makes the saved state the new baseline.
- Cancel restores committed state and closes.
- Close or Escape closes immediately when clean.
- Close or Escape while dirty shows an internal confirmation with Continue Editing and Discard.
- Save failure keeps the preview dirty, displays an inline footer error and permits retry.
- Opening Spotlight or Center Notch while Settings is active cancels the preview before closing it.
- Missing services render unavailable diagnostic values and never prevent Settings from loading.

## Performance constraints

- One DP-1 lightweight Settings window; no Titonium Settings layer on DP-3.
- Heavy content exists only while Settings is open.
- One selected page Loader; old pages are destroyed.
- Application lists use `ListView.reuseItems` and do not create the full catalog eagerly.
- No repeating timer, polling, shader, blur, glass, `MultiEffect` or infinite animation.
- Views contain no `FileView`, `Process`, native service import or raw command.

## Verification and acceptance

### Pure/static coverage

- v6 plus optional `dock.json` projection to v7.
- Invalid types, clamped ranges, duplicate IDs and the three Dock mode mappings.
- Preview/effective/committed transitions, dirty detection, Cancel and Apply state changes.
- Appearance restore isolation.
- Application hidden IDs and Dock pinned IDs remain independently persisted, with the explicit
  Dock-pin-over-global-hidden projection rule covered in both pinned and unpinned states.
- Settings view ownership, lazy loading and forbidden-dependency checks.
- Center Settings intent routes through composition rather than feature-to-feature import.

### Live coverage

- Open Settings from Center Notch and read-only IPC lifecycle seams.
- Exactly one Settings surface on DP-1 and none on DP-3.
- Mutual exclusion with Center Notch and Spotlight.
- Preview Appearance, workspace count, Dock visibility and toast duration, then verify Cancel.
- Apply inside isolated XDG runtime roots, restart and verify the persisted v7 projection.
- Repository state and both Hyprland configuration hashes remain unchanged.
- Full static, smoke and protected acceptance retain Spotlight and Input Method behavior.
- Runtime log contains no QML load error, TypeError, illegal method, duplicate ID or unavailable
  Settings type.

### Delivery batches

1. Preferences v7, migration and transaction.
2. Settings window/workspace and Center routing.
3. General, Appearance and Spotlight/Applications.
4. Bar and Dock.
5. Notifications, Audio and About.
6. Full live acceptance and user visual review.

Each batch begins with a failing focused contract, passes the full static gate and receives a local
review before the next batch. Runtime mutation acceptance uses isolated XDG data roots and never
changes the user's live configuration.
