# Spotlight Launcher and Arch Menu Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the large rail-based Launcher with a centered categorized 5×4 Spotlight Launcher and a compact macOS-style Arch system menu while restoring Settings as a standalone surface.

**Architecture:** `Titonium.Modules.Spotlight` owns keyboard application discovery, categorized browsing, calculator results and Clipboard mode. `Titonium.Modules.MenuBar.ArchMenu` owns only the MenuBar trigger, compact system menu and confirmation UI; both delegate operating-system work to Platform adapters and transient lifecycle to `SurfaceCoordinator`.

**Tech Stack:** Quickshell 0.3.1, Qt 6 QML/JavaScript, Quickshell `DesktopEntries` and event-driven clipboard property, Python/Node contract tests, Hyprland Lua bindings.

**Spec:** `docs/superpowers/specs/2026-08-26-spotlight-launcher-and-arch-menu-design.md`

## Global Constraints

- Use test-first RED → GREEN cycles; do not change production code before observing the new test fail for the intended reason.
- UI QML must not instantiate `Process`, call `Quickshell.execDetached`, persist files or contain raw `hyprctl`, `wl-paste`, `wl-copy`, `systemctl` or shell commands.
- Runtime state lives under Quickshell's Titonium Data/State directories and atomic persistence uses `FileView.setText()` with `atomicWrites: true`.
- Spotlight is nominally 800×620 logical pixels, centered on the focused monitor and stable across Browse, Results and Clipboard modes.
- Browse mode is fixed at five columns by four rows; search covers all applications regardless of selected category.
- `Super + Space` opens default Spotlight, `Super + V` opens Clipboard, and the duplicate `Super + R` binding is removed only after Spotlight acceptance passes.
- The Arch icon opens only the compact text-and-icon system menu; Settings is never embedded in it.
- Every session action, including Lock and Sleep, requires confirmation and executes only through `Platform/System/SessionActions.qml`.
- Only active views are loaded; no timer polling, infinite animation, shader, `MultiEffect` or hidden render loop is allowed.
- Preserve unrelated changes in `/home/cole/Projects/titonium-hyprland`; patch only the three approved Spotlight binding lines in each Hyprland config.
- All user-facing strings use `I18n.tr()`, semantic theme tokens and logical pixels.

## Target file structure

```text
Titonium/
├── Foundation/
│   ├── AppMetadata.qml                 # single source for About/build identity
│   ├── ClipboardHistory.js             # pure normalization/dedupe/classification
│   └── ClipboardHistoryStore.qml       # bounded, atomic clipboard history persistence
├── Platform/
│   ├── Applications/ApplicationCatalog.qml
│   ├── Clipboard/
│   │   ├── ClipboardAdapter.qml        # Quickshell clipboard event/copy boundary
│   │   └── qmldir
│   └── System/SessionActions.qml
└── Modules/
    ├── Spotlight/
    │   ├── SpotlightSurface.qml        # stable centered transient composition
    │   ├── SpotlightModel.qml          # ephemeral mode/query/category/page/selection
    │   ├── SpotlightLayout.js          # pure 5×4 paging and indicators
    │   ├── CategoryCatalog.js          # pure freedesktop category normalization
    │   ├── SearchEngine.js             # pure app scoring/result normalization
    │   ├── Calculator.js               # safe expression parser, no eval/new Function
    │   ├── AppGrid.qml
    │   ├── ApplicationTile.qml
    │   ├── SearchResults.qml
    │   ├── ClipboardView.qml
    │   ├── PageIndicator.qml
    │   └── qmldir
    └── MenuBar/ArchMenu/
        ├── ArchMenuWidget.qml           # MenuBar Arch trigger
        ├── ArchMenu.qml                 # compact anchored dropdown
        ├── ArchMenuModel.js             # grouped functional items
        ├── ArchMenuItem.qml
        ├── SessionConfirmation.qml
        ├── AboutTitonium.qml
        └── qmldir
```

The old `Titonium/Modules/MenuBar/Launcher` directory remains until Spotlight has replacements for
its tested grid pieces. It is removed atomically in Task 6 after `WidgetRegistry` and every runtime
reference point to the new modules.

---

### Task 1: Settings v4 and Spotlight preference ownership

**Files:**
- Create: `tests/fixtures/settings.v3.spotlight.json`
- Create: `Titonium/Modules/Settings/SpotlightPage.qml`
- Modify: `config/defaults/settings.json`
- Modify: `config/schemas/settings.schema.json`
- Modify: `Titonium/Foundation/ConfigMigrations.js`
- Modify: `Titonium/Foundation/ConfigValidator.js`
- Modify: `Titonium/Foundation/ConfigStore.qml`
- Modify: `scripts/validate_config.py`
- Modify: `Titonium/Modules/Settings/SettingsWorkspace.qml`
- Modify: `Titonium/Modules/Settings/qmldir`
- Modify: `Titonium/App/AppShell.qml`
- Modify: `config/i18n/en.json`
- Modify: `config/i18n/vi.json`
- Delete after references change: `Titonium/Modules/Settings/LauncherPage.qml`

