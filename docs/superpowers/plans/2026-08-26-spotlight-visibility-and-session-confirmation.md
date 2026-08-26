# Spotlight Visibility and Session Confirmation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a centered standalone session-confirmation surface, a taller top-anchored Spotlight, accurate existing categories and density pills, plus global application visibility managed inside Spotlight Settings.

**Architecture:** Keep the raw desktop-entry catalog in Platform, project preview-aware visibility through a new Foundation singleton, and let Spotlight consume only that visible projection. Replace Arch Menu with a dedicated confirmation descriptor through the existing one-transient-per-screen coordinator; no parallel transient or nested confirmation tree remains.

**Tech Stack:** Quickshell 0.3.1, Qt/QML, JavaScript domain helpers, JSON Schema draft 2020-12, Python/Node fixture gates, Bash PID-targeted live acceptance, Hyprland IPC.

**Spec:** `docs/superpowers/specs/2026-08-26-spotlight-visibility-and-session-confirmation-design.md`

## Global Constraints

- Dependency direction remains `App/Surfaces -> Modules/Composition -> Design/Foundation -> Platform`.
- UI must not instantiate `Process`, execute raw commands or persist files.
- Runtime settings remain outside the repository and Apply writes atomically through `ConfigStore`.
- Neutral Utility remains solid; this batch does not add glass/effects or alter Hyprland configuration.
- Spotlight stays 800 logical pixels wide, is top-anchored 12 pixels below the 40-pixel MenuBar and is at most 760 pixels tall.
- Applications use `rocket_launch`, Clipboard uses `content_paste`, and mock System Search uses `manage_search`, outside the Search field.
- Visible category IDs remain `all, development, games, graphics, internet, multimedia, office, system, utilities, other`; empty groups are absent.
- Page capacity remains fixed at 5×4. Density pill width is `12 + 44 × clamp(count / 20, 0, 1)`.
- Every session action requires the dedicated centered confirmation surface. Automated tests never confirm a real session action.
- No timer polling, infinite animation, shader, `MultiEffect` or hidden render loop may be added.

---

### Task 1: Settings v5 global application visibility contract

**Files:**
- Modify: `config/defaults/settings.json`
- Modify: `config/schemas/settings.schema.json`
- Create: `tests/fixtures/settings.v4.valid.json`
- Create: `tests/fixtures/settings.invalid-applications.json`
- Modify: `Titonium/Foundation/ConfigMigrations.js`
- Modify: `Titonium/Foundation/ConfigStore.qml`
- Modify: `scripts/validate_config.py`
- Modify: `scripts/check_config_migrations.js`
- Modify: `docs/CONFIG_AND_MIGRATIONS.md`

**Interfaces:**
- Consumes: settings v1–v4 migration pipeline and `ConfigStore.patch(path, value)`.
- Produces: settings v5 global `applications.hiddenIds: string[]`; `migrateSettings(data)` always returns v5 for supported v1–v5 input.

- [ ] **Step 1: Add failing v4→v5 and invalid visibility fixtures**

Create `settings.v4.valid.json` with non-default locale/appearance/accessibility/modules and no
`applications` key. Create `settings.invalid-applications.json` as v5 with duplicate IDs:

```json
{
  "$schema": "titonium.settings/v5",
  "schemaVersion": 5,
  "locale": "vi",
  "appearance": { "themeId": "titonium-neutral", "mode": "dark", "density": "comfortable", "overrides": {} },
  "accessibility": { "reducedMotion": false },
  "applications": { "hiddenIds": ["firefox.desktop", "firefox.desktop"] },
  "modules": {
    "frame": { "enabled": false, "thickness": 2, "cornerRadius": 12, "opacity": 0.85 },
    "audio": { "volumeStep": 5, "maxVolume": 100, "visualizerEnabled": false, "visualizerStyle": "bars", "visualizerBars": 32 },
    "spotlight": { "pageTransition": "slide-fade", "transitionDuration": 220 },
    "clock": { "use24Hour": true, "showLunar": true }
  }
}
```

Extend `validate_config.py` assertions so v4 migrates to:

```python
assert migrated["schemaVersion"] == 5
assert migrated["$schema"] == "titonium.settings/v5"
assert migrated["applications"] == {"hiddenIds": []}
```

Independently assert duplicate, empty, non-string and unknown `applications` fields are rejected.

