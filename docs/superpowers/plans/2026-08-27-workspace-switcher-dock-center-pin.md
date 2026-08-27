# Workspace, Switcher, Dock, and Center Pin Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add workspace-aware window focusing, an Ambxst-inspired five-slot workspace strip, corrected Dock pin/hover behavior, and a session-only Center Notch pin on DP-1 without changing Bluetooth.

**Architecture:** `HyprlandService` remains the single native compositor boundary and publishes enriched immutable window/workspace descriptors. Window Switcher, Dock, Workspaces, and Center controls consume narrow semantic APIs; each presentation change is protected by a pure rule or static architecture test before QML is edited.

**Tech Stack:** Quickshell 0.3.x, Qt 6 QML/JavaScript, Hyprland native Quickshell integration, Node.js fixture tests, Python architecture gates, shell live acceptance.

**Spec:** `docs/superpowers/specs/2026-08-27-workspace-switcher-dock-center-pin-design.md`

## Global Constraints

- Titonium owns only `DP-1`; no Titonium surface or exclusive zone may appear on `DP-3`.
- Do not modify `Titonium/Services/Bluetooth`, Bluetooth overlays, Audio handoff, either `hyprland.lua`, or runtime preferences.
- Do not introduce `Process`, raw `hyprctl`, polling timers, shaders, `MultiEffect`, native Hyprland objects in views, or continuous animation.
- Preserve Spotlight, Input Method, existing Super+Tab bindings, Dock actions, Center Notch lazy loading, and one-transient-surface behavior.
- Adapt only the occupied-range, stretchy-active, active-app-icon, and wheel-navigation patterns from Ambxst; do not import Axctl, Go, Ambxst config/theme objects, or raw compositor objects.
- Every production change follows RED → GREEN, and each task ends with its focused checks and a separate commit.

---

## File Map

- `Titonium/Services/Hyprland/WindowRules.js`: normalize public window descriptors, including workspace and monitor identity.
- `Titonium/Services/Hyprland/WindowRegistry.js`: private native re-lookup and ordered workspace/window activation.
- `Titonium/Services/Hyprland/WorkspaceRules.js`: pure five-slot grouping, occupied range, and active-icon projection.
- `Titonium/Services/Hyprland/HyprlandService.qml`: sole compositor observer/action owner and public workspace snapshot.
- `Titonium/Services/WindowSwitcher/WindowSwitcherService.qml`: close-before-focus acceptance.
- `Titonium/Services/Dock/DockService.qml`: consume the shared workspace-aware focus method.
- `Titonium/Bar/widgets/Workspaces.qml`: render five projected slots and bounded pointer interaction.
- `Titonium/Bar/islands/CenterGroup.qml`: screen-centered Center Island plus right-side pin.
- `Titonium/Bar/Bar.qml`: compose the Center group; the existing `BarSurface` mask follows the
  exported `centerHitbox` alias without modification.
- `Titonium/Bar/notch/CenterNotchCoordinator.qml` and `CenterNotchSurface.qml`: session-only pinned lifecycle.
- `Titonium/Dock/DockSurface.qml`, `DockWindow.qml`, and `DockAppButton.qml`: disjoint pin geometry, explicit input region, and no tooltip.
- `scripts/check_windows.js`, `check_window_switcher.py`, `check_workspaces.js`, `check_bar.py`, `check_center_notch.js`, `check_dock_layout.js`, and `check.sh`: focused RED/GREEN contracts.
- `scripts/workspace_interactions_acceptance.sh`: read-only lifecycle/DP-1 live acceptance.
- `config/i18n/en.json` and `vi.json`: Center pin accessibility strings only.

---

### Task 1: Enrich the shared window descriptor and focus boundary

**Files:**
- Modify: `scripts/check_windows.js`
- Modify: `Titonium/Services/Hyprland/WindowRules.js`
- Modify: `Titonium/Services/Hyprland/WindowRegistry.js`
- Modify: `Titonium/Services/Hyprland/HyprlandService.qml`

