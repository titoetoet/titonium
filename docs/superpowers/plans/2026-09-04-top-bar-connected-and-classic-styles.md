# Top Bar Connected and Classic Styles Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a global Connected Notch / Classic Separate Pills Top Bar style while preserving the current code, restoring the Classic presentation from commit `0cb73ec`, and connecting Network, Bluetooth and Audio popups to the right pill in the default style.

**Architecture:** `Preferences.modules.bar.style` selects one complete presentation tree. Current Bar/right-pill components remain the Connected implementation; restored `Classic*` components render the old separate-pill layout and detached popups. A pure routing helper selects Connected or Classic popup descriptors while `SurfaceManager` remains the single lifecycle owner.

**Tech Stack:** Qt 6 QML, Quickshell, JavaScript `.pragma library` helpers, Node.js contract tests, Python architecture checks, shell acceptance scripts.

**Spec:** `docs/superpowers/specs/2026-09-04-top-bar-connected-and-classic-styles-design.md`

## Global Constraints

- `connected` is the default; missing, malformed and unknown style values normalize to `connected`.
- `classic` restores the visual composition of Git commit `0cb73ec` under new `Classic*` names; never checkout old files over current files.
- The selected style is global. Do not add per-control visibility/style settings or mix Classic pills with Connected popups.
- Services remain the sole native Network, Bluetooth, Audio and System Tray owners.
- `SurfaceManager` remains the single transient-surface mutual-exclusion authority.
- Both styles remain restricted to `ScreenPolicy.screens`; no Titonium surface may fall back to an ineligible output.
- Automated tests must not toggle radios, connect devices, change volume, launch applications, write clipboard contents or edit Hyprland configuration.
- Preserve unrelated dirty-worktree changes. Stage and commit only files owned by the current task.

---

### Task 1: Bar style preference and Settings control

**Files:**
- Modify: `Titonium/Core/Runtime/PreferencesValidator.js`
- Modify: `Titonium/Core/Runtime/Preferences.qml`
- Modify: `config/defaults/settings.json`
- Modify: `Titonium/Settings/pages/BarPage.qml`
- Modify: `config/i18n/en.json`
- Modify: `config/i18n/vi.json`
- Modify: `scripts/check_preferences.js`
- Modify: `scripts/check_settings_pages.py`
- Modify: `tests/fixtures/settings-v7-runtime.json`

**Interfaces:**
- Produces: `Preferences.barStyle: string`, always `"connected"` or `"classic"`.
- Produces: persisted `modules.bar.style` and a Bar-page two-choice selector.

- [ ] **Step 1: Write failing preference tests**

Add literal assertions to `scripts/check_preferences.js`:

```js
assert.equal(projectedDefaults.modules.bar.style, "connected");
assert.equal(context.project({ modules: { bar: { style: "classic" } } }, defaults, null)
    .modules.bar.style, "classic");
assert.equal(context.project({ modules: { bar: { style: "detached-ish" } } }, defaults, null)
    .modules.bar.style, "connected");
assert.equal(context.project({ modules: { bar: { style: 12 } } }, defaults, null)
    .modules.bar.style, "connected");
```

Extend `scripts/check_settings_pages.py` to require:

```python
'Preferences.patch("modules.bar.style"'
'settings.bar.style'
'settings.bar.style.connected'
'settings.bar.style.classic'
```

- [ ] **Step 2: Verify RED**

Run: `node scripts/check_preferences.js && python3 scripts/check_settings_pages.py`

Expected: FAIL because the projected Bar record and Settings page do not expose `style`.

- [ ] **Step 3: Implement normalization and projection**

Add to the projected Bar record:

```js
style: oneOf(bar.style, ["connected", "classic"],
    oneOf(fallbackBar.style, ["connected", "classic"], "connected")),
```

Add to `Preferences.qml`:

```qml
readonly property string barStyle: root.bar.style === "classic" ? "classic" : "connected"
```