- [ ] **Step 2: Run RED gates**

Run:

```bash
python3 scripts/validate_config.py
node scripts/check_config_migrations.js
```

Expected: FAIL because schemaVersion 5 and `applications.hiddenIds` are unsupported.

- [ ] **Step 3: Implement the v5 migration and schema**

Add the exact default subtree:

```json
"applications": {
  "hiddenIds": []
}
```

Require it in the v5 root schema. Define `hiddenIds` with `type: array`, `uniqueItems: true`, and
items `{ "type": "string", "minLength": 1 }`; reject additional properties.

Append this migration after the existing v3→v4 block in both JavaScript and Python authorities:

```javascript
if (current.schemaVersion === 4) {
    current.applications = { "hiddenIds": [] };
    current.$schema = "titonium.settings/v5";
    current.schemaVersion = 5;
}
```

Accept v5 input without rewriting it. Update ConfigStore's loaded-schema log from v4 to v5 and
update every older migration expectation to terminate at v5 while preserving unrelated state.

- [ ] **Step 4: Run GREEN gates**

Run the two commands from Step 2. Expected: all config and migration assertions PASS.

- [ ] **Step 5: Commit**

```bash
git add config/defaults/settings.json config/schemas/settings.schema.json tests/fixtures/settings.v4.valid.json tests/fixtures/settings.invalid-applications.json Titonium/Foundation/ConfigMigrations.js Titonium/Foundation/ConfigStore.qml scripts/validate_config.py scripts/check_config_migrations.js docs/CONFIG_AND_MIGRATIONS.md
git commit -m "feat: add global application visibility settings"
```

---

### Task 2: Foundation application visibility projection

**Files:**
- Create: `Titonium/Foundation/ApplicationVisibility.js`
- Create: `Titonium/Foundation/ApplicationVisibilityStore.qml`
- Modify: `Titonium/Foundation/qmldir`
- Create: `scripts/check_application_visibility.js`
- Modify: `scripts/check.sh`
- Modify: `Titonium/Modules/Spotlight/SpotlightModel.qml`
- Modify: `scripts/check_architecture.py`
- Modify: `docs/ARCHITECTURE.md`
- Modify: `docs/MODULE_CONTRACT.md`

**Interfaces:**
- Consumes: `ApplicationCatalog.applications`, `ConfigStore.previewState.applications.hiddenIds`, and `ConfigStore.patch(path, value)`.
- Produces: singleton `ApplicationVisibilityStore` with readonly `allApplications`, readonly `visibleApplications`, `isVisible(entryId): bool`, and `setVisible(entryId, visible): bool`.

- [ ] **Step 1: Write failing pure visibility fixtures**

Create a Node VM fixture for `ApplicationVisibility.js` asserting:

```javascript
equal(normalizeHidden(["b.desktop", "a.desktop", "b.desktop", "", 3]),
      ["b.desktop", "a.desktop"]);
equal(filterVisible(apps, ["b.desktop"]).map(app => app.id),
      ["a.desktop", "c.desktop"]);
equal(setVisible(["missing.desktop", "a.desktop"], "a.desktop", true),
      ["missing.desktop"]);
equal(setVisible(["missing.desktop"], "a.desktop", false),
      ["missing.desktop", "a.desktop"]);
```

Add architecture assertions that `SpotlightModel` reads
`ApplicationVisibilityStore.visibleApplications`, settings may read `allApplications`, and no UI
other than launch calls reads `ApplicationCatalog.applications` directly.

- [ ] **Step 2: Run RED gates**

```bash
node scripts/check_application_visibility.js
python3 scripts/check_architecture.py
```

Expected: FAIL because the helper/singleton do not exist and Spotlight consumes the raw catalog.

- [ ] **Step 3: Implement pure projection and singleton**

`ApplicationVisibility.js` exports deterministic `normalizeHidden`, `filterVisible`, `isVisible`
and `setVisible`. Preserve missing IDs and first-seen order; use prefixed/null-safe membership.

`ApplicationVisibilityStore.qml` follows:

```qml
pragma Singleton
QtObject {
    readonly property var allApplications: ApplicationCatalog.applications
    readonly property var hiddenIds: ConfigStore.previewState.applications?.hiddenIds || []
    readonly property var visibleApplications:
        ApplicationVisibility.filterVisible(root.allApplications, root.hiddenIds)

    function isVisible(entryId: string): bool {
        return ApplicationVisibility.isVisible(root.hiddenIds, entryId);
    }
    function setVisible(entryId: string, visible: bool): bool {
        return ConfigStore.patch("applications.hiddenIds",
            ApplicationVisibility.setVisible(root.hiddenIds, entryId, visible));
    }
}
```

Register it in Foundation `qmldir`. In `SpotlightModel`, build categories and search results from
`ApplicationVisibilityStore.visibleApplications`; retain `ApplicationCatalog.launch()` only for
execution.

- [ ] **Step 4: Run GREEN gates and the full static suite**

```bash
node scripts/check_application_visibility.js
python3 scripts/check_architecture.py
./scripts/check.sh
```

Expected: visibility fixtures, architecture boundaries and full static suite PASS.

- [ ] **Step 5: Commit**

```bash
git add Titonium/Foundation/ApplicationVisibility.js Titonium/Foundation/ApplicationVisibilityStore.qml Titonium/Foundation/qmldir Titonium/Modules/Spotlight/SpotlightModel.qml scripts/check_application_visibility.js scripts/check.sh scripts/check_architecture.py docs/ARCHITECTURE.md docs/MODULE_CONTRACT.md
git commit -m "feat: project global application visibility"
```

---

### Task 3: Application visibility controls inside Spotlight Settings

**Files:**
- Create: `Titonium/Modules/Settings/ApplicationVisibilityList.qml`
- Modify: `Titonium/Modules/Settings/SpotlightPage.qml`
- Modify: `Titonium/Modules/Settings/qmldir`
- Modify: `Titonium/App/AppShell.qml`
- Modify: `config/i18n/en.json`
- Modify: `config/i18n/vi.json`
- Modify: `scripts/check_architecture.py`
- Modify: `scripts/settings_acceptance.sh`
- Modify: `docs/TESTING.md`

**Interfaces:**
- Consumes: `ApplicationVisibilityStore.allApplications`, `isVisible(entryId)` and `setVisible(entryId, visible)`.
- Produces: lazy settings list with local `query`; safe IPC test seam `settings.previewApplicationVisible(entryId, visible): bool` that works only during an active Settings preview.

- [ ] **Step 1: Add failing structure and acceptance assertions**

Extend architecture checks to require:

```text
ApplicationVisibilityList.qml contains ListView, ApplicationVisibilityStore.allApplications,
ApplicationVisibilityStore.setVisible, Controls.Switch, Image and Text.ElideRight.
SpotlightPage.qml instantiates ApplicationVisibilityList exactly once.
```

Extend `settings_acceptance.sh` to obtain a stable installed entry ID through a read-only
`spotlight firstVisibleApplicationId` IPC helper, begin Settings preview, hide it through
`settings previewApplicationVisible`, verify Spotlight's `visibleApplicationCount` decreases,
Cancel and verify the exact count/ID visibility returns. Repeat Apply with backed-up runtime
settings, then restore the runtime document in the existing cleanup trap. Never launch the app.

- [ ] **Step 2: Run RED gates**

```bash
python3 scripts/check_architecture.py
./scripts/settings_acceptance.sh
```

Expected: FAIL for the missing lazy list and visibility IPC methods.

- [ ] **Step 3: Implement the lazy list and preview seams**

Create `ApplicationVisibilityList.qml` as a `ColumnLayout` containing a local Search `TextField`
and a `ListView`. Its filtered model always starts from `allApplications`; each delegate shows
the record icon through `Image` with `apps` fallback, a one-line elided name, and a switch whose
checked state calls `isVisible` and whose trigger calls `setVisible`.

Refactor `SpotlightPage.qml` into a `ColumnLayout`: keep transition controls in a bounded top
Flickable/section, add a semantic divider and let `ApplicationVisibilityList` fill remaining
height. Do not nest its `ListView` inside the page Flickable.

Add localized keys for section title, description, search placeholder, visible/hidden accessible
state and empty search results in both catalogs.

Add the two safe read/test seams:

```qml
function previewApplicationVisible(entryId: string, visible: bool): bool {
    if (SurfaceCoordinator.ownerId.indexOf("settings:") !== 0 || !ConfigStore.previewActive)
        return false;
    return ApplicationVisibilityStore.setVisible(entryId, visible);
}
```