**Interfaces:**
- Produces: `WindowRules.descriptor(raw) -> Frozen<{id,appId,title,icon,active,urgent,minimized,workspaceId,monitorName}>`
- Produces: `WindowRegistry.focus(id, source) -> bool`
- Produces: `HyprlandService.focusWindow(id: string) -> bool`
- Preserves: `activateWindow(id)` only as a compatibility alias to `focusWindow(id)` until all consumers move.

- [ ] **Step 1: Extend the descriptor fixture before production code**

Add `workspaceId: 7` and `monitorName: "DP-1"` to the raw fixture and expected frozen object in `scripts/check_windows.js`. Add fallback assertions that invalid workspace IDs become `0`, non-string monitor names become `""`, and neither `workspace`, `wayland`, nor `native` survives projection.

```js
assert.deepEqual(plain(first), {
  id: "0xabc", appId: "org.mozilla.firefox", title: "Documentation",
  icon: "firefox", active: true, urgent: false, minimized: false,
  workspaceId: 7, monitorName: "DP-1",
});
assert.equal(rules.descriptor({ id: "0xdef", workspaceId: -2 }).workspaceId, 0);
```

- [ ] **Step 2: Add a failing ordered-focus registry fixture**

Replace the old activation-only expectation with a native containing `workspace.activate()` and `wayland.activate()`. Assert the call sequence is exactly `workspace`, then `window`; assert stale source and missing ID return `false` without calls; require registry keys to be exactly `close`, `focus`, and `replace`.

```js
const calls = [];
const native = {
  workspace: { activate() { calls.push("workspace"); } },
  wayland: { activate() { calls.push("window"); }, close() {} },
};
registry.replace([{ id: "0xabc", native }]);
assert.equal(registry.focus("0xabc", [native]), true);
assert.deepEqual(calls, ["workspace", "window"]);
```

- [ ] **Step 3: Run the focused test and verify RED**

Run: `node scripts/check_windows.js`

Expected: FAIL because descriptors lack `workspaceId`/`monitorName` and the registry has no `focus()` method.

- [ ] **Step 4: Implement the minimal pure contracts**

In `WindowRules.descriptor`, normalize a positive integer `workspaceId` and trimmed `monitorName`. In `WindowRegistry`, keep the native map lexical; `focus()` must revalidate membership in the current source, call `native.workspace.activate()` when available, then call `native.wayland.activate()`. Do not return or expose the native object.

- [ ] **Step 5: Project native workspace metadata and publish the service method**

In `HyprlandService.recomputeWindows()`, pass:

```qml
workspaceId: Number(toplevel?.workspace?.id || toplevel?.lastIpcObject?.workspace?.id || 0),
monitorName: toplevel?.workspace?.monitor?.name
    || toplevel?.lastIpcObject?.monitor || "",
```

Add `focusWindow(id)` delegating to `WindowRegistry.focus(id, Hyprland.toplevels.values || [])` and retain `activateWindow(id)` as a one-line compatibility alias.

- [ ] **Step 6: Verify GREEN and architecture ownership**

Run:

```bash
node scripts/check_windows.js
python3 scripts/check_dock.py
python3 scripts/check_window_switcher.py
```

Expected: PASS; the sole raw `Hyprland.toplevels` owner remains `HyprlandService.qml`.

- [ ] **Step 7: Commit the shared contract**

```bash
git add scripts/check_windows.js Titonium/Services/Hyprland/WindowRules.js \
  Titonium/Services/Hyprland/WindowRegistry.js Titonium/Services/Hyprland/HyprlandService.qml
git commit -m "feat: focus windows through their workspace"
```

---

### Task 2: Route Window Switcher and Dock through shared focus

**Files:**
- Modify: `scripts/check_window_switcher.py`
- Modify: `scripts/check_windows.js`
- Modify: `Titonium/Services/WindowSwitcher/WindowSwitcherService.qml`
- Modify: `Titonium/Services/Dock/DockService.qml`

**Interfaces:**
- Consumes: `HyprlandService.focusWindow(id: string) -> bool`
- Preserves: `WindowSwitcherService.accept() -> bool`, closing the surface before focus.

