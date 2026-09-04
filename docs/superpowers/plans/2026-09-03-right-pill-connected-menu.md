# Right Pill Connected Menu Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the detached DBusMenu popup with always-mounted edge owners so the pill containing the clicked control morphs directly into a headerless application menu canvas.

**Architecture:** Screen-local left/right pill windows each own one `EdgePillShape` and derive compact/menu geometry, clipping and input from edge-gated coordinator progress. `StartIsland` and `EndIsland` are presentation-only compact content, while a reusable `SystemTrayMenuView` consumes projected service values and narrow intents from the existing sole `QsMenuOpener` backend. Active Window routes to the left owner and Input Method to the right owner; the retired popup window and coordinator are removed after all callers migrate.

**Tech Stack:** QML/Qt Quick, Quickshell Wayland layer-shell, `QsMenuOpener`, JavaScript pure rules, Python/Node static contracts, shell acceptance tests.

**Spec:** `docs/superpowers/specs/2026-09-03-right-pill-connected-menu-design.md`

## Global Constraints

- The menu remains independent from Dynamic Island state and content.
- Exactly one screen-local owner paints the right silhouette in compact and menu states.
- The surface is flush with the top and right output edges and has no header, nested panel, filler or duplicate background.
- Compact height is 36dp; menu width is 420dp; menu height is content-derived and capped at 440dp and available output height.
- Open uses 240ms; close uses 190ms; both use one reversible `transitionProgress` and `Motion.springDamped`.
- Text and icons never scale during the state morph; Reduced Motion commits immediately.
- `SystemTrayBackend` remains the sole native System Tray and `QsMenuOpener` owner.
- App DBusMenu and Input Method use the connected right menu. Wi-Fi, Bluetooth and Audio keep their specialized popups.
- Preserve unrelated dirty-worktree changes and do not modify protected Hyprland configuration.
- Commit each task only from an isolated worktree. In the current shared dirty worktree, do not
  create partial commits that could capture user-owned changes.

---

### Task 1: Pure right-pill state and geometry rules

**Files:**
- Create: `Titonium/Bar/right/RightPillState.js`
- Create: `Titonium/Bar/right/qmldir`
- Create: `scripts/check_right_pill_state.js`
- Modify: `scripts/check.sh`

**Interfaces:**
- Produces: `normalizeState(active: bool): "compact" | "menu"`.
- Produces: `menuHeight(contentHeight: number, outputHeight: number): number` clamped to `120..min(440, outputHeight)`.
- Produces: `contentOpacity(progress: number, layer: "compact" | "menu"): number`.
- Produces: `inputMode(progress: number, active: bool): "compact" | "handoff" | "menu"`.

- [ ] **Step 1: Write the failing pure test**

```js
assert.equal(state.normalizeState(false), "compact");
assert.equal(state.normalizeState(true), "menu");
assert.equal(state.menuHeight(300, 900), 332); // 16dp top/bottom insets
assert.equal(state.menuHeight(900, 900), 440);
assert.equal(state.menuHeight(900, 360), 360);
assert.equal(state.menuHeight(0, 900), 120);
assert.equal(state.contentOpacity(0, "compact"), 1);
assert.equal(state.contentOpacity(1, "compact"), 0);
assert.equal(state.contentOpacity(0, "menu"), 0);
assert.equal(state.contentOpacity(1, "menu"), 1);
assert.equal(state.inputMode(0.2, true), "compact");
assert.equal(state.inputMode(0.5, true), "handoff");
assert.equal(state.inputMode(0.8, true), "menu");
```

- [ ] **Step 2: Run the test and verify RED**

Run: `node scripts/check_right_pill_state.js`

Expected: FAIL because `RightPillState.js` does not exist.

- [ ] **Step 3: Implement minimal clamped pure functions**

```js
.pragma library

function clamp01(value) {
    return Math.max(0, Math.min(1, Number(value) || 0));
}

function normalizeState(active) {
    return active === true ? "menu" : "compact";
}

function menuHeight(contentHeight, outputHeight) {
    const available = Math.max(36, Number(outputHeight) || 36);
    return Math.max(120, Math.min(440, available, (Number(contentHeight) || 0) + 32));
}

function contentOpacity(progress, layer) {
    const p = clamp01(progress);
    return layer === "compact" ? 1 - Math.min(1, p / 0.35)
        : Math.max(0, Math.min(1, (p - 0.2) / 0.55));
}

function inputMode(progress, active) {
    if (active !== true)
        return "compact";
    const p = clamp01(progress);
    return p < 0.35 ? "compact" : (p > 0.7 ? "menu" : "handoff");
}
```

