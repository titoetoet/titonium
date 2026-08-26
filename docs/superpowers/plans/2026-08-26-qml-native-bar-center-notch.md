# Titonium QML-Native Bar and Center Notch Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the minimal two-sided Bar with independently positioned Start, Center and End islands, then add an Ambxst-informed top-attached Center Notch containing safe Overview, Tools and Session mock pages.

**Architecture:** `BarHost` continues to create one screen-local composition with `Variants(Quickshell.screens)`. A compact Center trigger stays in the 40-pixel Bar; opening it activates a dedicated transparent overlay window for that screen, while `CenterNotchCoordinator` owns only cross-screen ownership and requested page. The expanded surface uses a 48-pixel rail and `StackView` so the incoming page loads before entering and the replaced page is destroyed after exiting.

**Tech Stack:** Quickshell 0.3.1, QML/QtQuick, QtQuick.Controls `StackView`, Quickshell `PanelWindow`/`Region`, Hyprland layer-shell focus, repository-local JavaScript domain helpers, Node fixture tests, Python architecture gates and Bash foreground IPC acceptance.

**Spec:** `docs/superpowers/specs/2026-08-26-qml-native-bar-center-notch-design.md`

## Global Constraints

- Work directly in `/home/cole/Projects/titonium`; do not create a second shell or compatibility tree.
- Preserve Spotlight Applications/Clipboard/System, Input Method and the current `Super + Space` / `Super + V` bindings.
- Keep one 40 logical pixel Bar with exclusive zone 40 for every reactive `Quickshell.screens` entry.
- Runtime implementation is QML, QtQuick and repository-local JavaScript only.
- Do not add Go, Python runtime code, shell helpers, external daemons or copied scripts.
- UI must not own `Process`, `FileView`, `execDetached`, raw commands or persistence.
- Do not use blur, shader, `MultiEffect`, infinite animation or an idle polling timer.
- Reimplement the inspected Ambxst layout behavior; do not copy its AGPL source, imports, theme or state graph.
- Tools, Session and Settings actions remain side-effect-free mocks in this plan.
- Do not create Audio, Bluetooth, Network, Settings or tool service stubs.
- Do not edit either Hyprland configuration file.
- Never launch an application, mutate clipboard contents or execute a session action in automated tests.
- Use `apply_patch` for source edits and preserve unrelated user changes.

## Target file map

```text
Titonium/App.qml                                      # Spotlight/notch mutual exclusion and IPC acceptance seam
Titonium/Bar/BarHost.qml                              # Per-screen Bar + notch overlay composition
Titonium/Bar/BarSurface.qml                           # 40px reserve and composed island input mask
Titonium/Bar/Bar.qml                                  # Three-island placement only
Titonium/Bar/islands/qmldir
Titonium/Bar/islands/StartIsland.qml                  # Workspaces container
Titonium/Bar/islands/CenterIsland.qml                 # Compact notch trigger
Titonium/Bar/islands/EndIsland.qml                    # Connectivity and status pill composition
Titonium/Bar/islands/ConnectivityPill.qml             # Non-fake diagnostic Network/BT/Audio icons
Titonium/Bar/islands/StatusPill.qml                   # Protected Input Method + Clock
Titonium/Bar/notch/qmldir
Titonium/Bar/notch/BarLayout.js                       # Pure center/collision geometry
Titonium/Bar/notch/CenterNotchState.js                # Page normalization/navigation/transition rules
Titonium/Bar/notch/CenterActionCatalog.js             # Immutable Tools/Session mock descriptors
Titonium/Bar/notch/CenterNotchCoordinator.qml         # One open notch across screens
Titonium/Bar/notch/CenterNotchWindow.qml              # Screen-local transparent overlay window
Titonium/Bar/notch/CenterNotchSurface.qml             # Outside click, focus and top-centered expanded shell
Titonium/Bar/notch/CenterNotch.qml                    # Solid notch silhouette, rail, viewport and feedback
Titonium/Bar/notch/CenterNotchRail.qml                # 48px rail and moving highlight
Titonium/Bar/notch/CenterNotchViewport.qml            # StackView replacement and latest-request queue
Titonium/Bar/notch/CenterActionButton.qml             # Accessible mock action tile
Titonium/Bar/notch/OverviewPage.qml
Titonium/Bar/notch/ToolsPage.qml
Titonium/Bar/notch/SessionPage.qml
config/i18n/{en,vi}.json                              # Center Notch labels and feedback
docs/research/2026-08-26-bar-center-notch-sources.md  # Upstream provenance and deviations
scripts/check_bar.py                                  # Static ownership/forbidden dependency gate
scripts/check_bar_layout.js                           # Pure island geometry fixtures
scripts/check_center_notch.js                         # Pure navigation/transition fixtures
scripts/check_center_actions.js                       # Catalog schema/side-effect fixtures
scripts/center_notch_acceptance.sh                    # Foreground IPC and protected interaction gate
scripts/check.sh                                      # Registers new static/domain tests
docs/{ARCHITECTURE,ROADMAP,TESTING}.md                 # Current behavior and handoff
```

