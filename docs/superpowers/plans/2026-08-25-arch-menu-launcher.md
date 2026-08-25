# Arch Menu Launcher Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the existing Launcher dashboard with a left-anchored, icon-rail Arch Menu containing adaptive Apps, shared Settings, read-only Yazi-like Places, Info and Power sections while leaving Spotlight untouched.

**Architecture:** `ArchMenu.qml` remains a single `SurfaceCoordinator` transient and delegates section resolution to `LauncherSectionRegistry.qml`; each section is lazy and owns presentation only. Application, filesystem, system information, settings persistence and session execution stay behind existing Foundation/Platform boundaries.

**Tech Stack:** Quickshell 0.3.1, Qt 6 QML/JavaScript, `Qt.labs.folderlistmodel`, Quickshell `FileView`/`Process`, Python and Node contract tests, Hyprland layer-shell.

**Spec:** `docs/superpowers/specs/2026-08-25-arch-menu-launcher-design.md`

## Global Constraints

- Spotlight source, IPC and interaction flow must not change.
- The Launcher has no keyboard shortcut and opens only from the leftmost Arch logo on MenuBar.
- UI QML must not instantiate `Process`, call `Quickshell.execDetached`, persist files or execute raw system commands.
- Runtime settings live outside Git and writes remain atomic through `ConfigStore`.
- The popup has stable Settings-sized geometry and a 64–72 logical-pixel icon-only rail on the left.
- Apps has no search, favorites, recent list, usage ranking or categories.
- Places v1 is read-only: navigate, preview and open only.
- Hidden section trees do not exist; no hidden timer, poller, shader or `MultiEffect` is allowed.
- All text uses `I18n.tr()` and all geometry uses logical pixels at DP-3 scale 1.0 and DP-1 scale 1.5.
- Existing dirty-worktree changes belong to the current Titonium milestone and must be preserved.

---

### Task 0: Preserve and verify the current milestone baseline

**Files:**
- Verify only; commit the already-present tracked/untracked milestone files shown by `git status --short`.

**Interfaces:**
- Consumes: current bootable Titonium shell.
- Produces: a clean rollback commit before the Launcher architecture changes.

- [ ] **Step 1: Record the exact baseline diff**

Run: `git status --short` and `git diff --check`.

Expected: only the known Active Window, Clock, Launcher, Settings/config/docs changes and new `LauncherHistoryStore.qml`, `AnalogClockPanel.qml`, and `Platform/System` files; no whitespace errors.

- [ ] **Step 2: Run baseline static and foreground tests**

Run: `./scripts/check.sh` then `./scripts/smoke.sh`.

Expected: config, architecture, lunar, qmllint and foreground smoke all pass.

- [ ] **Step 3: Commit the preserved baseline**

```bash
git add Titonium config docs scripts tests
git commit -m "feat: checkpoint menubar launcher and clock work"
```

Expected: the spec commit remains separate and the worktree becomes clean.

---

### Task 1: Settings v3 migration and adaptive Apps layout contract

**Files:**
- Create: `tests/fixtures/settings.v2.launcher.json`
- Create: `Titonium/Modules/MenuBar/Launcher/LauncherLayout.js`
- Create: `scripts/check_launcher_layout.js`
- Modify: `config/defaults/settings.json`
- Modify: `config/schemas/settings.schema.json`
- Modify: `Titonium/Foundation/ConfigMigrations.js`
- Modify: `Titonium/Foundation/ConfigValidator.js`
- Modify: `Titonium/Foundation/ConfigStore.qml`
- Modify: `scripts/validate_config.py`
- Modify: `scripts/check.sh`
- Modify: `Titonium/Modules/Settings/LauncherPage.qml`
- Modify: `config/i18n/en.json`
- Modify: `config/i18n/vi.json`

**Interfaces:**
- Consumes: `ConfigStore.previewState.modules.launcher` and application records from `ApplicationCatalog`.
- Produces: settings schema v3 launcher shape `{username, avatarIcon, pageTransition, transitionDuration}` and pure functions `columnCount(width, minimumTileWidth, gap)`, `rowCount(height, minimumTileHeight, gap)`, `pageSize(...)`, `pages(items, capacity)`, `fillRatio(page, capacity)`.