- [ ] **Step 4: Export the module and add the test to the main suite**

Create `Titonium/Bar/right/qmldir` with only `module qs.Titonium.Bar.right`. Export the coordinator
in Task 2 after its QML file exists so `qmllint` never observes a registered missing type.

Add `node "$project_root/scripts/check_right_pill_state.js"` immediately after the direct Bar checks in `scripts/check.sh`.

- [ ] **Step 5: Run tests and verify GREEN**

Run: `node scripts/check_right_pill_state.js && ./scripts/check.sh`

Expected: all tests pass; only allowlisted `qmllint` warnings remain.

---

### Task 2: Coordinator lifecycle and menu routing boundary

**Files:**
- Create: `Titonium/Bar/right/RightPillCoordinator.qml`
- Create: `scripts/check_right_pill.js`
- Modify: `Titonium/Bar/right/qmldir`
- Modify: `Titonium/Services/SystemTray/SystemTrayService.qml`
- Modify: `Titonium/Services/SystemTray/internal/SystemTrayBackend.qml`
- Modify: `scripts/check.sh`

**Interfaces:**
- Consumes: `SystemTrayService.prepareAppMenu`, `prepareInputMenu`, `resetPopupNavigation`,
  `popupPrepared`, and `popupEntries`.
- Produces: properties `ownerScreenName`, `exitingScreenName`, `state`, `active`, `compactWidth`, `transitionProgress`, `menuSource`.
- Produces: intents `setCompactWidth(width)`, `toggleApp(screenName, appId, appName)`, `toggleInput(screenName)`, `close()`, `finishClose(screenName)`.

- [ ] **Step 1: Write a failing static coordinator contract**

```js
for (const fragment of [
    'property string ownerScreenName: ""',
    'property real transitionProgress: root.active ? 1 : 0',
    'function toggleApp(screenName: string, appId: string, appName: string): bool',
    'SystemTrayService.prepareAppMenu(appId, appName)',
    'function toggleInput(screenName: string): bool',
    'SystemTrayService.prepareInputMenu()',
    'SystemTrayService.resetPopupNavigation()',
    'duration: Motion.reduced ? 0 : (root.active ? 240 : 190)',
    'easing.bezierCurve: Motion.springDamped',
]) assert.match(source, new RegExp(escape(fragment)));
```

- [ ] **Step 2: Run the contract and verify RED**

Run: `node scripts/check_right_pill.js`

Expected: FAIL because `RightPillCoordinator.qml` does not exist.

- [ ] **Step 3: Implement the coordinator**

Use one `Behavior on transitionProgress`; `toggleApp` and `toggleInput` prepare the service menu before setting `ownerScreenName`. If preparation fails, return `false` without changing state. `close()` moves the current owner into `exitingScreenName`; `finishClose()` clears the exit owner and resets menu navigation only after the reverse morph ends. Reopening during close cancels the exit name and reverses the same progress.

```qml
property real transitionProgress: root.active ? 1 : 0
readonly property string state: RightPillState.normalizeState(root.active)
readonly property bool active: root.ownerScreenName.length > 0

Behavior on transitionProgress {
    NumberAnimation {
        duration: Motion.reduced ? 0 : (root.active ? 240 : 190)
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Motion.springDamped
    }
}
```

Expose `popupPrepared` from `SystemTrayBackend` as `internal.popupCurrentMenu !== null` and project
it read-only through `SystemTrayService`. If it becomes false while the right menu is active, the
coordinator closes. A prepared menu with zero projected entries remains open without a timeout so
asynchronous `QsMenuOpener` population is not mistaken for source disappearance.

- [ ] **Step 4: Export the coordinator**

Add `singleton RightPillCoordinator 1.0 RightPillCoordinator.qml` to
`Titonium/Bar/right/qmldir` only after the coordinator file exists.

- [ ] **Step 5: Add coordinator invariants to the test**

Assert there is no `Loader`, native `SystemTray`, `QsMenuOpener`, repeating `Timer`, app-specific identifier or ChatGPT branch in the coordinator.

