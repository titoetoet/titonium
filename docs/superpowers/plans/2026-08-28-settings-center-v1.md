# Titonium Settings Center V1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a DP-1-only standalone Settings Center with transactional Preview/Apply/Cancel and real General, Appearance, Spotlight, Bar, Dock, Notifications, Audio and About pages.

**Architecture:** `Preferences` becomes the sole atomic v7 preference owner with committed, preview and effective projections. A lazy `SettingsHost` renders one selected page, while App composition coordinates Settings, Center Notch and Spotlight lifecycle. Feature facades consume semantic preferences; views never persist files or own native services.

**Tech Stack:** Quickshell 0.3/QML, QtQuick, QtQuick.Controls, `FileView.atomicWrites`, pure JavaScript domain rules, Node.js fixtures, Python static contracts and Bash read-only IPC acceptance.

**Spec:** `docs/superpowers/specs/2026-08-28-settings-center-v1-design.md`

## Global Constraints

- Settings is nominally `980x700`, centered, lazy and restricted to `ScreenPolicy.screens` (`DP-1`).
- DP-3 remains available to the other shell; Titonium creates no Settings surface or exclusive zone there.
- Runtime settings live only under `Quickshell.dataPath("settings.json")`; startup never rewrites data.
- Keep legacy `dock.json` unchanged as a migration input and rollback artifact.
- All writes use `FileView.atomicWrites`; suspend self-watch reload while previewing or saving.
- UI contains no `FileView`, `Process`, raw command, native service object, shader, blur, glass, `MultiEffect`, infinite animation or repeating timer.
- Do not edit either Hyprland configuration, keybinding or `hyprland.lua`.
- Reuse historical layout structure from commit `62f8ba1`; do not restore `ConfigStore`, `SurfaceCoordinator`, theme catalog, recursive layout or `Design/Controls`.
- Applications visibility stays inside Spotlight. An explicit Dock pin overrides global hiding for Dock only.
- Every user string exists in both `config/i18n/vi.json` and `config/i18n/en.json`.
- Each task starts RED, becomes GREEN, passes `git diff --check` and commits only its owned files.

---

## File structure

```text
Titonium/
├── Core/Runtime/
│   ├── Preferences.qml                 # v7 transaction and atomic persistence owner
│   └── PreferencesValidator.js         # pure projection, migration and path helpers
├── Settings/
│   ├── SettingsCatalog.js              # normalized navigation metadata
│   ├── SettingsCoordinator.qml         # open/page/close/dirty-confirm lifecycle
│   ├── SettingsHost.qml                # DP-1 Variants owner
│   ├── SettingsWindow.qml              # centered exclusive-focus layer window
│   ├── SettingsCenter.qml              # panel + discard confirmation
│   ├── SettingsWorkspace.qml           # header/nav/lazy page/footer
│   ├── components/
│   │   ├── SettingRow.qml
│   │   ├── ApplicationVisibilityList.qml
│   │   └── DockApplicationEditor.qml
│   ├── pages/
│   │   ├── GeneralPage.qml
│   │   ├── AppearancePage.qml
│   │   ├── SpotlightPage.qml
│   │   ├── BarPage.qml
│   │   ├── DockPage.qml
│   │   ├── NotificationsPage.qml
│   │   ├── AudioPage.qml
│   │   └── AboutPage.qml
│   └── qmldir files
└── Shared/
    ├── Select.qml
    └── Slider.qml

tests/fixtures/
├── settings-v6-runtime.json
├── settings-v7-runtime.json
└── dock-v1-runtime.json

scripts/
├── check_preferences_store.py
├── check_settings.py
├── check_settings_catalog.js
├── check_settings_pages.py
└── settings_acceptance.sh
```

### Task 1: Define the v7 preference projection and legacy Dock migration

**Files:**
- Modify: `Titonium/Core/Runtime/PreferencesValidator.js`
- Modify: `config/defaults/settings.json`
- Modify: `config/schemas/settings.schema.json`
- Create: `tests/fixtures/settings-v6-runtime.json`
- Create: `tests/fixtures/settings-v7-runtime.json`
- Create: `tests/fixtures/dock-v1-runtime.json`
- Modify: `scripts/check_preferences.js`
- Modify: `scripts/validate_config.py`

**Interfaces:**
- Consumes: nullable runtime settings, shipped v7 defaults and nullable legacy Dock v1 document.
- Produces: `project(document, defaults, legacyDock)`, `clone(value)`, `setPath(document, path, value)`, `same(left, right)`, `normalizePinnedIds(values)` and `dockModeFromLegacy(document)`.
- `project()` returns the complete writable v7 document including `$schema` and `schemaVersion`.

- [ ] **Step 1: Add failing v6/v7/migration fixtures**

Use these core assertions in `scripts/check_preferences.js`:

```js
const legacy = JSON.parse(fs.readFileSync("tests/fixtures/settings-v6-runtime.json"));
const legacyDock = JSON.parse(fs.readFileSync("tests/fixtures/dock-v1-runtime.json"));
const migrated = context.project(legacy, defaults, legacyDock);
assert.equal(migrated.$schema, "titonium.settings/v7");
assert.equal(migrated.modules.bar.workspaceCount, 5);
assert.equal(migrated.modules.dock.visibilityMode, "reserve-space");
assert.deepEqual(plain(migrated.modules.dock.pinnedIds), ["firefox.desktop", "org.kde.dolphin.desktop"]);
assert.equal(migrated.modules.notifications.toastDuration, 5000);

const candidate = context.setPath(migrated, "modules.bar.workspaceCount", 7);
assert.equal(candidate.modules.bar.workspaceCount, 7);
assert.equal(migrated.modules.bar.workspaceCount, 5);
assert.equal(context.same(candidate, migrated), false);
```