`CenterNotchWindow` is a transparent full-screen input surface only while its screen owns the
notch. Its visual child occupies the top-centered notch rectangle; the remaining transparent area
exists solely to close on outside click. The heavy notch tree is behind `Loader.active` and does not
exist while closed.

---

### Task 1: Lock upstream provenance and pure domain contracts

**Files:**
- Create: `docs/research/2026-08-26-bar-center-notch-sources.md`
- Create: `Titonium/Bar/notch/BarLayout.js`
- Create: `Titonium/Bar/notch/CenterNotchState.js`
- Create: `Titonium/Bar/notch/CenterActionCatalog.js`
- Create: `scripts/check_bar_layout.js`
- Create: `scripts/check_center_notch.js`
- Create: `scripts/check_center_actions.js`
- Modify: `scripts/check.sh`

**Interfaces:**
- Produces: `BarLayout.centerX(containerWidth, itemWidth): int`;
  `BarLayout.optionalVisibility(containerWidth, startWidth, centerWidth, endWidth, gap): object`;
  `CenterNotchState.normalizePage(pageId): string`;
  `CenterNotchState.arrowPage(pageId, delta): string`;
  `CenterNotchState.wheelPage(pageId, delta): string`;
  `CenterNotchState.transitionPlan(previousPage, nextPage, reducedMotion, duration): object`;
  `CenterActionCatalog.tools(): array`; `CenterActionCatalog.session(): array`.
- Consumes: approved spec and inspected Ambxst revision `65b7940`.

- [ ] **Step 1: Write the three failing Node fixture scripts**

Use the existing `vm` loading pattern from `scripts/check_spotlight.js`. The geometry assertions in
`check_bar_layout.js` must include:

```javascript
assert.equal(layout.centerX(1920, 180), 870);
assert.equal(layout.centerX(1280, 180), 550);
assert.equal(layout.centerX(1920, 180), layout.centerX(1920, 180, 600, 300),
    "outer island widths cannot influence true center");
assert.deepEqual(plain(layout.optionalVisibility(700, 260, 180, 260, 8)), {
    showActiveWindow: false,
    showConnectivityDiagnostics: false,
});
```

The state assertions in `check_center_notch.js` must cover:

```javascript
assert.equal(state.normalizePage("unknown"), "overview");
assert.equal(state.arrowPage("overview", -1), "session");
assert.equal(state.arrowPage("session", 1), "overview");
assert.equal(state.wheelPage("overview", -1), "overview");
assert.equal(state.wheelPage("session", 1), "session");
assert.equal(state.transitionPlan("overview", "tools", true, 160).duration, 0);
assert.equal(state.transitionPlan("overview", "session", false, 900).duration, 220);
assert.equal(state.transitionPlan("session", "tools", false, 160).offset, -12);
```

The catalog assertions in `check_center_actions.js` must require the exact IDs below, unique IDs,
namespaced label keys, `available === false`, boolean `dangerous` and string intents. It must also
assert that no descriptor contains `command`, `callback`, `process`, `script` or `executable`.