- [ ] **Step 6: Register and run tests**

Run: `node scripts/check_right_pill.js && ./scripts/check.sh`

Expected: coordinator contract and full suite pass.

---

### Task 3: Extract the reusable projected menu view

**Files:**
- Create: `Titonium/Overlays/SystemTray/SystemTrayMenuView.qml`
- Modify: `Titonium/Overlays/SystemTray/qmldir`
- Modify: `Titonium/Overlays/SystemTray/SystemTrayPopupSurface.qml`
- Modify: `scripts/check_system_tray.py`

**Interfaces:**
- Consumes: `SystemTrayService.popupEntries`, `popupCanGoBack`, `popupIsInputMethod`, `inputMenuPresentation`, `enterPopupEntry`, `triggerPopupEntry`, and `popupBack`.
- Produces: `implicitContentHeight` and signal `dismissRequested()`.

- [ ] **Step 1: Write the failing shared-view contract**

Require `SystemTrayMenuView.qml` to contain one `Flickable`, one entries `Repeater`, conditional Back, separator/disabled/checkbox/radio/submenu rendering, keyboard activation, and no `Shared.Panel`, `PanelWindow`, `SurfaceManager`, native `SystemTray`, `QsMenuOpener` or app-specific condition.

- [ ] **Step 2: Run and verify RED**

Run: `python3 scripts/check_system_tray.py`

Expected: FAIL with missing `SystemTrayMenuView.qml`.

- [ ] **Step 3: Move menu rows into the presentation-only view**

```qml
FocusScope {
    id: root
    signal dismissRequested()
    readonly property real implicitContentHeight: contentColumn.implicitHeight

    Flickable {
        anchors.fill: parent
        contentHeight: contentColumn.implicitHeight
        clip: true
        // Back row and projected-entry Repeater move here unchanged.
    }
}
```

For leaf activation, call `triggerPopupEntry(index)`. Emit `dismissRequested()` only when the projected entry has `buttonType === "none"`; keep checkbox/radio menus open. Submenu activation calls `enterPopupEntry(index)` and never dismisses.

- [ ] **Step 4: Replace duplicated popup content with the shared view**

Temporarily instantiate `SystemTrayMenuView` inside `SystemTrayPopupSurface` so behavior stays green before visual-owner migration. Connect `onDismissRequested` to the popup's existing close path.

- [ ] **Step 5: Run full menu contracts**

Run: `python3 scripts/check_system_tray.py && ./scripts/check.sh`

Expected: projected menu behavior and full suite pass.

---

### Task 4: Move compact right content under one screen-local visual owner

**Files:**
- Create: `Titonium/Bar/right/RightPillWindow.qml`
- Create: `Titonium/Bar/right/RightPillSurface.qml`
- Modify: `Titonium/Bar/islands/EndIsland.qml`
- Modify: `Titonium/Bar/Bar.qml`
- Modify: `Titonium/Bar/BarSurface.qml`
- Modify: `Titonium/Bar/BarHost.qml`
- Modify: `scripts/check_bar.py`
- Modify: `scripts/check_right_pill.js`

**Interfaces:**
- Consumes: `RightPillCoordinator` state/progress, `RightPillState`, `BarVisibilityState`, `EndIsland`, `EdgePillShape`, and `SystemTrayMenuView`.
- Produces: one compact reservation width to `Bar.qml`; one window input region for compact/menu/outside-click states.

- [ ] **Step 1: Extend failing contracts for sole ownership**

Require `BarHost` to create one `RightPillWindow` per eligible screen. Require exactly one `Shared.EdgePillShape` in `RightPillSurface`; forbid it in `EndIsland` and forbid an `EndIsland` instance in `Bar.qml`. Require `RightPillWindow` to stay mounted with no Loader. Require `Bar.qml` to reserve `RightPillCoordinator.compactWidth` without painting or accepting the right compact hitbox.

- [ ] **Step 2: Run and verify RED**

Run: `python3 scripts/check_bar.py && node scripts/check_right_pill.js`

Expected: FAIL on duplicate/old ownership.

- [ ] **Step 3: Make `EndIsland` compact-content only**

Remove `EdgePillShape`, width animation and outer clipping from `EndIsland`. Keep Pin, Connectivity, Input Method and conditional Notification composition. Publish its `implicitWidth` through `RightPillCoordinator.setCompactWidth()` on completion and width changes.