Add `"style": "connected"` to shipped defaults and the v7 fixture. On `BarPage.qml`, use the existing shared select/segmented-control pattern to patch exactly `modules.bar.style`; add Vietnamese and English title, description and choice labels.

- [ ] **Step 4: Verify GREEN**

Run: `node scripts/check_preferences.js && python3 scripts/check_settings_pages.py && python3 scripts/validate_config.py`

Expected: PASS with locale parity and schema validation clean.

- [ ] **Step 5: Commit only Task 1 files**

```bash
git add Titonium/Core/Runtime/PreferencesValidator.js Titonium/Core/Runtime/Preferences.qml \
  config/defaults/settings.json Titonium/Settings/pages/BarPage.qml config/i18n/en.json \
  config/i18n/vi.json scripts/check_preferences.js scripts/check_settings_pages.py \
  tests/fixtures/settings-v7-runtime.json
git commit -m "feat: add top bar style preference"
```

### Task 2: Pure popup-style routing contract

**Files:**
- Create: `Titonium/Bar/right/BarPopupRouting.js`
- Create: `scripts/check_bar_popup_routing.js`
- Modify: `scripts/check.sh`

**Interfaces:**
- Produces: `normalizeStyle(value): "connected" | "classic"`.
- Produces: `presentation(style, feature): { owner: string, source: string, anchor: string } | null`.
- Supported features: `network`, `bluetooth`, `audio`, `input`, `app`.

- [ ] **Step 1: Write the failing table-driven test**

Create `scripts/check_bar_popup_routing.js` and load the `.pragma library` helper with the same VM loader used by `check_right_pill_state.js`. Assert these hand-derived values:

```js
assert.equal(routing.normalizeStyle("classic"), "classic");
assert.equal(routing.normalizeStyle("CONNECTED"), "connected");
assert.deepEqual(JSON.parse(JSON.stringify(routing.presentation("connected", "network"))), {
  owner: "edge", source: "ConnectedNetworkPopupContent.qml", anchor: "network"
});
assert.deepEqual(JSON.parse(JSON.stringify(routing.presentation("classic", "network"))), {
  owner: "overlay", source: "ClassicNetworkPopupSurface.qml", anchor: ""
});
assert.deepEqual(JSON.parse(JSON.stringify(routing.presentation("connected", "audio"))), {
  owner: "edge", source: "ConnectedAudioPopupContent.qml", anchor: "audio"
});
assert.equal(routing.presentation("classic", "input").owner, "overlay");
assert.equal(routing.presentation("connected", "unknown"), null);
```

- [ ] **Step 2: Verify RED**

Run: `node scripts/check_bar_popup_routing.js`

Expected: FAIL because `BarPopupRouting.js` does not exist.

- [ ] **Step 3: Implement the smallest immutable route table**

```js
.pragma library

function normalizeStyle(value) {
    return value === "classic" ? "classic" : "connected";
}

function presentation(style, feature) {
    const routes = normalizeStyle(style) === "classic" ? {
        network: ["overlay", "ClassicNetworkPopupSurface.qml", ""],
        bluetooth: ["overlay", "ClassicBluetoothPopupSurface.qml", ""],
        audio: ["overlay", "ClassicAudioPopupSurface.qml", ""],
        input: ["overlay", "ClassicSystemTrayPopupSurface.qml", ""],
        app: ["overlay", "ClassicSystemTrayPopupSurface.qml", ""],
    } : {
        network: ["edge", "ConnectedNetworkPopupContent.qml", "network"],
        bluetooth: ["edge", "ConnectedBluetoothPopupContent.qml", "bluetooth"],
        audio: ["edge", "ConnectedAudioPopupContent.qml", "audio"],
        input: ["edge", "SystemTrayMenuView.qml", "input"],
        app: ["edge", "SystemTrayMenuView.qml", "app"],
    };
    const route = routes[feature];
    return route ? { owner: route[0], source: route[1], anchor: route[2] } : null;
}
```