- [ ] **Step 1: Make consumer contracts fail on the compatibility alias**

Require `HyprlandService.focusWindow` in both consumer sources and reject `HyprlandService.activateWindow`. In `check_window_switcher.py`, assert `root.cancel()` occurs textually before `HyprlandService.focusWindow(id)` inside `accept()`.

```python
if service.find("root.cancel();") > service.find("HyprlandService.focusWindow(id)"):
    errors.append("Window Switcher must close before workspace-aware focus")
```

- [ ] **Step 2: Run RED**

Run:

```bash
node scripts/check_windows.js
python3 scripts/check_window_switcher.py
python3 scripts/check_dock.py
```

Expected: FAIL because both consumers still call `activateWindow`.

- [ ] **Step 3: Change only the two consumer calls**

Update `WindowSwitcherService.accept()` and `DockService.activateOrLaunch()` to call `HyprlandService.focusWindow(...)`. Keep selection, cycling, close ordering, and failure warnings unchanged.

- [ ] **Step 4: Verify GREEN**

Run the three commands from Step 2 and `node scripts/check_window_switcher_rules.js`.

Expected: PASS with no new source owner or native-object reference.

- [ ] **Step 5: Commit the routing change**

```bash
git add scripts/check_window_switcher.py scripts/check_windows.js \
  Titonium/Services/WindowSwitcher/WindowSwitcherService.qml \
  Titonium/Services/Dock/DockService.qml
git commit -m "fix: switch workspaces when accepting windows"
```

---

### Task 3: Add pure five-slot workspace projection

**Files:**
- Create: `Titonium/Services/Hyprland/WorkspaceRules.js`
- Create: `scripts/check_workspaces.js`
- Modify: `Titonium/Services/Hyprland/HyprlandService.qml`
- Modify: `scripts/check.sh`

**Interfaces:**
- Produces: `WorkspaceRules.groupStart(activeId, count) -> int`
- Produces: `WorkspaceRules.project(activeId, count, nativeStates, windows) -> Frozen<Array<WorkspaceDescriptor>>`
- `WorkspaceDescriptor`: `{id,active,occupied,urgent,icon,appId,rangeStart,rangeEnd}` with no native object.
- Produces: `HyprlandService.workspaceSnapshot(screen, 5)` using the pure projection.

- [ ] **Step 1: Write the complete pure rule fixture**

Create `scripts/check_workspaces.js` to load `WorkspaceRules.js` through `vm`. Cover:

```js
assert.equal(rules.groupStart(1, 5), 1);
assert.equal(rules.groupStart(5, 5), 1);
assert.equal(rules.groupStart(6, 5), 6);
```

Project active workspace `7` with occupied `6,7,9`, urgent `9`, and MRU-ordered windows containing two workspace-7 apps. Assert exactly IDs `6..10`, the first workspace-7 window supplies its icon/appId, `6..7` share range boundaries, `9` is a separate one-slot range, and output contains no native/workspace/toplevel keys.

- [ ] **Step 2: Register and run RED**

Add `node "$project_root/scripts/check_workspaces.js"` immediately after `check_windows.js` in `scripts/check.sh`.

Run: `node scripts/check_workspaces.js`

Expected: FAIL with `WorkspaceRules.js` missing.

- [ ] **Step 3: Implement the minimal immutable projector**

Create `WorkspaceRules.js` as a `.pragma library`. Clamp `count` to `1..10`, derive the group start, normalize native workspace facts by ID, choose the first matching public window as the active icon, and compute contiguous occupied range starts/ends in two bounded passes. Freeze every descriptor and the result array.

- [ ] **Step 4: Replace service-local snapshot composition**

Keep native inspection in `HyprlandService.workspaceSnapshot()`, but transform it into plain facts:

```qml
{ id: workspace.id,
  occupied: Number(state.windows || 0) > 0 || (workspace.toplevels?.values?.length || 0) > 0,
  urgent: workspace.urgent === true }
```