- [ ] **Step 4: Implement the connected surface**

`RightPillSurface` fills the owner window and anchors its animated chassis to top/right. Interpolate from `compactWidth × 36` to `420 × menuHeight`. Use exactly one `EdgePillShape`; drive its body width, body height and inward shoulder from the same progress. The compact `EndIsland` is right-anchored, clipped and uses `RightPillState.contentOpacity(progress, "compact")`. The headerless `SystemTrayMenuView` fills the 16dp-inset menu viewport and uses menu opacity plus a progress-derived downward translation.

```qml
readonly property real visualWidth: compactWidth
    + (420 - compactWidth) * transitionProgress
readonly property real visualHeight: 36
    + (targetMenuHeight - 36) * transitionProgress

Shared.EdgePillShape {
    edge: "right"
    bodyWidth: chassis.width - chassis.shoulderSize
    bodyHeight: chassis.height
}
```

- [ ] **Step 5: Implement window mask and lifecycle**

`RightPillWindow` is a full-screen transparent `PanelWindow` anchored on all edges. In compact state its mask includes only the visible right pill. While menu is active or closing, its mask includes the screen so outside clicks reach `RightPillSurface`; the transparent root paints nothing. Keyboard focus is exclusive only for active/closing menu state. On reverse completion call `finishClose(screenName)`.

- [ ] **Step 6: Replace Bar ownership with reservation**

In `Bar.qml`, replace the visible `EndIsland` with an inert right reservation whose width is `RightPillCoordinator.compactWidth`. Remove the right region from `BarSurface.mask`. Add `RightPillWindow` beside `CenterPillWindow` in `BarHost`.

- [ ] **Step 7: Preserve Bar auto-hide behavior**

Include `RightPillCoordinator.active` in `BarSurface.revealRequested`. Compact right content follows `BarVisibilityState.revealed`; active menu stays at `y = 0` and keeps the Bar revealed until close completes.

- [ ] **Step 8: Run ownership and QML checks**

Run: `python3 scripts/check_bar.py && node scripts/check_right_pill.js && ./scripts/check.sh`

Expected: exactly one right surface/path contract and full suite pass.

---

### Task 5: Route every DBusMenu caller and remove the detached popup

**Files:**
- Modify: `Titonium/Bar/islands/ActiveWindowPill.qml`
- Modify: `Titonium/Bar/widgets/InputMethod.qml`
- Modify: `Titonium/Overlays/SystemTray/qmldir`
- Delete: `Titonium/Overlays/SystemTray/SystemTrayPopupCoordinator.qml`
- Delete: `Titonium/Overlays/SystemTray/SystemTrayPopupSurface.qml`
- Modify: `scripts/check_active_window.js`
- Modify: `scripts/check_system_tray.py`
- Modify: `scripts/check_surface_passthrough.py`

**Interfaces:**
- Consumes: `RightPillCoordinator.toggleApp(screenName, appId, appName)` and `toggleInput(screenName)`.
- Preserves: Active Window's existing Center Expanded fallback when no app menu can be prepared.

- [ ] **Step 1: Write failing routing/removal contracts**

Require `ActiveWindowPill.activate()` to call `RightPillCoordinator.toggleApp(...)` first and call `CenterNotchCoordinator.openExpanded(...)` only after a `false` return. Require Input Method to call `RightPillCoordinator.toggleInput(root.screen.name)`. Assert no QML file imports or references `SystemTrayPopupCoordinator`, and both retired popup files/qmldir entries are absent.

- [ ] **Step 2: Run and verify RED**

Run: `node scripts/check_active_window.js && python3 scripts/check_system_tray.py`

Expected: FAIL on old popup routing and existing popup files.

- [ ] **Step 3: Migrate Active Window routing**

```qml
function activate(): void {
    if (RightPillCoordinator.toggleApp(root.screen.name,
            root.activeWindow?.appId || "", root.appName)) {
        CenterNotchCoordinator.close();
        return;
    }
    CenterNotchCoordinator.openExpanded(root.screen.name);
}
```

- [ ] **Step 4: Migrate Input Method routing**

Replace `SystemTrayPopupCoordinator.toggleInput(root.screen, root)` with
`RightPillCoordinator.toggleInput(root.screen.name)`. Preserve left/right click acceptance and accessibility.