and Spotlight read-only `firstVisibleApplicationId()` / `visibleApplicationCount()` methods.

- [ ] **Step 4: Run GREEN and Settings acceptance**

```bash
python3 scripts/check_architecture.py
./scripts/check.sh
./scripts/settings_acceptance.sh
```

Expected: static suite and preview/hide/Cancel/Apply/runtime-restore acceptance PASS; repository and
both Hyprland Lua hashes unchanged.

- [ ] **Step 5: Commit**

```bash
git add Titonium/Modules/Settings/ApplicationVisibilityList.qml Titonium/Modules/Settings/SpotlightPage.qml Titonium/Modules/Settings/qmldir Titonium/App/AppShell.qml config/i18n/en.json config/i18n/vi.json scripts/check_architecture.py scripts/settings_acceptance.sh docs/TESTING.md
git commit -m "feat: manage visible apps in spotlight settings"
```

---

### Task 4: Spotlight placement, external scope icon, aliases and density pills

**Files:**
- Modify: `Titonium/Modules/Spotlight/SpotlightSurface.qml`
- Modify: `Titonium/Modules/Spotlight/CategoryCatalog.js`
- Modify: `Titonium/Modules/Spotlight/SpotlightLayout.js`
- Modify: `Titonium/Modules/Spotlight/PageIndicator.qml`
- Modify: `Titonium/Modules/Spotlight/AppGrid.qml`
- Modify: `config/i18n/en.json`
- Modify: `config/i18n/vi.json`
- Modify: `scripts/check_spotlight.js`
- Modify: `scripts/check_architecture.py`
- Modify: `scripts/spotlight_acceptance.sh`
- Modify: `docs/TESTING.md`

**Interfaces:**
- Consumes: existing `SpotlightModel.scope`, fixed 5×4 pages and the visibility projection from Task 2.
- Produces: `SpotlightLayout.indicatorVisualWidth(page, capacity): number`, `indicatorTargetWidth(): number`, expanded alias mapping, and top-anchored responsive composition.

- [ ] **Step 1: Write failing domain/UI contract fixtures**

Extend `check_spotlight.js` with installed-style records and assert:

```javascript
idsFor(["WordProcessor"])       // ["office"]
idsFor(["Settings"])            // ["system"]
idsFor(["FileManager"])         // ["utilities"]
idsFor(["WebBrowser"])          // ["internet"]
idsFor(["Audio", "Video"])    // ["multimedia"]
idsFor(["IDE", "Building"])   // ["development"]
indicatorVisualWidth(ids(20), 20) === 56
indicatorVisualWidth(ids(5), 20) === 23
indicatorVisualWidth([], 20) === 12
indicatorTargetWidth() === 56
```

Architecture assertions require `rocket_launch`, a sibling RowLayout icon before TextField, no
icon child inside TextField, `anchors.top`, `anchors.horizontalCenter`, exact 12-pixel offset
expression, max height 760 and accessible indicator count/capacity formatter.

- [ ] **Step 2: Run RED gates**

```bash
node scripts/check_spotlight.js
python3 scripts/check_architecture.py
```

Expected: FAIL for missing aliases, pill APIs and top/header contracts.

- [ ] **Step 3: Implement aliases and density pills**

Normalize every alias case-insensitively into the existing ten group IDs. Keep non-empty filtering
and stable order unchanged. Replace fixed track rendering with a transparent 56×20 FocusScope
target containing one centered-left pill whose width is `indicatorVisualWidth`; remove the full
background track. Current uses accent, inactive uses `Theme.borderStrong`.

Add `spotlight.page_density` translations:

```text
en: Page {page}, {count} of {capacity} applications
vi: Trang {page}, {count} trên {capacity} ứng dụng
```

- [ ] **Step 4: Implement top placement and external icons**

Replace panel centering with horizontal center plus top anchor. Use:

```qml
width: Math.min(800, root.width - Metrics.spacingLarge * 4)
height: Math.min(760, root.height - Metrics.barHeight - 12 - Metrics.spacingLarge)
anchors.top: parent.top
anchors.horizontalCenter: parent.horizontalCenter
anchors.topMargin: Metrics.barHeight + 12
```

Wrap icon and Search field in a `RowLayout`. Place the scope icon before the TextField and map Apps
to `rocket_launch`; remove the TextField's child icon and restore normal field padding. Preserve
Tab/Shift+Tab, query and focus behavior exactly.