Return `WorkspaceRules.project(activeId, count, facts, root.windows)` and import the helper. Do not pass native workspace objects into it.

- [ ] **Step 5: Verify GREEN**

Run:

```bash
node scripts/check_workspaces.js
node scripts/check_windows.js
./scripts/check.sh
```

Expected: PASS; only the documented allowlisted Quickshell PanelWindow metadata warnings may appear.

- [ ] **Step 6: Commit workspace projection**

```bash
git add Titonium/Services/Hyprland/WorkspaceRules.js \
  Titonium/Services/Hyprland/HyprlandService.qml scripts/check_workspaces.js scripts/check.sh
git commit -m "feat: project grouped workspace state"
```

---

### Task 4: Render the Ambxst-inspired five-slot workspace strip

**Files:**
- Modify: `scripts/check_bar.py`
- Modify: `Titonium/Bar/widgets/Workspaces.qml`

**Interfaces:**
- Consumes: `HyprlandService.workspaceSnapshot(screen, 5)` descriptors.
- Emits: `HyprlandService.activateWorkspace(id)` from click and adjacent ID from wheel.

- [ ] **Step 1: Strengthen the Bar contract before changing QML**

Require `count: 5`, `rangeStart`, `rangeEnd`, an active app `Shared.SystemIcon`, a `WheelHandler`, and `HyprlandService.activateWorkspace`. Reject `Timer`, native Hyprland imports, raw workspace objects, and unbounded/infinite animations. Require two finite highlight endpoints (`previousActiveIndex`, `activeIndex`) and `Motion.fast` behaviors.

- [ ] **Step 2: Run RED**

Run:

```bash
python3 scripts/check_bar.py
node scripts/check_workspaces.js
```

Expected: FAIL because the existing numbered-button strip lacks ranges, active icon, wheel handling, and stretchy endpoints.

- [ ] **Step 3: Implement occupied backing ranges**

Keep one five-item `Repeater`. Render contiguous occupied backing from descriptor range metadata behind the slots rather than adding per-window objects. Use fixed slot width and bounded geometry so Start Island does not jump when active icon/title changes.

- [ ] **Step 4: Implement the active stretch and content fallback**

Track previous/current active indices only when `activeWorkspaceId` changes. Draw one active rectangle whose `x` and `width` span the two endpoints during `Motion.fast`, then settle. Show `Shared.SystemIcon` only when the active descriptor has a non-empty icon; otherwise show the numeric label. Keep the inactive occupied/urgent semantic indicator.

- [ ] **Step 5: Add click and wheel intent**

Each slot calls `HyprlandService.activateWorkspace(id)`. A `WheelHandler` converts positive/negative wheel delta to the immediately previous/next workspace ID and accepts the event; it must not wrap across invalid ID `0`.

- [ ] **Step 6: Verify GREEN and QML lint**

Run:

```bash
python3 scripts/check_bar.py
node scripts/check_workspaces.js
./scripts/check.sh
```

Expected: PASS with no new QML warning.

- [ ] **Step 7: Commit workspace presentation**

```bash
git add scripts/check_bar.py Titonium/Bar/widgets/Workspaces.qml
git commit -m "feat: render grouped active workspaces"
```

---

### Task 5: Separate the Dock pin and remove hover text

**Files:**
- Modify: `scripts/check_dock_layout.js`
- Modify: `scripts/check_dock.py`
- Modify: `Titonium/Dock/DockSurface.qml`
- Modify: `Titonium/Dock/DockWindow.qml`
- Modify: `Titonium/Dock/DockAppButton.qml`

**Interfaces:**
- Preserves: `DockStore.setPinnedOpen(bool)` and Dock's 64-pixel pinned reservation.
- Produces: explicit `pinInputRect` in `DockWindow`, disjoint from launcher input geometry.

- [ ] **Step 1: Replace old layout expectations with the desired contract**

In `check_dock_layout.js`, require a 16-pixel `pinControl` hitbox, panel body inset below the root top edge, an explicit `Region { item: pinControl }` or exported `pinHitbox`, and a deterministic geometry assertion proving `pinRight <= launcherLeft`. Reject `QtQuick.Controls`, `ToolTip`, `dock.application_tooltip`, focus calls, key handlers, and FocusScope inside the pin block.