```text
Tools: screenshot, screen-recording, color-picker, ocr, qr-scan, camera-mirror, night-mode, more-tools
Session: lock, logout, sleep, hibernate, restart, shutdown
```

- [ ] **Step 2: Run the fixtures and verify RED**

Run:

```bash
node scripts/check_bar_layout.js
node scripts/check_center_notch.js
node scripts/check_center_actions.js
```

Expected: all three fail because their domain files do not exist.

- [ ] **Step 3: Implement the minimum pure helpers**

`CenterNotchState.js` uses this exact page order and bounded transition shape:

```javascript
.pragma library

const pages = ["overview", "tools", "session"];

function normalizePage(pageId) {
    return pages.indexOf(pageId) >= 0 ? pageId : "overview";
}

function arrowPage(pageId, delta) {
    const current = pages.indexOf(normalizePage(pageId));
    return pages[(current + (delta < 0 ? -1 : 1) + pages.length) % pages.length];
}

function wheelPage(pageId, delta) {
    const current = pages.indexOf(normalizePage(pageId));
    return pages[Math.max(0, Math.min(pages.length - 1, current + (delta < 0 ? -1 : 1)))];
}

function transitionPlan(previousPage, nextPage, reducedMotion, configuredDuration) {
    const previous = pages.indexOf(normalizePage(previousPage));
    const next = pages.indexOf(normalizePage(nextPage));
    const duration = reducedMotion ? 0
        : Math.max(80, Math.min(220, Math.round(Number(configuredDuration) || 160)));
    return { duration, offset: next >= previous ? 12 : -12 };
}
```

`BarLayout.optionalVisibility()` first removes the future Active Window reservation, then the
Connectivity diagnostic pill, and never hides Center, Input Method or Clock. Catalog functions
return fresh arrays so a view cannot mutate shared descriptors.

- [ ] **Step 4: Record exact provenance**

Write `docs/research/2026-08-26-bar-center-notch-sources.md` with:

- Ambxst URL, AGPL-3.0, revision `65b7940` and the four inspected Notch/Dashboard paths;
- Caelestia URL, GPL-3.0 and the inspected `Wrapper.qml`, `ClipWrapper.qml`, `Content.qml` paths;
- DMS URL, MIT and its role as a later Settings/monitoring reference;
- the retained behavior: top attachment, 48px rail, separator, true center, size transition and
  lazy page destruction;
- the rejected code: masks, `MultiEffect`, global state, persistent heavy loaders and backend
  dependencies;
- the statement “No upstream source was copied into Titonium.”

- [ ] **Step 5: Register the fixtures and verify GREEN**

Add the three Node commands immediately after `python3 scripts/check_bar.py` in `scripts/check.sh`.

Run:

```bash
node scripts/check_bar_layout.js
node scripts/check_center_notch.js
node scripts/check_center_actions.js
./scripts/check.sh
```

Expected: all fixtures and the existing full static gate pass.

- [ ] **Step 6: Commit the domain boundary**

```bash
git add docs/research/2026-08-26-bar-center-notch-sources.md \
  Titonium/Bar/notch/BarLayout.js Titonium/Bar/notch/CenterNotchState.js \
  Titonium/Bar/notch/CenterActionCatalog.js scripts/check_bar_layout.js \
  scripts/check_center_notch.js scripts/check_center_actions.js scripts/check.sh
git commit -m "test: define bar and center notch contracts"
```

---

### Task 2: Build independently positioned Bar islands and compact notch trigger

**Files:**
- Create: `Titonium/Bar/islands/qmldir`
- Create: `Titonium/Bar/islands/StartIsland.qml`
- Create: `Titonium/Bar/islands/CenterIsland.qml`
- Create: `Titonium/Bar/islands/EndIsland.qml`
- Create: `Titonium/Bar/islands/ConnectivityPill.qml`
- Create: `Titonium/Bar/islands/StatusPill.qml`
- Create: `Titonium/Bar/notch/qmldir`
- Create: `Titonium/Bar/notch/CenterNotchCoordinator.qml`
- Modify: `Titonium/Bar/Bar.qml`
- Modify: `Titonium/Bar/BarSurface.qml`
- Modify: `scripts/check_bar.py`