**Interfaces:**
- Consumes: settings v3 `modules.launcher.{username,avatarIcon,pageTransition,transitionDuration}`.
- Produces: settings v4 `modules.spotlight.{pageTransition:string,transitionDuration:int}`; migration drops profile-only fields and preserves locale, appearance, accessibility, layout-independent module settings.

- [ ] **Step 1: Add a failing v3→v4 migration fixture**

Create `tests/fixtures/settings.v3.spotlight.json` with schema v3, non-default locale/appearance,
unrelated Audio/Clock values and this legacy subtree:

```json
"launcher": {
  "username": "Cole",
  "avatarIcon": "terminal",
  "pageTransition": "slide-scale",
  "transitionDuration": 280
}
```

Extend `scripts/validate_config.py` with `expect_spotlight_v3_migration()` asserting schema v4,
exact preservation of all unrelated state, absence of `modules.launcher`, and:

```python
assert migrated["modules"]["spotlight"] == {
    "pageTransition": "slide-scale",
    "transitionDuration": 280,
}
```

- [ ] **Step 2: Run the validator and observe RED**

Run: `python3 scripts/validate_config.py`

Expected: FAIL because settings v4 and the `modules.spotlight` contract do not exist.

- [ ] **Step 3: Implement the minimal v4 schema and migration**

Add the following default/schema shape and reject unknown Spotlight keys:

```json
"spotlight": {
  "pageTransition": "slide-fade",
  "transitionDuration": 220
}
```

In `ConfigMigrations.js`, accept versions 1–4, retain the existing v1→v2→v3 chain, then transform
v3 with a cloned object:

```javascript
const launcher = current.modules?.launcher || {};
current.modules.spotlight = {
    pageTransition: launcher.pageTransition || "slide-fade",
    transitionDuration: Number.isInteger(launcher.transitionDuration)
        ? launcher.transitionDuration : 220
};
delete current.modules.launcher;
current.$schema = "titonium.settings/v4";
current.schemaVersion = 4;
```

Update both validators and ConfigStore's loaded-schema log to v4.

- [ ] **Step 4: Replace the Settings page without changing transaction behavior**

Create `SpotlightPage.qml` by retaining only the transition dropdown and duration slider from the
current Launcher page. Bind them to `ConfigStore.previewState.modules.spotlight`. Change the
Settings page ID from `launcher` to `spotlight` in `SettingsWorkspace.qml`, its `qmldir`, both i18n
catalogs and `AppShell.settings.openPage()`'s allowlist. Delete `LauncherPage.qml` only after `rg`
shows no caller.

- [ ] **Step 5: Verify GREEN and commit**

Run:

```bash
python3 scripts/validate_config.py
./scripts/check.sh
rg -n 'LauncherPage|modules\.launcher|"launcher"' Titonium/Modules/Settings config/defaults config/schemas
```

Expected: migration and static checks pass; the final `rg` has no active Settings/schema ownership
for the retired Launcher subtree.

Commit:

```bash
git add config Titonium/Foundation Titonium/Modules/Settings Titonium/App/AppShell.qml scripts tests/fixtures
git commit -m "feat: migrate launcher preferences to spotlight"
```

---

### Task 2: Pure Spotlight layout, category, search and state contracts

**Files:**
- Create: `Titonium/Modules/Spotlight/SpotlightLayout.js`
- Create: `Titonium/Modules/Spotlight/CategoryCatalog.js`
- Create: `Titonium/Modules/Spotlight/SearchEngine.js`
- Create: `Titonium/Modules/Spotlight/Calculator.js`
- Create: `Titonium/Modules/Spotlight/SpotlightState.js`
- Create: `scripts/check_spotlight.js`
- Modify: `scripts/check.sh`

**Interfaces:**
- Produces: `SpotlightLayout.pageSize():20`, `pages(items,20)`, `fillRatio(page,20)`,
  `indicatorWidth(page,20)`; `CategoryCatalog.catalogFor(apps)`; `SearchEngine.search(apps,query)`;
  `Calculator.evaluate(expression)`; `SpotlightState.initial(mode)`, `withQuery(state,query)`,
  `escape(state)`.

- [ ] **Step 1: Write failing Node fixtures for fixed paging and categories**

Create `scripts/check_spotlight.js` using the same `vm.runInContext` harness as
`scripts/check_launcher_layout.js`. Assert:

```javascript
equal(layout.columnCount(), 5);
equal(layout.rowCount(), 4);
equal(layout.pageSize(), 20);
deepEqual(layout.pages(ids(21), 20).map(page => page.length), [20, 1]);
equal(layout.indicatorWidth(ids(20), 20), 40);
equal(layout.indicatorWidth(ids(5), 20), 16);

deepEqual(categories.idsFor(["Development", "Utility"]), ["development", "utilities"]);
deepEqual(categories.idsFor(["Network"]), ["internet"]);
deepEqual(categories.idsFor(["AudioVideo"]), ["multimedia"]);
deepEqual(categories.idsFor(["Unrecognized"]), ["other"]);
```

Also assert empty categories are absent, output order is `all, development, games, graphics,
internet, multimedia, office, system, utilities, other`, multi-category apps appear in every
matching group, and names are alphabetic inside each group.

- [ ] **Step 2: Write failing search, calculator and state fixtures**

Add fixtures proving:

```javascript
deepEqual(search.search(apps, "fire").map(item => item.id), ["firefox.desktop"]);
equal(search.search(apps, "term")[0].type, "application");
equal(calculator.evaluate("2 + 3 * 4").value, "14");
equal(calculator.evaluate("sqrt(81) + 1").value, "10");
equal(calculator.evaluate("process.exit()").matched, false);
equal(state.withQuery({ mode: "browse", categoryId: "games" }, "fire").mode, "results");
equal(state.escape({ mode: "results", query: "fire", categoryId: "games" }).mode, "browse");
equal(state.escape({ mode: "browse", query: "", categoryId: "games" }).closeRequested, true);
```

Require search results to use the normalized record shape:

```javascript
{ id, type, title, subtitle, icon, score, executionId }
```

- [ ] **Step 3: Run the fixtures and observe RED**

Run: `node scripts/check_spotlight.js`

Expected: FAIL because the five domain files do not exist.

- [ ] **Step 4: Implement minimal pure functions**

Implement fixed paging and freedesktop category alias tables exactly as asserted. Rank app name
prefix above name substring, then subtitle/searchText substring, breaking ties alphabetically.

Implement `Calculator.js` as a tokenizer plus recursive-descent parser for numbers, `pi`, unary
plus/minus, parentheses, `+ - * / % ^`, `sqrt()`, `sin()` and `cos()`. Do not use `eval`,
`Function`, `new Function` or shell execution. Return `{matched:false}` for invalid syntax,
non-finite output or an expression with no numeric/operator signal.

- [ ] **Step 5: Add fixtures to the static gate and verify GREEN**

Add `node "$project_root/scripts/check_spotlight.js"` to `scripts/check.sh`, then run:

```bash
node scripts/check_spotlight.js
./scripts/check.sh
```

Expected: all Spotlight fixtures and existing checks pass.

Commit:

```bash
git add Titonium/Modules/Spotlight scripts/check_spotlight.js scripts/check.sh
git commit -m "feat: define spotlight domain contracts"
```

---

### Task 3: Spotlight surface, categorized grid and keyboard search

**Files:**
- Create: `Titonium/Modules/Spotlight/SpotlightModel.qml`
- Create: `Titonium/Modules/Spotlight/SpotlightSurface.qml`
- Create: `Titonium/Modules/Spotlight/AppGrid.qml`
- Create: `Titonium/Modules/Spotlight/ApplicationTile.qml`
- Create: `Titonium/Modules/Spotlight/SearchResults.qml`
- Create: `Titonium/Modules/Spotlight/PageIndicator.qml`
- Create: `Titonium/Modules/Spotlight/qmldir`
- Create: `Titonium/Platform/Clipboard/ClipboardAdapter.qml`
- Create: `Titonium/Platform/Clipboard/qmldir`
- Modify: `Titonium/App/AppShell.qml`
- Modify: `Titonium/Platform/Applications/ApplicationCatalog.qml`
- Modify: `scripts/check_architecture.py`
- Create: `scripts/spotlight_acceptance.sh`
- Modify: `config/i18n/en.json`
- Modify: `config/i18n/vi.json`

**Interfaces:**
- Consumes: `ApplicationCatalog.applications`, `ApplicationCatalog.launch(entryId)`, Task 2 pure
  functions and `ConfigStore.previewState.modules.spotlight`.
- Produces: IPC `spotlight.toggle()`, `spotlight.close()`, `spotlight.state()`,
  `spotlight.setQuery(query)`; descriptor mode `"applications"`; minimal
  `ClipboardAdapter.copy(text):bool` for calculator results.

- [ ] **Step 1: Add failing architecture and IPC acceptance checks**

Require `Titonium/Modules/Spotlight/qmldir`, every focused QML file above, lazy `Loader` branches
for `browse` and `results`, and absence of `Process`, `FileView`, raw commands, timers, shaders and
infinite animation in the Spotlight module. Require accessible names/focusability on the search
field, category chips, application tiles and result rows.