Fixtures must also cover v7 taking precedence over conflicting `dock.json`, duplicate/case-insensitive
Dock IDs, invalid workspace counts, invalid toast durations, unknown transition values and a v6
document preserving locale, appearance, hidden applications, reduced motion, Clock and Audio.

- [ ] **Step 2: Run the fixture and verify RED**

Run:

```bash
node scripts/check_preferences.js
python3 scripts/validate_config.py
```

Expected: FAIL because defaults/schema are v6 and the migration/path APIs do not exist.

- [ ] **Step 3: Implement exact v7 normalization**

Make `project()` clamp and normalize these values:

```js
bar.workspaceCount = integer 1..8, fallback 5
bar.autoHide = strict boolean, fallback false
dock.visibilityMode = "auto-hide" | "always-visible" | "reserve-space"
dock.pinnedIds = non-empty unique strings, case-insensitive, first spelling/order wins
notifications.toastsEnabled = strict boolean, fallback true
notifications.toastDuration = integer 2000..10000, fallback 5000
spotlight.transitionDuration = integer 0..500, fallback 220
```

`setPath()` must clone every traversed object, reject blank path segments and leave its input
untouched. `dockModeFromLegacy()` maps `pinnedOpen`, then `autoHide`, in the precedence specified by
the design. A v7 Dock subtree always overrides legacy Dock input.

- [ ] **Step 4: Update shipped schema validation and prove GREEN**

Require exact v7 keys and `additionalProperties: false` at every persisted object. Run:

```bash
node scripts/check_preferences.js
python3 scripts/validate_config.py
git diff --check
```

Expected: PASS with v7 defaults and all migration fixtures.

- [ ] **Step 5: Commit the preference data contract**

```bash
git add Titonium/Core/Runtime/PreferencesValidator.js config/defaults/settings.json \
  config/schemas/settings.schema.json tests/fixtures scripts/check_preferences.js \
  scripts/validate_config.py
git commit -m "feat: define settings v7 preferences"
```

### Task 2: Implement transactional Preferences and atomic persistence

**Files:**
- Modify: `Titonium/Core/Runtime/Preferences.qml`
- Create: `scripts/check_preferences_store.py`
- Modify: `scripts/check.sh`

**Interfaces:**
- Consumes: Task 1 `PreferencesValidator` functions and legacy `Quickshell.dataPath("dock.json")`.
- Produces: `committedState`, `previewState`, `effectiveState`, `previewActive`, `dirty`,
  `savePending`, `lastError`, `beginPreview()`, `patch(path, value)`, `apply()`, `cancel()`,
  `restoreAppearance()` and `commitPatch(path, value)`.
- Convenience projections: `bar`, `dock`, `notifications`, plus all existing public properties.

- [ ] **Step 1: Write the failing store ownership contract**

`scripts/check_preferences_store.py` must require:

```python
REQUIRED = (
    "property var committedState:", "property var previewState:",
    "readonly property var effectiveState:", "readonly property bool dirty:",
    "function beginPreview(): bool", "function patch(path: string, value: var): bool",
    "function apply(): bool", "function cancel(): void",
    "function restoreAppearance(): bool", "function commitPatch(path: string, value: var): bool",
    "atomicWrites: true", "watchChanges: !root.previewActive",
    'Quickshell.dataPath("dock.json")',
)
```

Reject a second `settings.json` writer anywhere under `Titonium`, startup `setText()`, direct
assignment to `Preferences.settings` outside Core, and any Settings view containing `FileView`.

- [ ] **Step 2: Run the contract and verify RED**

Run: `python3 scripts/check_preferences_store.py`

Expected: FAIL because `Preferences.qml` remains read-only.

- [ ] **Step 3: Implement the transaction state machine**

Use this state relationship and retain `settings` as a compatibility projection:

```qml
readonly property var effectiveState: root.previewActive
    ? root.previewState : root.committedState
readonly property var settings: root.effectiveState
readonly property bool dirty: root.previewActive
    && !Validator.same(root.previewState, root.committedState)
readonly property var bar: root.effectiveState.modules?.bar || ({})
readonly property var dock: root.effectiveState.modules?.dock || ({})
readonly property var notifications: root.effectiveState.modules?.notifications || ({})
```

`reload()` calls `Validator.project(runtime, defaults, legacyDock)` and never writes. `beginPreview()`
clones committed state. `patch()` projects the candidate back through v7 validation. `cancel()`
restores committed state and clears errors. `restoreAppearance()` patches only shipped
`appearance`.

For Settings Apply, retain a `pendingApplyState` clone; call `runtimeFile.setText()` and advance
`committedState` only in `onSaved`. Keep preview/dirty state and `lastError` on `onSaveFailed`.
For direct Bar/Dock actions outside Settings, `commitPatch()` updates the authoritative committed
projection optimistically, increments `pendingRuntimeWrites`, then atomically writes the complete
document. Reject `commitPatch()` while a preview session or Settings Apply is active.

- [ ] **Step 4: Protect the watcher and existing consumers**

Set the runtime watcher to:

```qml
watchChanges: !root.previewActive && root.pendingRuntimeWrites === 0
onFileChanged: root.reload()
onSaved: root.finishRuntimeWrite(true)
onSaveFailed: failure => root.finishRuntimeWrite(false, String(failure))
```

Existing locale, reduced motion, application visibility, Spotlight, Clock and Audio convenience
properties must read `effectiveState`, preserving all current import sites.