- [ ] **Step 1: Add failing v2→v3 migration assertions**

Add a v2 fixture containing every old Launcher field. Extend `scripts/validate_config.py` to assert migration output is schema v3, preserves username/avatar/transition, and removes `defaultCategory`, `resultLimit`, `columns`, `showSubtitles`, and `searchAutoFocus`.

Run: `python3 scripts/validate_config.py`.

Expected: FAIL because schema v3 and migration do not exist.

- [ ] **Step 2: Implement the v3 settings contract**

Make `migrateSettings()` apply v1→v2 then v2→v3 as pure transforms. Change defaults, schema and both validators to require only:

```json
"launcher": {
  "username": "",
  "avatarIcon": "terminal",
  "pageTransition": "slide-fade",
  "transitionDuration": 220
}
```

Update the ConfigStore log to `settings schema v3 loaded`. Remove retired controls and strings from `LauncherPage.qml` while retaining profile and page-transition controls.

Run: `python3 scripts/validate_config.py`.

Expected: PASS, including direct v1→v3 and v2→v3 fixtures.

- [ ] **Step 3: Write failing adaptive-layout fixtures**

Create `scripts/check_launcher_layout.js` using `vm.runInContext`, like `check_lunar.js`, and assert:

```js
assertEqual(columnCount(840, 120, 8), 6);
assertEqual(columnCount(612, 120, 8), 4);
assertEqual(rowCount(500, 112, 8), 4);
assertDeepEqual(pages([1,2,3,4,5], 4), [[1,2,3,4], [5]]);
assertEqual(fillRatio([5], 4), 0.25);
```

Run: `node scripts/check_launcher_layout.js`.

Expected: FAIL because `LauncherLayout.js` does not exist.

- [ ] **Step 4: Implement the pure layout helpers**

Use clamped integer arithmetic; counts never fall below one, capacity never falls below one, and an empty catalog returns one empty page. Add the test to `scripts/check.sh` immediately after lunar fixtures.

Run: `./scripts/check.sh`.

Expected: PASS.

- [ ] **Step 5: Commit the contract**

```bash
git add config Titonium/Foundation Titonium/Modules/Settings/LauncherPage.qml Titonium/Modules/MenuBar/Launcher/LauncherLayout.js scripts tests/fixtures config/i18n
git commit -m "feat: define adaptive launcher settings contract"
```

---

### Task 2: Arch Menu shell, left rail and adaptive Apps

**Files:**
- Create: `assets/icons/archlinux.svg`
- Create: `Titonium/Modules/MenuBar/Launcher/ArchMenu.qml`
- Create: `Titonium/Modules/MenuBar/Launcher/LauncherRail.qml`
- Create: `Titonium/Modules/MenuBar/Launcher/LauncherSectionRegistry.qml`
- Create: `Titonium/Modules/MenuBar/Launcher/AppsPage.qml`
- Create: `Titonium/Modules/MenuBar/Launcher/PageIndicator.qml`
- Modify: `Titonium/Modules/MenuBar/Launcher/ApplicationCatalogModel.qml`
- Modify: `Titonium/Modules/MenuBar/Launcher/ApplicationTile.qml`
- Modify: `Titonium/Modules/MenuBar/Launcher/LauncherWidget.qml`
- Modify: `Titonium/Modules/MenuBar/Launcher/qmldir`
- Modify: `Titonium/App/AppShell.qml`
- Modify: `scripts/check_architecture.py`
- Modify: `config/i18n/en.json`
- Modify: `config/i18n/vi.json`
- Delete after callers are removed: `Titonium/Modules/MenuBar/Launcher/Dashboard.qml`
- Delete after callers are removed: `Titonium/Foundation/LauncherHistoryStore.qml`

**Interfaces:**
- Consumes: `LauncherLayout.*`, `ApplicationCatalog.applications`, `ApplicationCatalog.launch(entryId)`, `SurfaceCoordinator`, and descriptor `{ownerId, keyboardFocus, closeOnMonitorChange, cancelPreviewOnClose}`.
- Produces: `ArchMenu.selectedSection: string`, `ArchMenu.selectSection(sectionId)`, registry `sourceFor(sectionId): url`, and Apps page signal `applicationLaunched()`.