Create `scripts/spotlight_acceptance.sh` using the ready-loop/cleanup pattern in
`scripts/settings_acceptance.sh`. Before UI exists, assert these calls:

```bash
qs -p "$project_root" ipc call spotlight toggle
qs -p "$project_root" ipc call spotlight state
qs -p "$project_root" ipc call spotlight setQuery fire
qs -p "$project_root" ipc call spotlight state
qs -p "$project_root" ipc call spotlight close
```

Expected states are `open:applications:<screen>`, then a state string containing
`mode=results;query=fire;selected=0`, then `closed`. Automated acceptance must not launch an
external desktop application.

- [ ] **Step 2: Run checks and observe RED**

Run:

```bash
python3 scripts/check_architecture.py
./scripts/spotlight_acceptance.sh
```

Expected: architecture reports missing Spotlight files and IPC reports an unknown target.

- [ ] **Step 3: Extend application records without moving execution into UI**

Keep `ApplicationCatalog.launch(entryId)` unchanged. Extend cached records with normalized raw
desktop-entry categories and search fields only:

```javascript
{
  id, name, nameLower, subtitle, searchText, icon,
  categories: Array.isArray(entry.categories) ? entry.categories : []
}
```

No entry object or executable command crosses the Platform boundary.

- [ ] **Step 4: Implement `SpotlightModel.qml`**

Model properties are `mode`, `query`, `categoryId`, `pageIndex`, `selectedIndex`, `categories`,
`visibleApps`, `pages` and `results`. Normal open resets to Browse/All/page 0; query transition
uses `SpotlightState.withQuery`; search always passes the full catalog to `SearchEngine.search`.
Append a normalized calculator result before matching applications when `Calculator.evaluate`
returns `matched:true`.

Expose `activateSelected(): bool`; calculator activation calls only `ClipboardAdapter.copy(value)`
and app activation calls only `ApplicationCatalog.launch(executionId)`.

Create the minimal Platform Clipboard boundary in this task: `copy(text)` rejects empty strings
and assigns `Quickshell.clipboardText = text`. Event observation and history persistence are added
in Task 4; no process or timer is introduced here.

- [ ] **Step 5: Build stable Spotlight composition**

`SpotlightSurface.qml` fills the overlay for outside-click capture and centers one
`Controls.Panel` with:

```qml
width: Math.min(800, root.width - Metrics.spacingLarge * 4)
height: Math.min(620, root.height - Metrics.spacingLarge * 4)
anchors.centerIn: parent
```

The search field remains mounted in both modes. Category chips are visible only in Browse and
use `CategoryCatalog` order. The body Loader selects `AppGrid.qml` or `SearchResults.qml`.
Application tiles use one-line width elision. `AppGrid` is fixed 5×4 and resets page index only
when category changes or a normal open occurs.

Vertical wheel delta advances horizontal pages by exactly one. `PageIndicator` width comes from
`SpotlightLayout.indicatorWidth`; active state changes semantic color only.

- [ ] **Step 6: Implement keyboard and close state**

Keep the search field focused on open. Up/Down wrap result selection. Enter activates index 0
when no explicit movement occurred. Escape calls `SpotlightState.escape`: first clear query and
return to the retained category/page, then close on the next Escape. Successful app activation
closes; failed activation leaves the surface open and logs through `ApplicationCatalog`.

Add `AppShell` IPC target `spotlight`. Resolve the target screen with
`ScreenRouter.screenForName(HyprlandAdapter.focusedMonitorName)` and fall back through the
existing router; add the explicit `qs.Titonium.Platform.Hyprland` import to AppShell. Open owner
`spotlight:<screen>` with exclusive focus, monitor-change close and `SpotlightSurface.qml` source.

- [ ] **Step 7: Verify static/runtime GREEN and commit**

Run:

```bash
./scripts/check.sh
./scripts/smoke.sh
./scripts/spotlight_acceptance.sh
```

Expected: all pass; logs contain `Configuration Loaded` and no `ERROR`, `TypeError`, duplicate ID
or missing method.

Commit:

```bash
git add Titonium/Modules/Spotlight Titonium/Platform/Applications Titonium/Platform/Clipboard Titonium/App/AppShell.qml scripts config/i18n
git commit -m "feat: add categorized spotlight application launcher"
```

---

### Task 4: Event-driven Clipboard mode and atomic history