- [ ] **Step 5: Run gates and commit**

```bash
python3 scripts/check_preferences_store.py
node scripts/check_preferences.js
./scripts/check.sh
git diff --check
```

Expected: PASS; malformed runtime remains read-only and startup creates no data file.

```bash
git add Titonium/Core/Runtime/Preferences.qml scripts/check_preferences_store.py scripts/check.sh
git commit -m "feat: add transactional preferences store"
```

### Task 3: Add the two missing Shared setting controls

**Files:**
- Create: `Titonium/Shared/Select.qml`
- Create: `Titonium/Shared/Slider.qml`
- Modify: `Titonium/Shared/qmldir`
- Modify: `scripts/check_shared_controls.py`

**Interfaces:**
- `Select`: `model`, `currentIndex`, `accessibleName`, `selected(index, value)`.
- `Slider`: `from`, `to`, `stepSize`, `value`, `accessibleName`, `moved(value)`.
- Both consume only Theme/Metrics/Typography/Motion and QtQuick Controls primitives.

- [ ] **Step 1: Extend the Shared contract and verify RED**

Require these fragments:

```python
SELECT_REQUIRED = ("property var model:", "property int currentIndex:",
    "signal selected(int index, var value)", "Accessible.name:")
SLIDER_REQUIRED = ("property real from:", "property real to:",
    "property real stepSize:", "signal moved(real value)", "Accessible.value:")
```

Also require `Select 1.0 Select.qml` and `Slider 1.0 Slider.qml` in the Shared `qmldir`. Reject
`FileView`, `Process`, `Timer`, `MultiEffect` and `ShaderEffect` in either file.

Run: `python3 scripts/check_shared_controls.py`

Expected: FAIL because both controls are absent.

- [ ] **Step 2: Implement Select**

Wrap a styled `QtQuick.Controls.ComboBox`; derive display text from `model[index].label`, emit the
associated `.value`, keep a 36px control height, Neutral Utility border/focus colors and keyboard
opening/selection. The wrapper owns no model mutation.

- [ ] **Step 3: Implement Slider**

Wrap `QtQuick.Controls.Slider` with semantic background, filled track and handle. Emit `moved(value)`
from `onMoved`, bind `Accessible.minimumValue`, `maximumValue` and `value`, and use Motion only for
color transitions, never a running animation.

- [ ] **Step 4: Run QML/static gates and commit**

```bash
python3 scripts/check_shared_controls.py
./scripts/check.sh
git diff --check
```

Expected: PASS with no new qmllint warnings.

```bash
git add Titonium/Shared scripts/check_shared_controls.py
git commit -m "feat: add settings select and slider controls"
```

### Task 4: Build the lazy Settings shell and functional General page

**Files:**
- Create: `Titonium/Settings/SettingsCatalog.js`
- Create: `Titonium/Settings/SettingsCoordinator.qml`
- Create: `Titonium/Settings/SettingsHost.qml`
- Create: `Titonium/Settings/SettingsWindow.qml`
- Create: `Titonium/Settings/SettingsCenter.qml`
- Create: `Titonium/Settings/SettingsWorkspace.qml`
- Create: `Titonium/Settings/components/SettingRow.qml`
- Create: `Titonium/Settings/components/qmldir`
- Create: `Titonium/Settings/pages/GeneralPage.qml`
- Create: `Titonium/Settings/pages/qmldir`
- Create: `Titonium/Settings/qmldir`
- Create: `scripts/check_settings_catalog.js`
- Create: `scripts/check_settings.py`
- Modify: `Titonium/App.qml`
- Modify: `scripts/check.sh`
- Modify: `config/i18n/en.json`
- Modify: `config/i18n/vi.json`

**Interfaces:**
- `SettingsCoordinator`: `open(screenName, pageId)`, `requestPage(pageId)`, `requestClose()`,
  `discardAndClose()`, `forceCancelAndClose()`, `apply()`, `active`, `ownerScreenName`,
  `requestedPage`, `discardConfirmationVisible`.
- App helper: `openSettings(requestedScreen, pageId): string`.
- IPC target `settings`: lifecycle-only `open(page)`, `page(page)`, `cancel()`, `state()`.

- [ ] **Step 1: Write failing catalog and architecture gates**

`check_settings_catalog.js` initially requires `general` normalization and unknown-page fallback.
`check_settings.py` requires one singleton coordinator, DP-1 `Variants`, a `PanelWindow` with
`980/700`, namespace `titonium-settings`, exclusive keyboard focus only while active,
`Loader.active`, 208px navigation, one page Loader, a dirty confirmation and lifecycle-only IPC.
Reject persistence/native/process imports in all Settings QML.

Run:

```bash
node scripts/check_settings_catalog.js
python3 scripts/check_settings.py
```

Expected: FAIL because `Titonium/Settings` is absent.

- [ ] **Step 2: Implement coordinator and centered host lifecycle**

Coordinator behavior:

```qml
function open(screenName: string, pageId: string): bool {
    if (!screenName) return false;
    Preferences.beginPreview();
    root.ownerScreenName = screenName;
    root.requestedPage = SettingsCatalog.normalizePage(pageId);
    root.discardConfirmationVisible = false;
    return true;
}
function requestClose(): bool {
    if (Preferences.dirty) {
        root.discardConfirmationVisible = true;
        return false;
    }
    return root.forceCancelAndClose();
}
```