- [ ] **Step 1: Add failing architecture assertions**

Extend `scripts/check_architecture.py` to require the new focused files, require the Launcher trigger source to be `ArchMenu.qml`, reject `query`, `category`, `LauncherHistoryStore`, and `Process` in Launcher UI, and require `Loader`-based section resolution.

Run: `python3 scripts/check_architecture.py`.

Expected: FAIL against the old Dashboard.

- [ ] **Step 2: Build the stable surface shell and section registry**

Implement `ArchMenu.qml` as a `FocusScope` with backdrop/outside-click handling and a left-anchored `Controls.Panel` sized `min(980, availableWidth)` by `min(700, availableHeightBelowBar)`. The row contains a 68px rail, divider and fill-width Loader. Opening always selects Apps and page one; Escape/outside click/monitor change closes it.

The initial registry exposes Apps only. Unknown IDs log once and return Apps. Add later section descriptors only in their owning tasks so no dead buttons appear.

- [ ] **Step 3: Build icon-only rail and Arch trigger**

Use the packaged Arch SVG in `LauncherWidget.qml`. `LauncherRail.qml` delegates icon-only buttons with tooltip/accessibility names and pins entries marked `placement: "bottom"` after a fill spacer. Do not render text labels in the rail.

Run: `/usr/lib/qt6/bin/qmllint` indirectly through `./scripts/check.sh`.

Expected: no new warning.

- [ ] **Step 4: Simplify the catalog model and implement adaptive pages**

`ApplicationCatalogModel.qml` exposes alphabetic `applications`, mutable `pageCapacity`, and `pages`. It delegates arithmetic to `LauncherLayout.js`; launch success closes the surface and does not record history.

`AppsPage.qml` calculates columns/rows from actual width/height, renders only the current horizontal page, maps vertical wheel delta to one page, and preserves `slide`, `slide-fade`, `slide-scale`, `none`, reduced motion and variable-width fullness indicators. Reset to page one on geometry/catalog changes.

`ApplicationTile.qml` displays icon and one-line width-elided name only; remove subtitle behavior.

- [ ] **Step 5: Remove obsolete Dashboard/history and run gates**

Update `qmldir`, AppShell Launcher IPC and all source references before deleting obsolete files. Remove their singleton registration and obsolete i18n keys.

Run: `rg -n 'Dashboard|LauncherHistoryStore|search_placeholder|category\.' Titonium config scripts`.

Expected: no active Launcher references.

Run: `./scripts/check.sh`, `./scripts/smoke.sh`, `hyprctl configerrors`.

Expected: all pass and Hyprland output is empty.

- [ ] **Step 6: Live multi-monitor acceptance and commit**

Restart the project with `qs -p /home/cole/Projects/titonium`. Open the Launcher on DP-3 and DP-1, verify left anchoring, stable size, adaptive column changes, page wheel/indicator and app launch.

```bash
git add assets Titonium config scripts docs
git commit -m "feat: replace dashboard with adaptive arch menu"
```

---

### Task 3: Reusable Settings workspace embedded in Arch Menu

**Files:**
- Create: `Titonium/Modules/Settings/SettingsWorkspace.qml`
- Create: `Titonium/Modules/MenuBar/Launcher/LauncherSettingsPage.qml`
- Modify: `Titonium/Modules/Settings/SettingsCenter.qml`
- Modify: `Titonium/Modules/Settings/qmldir`
- Modify: `Titonium/Modules/MenuBar/Launcher/LauncherSectionRegistry.qml`
- Modify: `Titonium/Modules/MenuBar/Launcher/ArchMenu.qml`
- Modify: `Titonium/App/AppShell.qml`
- Modify: `scripts/settings_acceptance.sh`
- Modify: `scripts/check_architecture.py`
- Modify: `config/i18n/en.json`
- Modify: `config/i18n/vi.json`

**Interfaces:**
- Consumes: `ConfigStore.beginPreview()`, `apply(): bool`, `cancel()`, `restoreAppearance()`, page components and current Settings IPC.
- Produces: `SettingsWorkspace.currentPage`, `dirty`, signals `applyRequested()`, `cancelRequested()`, and function `selectPage(pageId)`; both hosts use this exact workspace.