**Files:**
- Modify: `Titonium/Platform/Clipboard/ClipboardAdapter.qml`
- Create: `Titonium/Foundation/ClipboardHistoryStore.qml`
- Create: `Titonium/Foundation/ClipboardHistory.js`
- Modify: `Titonium/Foundation/qmldir`
- Create: `Titonium/Modules/Spotlight/ClipboardView.qml`
- Modify: `Titonium/Modules/Spotlight/SpotlightModel.qml`
- Modify: `Titonium/Modules/Spotlight/SpotlightSurface.qml`
- Modify: `Titonium/Modules/Spotlight/qmldir`
- Modify: `Titonium/App/AppShell.qml`
- Modify: `scripts/check_architecture.py`
- Modify: `scripts/spotlight_acceptance.sh`
- Create: `scripts/check_clipboard_history.js`
- Modify: `scripts/check.sh`
- Create: `tests/fixtures/clipboard-history.valid.json`
- Create: `tests/fixtures/clipboard-history.invalid.json`
- Modify: `config/i18n/en.json`
- Modify: `config/i18n/vi.json`

**Interfaces:**
- Extends: Task 3 `ClipboardAdapter.copy(text):bool` with `textObserved(string)`;
  `ClipboardHistoryStore.items`, `record(text)`, `remove(id)`, `clear()`, `copy(id):bool`; IPC
  `spotlight.clipboard()`.

- [ ] **Step 1: Add failing event/persistence boundary checks**

Extend architecture checks to require `ClipboardAdapter` to use `Quickshell.clipboardText` and
`clipboardTextChanged`, forbid `Timer`, `Process`, `wl-paste` and `wl-copy`, and require
`ClipboardHistoryStore` to use `Quickshell.dataPath("clipboard-history.json")`, `FileView`,
`atomicWrites: true` and `setText()`.

Extend `spotlight_acceptance.sh` to back up and restore the runtime history file and assert:

```bash
qs -p "$project_root" ipc call spotlight clipboard
qs -p "$project_root" ipc call spotlight state
```

returns `open:clipboard:<screen>` and `mode=clipboard` without changing repository files.

Create `scripts/check_clipboard_history.js` and load both JSON fixtures plus
`Foundation/ClipboardHistory.js`. Assert malformed documents normalize to `[]`, valid documents
retain only well-typed records, exact duplicate text moves to index 0, and inserting record 61
drops the oldest record. Assert URL/color/code/plain classification and the exact 80-character
single-line preview boundary.

- [ ] **Step 2: Run checks and observe RED**

Run:

```bash
python3 scripts/check_architecture.py
node scripts/check_clipboard_history.js
./scripts/spotlight_acceptance.sh
```

Expected: FAIL for missing history logic/store/view and Clipboard IPC.

- [ ] **Step 3: Implement event-driven Clipboard adapter**

Extend `ClipboardAdapter.qml` to forward non-empty `Quickshell.clipboardText` changes through
`textObserved`, including one non-empty initial value on component completion. Preserve Task 3's
`copy(text)` assignment boundary; it launches no process.

- [ ] **Step 4: Implement bounded atomic history**

Store at most 60 unique items with fields:

```javascript
{ id, text, preview, kind, colorHex, timestamp, lines, words, chars }
```

Deduplicate exact text by moving the existing value to the front. Classify URL, color, code and
plain text with pure string/regex checks. Parse malformed runtime JSON as an empty history and log
one warning. Serialize with `JSON.stringify({schemaVersion:1,items})` using `setText()` on an
atomic `FileView`. Put classification, normalization, dedupe and the 60-record cap in
`ClipboardHistory.js`; `ClipboardHistoryStore.qml` owns only lifecycle/persistence and subscribes
to the adapter event. UI does not.

- [ ] **Step 5: Build lazy Clipboard list and preview**

`ClipboardView.qml` filters history locally by the mode query, renders a selectable list and a
preview pane, and exposes copy/delete/clear intents to `ClipboardHistoryStore`. Enter copies the
selected record and closes Spotlight. Empty/unavailable history shows a localized state. The view
exists only while descriptor/model mode is `clipboard`.

- [ ] **Step 6: Verify GREEN and commit**

Run:

```bash
./scripts/check.sh
node scripts/check_clipboard_history.js
./scripts/smoke.sh
./scripts/spotlight_acceptance.sh
```

Expected: all pass; runtime history is restored after acceptance, repository status is unchanged,
and no polling/process warning appears.

Commit:

```bash
git add Titonium/Platform/Clipboard Titonium/Foundation Titonium/Modules/Spotlight Titonium/App/AppShell.qml scripts tests/fixtures config/i18n
git commit -m "feat: add event-driven spotlight clipboard mode"
```

---

### Task 5: Compact macOS-style Arch Menu and universal confirmation