`SettingsHost` uses `Variants { model: ScreenPolicy.screens }`. `SettingsWindow` is unanchored and
centered by layer-shell sizing, has zero exclusive zone, an input mask limited to its panel, and
loads `SettingsCenter` only when it owns the coordinator screen.
`SettingsCenter` uses only `Theme.background`, `Theme.surface`, `Theme.border` and Shared solid
surfaces; it has no transparency/material backend control.

- [ ] **Step 3: Port the approved workspace structure and General page**

Use the historical 64/208/content/64 layout with current Shared controls. The page map contains
General only in this task. `GeneralPage` patches locale and reduced motion using `SettingRow`, a
two-option `Shared.Select` and `Shared.Toggle`. Locale changes must translate the open Settings UI
reactively.

Footer behavior:

```qml
Cancel  -> SettingsCoordinator.discardAndClose()
Apply   -> SettingsCoordinator.apply(); window remains open
Close   -> SettingsCoordinator.requestClose()
Escape  -> SettingsCoordinator.requestClose()
```

Bind Apply enabled to `Preferences.dirty && !Preferences.savePending`; show a translated saving
state while pending and `Preferences.lastError` on failure. Prevent a second Apply and prevent
closing until the current atomic save callback finishes.

Add these equal-key namespaces to both locales:

```text
settings.title, settings.preview_hint, settings.unsaved, settings.saving,
settings.close, settings.cancel, settings.apply,
settings.discard.title, settings.discard.body,
settings.discard.continue, settings.discard.confirm,
settings.nav.general, settings.general.title, settings.general.description,
settings.general.language, settings.general.reduced_motion,
settings.general.reduced_motion.description
```

- [ ] **Step 4: Compose App and lifecycle IPC**

Add exactly one `SettingsHost {}`. `openSettings()` resolves only through `ScreenRouter`, closes
`SurfaceManager` and `CenterNotchCoordinator`, then opens Settings. IPC must expose no patch,
restore or Apply method. Existing `openSpotlight()` and the `SurfaceManager.onOpened` composition
handler must call `SettingsCoordinator.forceCancelAndClose()` before another transient becomes
active.

- [ ] **Step 5: Run focused/full gates and commit**

```bash
node scripts/check_settings_catalog.js
python3 scripts/check_settings.py
./scripts/check.sh
git diff --check
```

Expected: PASS; Settings opens on DP-1 with a working General page and unloaded content when closed.

```bash
git add Titonium/Settings Titonium/App.qml config/i18n scripts/check_settings_catalog.js \
  scripts/check_settings.py scripts/check.sh
git commit -m "feat: add lazy settings shell"
```

### Task 5: Restore Center Notch entry and separate the Topbar Pin

**Files:**
- Create: `Titonium/Bar/islands/TopbarPin.qml`
- Modify: `Titonium/Bar/islands/qmldir`
- Modify: `Titonium/Bar/islands/CenterIsland.qml`
- Modify: `Titonium/Bar/islands/CenterGroup.qml`
- Modify: `Titonium/Bar/Bar.qml`
- Modify: `Titonium/Bar/BarSurface.qml`
- Modify: `Titonium/Bar/BarHost.qml`
- Modify: `Titonium/Bar/notch/CenterNotch.qml`
- Modify: `Titonium/Bar/notch/CenterNotchSurface.qml`
- Modify: `Titonium/Bar/notch/CenterNotchWindow.qml`
- Modify: `Titonium/Bar/notch/OverviewPage.qml`
- Modify: `Titonium/App.qml`
- Modify: `scripts/check_bar.py`
- Modify: `scripts/check_center_notch.js`
- Modify: `scripts/check_center_focus.js`
- Modify: `config/i18n/en.json`
- Modify: `config/i18n/vi.json`

**Interfaces:**
- `CenterIsland.notchRequested(screen)` replaces direct Daily Focus launch.
- `BarHost.centerRequested(screen)` and `BarHost.settingsRequested(screen)` reach App composition.
- `TopbarPin` is a sibling hitbox, not a `CenterGroup` child.
- `OverviewPage` invokes `CenterFocusStore.openScratchpad()` only from its explicit Daily Focus
  control inside the Notch.

- [ ] **Step 1: Strengthen Center/Bar tests and verify RED**

Require that `CenterIsland.qml` contains no `openScratchpad`, emits `notchRequested`, and that
`OverviewPage.qml` owns the only Center-view call to `CenterFocusStore.openScratchpad()`. Require
`TopbarPin.qml`, a fourth `Bar.pinHitbox`, four Bar content mask regions plus the existing edge-reveal
region, and no pin inside `CenterGroup.qml`.

Run:

```bash
python3 scripts/check_bar.py
node scripts/check_center_notch.js
node scripts/check_center_focus.js
```

Expected: FAIL against the current direct-open Center and nested Pin.

- [ ] **Step 2: Split Center and Pin geometry**

Make `CenterGroup` contain only `CenterIsland`. In `Bar.qml`, position `TopbarPin` at
`centerGroup.x + centerGroup.width + Metrics.spacingSmall`; do not include it in `BarLayout.centerX`.
Expose a separate alias and mask region. `TopbarPin` retains current icons/accessibility but delegates
state to `BarVisibilityState`.

- [ ] **Step 3: Route Center and Settings intent through App**

Propagate Center activation to `App.openCenterNotch(screen, "overview")`. Propagate the existing
rail `settingsRequested` signal through CenterNotch, Surface, Window and BarHost to
`App.openSettings(screen, "general")`. No Bar file imports `qs.Titonium.Settings`.
`openCenterNotch()` calls `SettingsCoordinator.forceCancelAndClose()` before opening the Notch.
Route the `centerNotch` IPC `open()` method through the same App helper. Add an App connection that
force-cancels Settings whenever `CenterNotchCoordinator.active` becomes true, covering the existing
ActiveWindowPill path without giving that Bar view a Settings dependency.