Register the test directly after `check_right_pill_state.js` in `scripts/check.sh`.

- [ ] **Step 4: Verify GREEN**

Run: `node scripts/check_bar_popup_routing.js && ./scripts/check.sh`

Expected: routing test passes; any unrelated pre-existing full-gate failure is recorded rather than hidden.

- [ ] **Step 5: Commit only Task 2 files**

```bash
git add Titonium/Bar/right/BarPopupRouting.js scripts/check_bar_popup_routing.js scripts/check.sh
git commit -m "test: define top bar popup style routing"
```

### Task 3: Restore the Classic separate-pill Top Bar

**Files:**
- Create: `Titonium/Bar/classic/ClassicBar.qml`
- Create: `Titonium/Bar/classic/ClassicStartIsland.qml`
- Create: `Titonium/Bar/classic/ClassicCenterGroup.qml`
- Create: `Titonium/Bar/classic/ClassicEndIsland.qml`
- Create: `Titonium/Bar/classic/qmldir`
- Modify: `Titonium/Bar/BarSurface.qml`
- Modify: `Titonium/Bar/BarHost.qml`
- Create: `scripts/check_classic_bar.js`
- Modify: `scripts/check.sh`

**Interfaces:**
- Produces: `ClassicBar.screen`, `ClassicBar.leftHitbox`, `centerHitbox`, `notificationHitbox`, `rightHitbox`, `hovered`.
- Consumes: current leaf controls and `Preferences.barStyle`.

- [ ] **Step 1: Write the failing Classic composition test**

Create `scripts/check_classic_bar.js`. Validate the restored QML files exist, run the repository QML linter through the existing check harness, and require these public facts:

```js
const required = [
  "Titonium/Bar/classic/ClassicBar.qml",
  "Titonium/Bar/classic/ClassicStartIsland.qml",
  "Titonium/Bar/classic/ClassicCenterGroup.qml",
  "Titonium/Bar/classic/ClassicEndIsland.qml",
  "Titonium/Bar/classic/qmldir",
];
for (const file of required)
  assert.equal(fs.existsSync(path.join(root, file)), true, `${file} must exist`);
```

Add checks that the Classic files contain separate `Shared.Surface` owners for Arch/Workspace,
Active Window, Center, Notification, Pin, Connectivity and Status groups, and that `BarSurface`
selects one tree from `Preferences.barStyle` rather than making both hit-testable.

- [ ] **Step 2: Verify RED**

Run: `node scripts/check_classic_bar.js`

Expected: FAIL because the `classic` module does not exist.

- [ ] **Step 3: Restore under new names**

Use `git show 0cb73ec:<path>` as read-only source. Recreate the checkpoint composition under
`Titonium/Bar/classic/`, changing imports and component names only. `ClassicStartIsland` contains
the separate Arch, Workspace and Active Window pills; `ClassicEndIsland` contains separate Pin,
Connectivity and Status pills; `ClassicCenterGroup` wraps only Center. Recreate the separate
Notification placement in `ClassicBar`.

In `BarSurface`, use two Loaders with mutually exclusive activation:

```qml
Loader {
    id: connectedBarLoader
    active: Preferences.barStyle === "connected"
    sourceComponent: connectedBarComponent
}
Loader {
    id: classicBarLoader
    active: Preferences.barStyle === "classic"
    sourceComponent: classicBarComponent
}
```

Derive the input mask aliases from the active item only. In `BarHost`, keep Center/Edge windows
mounted but pass `styleActive: Preferences.barStyle === "connected"` so they become inert in
Classic mode.

- [ ] **Step 4: Verify GREEN**

Run: `node scripts/check_classic_bar.js && python3 scripts/check_bar.py && ./scripts/check.sh`

Expected: Classic composition test and Bar contracts pass without duplicate input regions.

- [ ] **Step 5: Commit only Task 3 files**