**Files:**
- Create: `Titonium/Modules/MenuBar/ArchMenu/ArchMenuWidget.qml`
- Create: `Titonium/Modules/MenuBar/ArchMenu/ArchMenu.qml`
- Create: `Titonium/Modules/MenuBar/ArchMenu/ArchMenuModel.js`
- Create: `Titonium/Modules/MenuBar/ArchMenu/ArchMenuItem.qml`
- Create: `Titonium/Modules/MenuBar/ArchMenu/SessionConfirmation.qml`
- Create: `Titonium/Modules/MenuBar/ArchMenu/AboutTitonium.qml`
- Create: `Titonium/Modules/MenuBar/ArchMenu/qmldir`
- Create: `Titonium/Foundation/AppMetadata.qml`
- Modify: `Titonium/Foundation/qmldir`
- Modify: `Titonium/Composition/WidgetRegistry.qml`
- Modify: `Titonium/App/AppShell.qml`
- Modify: `Titonium/Platform/System/SessionActions.qml`
- Modify: `scripts/check_architecture.py`
- Create: `scripts/check_arch_menu.js`
- Modify: `scripts/check.sh`
- Modify: `config/i18n/en.json`
- Modify: `config/i18n/vi.json`

**Interfaces:**
- Produces: MenuBar widget remains registered as `menubar.launcher`; IPC target becomes
  `arch-menu.toggle(screenName)`, `close()`, `state()`; `SessionActions.supportedActions` adds
  `lock`; `SessionActions` emits `actionStarted(action)` and `actionFailed(action,error)`;
  confirmation receives `actionId`, emits `cancelled()` or `confirmed(actionId)`.

- [ ] **Step 1: Write failing menu contract and architecture tests**

Create `scripts/check_arch_menu.js` loading `ArchMenuModel.js` and assert the functional initial
menu groups exactly:

```javascript
[
  ["about"],
  ["settings"],
  ["lock", "sleep", "hibernate"],
  ["restart", "shutdown"],
  ["logout"]
]
```

System Information and Task Manager must be absent until their future modules exist. Assert every
session item has `requiresConfirmation:true`, a label key and icon.

Extend architecture checks to require icon+text menu items and separators, reject grid/rail/search
code in `MenuBar/ArchMenu`, and require every action path to pass through
`SessionActions.executeConfirmed` only after `pendingAction` is set. Require accessible names,
button/menu roles and keyboard focus on every menu item and confirmation control.

- [ ] **Step 2: Run checks and observe RED**

Run:

```bash
node scripts/check_arch_menu.js
python3 scripts/check_architecture.py
```

Expected: FAIL because the compact module and model do not exist.

- [ ] **Step 3: Add direct lock support at the Platform boundary**

Add `lock` to `supportedActions`. Map it to direct process command `["hyprlock"]`; do not use a
shell fallback. Preserve direct `systemctl` argument arrays for sleep/hibernate/restart/shutdown
and Hyprland dispatch for logout. Rejected concurrent/unknown actions return false and set a
localized-safe `lastError` token or message. Emit `actionStarted(action)` from the Process started
signal (and immediately after accepted logout dispatch); emit `actionFailed(action,error)` when a
process cannot start or exits unsuccessfully before start.

- [ ] **Step 4: Implement compact anchored menu**

`ArchMenuWidget.qml` retains the packaged Arch SVG and opens an owner `arch-menu:<screen>`.
`ArchMenu.qml` uses the full overlay only for outside-click capture and renders a compact panel
below the Arch trigger at the left MenuBar edge. It delegates grouped rows from `ArchMenuModel.js`;
`ArchMenuItem.qml` shows a small leading icon and one text label. Group boundaries render one
semantic 1px separator. Escape/outside click closes.

Selecting Settings closes/replaces the menu, calls `ConfigStore.beginPreview()` and opens
`SettingsCenter.qml` with `cancelPreviewOnClose:true`. Selecting About replaces it with
`AboutTitonium.qml`. Add singleton `AppMetadata` with name `Titonium` and version `0.1.0-dev` so the
About surface does not duplicate build identity; it also shows Neutral Utility theme identity and
Quickshell/Hyprland session labels without runtime polling.

- [ ] **Step 5: Implement macOS-inspired confirmation**

Selecting any of Lock/Sleep/Hibernate/Restart/Shutdown/Logout sets `pendingAction`; no adapter is
called yet. Replace the menu panel with a focused confirmation sheet containing title,
consequence, Cancel and an action-specific confirm button. Cancel receives initial keyboard focus.
Enter on Cancel is safe; only explicit activation of the action button calls
`SessionActions.executeConfirmed(actionId)`. Keep the sheet visible and disabled while launch is
pending. `actionStarted` closes the transient; `actionFailed` re-enables the sheet and displays
the error. No timeout or countdown exists.

- [ ] **Step 6: Wire registry/IPC and verify GREEN**

Point `WidgetRegistry.sources["menubar.launcher"]` at `ArchMenuWidget.qml`. Replace the old
`launcher` IPC target with `arch-menu`; retain no `section()` method. Add the Node check to
`scripts/check.sh`.