- [ ] **Step 4: Move Daily Focus action into Overview**

Add one translated Overview card/button with the Daily Focus text and an edit/open icon. It calls
`CenterFocusStore.openScratchpad()` only from explicit pointer/keyboard activation. The other
Overview cards remain informational.

Add `center_notch.overview.daily_focus` and `center_notch.overview.daily_focus.open` to both locale
catalogs with Vietnamese and English values.

- [ ] **Step 5: Run gates and commit**

```bash
python3 scripts/check_bar.py
node scripts/check_center_notch.js
node scripts/check_center_focus.js
python3 scripts/check_settings.py
./scripts/check.sh
git diff --check
```

Expected: PASS with Center opening Notch, Settings opening from the rail and Pin geometry independent.

```bash
git add Titonium/Bar Titonium/App.qml config/i18n scripts/check_bar.py \
  scripts/check_center_notch.js scripts/check_center_focus.js
git commit -m "feat: route center to settings notch"
```

### Task 6: Add Appearance and Spotlight/Applications pages

**Files:**
- Create: `Titonium/Settings/pages/AppearancePage.qml`
- Create: `Titonium/Settings/pages/SpotlightPage.qml`
- Create: `Titonium/Settings/components/ApplicationVisibilityList.qml`
- Modify: `Titonium/Services/Applications/ApplicationService.qml`
- Modify: `Titonium/Settings/pages/qmldir`
- Modify: `Titonium/Settings/components/qmldir`
- Modify: `Titonium/Settings/SettingsCatalog.js`
- Modify: `Titonium/Settings/SettingsWorkspace.qml`
- Create: `scripts/check_settings_pages.py`
- Modify: `scripts/check_settings_catalog.js`
- Modify: `scripts/check.sh`
- Modify: `config/i18n/en.json`
- Modify: `config/i18n/vi.json`

**Interfaces:**
- Appearance patches `appearance.mode` and calls `Preferences.restoreAppearance()`.
- Spotlight patches `modules.spotlight.pageTransition`, `transitionDuration` and
  `applications.hiddenIds` using
  `ApplicationService.hiddenIdsForVisibility(hiddenIds, entryId, visible)`.
- Application rows consume `ApplicationService.allApplications`; they never launch.

- [ ] **Step 1: Write failing page contracts**

Require catalog order `general, appearance, spotlight`. Require Appearance values exactly dark/light,
the Neutral Utility identity and restore isolation. Require Spotlight values exactly
`slide-fade, fade, none`, range `0..500`, searchable reusable rows, hidden count and no call to
`ApplicationService.launch`.

Run:

```bash
node scripts/check_settings_catalog.js
python3 scripts/check_settings_pages.py
```

Expected: FAIL because both pages and list are absent.

- [ ] **Step 2: Implement Appearance preview**

Use two selectable cards/buttons bound to `Preferences.effectiveState.appearance.mode`. Restore
invokes only `Preferences.restoreAppearance()`. Show translated `Neutral Utility` and `Solid` labels;
do not create theme, font, density or material controls.

- [ ] **Step 3: Implement Spotlight settings and application visibility**

Port the historical Spotlight page layout to current controls. Use `ListView.reuseItems: true`,
`Shared.SystemIcon`, an empty initial search string and no current index. Each toggle computes:

```qml
Preferences.patch("applications.hiddenIds", ApplicationService.hiddenIdsForVisibility(
    Preferences.hiddenApplicationIds, modelData.id, checked))
```

The list model must use `allApplications`, not `visibleApplications`, so hidden rows remain available
to restore. `ApplicationService.hiddenIdsForVisibility()` is a value-only wrapper over its existing
private `Visibility.setVisible()` helper; Settings does not import service-private JavaScript.
Duration is disabled when transition is `none`.

Use these namespaces in both locale catalogs:

```text
settings.nav.appearance, settings.appearance.title, settings.appearance.description,
settings.appearance.dark, settings.appearance.light, settings.appearance.identity,
settings.appearance.solid, settings.appearance.restore,
settings.nav.spotlight, settings.spotlight.title, settings.spotlight.description,
settings.spotlight.transition, settings.spotlight.transition.slide_fade,
settings.spotlight.transition.fade, settings.spotlight.transition.none,
settings.spotlight.duration, settings.spotlight.hidden_count,
settings.spotlight.applications.search, settings.spotlight.applications.empty,
settings.spotlight.applications.visible, settings.spotlight.applications.hidden
```

- [ ] **Step 4: Run gates and commit**

```bash
node scripts/check_settings_catalog.js
python3 scripts/check_settings_pages.py
node scripts/check_application_visibility.js
./scripts/check.sh
git diff --check
```

Expected: PASS; preview affects live Spotlight/ApplicationService and Cancel restores it.

```bash
git add Titonium/Settings Titonium/Services/Applications/ApplicationService.qml config/i18n scripts/check_settings_catalog.js \
  scripts/check_settings_pages.py scripts/check.sh
git commit -m "feat: add appearance and spotlight settings"
```

### Task 7: Make Bar and workspace behavior preference-driven