- [ ] **Step 1: Add failing shared-workspace lifecycle checks**

Extend architecture checks to require both `SettingsCenter.qml` and `LauncherSettingsPage.qml` to instantiate `SettingsWorkspace`, forbid page component duplication in either host, and require the Launcher descriptor to set `cancelPreviewOnClose: true`.

Extend `settings_acceptance.sh` with Launcher IPC checks: open Launcher, select Settings via a narrow IPC method, patch a harmless appearance value, close Launcher and verify rollback; reopen, patch/apply and verify runtime-only persistence.

Run: `python3 scripts/check_architecture.py`.

Expected: FAIL until the workspace is extracted.

- [ ] **Step 2: Extract Settings content without changing pages**

Move header, page navigation, page Loader, dirty state and footer controls from `SettingsCenter.qml` into `SettingsWorkspace.qml`. The workspace never imports or calls `SurfaceCoordinator`; it emits Apply/Cancel intent. Keep all current page IDs and conditional Material page behavior.

Make `SettingsCenter.qml` only backdrop, centered panel and lifecycle wiring. Preserve standalone Apply=commit-and-close and Cancel/Escape/outside-click=rollback-and-close behavior.

- [ ] **Step 3: Host Settings inside Arch Menu**

Register Settings only after `LauncherSettingsPage.qml` exists. Selecting it calls `beginPreview()` only when no preview is active. Embedded Apply commits and stays on Settings; Cancel rolls back and stays open. Leaving Settings preserves the preview for a return; closing/replacing the Arch Menu rolls it back through `cancelPreviewOnClose`.

Add Launcher IPC `section(screenName, sectionId)` for acceptance only; invalid IDs fall back to Apps and log a warning.

- [ ] **Step 4: Run settings and runtime acceptance**

Run: `./scripts/check.sh`, `./scripts/smoke.sh`, `./scripts/settings_acceptance.sh`, `hyprctl configerrors`.

Expected: all pass, runtime files restored by the acceptance trap, Git source unchanged by Apply, and both `hyprland.lua` hashes unchanged.

- [ ] **Step 5: Commit**

```bash
git add Titonium scripts config/i18n docs
git commit -m "refactor: share settings workspace with arch menu"
```

---

### Task 4: Read-only Yazi-like Places

**Files:**
- Create: `Titonium/Platform/Filesystem/DirectoryModel.qml`
- Create: `Titonium/Platform/Filesystem/FilePreview.qml`
- Create: `Titonium/Platform/Filesystem/FilesystemAdapter.qml`
- Create: `Titonium/Platform/Filesystem/qmldir`
- Modify: `Titonium/Platform/qmldir`
- Create: `Titonium/Modules/MenuBar/Launcher/PlacesModel.qml`
- Create: `Titonium/Modules/MenuBar/Launcher/PlacesPage.qml`
- Modify: `Titonium/Modules/MenuBar/Launcher/LauncherSectionRegistry.qml`
- Modify: `Titonium/Modules/MenuBar/Launcher/qmldir`
- Modify: `scripts/check_architecture.py`
- Modify: `config/i18n/en.json`
- Modify: `config/i18n/vi.json`

**Interfaces:**
- Consumes: QtCore `StandardPaths`, `FolderListModel`, Quickshell `FileView`, and `Qt.openUrlExternally(url)` only inside Platform.
- Produces: `DirectoryModel.folder`, `parentFolder`, `entries`, `status`, `errorText`; `FilesystemAdapter.bookmarks`, `previewKind(url,suffix,size)`, `openUrl(url): bool`; `PlacesModel.enter(entry)`, `goParent()`, `select(index)`.

- [ ] **Step 1: Add failing boundary and contract checks**

Require all `Qt.labs.folderlistmodel`, `FileView` and `openUrlExternally` references to live under `Platform/Filesystem`. Reject mutation verbs (`remove`, `rename`, `mkdir`, `setText`) in the adapter and Places UI. Require the registry to resolve `places` lazily.

Run: `python3 scripts/check_architecture.py`.

Expected: FAIL because the Platform module is absent.

- [ ] **Step 2: Implement the read-only Platform boundary**