```bash
git add Titonium/Bar/classic Titonium/Bar/BarSurface.qml Titonium/Bar/BarHost.qml \
  scripts/check_classic_bar.js scripts/check.sh
git commit -m "feat: restore classic separate top bar pills"
```

### Task 4: Preserve detached Classic popup surfaces

**Files:**
- Create: `Titonium/Overlays/Network/ClassicNetworkPopupSurface.qml`
- Create: `Titonium/Overlays/Bluetooth/ClassicBluetoothPopupSurface.qml`
- Create: `Titonium/Overlays/Audio/ClassicAudioPopupSurface.qml`
- Create: `Titonium/Overlays/SystemTray/ClassicSystemTrayPopupSurface.qml`
- Modify: each affected `qmldir`
- Modify: `scripts/check_wifi.py`
- Modify: `scripts/check_bluetooth.py`
- Modify: `scripts/check_audio.py`
- Modify: `scripts/check_right_pill.js`

**Interfaces:**
- Produces detached full-screen FocusScope surfaces with `descriptor`, `screen`, `close()` and Escape/outside-click behavior.
- Consumes current feature services and current row components; no old service code is restored.

- [ ] **Step 1: Add failing Classic popup contracts**

Require each Classic surface to exist and expose `property var descriptor`, `property var screen`,
`Shared.Panel`, `SurfaceManager.close`, `Keys.onEscapePressed`, and a full-screen transparent
outside-click handler. Require System Tray Classic content to consume current
`SystemTrayService.popupEntries` and current navigation intents.

- [ ] **Step 2: Verify RED**

Run: `python3 scripts/check_wifi.py && python3 scripts/check_bluetooth.py && python3 scripts/check_audio.py && node scripts/check_right_pill.js`

Expected: FAIL with missing `Classic*PopupSurface.qml` contracts.

- [ ] **Step 3: Restore and adapt the surfaces**

Copy presentation structure from `0cb73ec` using `git show`, under the new filenames. Retain these
detached geometry values from the checkpoint/current detached implementation:

```qml
readonly property real panelTop: Metrics.barHeight + Metrics.barSpacing
anchors.rightMargin: Metrics.barPadding
width: 380
```

Keep current services, current rows and current content calculations. For System Tray, reconstruct
the detached shell around the current `SystemTrayMenuView`; do not revive a native menu owner.

- [ ] **Step 4: Verify GREEN**

Run the four focused commands from Step 2, then `./scripts/check.sh`.

Expected: all focused contracts pass; only current services own native integrations.

- [ ] **Step 5: Commit only Task 4 files**

```bash
git add Titonium/Overlays/Network/ClassicNetworkPopupSurface.qml \
  Titonium/Overlays/Bluetooth/ClassicBluetoothPopupSurface.qml \
  Titonium/Overlays/Audio/ClassicAudioPopupSurface.qml \
  Titonium/Overlays/SystemTray/ClassicSystemTrayPopupSurface.qml \
  Titonium/Overlays/Network/qmldir Titonium/Overlays/Bluetooth/qmldir \
  Titonium/Overlays/Audio/qmldir Titonium/Overlays/SystemTray/qmldir \
  scripts/check_wifi.py scripts/check_bluetooth.py scripts/check_audio.py scripts/check_right_pill.js
git commit -m "feat: preserve classic detached popups"
```

### Task 5: Extract Connected feature popup content

**Files:**
- Create: `Titonium/Overlays/Network/ConnectedNetworkPopupContent.qml`
- Create: `Titonium/Overlays/Bluetooth/ConnectedBluetoothPopupContent.qml`
- Create: `Titonium/Overlays/Audio/ConnectedAudioPopupContent.qml`
- Modify: each affected `qmldir`
- Create: `scripts/check_connected_popup_content.js`
- Modify: `scripts/check.sh`