**Files:**
- Create: `Titonium/Settings/pages/BarPage.qml`
- Modify: `Titonium/Settings/pages/qmldir`
- Modify: `Titonium/Settings/SettingsCatalog.js`
- Modify: `Titonium/Settings/SettingsWorkspace.qml`
- Modify: `Titonium/Core/Runtime/BarVisibilityState.qml`
- Modify: `Titonium/Bar/widgets/Workspaces.qml`
- Modify: `Titonium/Bar/islands/StartIsland.qml`
- Modify: `scripts/check_settings_catalog.js`
- Modify: `scripts/check_settings_pages.py`
- Modify: `scripts/check_bar_visibility.js`
- Modify: `scripts/check_workspaces.js`
- Modify: `config/i18n/en.json`
- Modify: `config/i18n/vi.json`

**Interfaces:**
- `BarVisibilityState.pinned == !Preferences.bar.autoHide`.
- `BarVisibilityState.togglePinned()` patches preview or calls `Preferences.commitPatch()`.
- Workspaces bind count to `Preferences.bar.workspaceCount`.

- [ ] **Step 1: Write failing preference-consumer tests**

Require zero literal `count: 5` in Bar composition, `workspaceCount` range text in BarPage, and this
state mapping:

```qml
readonly property bool pinned: Preferences.bar.autoHide !== true
function togglePinned(): bool {
    const nextAutoHide = root.pinned;
    return Preferences.previewActive
        ? Preferences.patch("modules.bar.autoHide", nextAutoHide)
        : Preferences.commitPatch("modules.bar.autoHide", nextAutoHide);
}
```

Run the Bar/workspace/settings checks and expect failure against hardcoded state.

- [ ] **Step 2: Bind Bar runtime consumers**

Remove mutable `pinned` ownership from `BarVisibilityState`. Bind Workspaces and StartIsland to the
effective 1..8 count. Preserve the five-workspace default and all current active/occupied visuals.

- [ ] **Step 3: Implement Bar page**

Use a stepper or integer Slider from 1 through 8 and one Auto-hide toggle. Page changes patch only
`modules.bar`. Do not expose bar height, padding, spacing, Center width, icon size or radius.
Add `settings.nav.bar`, `settings.bar.title`, `settings.bar.description`,
`settings.bar.workspace_count`, `settings.bar.auto_hide` and
`settings.bar.auto_hide.description` to both locale catalogs.

- [ ] **Step 4: Run gates and commit**

```bash
node scripts/check_bar_visibility.js
node scripts/check_workspaces.js
node scripts/check_settings_catalog.js
python3 scripts/check_settings_pages.py
./scripts/check.sh
git diff --check
```

Expected: PASS with live workspace-count and Bar visibility preview.

```bash
git add Titonium/Core/Runtime/BarVisibilityState.qml Titonium/Bar Titonium/Settings \
  config/i18n scripts/check_bar_visibility.js scripts/check_workspaces.js \
  scripts/check_settings_catalog.js scripts/check_settings_pages.py
git commit -m "feat: add bar and workspace settings"
```

### Task 8: Move Dock preferences behind the v7 facade and enforce visibility precedence

**Files:**
- Modify: `Titonium/Services/Dock/DockRules.js`
- Modify: `Titonium/Services/Dock/DockStore.qml`
- Modify: `Titonium/Services/Dock/DockService.qml`
- Modify: `Titonium/Dock/DockWindow.qml`
- Modify: `scripts/check_dock_rules.js`
- Modify: `scripts/check_dock_store.py`
- Modify: `scripts/check_dock.py`

**Interfaces:**
- `DockStore.visibilityMode`, `pinnedIds`, `autoHide`, `pinnedOpen` read `Preferences.dock`.
- Mutations: `setVisibilityMode(mode)`, `setPinnedIds(ids)`, `togglePin(id)`,
  `movePin(fromIndex, toIndex)`.
- `DockRules.mergeItems(pinnedIds, runningGroups, entriesById, firstSeenIds, hiddenIds)` implements
  explicit-pin-over-hidden precedence.
- `DockService` builds `entriesById` from the full `ApplicationService.allApplications` catalog so
  a selected application remains visible while it has no running window.

- [ ] **Step 1: Add failing Dock migration/projection fixtures**

Cover all three mode mappings and these exact projections:

```js
mergeItems(["hidden.desktop"], running, entries, [], ["hidden.desktop"])
    // contains hidden.desktop because it is explicitly pinned
mergeItems([], running, entries, [], ["hidden.desktop"])
    // excludes hidden.desktop although it is running
movePinnedId(["a", "b", "c"], 2, 0)
    // returns ["c", "a", "b"]
mergeItems(["offline.desktop"], [], allInstalledEntries, [], [])
    // contains offline.desktop with runningCount=0
```

Strengthen the store gate to reject `FileView`, `Quickshell.Io`, `dock.json`, `atomicWrites` and a
mutable local `state` in `DockStore.qml`.

- [ ] **Step 2: Run focused checks and verify RED**

```bash
node scripts/check_dock_rules.js
python3 scripts/check_dock_store.py
python3 scripts/check_dock.py
```

Expected: FAIL against the separate Dock v1 store and hidden-unaware merge.

- [ ] **Step 3: Implement the v7 Dock facade**

Map modes exactly:

```js
auto-hide      -> autoHide=true,  pinnedOpen=false
always-visible -> autoHide=false, pinnedOpen=false
reserve-space  -> autoHide=false, pinnedOpen=true
```

All mutations normalize through DockRules then call `Preferences.patch()` during preview or
`Preferences.commitPatch()` otherwise. Keep `snapshot()` stable but include `visibilityMode`.
Update DockService to build an installed-entry map from `ApplicationService.allApplications`, merge
running groups into it and pass both that map and `Preferences.hiddenApplicationIds` into
`mergeItems()`.