Wrap `FolderListModel` with dirs-first, readable-only, no dot entries and immutable entry records containing name, URL, directory flag, suffix, byte size and modified time. Build bookmarks from `StandardPaths.HomeLocation`, Documents, Download, Pictures and `StandardPaths.HomeLocation + "/Projects"` only when each location is readable; derive the mount root as `"/run/media/" + UserIdentity.loginName` and discover its readable children without invoking a process.

Preview policy: image suffixes (`png`, `jpg`, `jpeg`, `webp`, `svg`) return `image`; text/config suffixes up to 256 KiB return `text`; everything else returns `metadata`. `FilePreview.qml` caps displayed text at 32 KiB. Opening uses `Qt.openUrlExternally` and reports failure through `errorText`.

- [ ] **Step 3: Implement state model and three-column UI**

PlacesModel resets selection on directory change, clamps indexes and treats unavailable parents/bookmarks as recoverable errors. PlacesPage renders bookmark, directory and preview/metadata columns. Add arrows, Enter, Backspace and conflict-free `h/j/k/l`; pointer selection and double-click/Enter open folders/files.

Keep preview and directory adapters inside the lazy Places page so closing/changing section destroys them.

- [ ] **Step 4: Test failure cases and gates**

Run: `./scripts/check.sh` and `./scripts/smoke.sh`.

Manual fixtures: navigate Home→Projects→parent; select image/text/binary; select a disappearing entry; visit an unreadable directory. Expected: inline error/metadata fallback, no crash, no shell process, no filesystem mutation.

- [ ] **Step 5: Commit**

```bash
git add Titonium/Platform/Filesystem Titonium/Platform/qmldir Titonium/Modules/MenuBar/Launcher scripts config/i18n docs
git commit -m "feat: add read-only places navigator"
```

---

### Task 5: Visibility-gated Info section

**Files:**
- Create: `Titonium/Platform/System/SystemInfo.qml`
- Modify: `Titonium/Platform/System/qmldir`
- Create: `Titonium/Modules/MenuBar/Launcher/InfoPage.qml`
- Modify: `Titonium/Modules/MenuBar/Launcher/LauncherSectionRegistry.qml`
- Modify: `Titonium/Modules/MenuBar/Launcher/qmldir`
- Modify: `scripts/check_architecture.py`
- Modify: `config/i18n/en.json`
- Modify: `config/i18n/vi.json`

**Interfaces:**
- Consumes: QtCore `SystemInformation`, visibility-gated Platform `FileView` reads for `/proc/meminfo` and `/proc/uptime`, and one direct `df -B1 --output=size,used,avail,pcent /` probe.
- Produces: `SystemInfo.active`, `hostname`, `osName`, `kernel`, `architecture`, `uptimeSeconds`, `memoryTotalBytes`, `memoryUsedBytes`, `storageTotalBytes`, `storageUsedBytes`, `lastError`.

- [ ] **Step 1: Add failing performance-boundary checks**

Require every Info Timer/Process to be under `Platform/System/SystemInfo.qml`, require refresh timers to use `running: root.active`, require the one-shot storage process to start only inside an `active === true` transition, and forbid SystemInfo instantiation outside `InfoPage.qml`.

Run: `python3 scripts/check_architecture.py`.

Expected: FAIL until SystemInfo exists.

- [ ] **Step 2: Implement active-only data collection**

Use constant `SystemInformation` properties for host/OS/kernel/architecture. While `active`, refresh memory/uptime every five seconds and storage once on activation. Stop timers and processes immediately when inactive. Parse malformed data into `lastError` without replacing the last valid sample.

- [ ] **Step 3: Add Info presentation and gates**

Register Info only after its page exists. Present identity facts and semantic memory/storage progress without graphs or continuous animation.

Run: `./scripts/check.sh`, `./scripts/smoke.sh`, `hyprctl configerrors`.

Expected: pass; process/timer absent when Launcher is closed or another section is selected.

- [ ] **Step 4: Commit**

```bash
git add Titonium/Platform/System Titonium/Modules/MenuBar/Launcher scripts config/i18n docs
git commit -m "feat: add lazy launcher system info"
```

---

### Task 6: Large confirmed Power actions