- [ ] **Step 5: Run GREEN and live Spotlight acceptance**

```bash
node scripts/check_spotlight.js
python3 scripts/check_architecture.py
./scripts/check.sh
./scripts/spotlight_acceptance.sh
```

Expected: fixtures/static/live Apps→Clipboard→System scope acceptance PASS with no Loader warning.

- [ ] **Step 6: Commit**

```bash
git add Titonium/Modules/Spotlight/SpotlightSurface.qml Titonium/Modules/Spotlight/CategoryCatalog.js Titonium/Modules/Spotlight/SpotlightLayout.js Titonium/Modules/Spotlight/PageIndicator.qml Titonium/Modules/Spotlight/AppGrid.qml config/i18n/en.json config/i18n/vi.json scripts/check_spotlight.js scripts/check_architecture.py scripts/spotlight_acceptance.sh docs/TESTING.md
git commit -m "feat: refine spotlight composition and density"
```

---

### Task 5: Dedicated centered session-confirmation surface

**Files:**
- Create: `Titonium/Modules/MenuBar/ArchMenu/SessionConfirmationSurface.qml`
- Modify: `Titonium/Modules/MenuBar/ArchMenu/ArchMenu.qml`
- Modify: `Titonium/Modules/MenuBar/ArchMenu/SessionConfirmation.qml`
- Modify: `Titonium/Modules/MenuBar/ArchMenu/qmldir`
- Modify: `Titonium/App/AppShell.qml`
- Modify: `scripts/check_arch_menu.js`
- Modify: `scripts/check_architecture.py`
- Modify: `scripts/settings_acceptance.sh`
- Modify: `docs/MODULE_CONTRACT.md`
- Modify: `docs/TESTING.md`

**Interfaces:**
- Consumes: `SurfaceCoordinator.open/close/forceClose/guardOwner/releaseOwnerGuard`, `SessionActions.executeConfirmed(actionId)` and existing `SessionConfirmation` content control.
- Produces: dedicated descriptor `{source, ownerId, actionId, keyboardFocus, closeOnMonitorChange}` and safe IPC `arch-menu.previewSessionAction(actionId): string` that only opens confirmation.

- [ ] **Step 1: Add failing architecture and model gates**

Require all six session IDs to map to a `session-confirm:<screen>:<action>` descriptor; reject
`pendingAction`, `SessionActions` and `confirmationComponent` inside `ArchMenu.qml`; require exactly
one confirmed Platform execution path inside `SessionConfirmationSurface.qml` after owner guard.
Require center anchors, width 420, minimum 240, maximum 320, Cancel/Escape close and failure
retention. Ensure `SessionConfirmation` still has exactly Cancel and Confirm controls.

Extend PID-targeted acceptance to call:

```bash
qs ... ipc --pid "$shell_pid" call arch-menu previewSessionAction lock
qs ... ipc --pid "$shell_pid" call arch-menu state
qs ... ipc --pid "$shell_pid" call arch-menu close
```

Expect `confirmation:lock:<screen>`, then `closed`; never call Confirm.

- [ ] **Step 2: Run RED gates**

```bash
node scripts/check_arch_menu.js
python3 scripts/check_architecture.py
./scripts/settings_acceptance.sh
```

Expected: FAIL because confirmation is nested and no safe preview method/source exists.

- [ ] **Step 3: Move lifecycle into the dedicated surface**

`SessionConfirmationSurface.qml` is a full-screen FocusScope with transparent outside-click layer
and centered `Controls.Panel`. It reads `descriptor.actionId`, owns `launchPending` and
`failureMessage`, guards its exact owner before `executeConfirmed`, and uses existing
`SessionActions.actionStarted/actionFailed` signals. Cancel/Escape close only while not pending;
failure releases the guard and keeps the panel visible.

Keep `SessionConfirmation.qml` presentation-only. Constrain its content inside a Flickable when
implicit height exceeds 320.

- [ ] **Step 4: Make Arch Menu route by descriptor replacement**

Replace `requestSessionAction` with:

```qml
function openSessionConfirmation(actionId: string): void {
    if (SessionActions.supportedActions.indexOf(actionId) < 0) {
        Logger.warn("arch-menu", "unsupported session action: " + actionId);
        return;
    }
    const confirmationOwner = "session-confirm:" + root.screen.name + ":" + actionId;
    SurfaceCoordinator.open(confirmationOwner, {
        "source": Qt.resolvedUrl("SessionConfirmationSurface.qml"),
        "keyboardFocus": "exclusive",
        "closeOnMonitorChange": true,
        "ownerId": confirmationOwner,
        "actionId": actionId
    }, root.screen);
}
```

Arch Menu retains About/Settings/unknown routing only. Add `previewSessionAction` IPC with the same
supported-action validation and descriptor helper; `arch-menu.state()` recognizes both menu and
session-confirmation owners, while `arch-menu.close()` safely closes either.

- [ ] **Step 5: Run GREEN gates and safe live acceptance**

```bash
node scripts/check_arch_menu.js
python3 scripts/check_architecture.py
./scripts/check.sh
./scripts/settings_acceptance.sh
```

Expected: dedicated confirmation source loads, Cancel closes, no real action executes, and all
settings/Arch Menu checks PASS.

- [ ] **Step 6: Commit**

```bash
git add Titonium/Modules/MenuBar/ArchMenu/SessionConfirmationSurface.qml Titonium/Modules/MenuBar/ArchMenu/ArchMenu.qml Titonium/Modules/MenuBar/ArchMenu/SessionConfirmation.qml Titonium/Modules/MenuBar/ArchMenu/qmldir Titonium/App/AppShell.qml scripts/check_arch_menu.js scripts/check_architecture.py scripts/settings_acceptance.sh docs/MODULE_CONTRACT.md docs/TESTING.md
git commit -m "feat: center session confirmations in a dedicated surface"
```

---

### Task 6: Whole-batch verification, live cutover and handoff

**Files:**
- Modify: `README.md`
- Modify: `docs/ROADMAP.md`
- Modify: `docs/PERFORMANCE.md`
- Modify: `docs/OPERATIONS.md`

**Interfaces:**
- Consumes: Tasks 1–5 and current live runtime at `/home/cole/Projects/titonium`.
- Produces: documented schema v5, app visibility behavior, centered confirmation operations and live tested shell; no Hyprland file changes.

- [ ] **Step 1: Update maintained authority docs**

Document settings v5, the Foundation visibility boundary, Spotlight's 800×≤760 top placement,
external scope icons, alias-only categories, 12–56 density pills and dedicated confirmation owner.
Keep Wi-Fi/Bluetooth/Sound/Notification Toast explicitly next, not complete.

- [ ] **Step 2: Run the complete static and atomic-persistence gates**

```bash
./scripts/check.sh
./scripts/settings_acceptance.sh
git diff --check
```

Expected: all pass; repository and both Hyprland Lua hashes remain unchanged during acceptance.

- [ ] **Step 3: Run a fresh foreground smoke**

Stop only the exact Titonium instance:

```bash
qs kill -p /home/cole/Projects/titonium
./scripts/smoke.sh
```

Expected: `PASS foreground smoke`, `Configuration Loaded`, no rejected runtime pattern.

- [ ] **Step 4: Restore the live shell and run focused acceptance**

```bash
qs -d -p /home/cole/Projects/titonium
./scripts/spotlight_acceptance.sh
./scripts/settings_acceptance.sh
hyprctl configerrors
```

Expected: Spotlight Apps/Clipboard/System and visibility preview/Cancel/Apply pass; centered Lock
confirmation loads and cancels safely; `hyprctl configerrors` is empty. Leave Titonium running.

- [ ] **Step 5: Manual visual checklist without destructive activation**

On DP-1 scale 1.5 and DP-3 scale 1.0 verify: top gap 12; no bottom clipping; external icon changes;
Tab query/focus stability; installed WPS/Fcitx/Yazi aliases; full/partial density difference;
hidden app preview/Cancel; every session item opens the centered dialog. Press only Cancel/Escape.

- [ ] **Step 6: Commit handoff docs**

```bash
git add README.md docs/ROADMAP.md docs/PERFORMANCE.md docs/OPERATIONS.md
git commit -m "docs: close spotlight visibility and confirmation batch"
```

- [ ] **Step 7: Begin the next milestone as a separate design cycle**

Audit the read-only legacy Wi-Fi, Bluetooth, Sound and Notification implementations plus current
Quickshell APIs. Write a new design/spec before porting any module. Do not create feature stubs in
this plan.