Update `check_dock.py` to require `Shared.SystemIcon`, accessibility metadata, and absence of visual tooltip imports/text.

- [ ] **Step 2: Run RED**

Run:

```bash
node scripts/check_dock_layout.js
python3 scripts/check_dock.py
python3 scripts/check_surface_passthrough.py
```

Expected: FAIL because the old pin sits within the panel/launcher corner and `DockAppButton` still owns a tooltip.

- [ ] **Step 3: Reshape the Dock surface without changing reservation**

Make `DockSurface` root 64 pixels high. Place the 56-pixel visual panel at `x: 8`, `y: 8`, with
8-pixel inner horizontal padding. Place the 16-pixel pin hitbox at `x: 0`, `y: 0`; its right edge
then meets, but does not overlap, the launcher's left edge at root-local `x: 16`. Set root width to
the row width plus 32 pixels and center `dockRow` in the panel, not the root.

Expose the pin item as a read-only alias for `DockWindow` masking/input publication. Keep `visible: root.hovered`, glyph size around 9–10 logical pixels, and pointer-only `HoverHandler`/`TapHandler`.

- [ ] **Step 4: Publish the complete input region**

Update `DockWindow.mask` and `bodyInputRect` to include both panel and pin bounds when revealed. The window must retain `WlrKeyboardFocus.None`; repeated pin/unpin cannot acquire keyboard focus.

- [ ] **Step 5: Remove visual hover text only**

Delete the `QtQuick.Controls` import and both tooltip bindings from `DockAppButton.qml`. Preserve `Accessible.name`, application context menu labels, icon fallback, hover lift/scale, and all mouse/keyboard actions.

- [ ] **Step 6: Verify GREEN**

Run the three commands from Step 2 plus `./scripts/check.sh`.

Expected: PASS; Dock remains pointer-only and the accessibility contract remains present.

- [ ] **Step 7: Commit Dock interaction cleanup**

```bash
git add scripts/check_dock_layout.js scripts/check_dock.py \
  Titonium/Dock/DockSurface.qml Titonium/Dock/DockWindow.qml \
  Titonium/Dock/DockAppButton.qml
git commit -m "fix: isolate dock pin and remove hover labels"
```

---

### Task 6: Add the TopBar Center pin and pinned lifecycle

**Files:**
- Modify: `scripts/check_center_notch.js`
- Modify: `scripts/check_bar.py`
- Create: `Titonium/Bar/islands/CenterGroup.qml`
- Modify: `Titonium/Bar/islands/qmldir`
- Modify: `Titonium/Bar/Bar.qml`
- Modify: `Titonium/Bar/notch/CenterNotchCoordinator.qml`
- Modify: `Titonium/Bar/notch/CenterNotchSurface.qml`
- Modify: `config/i18n/en.json`
- Modify: `config/i18n/vi.json`

**Interfaces:**
- Produces: `CenterNotchCoordinator.pinned: bool`
- Produces: `CenterNotchCoordinator.togglePinned(screenName: string) -> bool`
- Changes: outside-click close is conditional on `!CenterNotchCoordinator.pinned`; explicit close always clears pin.

- [ ] **Step 1: Add pure pinned-state expectations**

Extend `CenterNotchState.js` with pure
`pinTransition(owner, requestedScreen, pinned, action)` to keep coordinator branching testable. In
`check_center_notch.js`, assert:

```js
plain(context.pinTransition("", "DP-1", false, "toggle"))
// => { ownerScreenName: "DP-1", pinned: true, shouldClose: false }
plain(context.pinTransition("DP-1", "DP-1", true, "toggle"))
// => { ownerScreenName: "", pinned: false, shouldClose: true }
```

Also cover explicit close and switching requested screens. `action === "close"` always returns an
empty owner and `pinned: false`; toggling a different non-empty screen transfers ownership and
returns `pinned: true`.