**Interfaces:**
- Each content component produces `implicitContentWidth`, `implicitContentHeight`, `dismissRequested()` and a content-only visual tree.
- Content components never paint `Shared.Panel`, own a full-screen TapHandler or call `SurfaceManager.close` directly.

- [ ] **Step 1: Write the failing content-boundary test**

For all three files assert existence and the public properties/signals above. Reject
`Shared.Panel`, `anchors.fill: parent` on an outside-click rectangle, independent entrance/exit
animations and direct `SurfaceManager.close` calls.

- [ ] **Step 2: Verify RED**

Run: `node scripts/check_connected_popup_content.js`

Expected: FAIL because the Connected content components do not exist.

- [ ] **Step 3: Extract current content without its detached shell**

Move/copy only each existing panel's inner content into its Connected component. Root sizing uses:

```qml
readonly property real implicitContentWidth: 380
readonly property real implicitContentHeight: contentColumn.implicitHeight + 32
implicitWidth: implicitContentWidth
implicitHeight: implicitContentHeight
```

Audio preserves its bounded device and stream calculations, but receives the available viewport
height as a property from `EdgeMenuSurface` instead of reading full-screen panel coordinates.

- [ ] **Step 4: Verify GREEN**

Run: `node scripts/check_connected_popup_content.js && python3 scripts/check_wifi.py && python3 scripts/check_bluetooth.py && python3 scripts/check_audio.py`

Expected: all content and feature contracts pass.

- [ ] **Step 5: Commit only Task 5 files**

```bash
git add Titonium/Overlays/Network/ConnectedNetworkPopupContent.qml \
  Titonium/Overlays/Bluetooth/ConnectedBluetoothPopupContent.qml \
  Titonium/Overlays/Audio/ConnectedAudioPopupContent.qml \
  Titonium/Overlays/Network/qmldir Titonium/Overlays/Bluetooth/qmldir \
  Titonium/Overlays/Audio/qmldir scripts/check_connected_popup_content.js scripts/check.sh
git commit -m "feat: add connected connectivity popup content"
```

### Task 6: Add connectivity anchors and connected Loader ownership

**Files:**
- Modify: `Titonium/Bar/islands/ConnectivityPill.qml`
- Modify: `Titonium/Bar/islands/EndIsland.qml`
- Modify: `Titonium/Bar/right/EdgeMenuSurface.qml`
- Modify: `Titonium/Bar/right/EdgeMenuWindow.qml`
- Modify: `Titonium/Core/Surfaces/OverlayHost.qml`
- Modify: `Titonium/Bar/right/RightPillCoordinator.qml`
- Modify: `scripts/check_edge_menu_geometry.js`
- Modify: `scripts/check_right_pill.js`
- Modify: `scripts/check_surface_passthrough.py`

**Interfaces:**
- `ConnectivityPill.anchorRect(name): rect` supports `network`, `bluetooth`, `audio`.
- `EndIsland.connectivityAnchorRect(name): rect` converts the child rectangle to EndIsland coordinates.
- Connected descriptors contain `barConnected: true`, `anchor`, and `source`.

- [ ] **Step 1: Write failing anchor and exclusive-owner tests**

Add literal geometry fixtures proving three 28-pixel controls select distinct source centers and
the resulting 380-pixel right branch clamps to the 12-pixel margin. Extend right-pill and surface
checks to require the Edge Loader for `descriptor.barConnected === true` and require OverlayHost's
Loader condition to exclude it.

- [ ] **Step 2: Verify RED**

Run: `node scripts/check_edge_menu_geometry.js && node scripts/check_right_pill.js && python3 scripts/check_surface_passthrough.py`

Expected: FAIL because anchor selection and connected descriptor ownership are absent.

- [ ] **Step 3: Publish anchors and load the selected content**

In `ConnectivityPill.qml`:

```qml
function anchorRect(name: string): rect {
    const item = name === "network" ? networkButton
        : (name === "bluetooth" ? bluetoothButton : (name === "audio" ? audioButton : null));
    return item ? Qt.rect(iconRow.x + item.x, iconRow.y + item.y, item.width, item.height)
        : Qt.rect(0, 0, 0, 0);
}
```