**Files:**
- Create: `Titonium/Modules/MenuBar/Launcher/PowerPage.qml`
- Modify: `Titonium/Modules/MenuBar/Launcher/LauncherSectionRegistry.qml`
- Modify: `Titonium/Modules/MenuBar/Launcher/qmldir`
- Modify: `scripts/check_architecture.py`
- Modify: `config/i18n/en.json`
- Modify: `config/i18n/vi.json`

**Interfaces:**
- Consumes: `SessionActions.supportedActions`, `busy`, `lastError`, and `executeConfirmed(action): bool`.
- Produces: local `pendingAction`, `request(action)`, `cancelConfirmation()`, `confirm()`; no automated test invokes a real session action.

- [ ] **Step 1: Add failing safety assertions**

Require the Power page to render only `SessionActions.supportedActions`, set `pendingAction` before execution and call `executeConfirmed` only from the confirmation handler. Reject direct `systemctl`, Hyprland dispatch or `Process` in Launcher QML.

Run: `python3 scripts/check_architecture.py`.

Expected: FAIL because PowerPage is absent.

- [ ] **Step 2: Implement the large action grid and confirmation**

Use an adaptive three-column grid of large action cards for Sleep, Hibernate, Logout, Restart and Shutdown. Restart/Shutdown use danger semantics. First activation opens an in-page confirmation panel with Cancel and Confirm; only Confirm calls the Platform boundary. Disable every action while `SessionActions.busy`; show `lastError` inline.

- [ ] **Step 3: Run non-destructive gates and live visual check**

Run: `./scripts/check.sh`, `./scripts/smoke.sh`.

Inspect focus, pointer hit targets and confirmation for all five actions but do not activate Confirm during automated/manual acceptance. Verify outside click/Escape closes Launcher without executing.

- [ ] **Step 4: Commit**

```bash
git add Titonium/Modules/MenuBar/Launcher scripts config/i18n docs
git commit -m "feat: add confirmed arch menu power actions"
```

---

### Task 7: Documentation, final runtime acceptance and handoff

**Files:**
- Modify: `AGENTS.md`
- Modify: `docs/ARCHITECTURE.md`
- Modify: `docs/MODULE_CONTRACT.md`
- Modify: `docs/PERFORMANCE.md`
- Modify: `docs/TESTING.md`
- Modify: `docs/ROADMAP.md`

**Interfaces:**
- Consumes: all completed Launcher section contracts.
- Produces: accurate takeover documentation and final test evidence.

- [ ] **Step 1: Update docs to the implemented state**

Replace the old 1/3–2/3/search/history Launcher description with the Arch Menu shell, registry, adaptive grid, shared Settings lifecycle, Places read-only boundary, Info activation policy and confirmed Power actions. Keep Spotlight as Milestone 3 and explicitly unaffected.

- [ ] **Step 2: Run the complete static/runtime suite**

Run, in order:

```bash
git diff --check
./scripts/check.sh
./scripts/smoke.sh
./scripts/runtime_acceptance.sh
./scripts/settings_acceptance.sh
hyprctl configerrors
```

Expected: every script passes; `hyprctl configerrors` is empty; repo source and both `hyprland.lua` hashes remain unchanged by runtime Apply.

- [ ] **Step 3: Run final live acceptance on both outputs**

Restart using `qs -p /home/cole/Projects/titonium`. On DP-3 and DP-1 verify: one MenuBar and 40px reserve; Arch trigger left of Workspaces; stable left-anchored popup; icon-only rail; Apps adaptive paging; Settings Preview/Apply/Cancel; Places navigation/preview; Info only while visible; Power confirmation without execution; outside click/Escape/cross-monitor close.

- [ ] **Step 4: Inspect runtime health and commit docs**

Check the foreground/current runtime log for `ERROR`, `TypeError`, duplicate ID, missing method and repeated catalog/system logs. Fix any discovered defect through its owning task boundary and rerun the relevant gate.

```bash
git add AGENTS.md docs
git commit -m "docs: complete arch menu launcher handoff"
```

- [ ] **Step 5: Report handoff**

Report implemented sections, commits, exact test commands/results, any intentionally deferred visual refinements, and the current Quickshell instance status. Do not claim completion without fresh command output.