**Interfaces:**
- Consumes: `BarLayout.centerX()` and `optionalVisibility()` from Task 1; existing Workspaces,
  Input Method, Clock, Shared controls and semantic tokens.
- Produces: `CenterNotchCoordinator.open(screenName, pageId): bool`, `toggle(screenName): bool`,
  `requestPage(pageId): bool`, `close(): bool`; compact Center trigger and Start/End island hitboxes.

- [ ] **Step 1: Extend the static Bar gate and verify RED**

Add every Task 2 QML/qmldir path to `scripts/check_bar.py`. Require:

```python
contracts = {
    "Bar.qml": ("StartIsland {", "CenterIsland {", "EndIsland {", "BarLayout.centerX"),
    "islands/CenterIsland.qml": ("CenterNotchCoordinator.toggle",),
    "islands/EndIsland.qml": ("ConnectivityPill {", "StatusPill {"),
    "islands/StatusPill.qml": ("InputMethod {", "Clock {"),
}
```

Retain the existing forbidden dependency scan and add `MultiEffect`, `ShaderEffect`, `execDetached`
and upstream import prefixes to its rejected tokens.

Run: `python3 scripts/check_bar.py`

Expected: FAIL with the missing island files.

- [ ] **Step 2: Add the Bar modules and coordinator**

Declare `qs.Titonium.Bar.Islands` and `qs.Titonium.Bar.Notch` in their qmldir files. Mark
`CenterNotchCoordinator` as a singleton. Its state is exactly:

```qml
property string ownerScreenName: ""
property string requestedPage: "overview"
readonly property bool active: ownerScreenName.length > 0
```

`open()` validates a nonempty screen name, normalizes the page, closes `SurfaceManager`, then sets
ownership. `toggle()` closes the same owner or opens Overview. `requestPage()` returns false while
closed. `close()` clears ownership and resets the requested page to Overview. It owns no Timer,
Loader, view reference or service state.

- [ ] **Step 3: Compose Start and End islands**

`StartIsland.qml` wraps the current Workspaces widget in one elevated solid surface. Do not add the
future Arch or Active Window widgets.

`ConnectivityPill.qml` renders three muted icons (`wifi`, `bluetooth`, `volume_up`) with accessible
names ending in “module planned”. They are not Buttons, do not imply live state and disappear when
`showDiagnostics` is false.

`StatusPill.qml` contains the protected Input Method and Clock. `EndIsland.qml` places
ConnectivityPill before StatusPill with `Metrics.barSpacing`.

- [ ] **Step 4: Replace the two Row layout with true-center positioning**

`Bar.qml` exposes aliases for `startIsland`, `centerIsland` and `endIsland` to aid live inspection.
Use direct coordinates:

```qml
StartIsland {
    id: startIsland
    x: Metrics.barPadding
    anchors.verticalCenter: parent.verticalCenter
    screen: root.screen
}

CenterIsland {
    id: centerIsland
    x: BarLayout.centerX(root.width, width)
    anchors.verticalCenter: parent.verticalCenter
    screen: root.screen
}

EndIsland {
    id: endIsland
    x: root.width - width - Metrics.barPadding
    anchors.verticalCenter: parent.verticalCenter
    screen: root.screen
}
```

Bind optional diagnostic visibility to `BarLayout.optionalVisibility(...)`; protected content is
never hidden. CenterIsland draws a compact solid 180×32 pill with a Titonium icon and label and
calls `CenterNotchCoordinator.toggle(screen.name)` on activation. When its screen owns the expanded
notch, the compact pill remains present but sets its content opacity to zero so the overlay can
visually replace it.

Remove the full-width Bar background. Give `Bar.qml` read-only aliases for the three island items,
then set `BarSurface.mask` to a composed `Region` containing one child Region for each alias:

```qml
mask: Region {
    Region { item: bar.startIsland }
    Region { item: bar.centerIsland }
    Region { item: bar.endIsland }
}
```

This makes transparent Bar space click-through without a shader or custom shape.