Forward the rect through `EndIsland`, freeze it when opening, and feed it into the existing
`EdgeMenuGeometry.branchRect("right", ...)`. Add one Loader inside the existing branch clip whose
source comes from the connected descriptor. Keep `EndIsland` above the shape so icons stay visible.

In `OverlayHost.qml`, set Loader activation to:

```qml
active: window.ownsSurface && Boolean(SurfaceManager.descriptor.source)
    && SurfaceManager.descriptor.barConnected !== true
```

Extend window focus and masks so the connected descriptor uses the Edge window exclusively.

- [ ] **Step 4: Verify GREEN**

Run the three focused commands from Step 2, then `./scripts/check.sh`.

Expected: one visual/input owner, three distinct anchors and clean geometry contracts.

- [ ] **Step 5: Commit only Task 6 files**

```bash
git add Titonium/Bar/islands/ConnectivityPill.qml Titonium/Bar/islands/EndIsland.qml \
  Titonium/Bar/right/EdgeMenuSurface.qml Titonium/Bar/right/EdgeMenuWindow.qml \
  Titonium/Bar/right/RightPillCoordinator.qml Titonium/Core/Surfaces/OverlayHost.qml \
  scripts/check_edge_menu_geometry.js scripts/check_right_pill.js scripts/check_surface_passthrough.py
git commit -m "feat: connect right pill feature popup ownership"
```

### Task 7: Route all coordinators by the selected style

**Files:**
- Modify: `Titonium/Overlays/Network/NetworkPopupCoordinator.qml`
- Modify: `Titonium/Overlays/Bluetooth/BluetoothPopupCoordinator.qml`
- Modify: `Titonium/Overlays/Audio/AudioPopupCoordinator.qml`
- Modify: `Titonium/Bar/islands/ConnectivityPill.qml`
- Modify: `Titonium/Bar/islands/ActiveWindowPill.qml`
- Modify: `Titonium/Bar/widgets/InputMethod.qml`
- Modify: `Titonium/Bar/right/RightPillCoordinator.qml`
- Create: `scripts/check_top_bar_style_lifecycle.js`
- Modify: `scripts/check.sh`

**Interfaces:**
- All existing public `open`, `toggle`, `close`, `openForIpc` signatures remain stable.
- Coordinator descriptors add `barConnected`, `anchor`, `feature`, and generation-safe owner facts.

- [ ] **Step 1: Write failing descriptor/lifecycle tests**

Require Connected Network/Bluetooth/Audio routes to produce `barConnected: true` with their exact
anchor and Connected source. Require Classic routes to produce `barConnected: false` with the
matching `Classic*PopupSurface`. Add state fixtures proving a stale close generation cannot close
a newer owner and a style change requests close before activating the alternate tree.

- [ ] **Step 2: Verify RED**

Run: `node scripts/check_top_bar_style_lifecycle.js && node scripts/check_bar_popup_routing.js`

Expected: FAIL because coordinators ignore `Preferences.barStyle` and no generation guard exists.

- [ ] **Step 3: Centralize descriptor construction**

Each coordinator reads `BarPopupRouting.presentation(Preferences.barStyle, feature)` and constructs:

```qml
{
    "source": Qt.resolvedUrl(route.source),
    "keyboardFocus": "exclusive",
    "closeOnMonitorChange": true,
    "ownerId": owner,
    "feature": feature,
    "barConnected": route.owner === "edge",
    "anchor": route.anchor,
    "invoker": invoker,
}
```

Pass `audioButton` into `AudioPopupCoordinator.toggle(root.screen, audioButton)`. Route Classic
Active Window and Input Method through the detached System Tray surface. Add one preference-change
connection that closes the current owner and both visual coordinators before the alternate tree is
made interactive; guard finish callbacks by owner ID/generation.