- [ ] **Step 2: Add the static Bar composition contract**

Require one `CenterGroup` in `Bar.qml`, `centerHitbox: centerGroup`, `CenterIsland` followed by a separate pin control in `CenterGroup.qml`, `CenterNotchCoordinator.togglePinned(root.screen.name)`, and translated accessible names. Require center placement to use `BarLayout.centerX(root.width, centerGroup.width)`.

Require `CenterNotchSurface` outside clicks to check `CenterNotchCoordinator.pinned`, while Escape still calls unconditional `close()`.

- [ ] **Step 3: Run RED**

Run:

```bash
node scripts/check_center_notch.js
python3 scripts/check_bar.py
```

Expected: FAIL because CenterGroup, pin state, and pinned outside-click behavior do not exist.

- [ ] **Step 4: Implement coordinator lifecycle**

Add `property bool pinned: false`. `open()` remains unpinned unless invoked by `togglePinned`; `togglePinned(screenName)` opens `overview` and pins when closed, pins an already-open same-screen notch, and closes/clears when already pinned. `close()` always clears owner, page, and pin. Existing monitor-change, Spotlight mutual exclusion, destruction, and Escape already call `close()` and therefore clear pin.

- [ ] **Step 5: Compose the centered group and click-through mask**

Create `CenterGroup.qml` with a `Row`: existing `CenterIsland`, then a compact quiet `Shared.Button` using `keep`/`keep_off`. Export the whole group as the Bar center hitbox. The group—not the old island alone—is centered, so the pin is immediately right of Center without shifting input masking away from the visible geometry.

- [ ] **Step 6: Make outside click pin-aware and add i18n**

In `CenterNotchSurface.qml`, close on outside tap only when not pinned. Keep Escape unconditional. Add exactly:

```json
"menubar.center_pin.open": "Keep Center open",
"menubar.center_pin.close": "Close pinned Center"
```

and natural Vietnamese equivalents in `vi.json`.

- [ ] **Step 7: Verify GREEN**

Run:

```bash
node scripts/check_center_notch.js
python3 scripts/check_bar.py
python3 scripts/validate_config.py
./scripts/check.sh
```

Expected: PASS; Center heavy content remains Loader-controlled and no persistence file changes.

- [ ] **Step 8: Commit Center pin**

```bash
git add scripts/check_center_notch.js scripts/check_bar.py \
  Titonium/Bar/islands/CenterGroup.qml Titonium/Bar/islands/qmldir Titonium/Bar/Bar.qml \
  Titonium/Bar/notch/CenterNotchCoordinator.qml Titonium/Bar/notch/CenterNotchSurface.qml \
  config/i18n/en.json config/i18n/vi.json
git commit -m "feat: pin the center notch from the bar"
```

---

### Task 7: Add focused read-only acceptance and close documentation

**Files:**
- Create: `scripts/workspace_interactions_acceptance.sh`
- Modify: `scripts/check.sh`
- Modify: `scripts/protected_acceptance.sh`
- Modify: `docs/TESTING.md`

**Interfaces:**
- Produces: one read-only acceptance command that starts a temporary foreground Titonium instance and restores one DP-1 daemon afterward at controller level.
- Does not expose mutating Bluetooth, audio, application-launch, clipboard-write, or power IPC.

- [ ] **Step 1: Add an architecture registration test before the script**

Extend `check_bar.py` or `check_window_switcher.py` to require:

```bash
bash -n "$project_root/scripts/workspace_interactions_acceptance.sh"
```

in `scripts/check.sh` and invocation from `protected_acceptance.sh`. Require bounded runtime error tokens and reject `bluetooth`, `audio set`, `launch`, clipboard writes, and Hyprland config writes in the new script.

- [ ] **Step 2: Run RED**

Run: `python3 scripts/check_bar.py`

Expected: FAIL because the acceptance script and registrations are absent.

- [ ] **Step 3: Create the read-only acceptance script**

Follow existing smoke/acceptance helpers. The script must:

- reject a dirty repository introduced during its run;
- hash both Hyprland configuration files before/after;
- launch a bounded foreground `qs -p /home/cole/Projects/titonium` instance;
- require `Configuration Loaded` and reject `ERROR`, `TypeError`, unavailable types, illegal methods, and duplicate IDs;
- read Window Switcher/Center/Dock state only;
- open Center through existing lifecycle IPC, verify state, and close it;
- inspect `hyprctl layers -j` read-only to require Titonium Bar/Dock on DP-1 and none on DP-3;
- clean up only its own temporary Titonium process.

Do not automate Super key release or workspace mutation; those remain manual because they would move the user's live session.

- [ ] **Step 4: Register the script and document the manual checkpoint**

Add syntax validation to `check.sh`, invoke the focused script from `protected_acceptance.sh`, and document manual Super-release, workspace click/wheel, Dock pin keyboard retention, no-tooltip, and Center pin outside-click behavior in `docs/TESTING.md`. State explicitly that Bluetooth is unchanged and excluded.

- [ ] **Step 5: Verify static GREEN before touching the daemon**

Run:

```bash
bash -n scripts/workspace_interactions_acceptance.sh scripts/protected_acceptance.sh
./scripts/check.sh
git diff --check
```

Expected: PASS with only allowlisted PanelWindow metadata warnings.

- [ ] **Step 6: Commit the acceptance slice**

```bash
git add scripts/workspace_interactions_acceptance.sh scripts/check.sh \
  scripts/protected_acceptance.sh scripts/check_bar.py scripts/check_window_switcher.py \
  docs/TESTING.md
git commit -m "test: cover workspace and pin interactions"
```

---

### Task 8: Full DP-1 verification and handoff

**Files:**
- Verify only; do not edit production files unless a reproduced test failure starts a new RED/GREEN cycle.

**Interfaces:**
- Confirms all spec acceptance without mutating Bluetooth.

- [ ] **Step 1: Confirm scope isolation**

Run:

```bash
git status --short
git diff 2880f67..HEAD -- Titonium/Services/Bluetooth Titonium/Overlays/Bluetooth \
  Titonium/Services/Audio
```

Expected: clean status and empty scoped diff for Bluetooth/Audio. The acceptance scripts compare
both Hyprland configuration hashes before and after their live run.

- [ ] **Step 2: Run all static gates**

Run:

```bash
./scripts/check.sh
git diff --check
```

Expected: PASS.

- [ ] **Step 3: Stop only Titonium and run foreground gates**

Run:

```bash
qs -p /home/cole/Projects/titonium kill
./scripts/smoke.sh
./scripts/workspace_interactions_acceptance.sh
./scripts/protected_acceptance.sh
hyprctl configerrors
```

Expected: every script PASS and `hyprctl configerrors` empty. Do not stop the reference Quickshell on DP-3.

- [ ] **Step 4: Restore one Titonium daemon on DP-1**

Run: `qs -d -p /home/cole/Projects/titonium`

Expected: exactly one Titonium instance; Titonium layers only on DP-1.

- [ ] **Step 5: Perform the manual interaction checkpoint with the user**

Verify:

1. Super+Tab cycles and Super release moves to the selected window's workspace.
2. Five workspace slots group correctly; occupied ranges, active icon, click, and wheel behave smoothly.
3. Dock pin appears over the upper-left border only on hover, never triggers Launcher, and repeated pin/unpin leaves typing in the original app.
4. Dock application hover shows no tooltip text.
5. Center pin is immediately right of Center; outside click preserves a pinned notch; Escape, Spotlight, and unpin close and clear it.
6. DP-3 reference shell remains untouched and Bluetooth is tested separately by the user.

- [ ] **Step 6: Record final evidence**

Append the command results and manual checkpoint status to `docs/TESTING.md` only after they are actually observed. If the user reports a defect, reproduce it and start a new focused RED/GREEN cycle before claiming completion.

- [ ] **Step 7: Commit observed verification notes if changed**

```bash
git add docs/TESTING.md
git commit -m "docs: record workspace interaction acceptance"
```

Skip this commit when no documentation content changed.