- [ ] **Step 5: Verify static and protected behavior**

Run:

```bash
python3 scripts/check_bar.py
./scripts/check.sh
./scripts/smoke.sh
./scripts/protected_acceptance.sh
```

Expected: all pass; smoke reports `Configuration Loaded`; Spotlight and Input Method behavior is
unchanged. Clicking the compact trigger changes coordinator state but no expanded window exists yet.

Pause for the user's visual approval of Start/Center/End balance and true centering. Do not begin
the expanded surface while the compact Bar geometry is rejected.

- [ ] **Step 6: Commit the island geometry**

```bash
git add Titonium/Bar/Bar.qml Titonium/Bar/BarSurface.qml Titonium/Bar/islands Titonium/Bar/notch/qmldir \
  Titonium/Bar/notch/CenterNotchCoordinator.qml scripts/check_bar.py
git commit -m "feat: add three-island bar geometry"
```

---

### Task 3: Add the screen-local expanded notch window and close lifecycle

**Files:**
- Create: `Titonium/Bar/notch/CenterNotchWindow.qml`
- Create: `Titonium/Bar/notch/CenterNotchSurface.qml`
- Create: `Titonium/Bar/notch/CenterNotch.qml`
- Modify: `Titonium/Bar/notch/qmldir`
- Modify: `Titonium/Bar/BarHost.qml`
- Modify: `Titonium/App.qml`
- Modify: `scripts/check_bar.py`

**Interfaces:**
- Consumes: `CenterNotchCoordinator`, `Quickshell.screens`, existing `SurfaceManager`,
  `ScreenRouter` and `HyprlandService`.
- Produces: one lazy expanded notch surface for the owning screen; IPC
  `centerNotch.open(page)`, `centerNotch.page(page)`, `centerNotch.close()` and
  `centerNotch.state()` for safe live acceptance.

- [ ] **Step 1: Add failing lifecycle assertions to the static gate**

Require `BarHost.qml` to contain one `CenterNotchWindow` beside `BarSurface`, and require the window
source to contain:

```text
PanelWindow {
Loader {
active: window.ownsNotch
WlrLayershell.exclusionMode: ExclusionMode.Ignore
WlrLayershell.keyboardFocus:
```

Require `CenterNotchSurface.qml` to call `CenterNotchCoordinator.close()` for Escape and outside
click. Run `python3 scripts/check_bar.py`; expect RED.

- [ ] **Step 2: Make each Variants delegate own both windows**

Change `BarHost` to:

```qml
Variants {
    model: Quickshell.screens
    Scope {
        required property var modelData
        BarSurface { screenModel: modelData }
        CenterNotchWindow { screenModel: modelData }
    }
}
```

`CenterNotchWindow` is a transparent overlay-layer `PanelWindow`, anchored on all four edges, with
`visible` and its Loader `active` only when
`CenterNotchCoordinator.ownerScreenName === screenModel.name`. It ignores exclusion zones and takes
exclusive keyboard focus only while it owns the notch.

- [ ] **Step 3: Implement outside-click and top attachment**

`CenterNotchSurface` fills the overlay. A background `TapHandler` maps its event into the notch
panel and closes only when the point is outside. `CenterNotch` is anchored with `topMargin: 0` and
horizontal center, nominal width 900 and height 430, clamped to 16 logical pixels of screen padding.
Its solid surface has zero top corner radii and 20-pixel lower radii; no layer effect is enabled.

Escape closes the coordinator. Focus is moved into `CenterNotch` on completion. A focused-monitor
change or destruction of the screen delegate closes an owned notch.

- [ ] **Step 4: Enforce mutual exclusion with Spotlight**

Before `App.openSpotlight()` calls `SurfaceManager.open()`, call `CenterNotchCoordinator.close()`.
`CenterNotchCoordinator.open()` already closes any existing `SurfaceManager` owner. Add an
`IpcHandler` target `centerNotch` in `App.qml`:

```qml
function open(page: string): string
function page(page: string): string
function close(): string
function state(): string
```