Run:

```bash
./scripts/check.sh
./scripts/smoke.sh
```

Expected: static and foreground runtime checks pass. Do not confirm a real session action during
automated acceptance.

Commit:

```bash
git add Titonium/Modules/MenuBar/ArchMenu Titonium/Composition/WidgetRegistry.qml Titonium/App/AppShell.qml Titonium/Platform/System scripts config/i18n
git commit -m "feat: replace launcher trigger with compact arch menu"
```

---

### Task 6: Remove the superseded Launcher and restore standalone Settings ownership

**Files:**
- Delete: `Titonium/Modules/MenuBar/Launcher/ArchMenu.qml`
- Delete: `Titonium/Modules/MenuBar/Launcher/LauncherRail.qml`
- Delete: `Titonium/Modules/MenuBar/Launcher/LauncherSectionRegistry.qml`
- Delete: `Titonium/Modules/MenuBar/Launcher/LauncherSettingsPage.qml`
- Delete: `Titonium/Modules/MenuBar/Launcher/PowerPage.qml`
- Delete: `Titonium/Modules/MenuBar/Launcher/AppsPage.qml`
- Delete: `Titonium/Modules/MenuBar/Launcher/ApplicationCatalogModel.qml`
- Delete: `Titonium/Modules/MenuBar/Launcher/ApplicationTile.qml`
- Delete: `Titonium/Modules/MenuBar/Launcher/PageIndicator.qml`
- Delete: `Titonium/Modules/MenuBar/Launcher/LauncherLayout.js`
- Delete: `Titonium/Modules/MenuBar/Launcher/LauncherWidget.qml`
- Delete: `Titonium/Modules/MenuBar/Launcher/qmldir`
- Delete: `scripts/check_launcher_layout.js`
- Modify: `scripts/check_architecture.py`
- Modify: `scripts/check.sh`
- Modify: `scripts/settings_acceptance.sh`
- Modify: `docs/ARCHITECTURE.md`
- Modify: `docs/MODULE_CONTRACT.md`

**Interfaces:**
- Consumes: new Spotlight and Arch Menu modules from Tasks 3–5.
- Produces: exactly one Settings host (`SettingsCenter` + reusable `SettingsWorkspace`) and no
  runtime import/reference to the superseded Launcher module.

- [ ] **Step 1: Add failing closure assertions before deleting files**

Change architecture checks to fail when `Titonium/Modules/MenuBar/Launcher` exists, when
`LauncherSettingsPage`, `LauncherSectionRegistry`, `cancelPreviewOnClose` on an Arch Menu
descriptor, or IPC target `launcher` remains. Require `SettingsCenter.qml` to instantiate
`SettingsWorkspace` and require Arch Menu Settings activation to open `SettingsCenter.qml`.

Extend `settings_acceptance.sh` to open Settings through its existing IPC after Arch Menu has
been opened/closed, then repeat Preview/Cancel and Apply checks. Remove the obsolete embedded
Launcher Settings acceptance path.

- [ ] **Step 2: Run closure checks and observe RED**

Run: `python3 scripts/check_architecture.py`

Expected: FAIL listing the still-present old Launcher directory/references.

- [ ] **Step 3: Delete only superseded files and references**

Remove the listed directory files with `apply_patch` after confirming `WidgetRegistry`, AppShell,
Spotlight and Arch Menu no longer import them. Remove `scripts/check_launcher_layout.js` only after
`check_spotlight.js` covers paging/indicator behavior. Do not delete `SettingsWorkspace.qml` or
alter Preview/Apply/Cancel semantics.

- [ ] **Step 4: Update architecture documentation and verify GREEN**

Document separate Spotlight, Arch Menu and standalone Settings flows. Run:

```bash
rg -n 'Modules/MenuBar/Launcher|LauncherSettingsPage|LauncherSectionRegistry|target: "launcher"' Titonium scripts config
./scripts/check.sh
./scripts/settings_acceptance.sh
./scripts/smoke.sh
git diff --check
```

Expected: `rg` returns no active runtime reference; every gate passes and Settings writes only to
runtime data outside Git.

Commit:

```bash
git add Titonium scripts docs
git commit -m "refactor: retire the superseded launcher surface"
```

---

### Task 7: Hyprland binding cutover, live acceptance and roadmap closure

**Files:**
- Modify narrowly: `/home/cole/.config/hypr/hyprland.lua`
- Modify narrowly: `/home/cole/Projects/titonium-hyprland/config/hypr/hyprland.lua`
- Modify: `docs/ROADMAP.md`
- Modify: `docs/TESTING.md`
- Modify: `docs/OPERATIONS.md`
- Modify: `AGENTS.md`