- [ ] **Step 4: Preserve Dock window behavior**

`DockWindow` continues to reserve only in `reserve-space`; `always-visible` remains overlay-only;
`auto-hide` retains edge/empty-workspace reveal. Keep current pin exactly-once input semantics and
map its click between `reserve-space` and `auto-hide`.

- [ ] **Step 5: Run gates and commit**

```bash
node scripts/check_dock_rules.js
python3 scripts/check_dock_store.py
python3 scripts/check_dock.py
./scripts/check.sh
git diff --check
```

Expected: PASS; Dock has no persistence owner besides Preferences.

```bash
git add Titonium/Services/Dock Titonium/Dock/DockWindow.qml scripts/check_dock_rules.js \
  scripts/check_dock_store.py scripts/check_dock.py
git commit -m "refactor: move dock preferences to settings v7"
```

### Task 9: Build the Dock settings page and ordered application editor

**Files:**
- Create: `Titonium/Settings/pages/DockPage.qml`
- Create: `Titonium/Settings/components/DockApplicationEditor.qml`
- Modify: `Titonium/Settings/pages/qmldir`
- Modify: `Titonium/Settings/components/qmldir`
- Modify: `Titonium/Settings/SettingsCatalog.js`
- Modify: `Titonium/Settings/SettingsWorkspace.qml`
- Modify: `scripts/check_settings_catalog.js`
- Modify: `scripts/check_settings_pages.py`
- Modify: `config/i18n/en.json`
- Modify: `config/i18n/vi.json`

**Interfaces:**
- Page consumes Task 8 DockStore mutations and `ApplicationService.allApplications`.
- Selected list order equals `DockStore.pinnedIds`; catalog toggles never launch applications.
- Drag release and keyboard arrows both call `DockStore.movePin(fromIndex, toIndex)`.

- [ ] **Step 1: Add failing Dock page contracts**

Require three mode values, searchable application catalog, pinned list, unavailable-entry removal,
drag handle, move-up/move-down accessibility actions and absence of any launch method. Require
catalog order `general, appearance, spotlight, bar, dock`.

Run settings page/catalog checks and expect missing-page failures.

- [ ] **Step 2: Implement visibility mode selection**

Render three selectable cards with concise descriptions. Selection calls
`DockStore.setVisibilityMode(value)` and live-previews Dock reveal/exclusive-zone behavior.

- [ ] **Step 3: Implement fixed application management**

The upper list follows ordered `pinnedIds`. Resolve installed entries through
`ApplicationService.desktopEntryForAppId(id)`; retain a translated Unavailable row when resolution
fails. The lower searchable catalog uses all installed applications and toggles pin membership.

For drag reordering, compute the target index from the released delegate center divided by row
height, clamp it to `[0, count - 1]`, call `movePin(sourceIndex, targetIndex)`, then reset delegate
translation. Up/down buttons invoke the same method and disable at list bounds.

Add these key namespaces to both locale catalogs:

```text
settings.nav.dock, settings.dock.title, settings.dock.description,
settings.dock.mode, settings.dock.mode.auto_hide,
settings.dock.mode.always_visible, settings.dock.mode.reserve_space,
settings.dock.pinned, settings.dock.catalog, settings.dock.search,
settings.dock.add, settings.dock.remove, settings.dock.move_up,
settings.dock.move_down, settings.dock.unavailable
```

- [ ] **Step 4: Run gates and commit**

```bash
node scripts/check_settings_catalog.js
python3 scripts/check_settings_pages.py
node scripts/check_dock_rules.js
python3 scripts/check_dock.py
./scripts/check.sh
git diff --check
```

Expected: PASS; selected apps remain visible and running state still uses the current green dot.

```bash
git add Titonium/Settings config/i18n scripts/check_settings_catalog.js \
  scripts/check_settings_pages.py
git commit -m "feat: add dock application settings"
```

### Task 10: Add Notifications, Audio and About pages with real consumers

**Files:**
- Create: `Titonium/Settings/pages/NotificationsPage.qml`
- Create: `Titonium/Settings/pages/AudioPage.qml`
- Create: `Titonium/Settings/pages/AboutPage.qml`
- Modify: `Titonium/Settings/pages/qmldir`
- Modify: `Titonium/Settings/SettingsCatalog.js`
- Modify: `Titonium/Settings/SettingsWorkspace.qml`
- Modify: `Titonium/Services/Notifications/NotificationService.qml`
- Modify: `Titonium/Notifications/ToastCard.qml`
- Modify: `scripts/check_notifications.py`
- Modify: `scripts/check_settings_catalog.js`
- Modify: `scripts/check_settings_pages.py`
- Modify: `config/i18n/en.json`
- Modify: `config/i18n/vi.json`

**Interfaces:**
- Notifications consume `Preferences.notifications.toastsEnabled` and `.toastDuration`.
- Audio patches the existing `modules.audio.allowAmplification` preference.
- About reads value-only service properties and `ScreenPolicy.targetScreenName`; it performs no
  mutation or polling.

- [ ] **Step 1: Write failing final-page/service contracts**

Require final catalog order:

```text
general, appearance, spotlight, bar, dock, notifications, audio, about
```

Require Notifications range `2000..10000`, Audio amplification only, About read-only diagnostics,
and no Settings import of native Quickshell service modules. Require ToastCard interval to bind
Preferences rather than literal `5000`.

- [ ] **Step 2: Implement notification policy**

On notification arrival, always update bounded history and unread IDs, but add a toast ID only when
`toastsEnabled`. On transition to disabled, clear `toastIds` without altering notifications or
unread IDs. Re-enabling leaves the queue empty until a new notification. Bind each one-shot
ToastCard timer to `Preferences.notifications.toastDuration`.