`open()` resolves the focused screen through `ScreenRouter`; `page()` rejects a closed notch;
`state()` returns `closed` or
`open:<screenName>;page=<normalizedPage>`. These methods never activate mock actions.

- [ ] **Step 5: Verify the live window lifecycle**

Run:

```bash
./scripts/check.sh
./scripts/smoke.sh
qs -p /home/cole/Projects/titonium ipc call centerNotch open overview
qs -p /home/cole/Projects/titonium ipc call centerNotch state
qs -p /home/cole/Projects/titonium ipc call centerNotch close
./scripts/protected_acceptance.sh
```

Expected: the state reports the focused output and Overview; the expanded solid shell touches the
top edge and closes without changing Spotlight behavior.

- [ ] **Step 6: Commit the lifecycle**

```bash
git add Titonium/App.qml Titonium/Bar/BarHost.qml Titonium/Bar/notch \
  scripts/check_bar.py
git commit -m "feat: add lazy center notch surface"
```

---

### Task 4: Implement the Ambxst-informed rail and lazy viewport

**Files:**
- Create: `Titonium/Bar/notch/CenterNotchRail.qml`
- Create: `Titonium/Bar/notch/CenterNotchViewport.qml`
- Create: `Titonium/Bar/notch/OverviewPage.qml`
- Modify: `Titonium/Bar/notch/CenterNotch.qml`
- Modify: `Titonium/Bar/notch/qmldir`
- Modify: `scripts/check_bar.py`

**Interfaces:**
- Consumes: `CenterNotchState`, `CenterNotchCoordinator.requestedPage`, `Motion.reduced`, existing
  semantic controls.
- Produces: `CenterNotchRail.pageRequested(pageId)` and `settingsRequested()`;
  `CenterNotchViewport.currentPage`, `requestPage(pageId)` and `feedbackRequested(key)`.

- [ ] **Step 1: Add failing rail/viewport contracts**

Require the rail source to expose a 48-pixel width, one moving highlight item and the exact three
page IDs. Require the viewport to use `StackView`, `replace`, `busy` and `pendingPage`, and reject
`MultiEffect`. Run `python3 scripts/check_bar.py`; expect RED.

- [ ] **Step 2: Build the 48-pixel rail**

Create three 48×48 icon buttons at the top (`dashboard`, `construction`, `power_settings_new`) with
8-pixel gaps and a fixed 48×48 Settings button (`settings`) at the bottom. One Rectangle highlight
binds to the selected primary index and animates `y`/`height` with `Motion.normal`. The selected icon
uses accent foreground; focus uses the existing focus token.

Wheel input calls `CenterNotchState.wheelPage()`. Up/Down call `arrowPage()`, Home selects Overview,
End selects Session, Enter activates the focused entry and Escape closes the coordinator. Normal
Tab focus reaches the bottom Settings entry.

- [ ] **Step 3: Build the lazy StackView viewport**

The viewport defines local Components for Overview, Tools and Session and an exact `componentFor()`
switch. Unknown IDs normalize to Overview and log one warning through `Logger.warn`.

On request while `stack.busy`, store only the latest normalized ID in `pendingPage`. Otherwise call
`stack.replace(componentFor(nextPage), { "pageId": nextPage })`. Define replace transitions using
opacity and a ±12 vertical translation from `CenterNotchState.transitionPlan()`. When `busy` becomes
false, process and clear the latest pending request. `StackView.replace` destroys the outgoing page
after the exit transition, satisfying lazy unload without a page cache.

- [ ] **Step 4: Compose the Ambxst layout grammar**

`CenterNotch.qml` uses a Row with:

```text
48px rail · 8px gap · 1px separator · 16px gap · fill-width viewport
```

Keep 16-pixel outer padding. Overview contains a title, a concise explanation and four inert sample
cards used only to verify grid responsiveness. It has no Timer or service import. A common feedback
label sits below the viewport and is collapsed when empty.

Bind coordinator page requests into the viewport and report the selected page back through the
coordinator only after `StackView` is no longer busy. Settings activation sets
`center_notch.settings.unavailable` feedback without changing the page.

- [ ] **Step 5: Verify transitions and protected gates**