**Interfaces:**
- Consumes: accepted IPC `spotlight.toggle`, `spotlight.clipboard`, `arch-menu.toggle`.
- Produces: live shortcuts `Super + Space` and `Super + V`; no `Super + R` Spotlight binding.

- [ ] **Step 1: Record the exact external-config baseline**

Run:

```bash
git -C /home/cole/Projects/titonium-hyprland status --short
sha256sum /home/cole/.config/hypr/hyprland.lua
sha256sum /home/cole/Projects/titonium-hyprland/config/hypr/hyprland.lua
sed -n '340,355p' /home/cole/.config/hypr/hyprland.lua
sed -n '340,355p' /home/cole/Projects/titonium-hyprland/config/hypr/hyprland.lua
```

Expected: capture the pre-existing dirty dotfiles state and exact three legacy Spotlight lines.
Do not stage or rewrite unrelated dotfiles hunks.

- [ ] **Step 2: Run pre-cutover acceptance**

Run:

```bash
./scripts/check.sh
./scripts/smoke.sh
./scripts/spotlight_acceptance.sh
./scripts/settings_acceptance.sh
```

Expected: all pass before any live binding is enabled.

- [ ] **Step 3: Patch only approved bindings in both Lua files**

Use `apply_patch` on the exact binding block so it contains:

```lua
hl.bind(mainMod .. " + V", hl.dsp.exec_cmd("qs -p /home/cole/Projects/titonium ipc call spotlight clipboard"))
hl.bind(mainMod .. " + space", hl.dsp.exec_cmd("qs -p /home/cole/Projects/titonium ipc call spotlight toggle"))
```

Delete only the `mainMod .. " + R"` Spotlight binding. Do not change Hyprglass declarations,
theme Lua, autostart, switcher submaps or any other binding.

- [ ] **Step 4: Reload and verify Hyprland**

Run:

```bash
hyprctl reload
hyprctl configerrors
rg -n 'spotlight (clipboard|toggle)' /home/cole/.config/hypr/hyprland.lua /home/cole/Projects/titonium-hyprland/config/hypr/hyprland.lua
```

Expected: `configerrors` is empty; each file has exactly the V and Space bindings and no R binding.

- [ ] **Step 5: Perform live visual/interaction acceptance**

Restart the shell with:

```bash
qs kill -p /home/cole/Projects/titonium
qs -d -p /home/cole/Projects/titonium
```

On DP-3 scale 1.0 and DP-1 scale 1.5 verify:

1. `Super + Space` opens an 800×620-centered stable panel on the focused monitor.
2. All/category browsing is 5×4; wheel paging and occupancy indicators are correct.
3. Typing transitions to a list without resize; Enter launches the first result.
4. Escape clears query before closing; reduced motion removes transition duration.
5. `Super + V` opens Clipboard list/preview and copy closes the surface.
6. Arch click opens the compact text/icon/separator menu under the MenuBar trigger.
7. Settings opens independently and Preview/Apply/Cancel remain correct.
8. Every session action opens confirmation; test Cancel only, never confirm a real destructive
   action during this acceptance pass.
9. Outside click closes each surface and only one transient exists per screen.

- [ ] **Step 6: Inspect runtime cost and logs**

With all transients closed, inspect the Titonium log and process for 30 seconds. Verify no repeated
clipboard/application polling messages, no `ERROR`/`TypeError`, stable RSS and no continuous UI
animation. Open/close Spotlight ten times and verify the heavy Loader tree is released rather than
growing RSS monotonically.

- [ ] **Step 7: Close roadmap/docs and commit repository-owned changes**

Mark Spotlight Launcher and compact Arch Menu complete in `docs/ROADMAP.md`; document both
shortcuts, rollback command and the separation of Arch Menu/Spotlight/Settings. Update `AGENTS.md`
current milestone. Run final gates:

```bash
./scripts/check.sh
./scripts/smoke.sh
./scripts/spotlight_acceptance.sh
./scripts/settings_acceptance.sh
hyprctl configerrors
git diff --check
git status --short
```

Commit Titonium documentation only:

```bash
git add AGENTS.md README.md docs
git commit -m "docs: close spotlight launcher migration"
```

Preserve the existing dirty state in `titonium-hyprland`; report the two binding-only hunks
separately instead of staging unrelated user changes.

## Rollback

Before Task 7, rollback is simply the previous Titonium commit and the still-disabled legacy
bindings. After cutover, restore the two recorded Lua binding blocks, run `hyprctl reload`, then
start the last known-good shell commit with:

```bash
qs kill -p /home/cole/Projects/titonium
git -C /home/cole/Projects/titonium switch --detach 8fdb106
qs -d -p /home/cole/Projects/titonium
```

Do not use `git reset --hard` or overwrite either Hyprland config wholesale.