- [ ] **Step 3: Implement pages**

Notifications has one Toggle and duration Slider; disable duration when toasts are off. Audio has
only Allow Amplification. About displays settings schema, `DP-1`, runtime path, application count,
Audio ready, Network available, Bluetooth available and Notification counts using existing semantic
properties.

Add the following namespaces with equal key parity:

```text
settings.nav.notifications, settings.notifications.title,
settings.notifications.description, settings.notifications.toasts,
settings.notifications.duration,
settings.nav.audio, settings.audio.title, settings.audio.description,
settings.audio.amplification, settings.audio.amplification.description,
settings.nav.about, settings.about.title, settings.about.description,
settings.about.schema, settings.about.screen, settings.about.runtime,
settings.about.applications, settings.about.audio, settings.about.network,
settings.about.bluetooth, settings.about.notifications,
settings.state.ready, settings.state.unavailable
```

- [ ] **Step 4: Run gates and commit**

```bash
python3 scripts/check_notifications.py
node scripts/check_settings_catalog.js
python3 scripts/check_settings_pages.py
./scripts/check.sh
git diff --check
```

Expected: PASS with no extra notification timer or native owner.

```bash
git add Titonium/Settings Titonium/Services/Notifications Titonium/Notifications/ToastCard.qml \
  config/i18n scripts/check_notifications.py scripts/check_settings_catalog.js \
  scripts/check_settings_pages.py
git commit -m "feat: complete settings module pages"
```

### Task 11: Add isolated lifecycle acceptance, documentation and final visual checkpoint

**Files:**
- Create: `scripts/settings_acceptance.sh`
- Modify: `scripts/check.sh`
- Modify: `scripts/protected_acceptance.sh`
- Modify: `docs/ARCHITECTURE.md`
- Modify: `docs/CONFIG_AND_MIGRATIONS.md`
- Modify: `docs/TESTING.md`
- Modify: `docs/ROADMAP.md`

**Interfaces:**
- Consumes lifecycle-only `settings` IPC plus existing Center Notch and Spotlight IPC.
- Produces isolated DP-1 lifecycle/migration evidence without modifying the user's runtime.

- [ ] **Step 1: Add failing acceptance/script contracts**

Require `bash -n scripts/settings_acceptance.sh`, isolated `XDG_DATA_HOME`, `XDG_STATE_HOME` and
`XDG_CACHE_HOME`, a cleanup trap, DP-1/DP-3 layer checks, runtime rejection tokens, Git status and
both Hyprland hashes. The script may call only Settings `open`, `page`, `cancel`, `state`; reject
patch/Apply IPC.

- [ ] **Step 2: Implement isolated lifecycle acceptance**

Seed a v6 runtime settings fixture and legacy Dock fixture below the isolated Quickshell data root,
start one foreground Titonium instance, then require:

```text
settings open general -> open:DP-1;page=general;dirty=false
settings page dock    -> open:DP-1;page=dock;dirty=false
spotlight toggle      -> Settings closes and preview cancels
centerNotch open      -> Spotlight closes
settings open dock    -> Notch closes and Settings opens
settings cancel      -> closed
```

Verify one Settings layer on DP-1 only while open, no runtime error, no repository mutation and no
change to either Hyprland configuration hash.
The Center-rail Settings click is enforced statically in Task 5 and exercised manually in Step 4;
the lifecycle IPC intentionally cannot invoke a rail control.

- [ ] **Step 3: Run automated final gates**

```bash
bash -n scripts/settings_acceptance.sh
./scripts/check.sh
./scripts/smoke.sh
./scripts/settings_acceptance.sh
./scripts/center_notch_acceptance.sh
./scripts/spotlight_acceptance.sh
./scripts/protected_acceptance.sh
hyprctl configerrors
git diff --check
```

Expected: every gate passes; DP-3 retains no Titonium layer.

- [ ] **Step 4: Perform the manual transactional/visual checkpoint**

Before testing, copy the live v6 `settings.json` and `dock.json` to `/tmp`. Open Settings from Center
Notch and verify all eight pages, 980x700 centering, navigation, keyboard focus and unloaded close.
Preview then Cancel each of: Light mode, seven workspaces, `always-visible` Dock and a 2000ms toast.
Confirm every surface rolls back. Repeat, Apply, wait for footer success, restart Titonium and confirm
the selected values persist as v7. Restore the captured runtime files after the checkpoint.

Test Dock mode semantics, add/remove/reorder installed apps, unavailable-ID removal, hidden pinned
override and green running dot. Close dirty Settings through Escape and `×` and verify the internal
discard confirmation. Confirm Center click opens Notch, its Settings button opens Settings, Daily
Focus opens only from Overview and the Topbar Pin remains separately clickable.

- [ ] **Step 5: Document evidence and commit**

Update architecture with Settings ownership and signal routing; configuration docs with v7 and
legacy Dock migration; testing docs with automated/manual commands; roadmap with Settings V1 visual
status.

```bash
git add scripts/settings_acceptance.sh scripts/check.sh scripts/protected_acceptance.sh \
  docs/ARCHITECTURE.md docs/CONFIG_AND_MIGRATIONS.md docs/TESTING.md docs/ROADMAP.md
git commit -m "test: cover settings center lifecycle"
```

Leave exactly one Titonium daemon running on DP-1 only after approval:

```bash
qs -p /home/cole/Projects/titonium kill
qs -d -p /home/cole/Projects/titonium
```