Run:

```bash
node scripts/check_center_notch.js
python3 scripts/check_bar.py
./scripts/check.sh
./scripts/smoke.sh
./scripts/protected_acceptance.sh
```

Then issue `centerNotch page tools`, `session`, `overview` rapidly. Expected: only the latest request
remains selected, no page stays loaded behind the active one after its exit, and reduced motion uses
zero-duration replacement.

- [ ] **Step 6: Commit the rail and viewport**

```bash
git add Titonium/Bar/notch scripts/check_bar.py
git commit -m "feat: add center notch navigation"
```

---

### Task 5: Add safe Tools and Session mock pages with i18n

**Files:**
- Create: `Titonium/Bar/notch/CenterActionButton.qml`
- Create: `Titonium/Bar/notch/ToolsPage.qml`
- Create: `Titonium/Bar/notch/SessionPage.qml`
- Modify: `Titonium/Bar/notch/CenterNotchViewport.qml`
- Modify: `Titonium/Bar/notch/qmldir`
- Modify: `config/i18n/en.json`
- Modify: `config/i18n/vi.json`
- Modify: `scripts/validate_config.py`
- Modify: `scripts/check_bar.py`

**Interfaces:**
- Consumes: immutable descriptors from `CenterActionCatalog` and `I18n.tr()`.
- Produces: `CenterActionButton.actionRequested(intent, feedbackKey)` and page-level
  `feedbackRequested(key)`; no executable action boundary.

- [ ] **Step 1: Extend validation and verify RED**

Require matching English and Vietnamese keys for:

```text
center_notch.title
center_notch.tab.{overview,tools,session,settings}
center_notch.settings.unavailable
center_notch.action.<all 14 action IDs>
center_notch.action.unavailable
center_notch.tools.title
center_notch.session.title
```

Extend `validate_config.py` so the locale key sets must remain identical. Extend `check_bar.py` to
reject `Process`, `execDetached`, command-like properties and service imports in both mock pages.
Run both gates and expect RED for missing keys/files.

- [ ] **Step 2: Implement an interactive but unavailable action tile**

`CenterActionButton` remains enabled so pointer and keyboard activation can be tested. It accepts a
descriptor, displays icon and translated label, adds a translated “Not available yet” status, and
emits feedback instead of executing the descriptor intent. It never exposes an `onExecute` or
callback property.

Use a centered icon+label composition with minimum height 88. Long labels elide on one line and the
accessible name includes both the action label and unavailable status.

- [ ] **Step 3: Build responsive mock grids**

Tools uses four columns when the viewport is at least 600 logical pixels wide and two otherwise.
Session uses three columns when at least 540 pixels wide and two otherwise. Both pages use
`GridLayout` and `Repeater` over fresh catalog arrays. Activating any tile forwards
`center_notch.action.unavailable` to the common feedback label.

Session marks Logout, Hibernate, Restart and Shutdown as dangerous in the descriptor but does not
apply an alarming filled style while unavailable. No confirmation surface is created in this plan.

- [ ] **Step 4: Add exact Vietnamese and English strings**

Use concise labels. The common feedback is:

```json
"center_notch.action.unavailable": "This action is not available yet."
```

and:

```json
"center_notch.action.unavailable": "Tính năng này chưa khả dụng."
```

Do not add strings for Network connection state, Bluetooth power or volume because those states do
not exist in this slice.

- [ ] **Step 5: Verify catalogs, i18n and UI boundaries**

Run:

```bash
node scripts/check_center_actions.js
python3 scripts/validate_config.py
python3 scripts/check_bar.py
./scripts/check.sh
./scripts/smoke.sh
./scripts/protected_acceptance.sh
```

Expected: every mock provides feedback and no action produces a process, file, notification or new
surface.

- [ ] **Step 6: Commit mock content**

```bash
git add Titonium/Bar/notch config/i18n scripts/validate_config.py scripts/check_bar.py
git commit -m "feat: add center notch mock actions"
```

---

### Task 6: Add foreground acceptance, performance gates and handoff documentation