- [ ] **Step 4: Verify GREEN**

Run: `node scripts/check_top_bar_style_lifecycle.js && node scripts/check_bar_popup_routing.js && ./scripts/check.sh`

Expected: style routing and lifecycle contracts pass with unchanged public coordinator methods.

- [ ] **Step 5: Commit only Task 7 files**

```bash
git add Titonium/Overlays/Network/NetworkPopupCoordinator.qml \
  Titonium/Overlays/Bluetooth/BluetoothPopupCoordinator.qml \
  Titonium/Overlays/Audio/AudioPopupCoordinator.qml Titonium/Bar/islands/ConnectivityPill.qml \
  Titonium/Bar/islands/ActiveWindowPill.qml Titonium/Bar/widgets/InputMethod.qml \
  Titonium/Bar/right/RightPillCoordinator.qml scripts/check_top_bar_style_lifecycle.js scripts/check.sh
git commit -m "feat: route top bar popups by style"
```

### Task 8: Full verification and documentation alignment

**Files:**
- Modify: `docs/ARCHITECTURE.md`
- Modify: `docs/TESTING.md`
- Modify only if a verified contract requires it: affected acceptance scripts.

**Interfaces:**
- Produces a documented, verified two-style Top Bar contract.

- [ ] **Step 1: Run all focused static checks**

```bash
node scripts/check_preferences.js
python3 scripts/check_settings_pages.py
node scripts/check_bar_popup_routing.js
node scripts/check_classic_bar.js
node scripts/check_connected_popup_content.js
node scripts/check_edge_menu_geometry.js
node scripts/check_right_pill.js
node scripts/check_top_bar_style_lifecycle.js
python3 scripts/check_wifi.py
python3 scripts/check_bluetooth.py
python3 scripts/check_audio.py
python3 scripts/check_surface_passthrough.py
```

Expected: every focused check passes.

- [ ] **Step 2: Run repository static and formatting gates**

Run: `./scripts/check.sh && git diff --check`

Expected: PASS with no new QML warnings or whitespace errors.

- [ ] **Step 3: Update architecture/testing docs**

Document `modules.bar.style`, the Connected Edge owner, Classic restored tree, exclusive Loader
ownership, migration behavior and both manual review modes. Do not claim live checks that were not
actually run.

- [ ] **Step 4: Run safe live acceptance**

```bash
./scripts/smoke.sh
./scripts/settings_acceptance.sh
./scripts/audio_acceptance.sh
./scripts/bluetooth_acceptance.sh
./scripts/wifi_acceptance.sh
./scripts/protected_acceptance.sh
hyprctl configerrors
```

Expected: all scripts pass, one Titonium Top Bar exists on DP-1, no Titonium layer exists on DP-3,
and both Hyprland hashes remain unchanged.

- [ ] **Step 5: Manually inspect both styles without mutating devices**

Use Settings preview to switch Connected → Classic → Cancel, then Connected → Classic → Apply.
Verify separate Classic pill gaps and detached popups, then return to Connected and verify Wi-Fi,
Bluetooth and Audio grow from their own right-pill anchors. Check Escape, outside click, switching
controls, a style switch with a popup open and scales 1.0/1.5. Do not power/scan/connect Bluetooth
or Wi-Fi and do not change audio controls during this visual pass.

- [ ] **Step 6: Commit documentation and any acceptance-only adjustments**

```bash
git add docs/ARCHITECTURE.md docs/TESTING.md
git commit -m "docs: document selectable top bar styles"
```

- [ ] **Step 7: Final mutation and scope review**

Confirm the tests fail if: the default becomes Classic, an unknown value stops normalizing, an
OverlayHost loads a Connected descriptor, two styles expose hitboxes simultaneously, Network and
Bluetooth anchors are swapped, or a stale close clears a newer owner. Run `git status --short` and
verify no unrelated user-owned file was staged or committed.