- [ ] **Step 5: Delete the detached popup implementation**

After `rg -n "SystemTrayPopupCoordinator|SystemTrayPopupSurface" Titonium` returns only the two retired files, delete both files and their qmldir exports. Update passthrough contracts so no detached system-tray surface is expected.

- [ ] **Step 6: Run routing and full tests**

Run: `node scripts/check_active_window.js && python3 scripts/check_system_tray.py && python3 scripts/check_surface_passthrough.py && ./scripts/check.sh`

Expected: no old popup references and all tests pass.

---

### Task 6: Mutual exclusion, stale-menu handling and runtime acceptance

**Files:**
- Modify: `Titonium/Orchestration/SurfaceRouter.qml`
- Modify: `Titonium/Bar/right/RightPillCoordinator.qml`
- Create: `scripts/right_pill_menu_acceptance.sh`
- Modify: `scripts/check_right_pill.js`
- Modify: `scripts/check.sh`
- Modify: `docs/ARCHITECTURE.md`
- Modify: `docs/THEMING_AND_GLASS.md`
- Modify: `docs/TESTING.md`

**Interfaces:**
- Consumes: `SurfaceManager`, `CenterNotchCoordinator`, `SettingsCoordinator`, and selected System Tray menu validity.
- Produces: deterministic mutual exclusion and acceptance coverage for the connected menu lifecycle.

- [ ] **Step 1: Write failing mutual-exclusion contracts**

Require `SurfaceRouter` to close `RightPillCoordinator` before opening Spotlight/Settings and when
another `SurfaceManager` owner opens. Require Center activation to close the right menu, and
right-menu activation to close Center. Assert the coordinator closes when
`SystemTrayService.popupPrepared` becomes false while the menu is active.

- [ ] **Step 2: Add a syntax-safe runtime acceptance script**

Follow existing acceptance harnesses and verify state snapshots for compact → menu → compact, Escape, outside click, rapid reopen during close, submenu/Back, leaf close, checkbox/radio persistence, source disappearance, Center mutual exclusion, Spotlight mutual exclusion, masks and scales 1.0/1.5. Hash protected Hyprland files before and after.

- [ ] **Step 3: Implement mutual exclusion**

Add `Connections` in `SurfaceRouter` for right and center active changes with guards that only close the opposite active owner. Extend existing Spotlight, Settings and generic surface-open paths to close the right coordinator. Do not create a raw dependency from Dynamic Island presentation components to menu content.

- [ ] **Step 4: Implement stale-menu close**

Observe `SystemTrayService.popupPrepared`. If it changes to false while the right menu is active,
call `close()` and reset navigation after reverse completion. A prepared menu with zero projected
entries remains in the in-surface loading/empty state without a timeout, allowing asynchronous
`QsMenuOpener` population to complete.

- [ ] **Step 5: Update canonical documentation**

Document one right visual owner, headerless 420×adaptive/440dp geometry, app/Input Method routing, reverse motion, auto-hide behavior, mutual exclusion and removal of the detached popup. Mark prior detached popup descriptions superseded.

- [ ] **Step 6: Run complete verification**

Run:

```bash
./scripts/check.sh
bash scripts/right_pill_menu_acceptance.sh
git diff --check
```

Expected: all static/pure checks pass, acceptance completes without runtime errors, and protected configuration hashes are unchanged.

---

### Task 7: Final scope and performance review

**Files:**
- Review only: every file changed by Tasks 1–6

**Interfaces:**
- Produces no new runtime interface; validates the implementation against the approved spec.

- [ ] **Step 1: Confirm ownership and dependency boundaries**

Run `rg` checks proving one `EdgePillShape` owner for the right surface, one native `SystemTray` import, two `QsMenuOpener` instances only in the backend, and zero retired popup references.

- [ ] **Step 2: Confirm hidden-work behavior**

Inspect animations and bindings to verify compact notification/equalizer motion stops when hidden, menu content owns no polling timer, and the always-mounted full-screen window paints only the connected shape.

- [ ] **Step 3: Review the final diff**

Run `git diff --check` and inspect `git diff --` for only the plan's files. Preserve unrelated worktree changes.

- [ ] **Step 4: Run final verification again**

Run `./scripts/check.sh` and the right-menu acceptance script from a fresh shell invocation. Report exact failures rather than claiming completion if either command exits non-zero.