**Files:**
- Create: `scripts/center_notch_acceptance.sh`
- Modify: `scripts/check.sh`
- Modify: `docs/ARCHITECTURE.md`
- Modify: `docs/ROADMAP.md`
- Modify: `docs/TESTING.md`

**Interfaces:**
- Consumes: `centerNotch` IPC from Task 3 and all static/domain gates.
- Produces: a repeatable no-side-effect live acceptance and the documented checkpoint before Audio.

- [ ] **Step 1: Write the foreground acceptance script**

Follow `scripts/spotlight_acceptance.sh`: create a temporary log directory, snapshot Git status and
both Hyprland hashes, launch one foreground `qs -p "$project_root" --no-color`, wait for `app
status`, and clean up through a trap.

Exercise this sequence:

```text
centerNotch open overview  -> open:<focused-screen>;page=overview
centerNotch page tools     -> page=tools
centerNotch page session   -> page=session
spotlight toggle           -> Spotlight open and Center Notch closed
spotlight close
centerNotch open overview
centerNotch close          -> closed
```

Reject logs matching:

```text
ERROR|TypeError|Illegal method name|Type .* unavailable|duplicate id|missing method
```

The script must not expose or invoke an IPC method for mock actions.

- [ ] **Step 2: Add static idle-performance assertions**

Extend `check_bar.py` to reject `Timer`, `MultiEffect`, `ShaderEffect`, `NumberAnimation` with
`loops: Animation.Infinite`, an always-active notch page Loader, and direct imports of future Audio,
Bluetooth or Network services. Allow bounded Behaviors and StackView transitions.

Run the gate once against a temporary fixture containing `Timer { repeat: true }` and confirm it
fails; remove the fixture and confirm the real tree passes.

- [ ] **Step 3: Register and run the complete acceptance set**

Add only static/domain checks to `scripts/check.sh`; keep live acceptance explicit. Run:

```bash
./scripts/check.sh
./scripts/smoke.sh
./scripts/protected_acceptance.sh
./scripts/center_notch_acceptance.sh
hyprctl configerrors
```

Expected: all scripts pass, `hyprctl configerrors` is empty, Git status and both Hyprland hashes are
unchanged, and the runtime log contains `Configuration Loaded` with no rejection pattern.

- [ ] **Step 4: Perform the two-monitor visual checklist**

On DP-1 scale 1.5 and DP-3 scale 1.0 verify:

- one Bar and compact notch per monitor;
- center position does not move when outer widths differ;
- opening on one monitor closes an open notch on the other;
- expanded notch touches the top edge and resembles the Ambxst rail/content proportions;
- transparent outside click closes without leaving keyboard focus captured;
- rapid rail changes remain smooth and select the latest page;
- narrow width reduces grid columns without stretching a tile vertically;
- mock feedback is visible and no system action occurs;
- Spotlight still opens at its protected position and closes the notch;
- Input Method remains reactive.

Stop at this checkpoint for user review. Do not begin Audio automatically.

- [ ] **Step 5: Update architecture, testing and roadmap**

Document the Bar-owned notch overlay, coordinator boundary, StackView unload lifecycle, IPC
acceptance seam and mock-only limitation. Change the roadmap next item to “Audio native slice —
awaiting design” followed by Bluetooth and Network. Do not describe mocks as implemented tools.

- [ ] **Step 6: Commit the accepted Slice 1 handoff**

```bash
git add scripts/center_notch_acceptance.sh scripts/check.sh scripts/check_bar.py \
  docs/ARCHITECTURE.md docs/ROADMAP.md docs/TESTING.md
git commit -m "test: accept qml native center notch"
```

## Final verification

Run after the last commit:

```bash
git status --short
./scripts/check.sh
./scripts/smoke.sh
./scripts/protected_acceptance.sh
./scripts/center_notch_acceptance.sh
hyprctl configerrors
git log --oneline -6
```

Expected:

- `git status --short` is empty before and after runtime tests;
- all four gates pass;
- Hyprland reports no configuration error;
- the six commits correspond to the six independently reviewable tasks;
- no Audio, Bluetooth, Network, Settings, tool implementation or session command was added.
