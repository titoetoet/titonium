# Titonium Native Dock + Bluetooth Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Correct the Audio popup geometry, then deliver a DP-1-only native Dock and Bluetooth popup without adding any non-QML runtime backend.

**Architecture:** Dock is a persistent screen-scoped edge surface driven by a normalized Hyprland model and a single persistence owner. Bluetooth is a lazy transient surface driven by one native `Quickshell.Bluetooth` service; both features reuse Titonium screen, theme, i18n and surface contracts while shared integration files remain sequentially owned.

**Tech Stack:** Quickshell 0.3.1, Qt 6 QML/JavaScript, `Quickshell.Hyprland`, `Quickshell.Bluetooth`, Node.js pure-rule fixtures, Python static source gates and shell read-only acceptance.

**Spec:** `docs/superpowers/specs/2026-08-27-dock-bluetooth-native-design.md`

## Global Constraints

- Runtime is pure QML/JavaScript: no Go, Python, shell helper, external daemon, `Process`, raw `hyprctl`, `bluetoothctl`, `wpctl` or polling loop.
- Titonium surfaces remain restricted to `ScreenPolicy.screens`, currently `DP-1`; create no surface or exclusive zone on `DP-3`.
- Preserve Spotlight, Input Method, existing keybindings and both `hyprland.lua` files byte-for-byte.
- Dock presentation is solid Neutral Utility: no glass, blur, shader, `MultiEffect`, gradient, glow or infinite animation.
- Bluetooth imports and mutates native objects only inside `BluetoothService.qml`; Dock raw toplevels stay private to `DockService.qml`.
- UI owns no `FileView`, persistence, native model or raw compositor command.
- All transient heavy trees use `SurfaceManager` and `OverlayHost.Loader.active`; only one transient owner is open.
- Automated tests never launch/focus/close applications and never mutate real Audio or Bluetooth state.
- Every QML directory has a `qmldir`; user-facing strings use `I18n.tr()` with EN/VI parity.
- Workers do not start Quickshell daemons. Only the controller runs live acceptance and restores one DP-1 Titonium daemon.

---

## File Structure

### Audio prerequisite

- Modify `Titonium/Overlays/Audio/AudioPopupSurface.qml`: count `Panel.padding` exactly once.
- Modify `scripts/check_audio.py`: assert the surface does not add a second content margin.
- Create `scripts/check_audio_geometry.js`: pure fixed/stream/outer-height fixture.
- Modify `scripts/check.sh`: register the geometry fixture.

### Dock domain, service and persistence

- Create `Titonium/Services/Dock/DockRules.js`: pure projection, stable order, visibility and cycle rules.
- Create `Titonium/Services/Dock/DockStore.qml`: sole `FileView` owner for `dock.json`.
- Create `Titonium/Services/Dock/DockService.qml`: sole raw Hyprland toplevel owner and intent API.
- Create `Titonium/Services/Dock/qmldir`: export both singleton services.
- Create `config/defaults/dock.json`: immutable v1 defaults.
- Create `config/schemas/dock.schema.json`: shipped v1 validation contract.
- Create `scripts/check_dock_rules.js`: pure domain fixtures.
- Create `scripts/check_dock_store.py`: schema, persistence and architecture source gate.
- Create `scripts/check_dock.py`: QML ownership and forbidden-dependency gate.

### Dock presentation

- Create `Titonium/Dock/DockHost.qml`: `Variants(ScreenPolicy.screens)` lifecycle.
- Create `Titonium/Dock/DockWindow.qml`: DP-1 panel, mask and exclusive-zone lifecycle.
- Create `Titonium/Dock/DockSurface.qml`: visual ordering and keyboard focus.
- Create `Titonium/Dock/DockAppButton.qml`: one normalized app group.
- Create `Titonium/Dock/DockItemMenuCoordinator.qml`: SurfaceManager descriptor owner.
- Create `Titonium/Dock/DockItemMenuSurface.qml`: lazy item actions and inline focus return.
- Create `Titonium/Dock/qmldir`: presentation exports.
- Create `scripts/check_dock_layout.js`: dimensions, reveal and reserve fixtures.

### Bluetooth domain and presentation

- Create `Titonium/Services/Bluetooth/BluetoothRules.js`: pure normalization, grouping, sorting and state text keys.
- Create `Titonium/Services/Bluetooth/BluetoothService.qml`: sole native Bluetooth owner.
- Create `Titonium/Services/Bluetooth/qmldir`: singleton export.
- Create `Titonium/Overlays/Bluetooth/BluetoothPopupCoordinator.qml`: SurfaceManager owner.
- Create `Titonium/Overlays/Bluetooth/BluetoothPopupSurface.qml`: lazy header and section list.
- Create `Titonium/Overlays/Bluetooth/BluetoothDeviceRow.qml`: device state/actions and inline forget confirmation.
- Create `Titonium/Overlays/Bluetooth/qmldir`: presentation exports.
- Create `scripts/check_bluetooth_rules.js`: pure model fixtures.
- Create `scripts/check_bluetooth.py`: native-owner, lazy-loader and forbidden-dependency gate.
- Create `scripts/bluetooth_acceptance.sh`: read-only IPC/transient acceptance.

### Shared integration and delivery

- Modify `Titonium/App.qml`: compose Dock and add read-only Dock/Bluetooth IPC.
- Modify `Titonium/Bar/islands/ConnectivityPill.qml`: replace diagnostic Bluetooth glyph with native button.
- Modify `config/i18n/en.json` and `config/i18n/vi.json`: namespaced Dock/Bluetooth strings.
- Modify `scripts/check.sh`: register all static and syntax gates.
- Modify `scripts/protected_acceptance.sh`: include read-only Dock/Bluetooth acceptance.
- Create `scripts/dock_acceptance.sh`: DP-1-only state/layer checks.
- Create `docs/references/AMBXST_DOCK.md`: provenance, inspected revision/license/files and adaptation boundary.
- Modify `docs/TESTING.md`: commands and safe manual checkpoint.
- Modify `docs/ROADMAP.md`: record completion and defer Network/Wi-Fi.

---

### Task 1: Correct Audio popup geometry

**Files:**
- Modify: `Titonium/Overlays/Audio/AudioPopupSurface.qml`
- Modify: `scripts/check_audio.py`
- Create: `scripts/check_audio_geometry.js`
- Modify: `scripts/check.sh`

**Interfaces:**
- Consumes: `Shared.Panel.padding === Metrics.spacingLarge` and the existing `fixedContentHeight`, `streamHeight`, `maximumHeight` properties.
- Produces: `panel.height = min(maximumHeight, availableHeight, fixedContentHeight + streamHeight + 2 * panel.padding)` with the child layout filling `panel.contentItem` without another margin.

- [ ] **Step 1: Add the failing geometry and source assertions**

  In `scripts/check_audio_geometry.js`, calculate fixed content `236`, stream content `120`, padding `16` and assert outer height `388`, then assert capped height never exceeds `availableHeight`. In `scripts/check_audio.py`, reject `ColumnLayout` margins inside `AudioPopupSurface.qml` and require `2 * panel.padding` in the height expression.

- [ ] **Step 2: Prove RED**

  Run: `node scripts/check_audio_geometry.js && python3 scripts/check_audio.py`

  Expected: FAIL because current height omits outer padding and the child has `anchors.margins`.

- [ ] **Step 3: Make the minimal geometry correction**

  Remove `anchors.margins: Metrics.spacingLarge` from the `ColumnLayout`; change panel height to include `2 * panel.padding`; compute `maximumStreamHeight` after subtracting the same outer padding exactly once.

- [ ] **Step 4: Prove GREEN and preserve Audio behavior**

  Run: `node scripts/check_audio_geometry.js && python3 scripts/check_audio.py && node scripts/check_audio_rules.js && ./scripts/check.sh`

  Expected: all PASS; `qmllint` has only the existing allowlisted `PanelWindow` warnings.

- [ ] **Step 5: Commit**

  ```bash
  git add Titonium/Overlays/Audio/AudioPopupSurface.qml scripts/check_audio.py scripts/check_audio_geometry.js scripts/check.sh
  git commit -m "fix: correct audio popup content geometry"
  ```

### Task 2: Build Dock pure rules and persistence

**Files:**
- Create: `Titonium/Services/Dock/DockRules.js`
- Create: `Titonium/Services/Dock/DockStore.qml`
- Create: `Titonium/Services/Dock/qmldir`
- Create: `config/defaults/dock.json`
- Create: `config/schemas/dock.schema.json`
- Create: `scripts/check_dock_rules.js`
- Create: `scripts/check_dock_store.py`

**Interfaces:**
- Consumes: `Quickshell.dataPath("dock.json")`, `Quickshell.configPath("config/defaults/dock.json")`, `FileView.setText()` and `Logger.warn(scope, message)`.
- Produces from `DockRules.js`: `normalizeState(raw): object`, `mergeItems(pinnedIds, runningGroups, entriesById, firstSeenIds): array`, `nextCycleIndex(previousIndex, count): int`, `shouldReveal(autoHide, pinnedOpen, activeWorkspaceWindowCount, edgeHovered, dockHovered): bool`.
- Produces from `DockStore`: read-only `pinnedIds: array`, `pinnedOpen: bool`, `autoHide: bool`, `ready: bool`; methods `togglePin(appId): bool`, `setPinnedOpen(value): bool`, `setAutoHide(value): bool`, `snapshot(): object`.

- [ ] **Step 1: Write failing DockRules fixtures**

  Cover non-empty-string filtering, stable dedupe, unknown pin retention in normalized state, hidden unknown pins in projection, stable pinned order, first-seen unpinned order, active/urgent aggregation, cycle wrap and reveal truth table.

- [ ] **Step 2: Prove domain RED**

  Run: `node scripts/check_dock_rules.js`

  Expected: FAIL because `DockRules.js` does not exist.

- [ ] **Step 3: Implement pure deterministic rules**

  Return new arrays/objects, never retain QML/native objects, compare IDs case-insensitively for grouping while preserving the canonical persisted ID, and hide unavailable pinned entries only from `mergeItems()` output.

- [ ] **Step 4: Prove rules GREEN**

  Run: `node scripts/check_dock_rules.js`

  Expected: PASS with one summary line for each rule family.

- [ ] **Step 5: Add failing persistence/schema gates**

  Require exact schema `titonium.dock/v1`, version `1`, defaults `[]/false/true`, sole `FileView` ownership in `DockStore.qml`, data path write target, shipped-default read target, bounded corruption warning and no repository/config mutation path.

- [ ] **Step 6: Prove persistence RED, implement store, then prove GREEN**

  Run before implementation: `python3 scripts/check_dock_store.py` (expected FAIL). Implement a single watched `FileView`, project through `DockRules.normalizeState`, serialize only the three public values plus schema fields, and call `setText(JSON.stringify(value, null, 2))`. Run again; expected PASS.

- [ ] **Step 7: Commit**

  ```bash
  git add Titonium/Services/Dock config/defaults/dock.json config/schemas/dock.schema.json scripts/check_dock_rules.js scripts/check_dock_store.py
  git commit -m "feat: add dock rules and runtime store"
  ```

### Task 3: Build native Dock service

**Files:**
- Create: `Titonium/Services/Dock/DockService.qml`
- Modify: `Titonium/Services/Dock/qmldir`
- Create: `scripts/check_dock.py`

**Interfaces:**
- Consumes: `Hyprland.toplevels.values`, `Hyprland.focusedToplevel`, `ApplicationService.desktopEntryForAppId(appId)`, `iconForAppId(appId)`, `nameForAppId(appId)`, `launch(entryId)` and Task 2 contracts.
- Produces: read-only `items: array`, `activeWorkspaceWindowCount: int`; methods `activateOrLaunch(appId): bool`, `launchNew(appId): bool`, `closeActive(appId): bool`, `togglePin(appId): bool`, `snapshot(): string`. Each item is `{appId,name,icon,runningCount,active,urgent,pinned}` and contains no native object.

- [ ] **Step 1: Add a failing ownership/API gate**

  Assert only `DockService.qml` imports `Quickshell.Hyprland` under the Dock slice, descriptors contain the seven exact public fields, raw toplevels are held in a private lookup keyed by normalized app ID, and mutation methods relookup their target.

- [ ] **Step 2: Prove RED**

  Run: `python3 scripts/check_dock.py`

  Expected: FAIL because `DockService.qml` is absent.

- [ ] **Step 3: Implement reactive grouping and intents**

  Recompute on toplevel model/focus/workspace signals; append newly observed app IDs to a session-only first-seen list; map classes through `ApplicationService`; use `HyprlandToplevel.activate()` and `.close()` only after lookup; use `ApplicationService.launch(entry.id)` for launch/new-window intents.

- [ ] **Step 4: Prove GREEN without launching applications**

  Run: `python3 scripts/check_dock.py && node scripts/check_dock_rules.js && ./scripts/check.sh`

  Expected: PASS; fixtures inspect APIs/source only and invoke no intent method.

- [ ] **Step 5: Commit**

  ```bash
  git add Titonium/Services/Dock/DockService.qml Titonium/Services/Dock/qmldir scripts/check_dock.py
  git commit -m "feat: add native dock application model"
  ```

### Task 4: Build native Bluetooth domain service

**Files:**
- Create: `Titonium/Services/Bluetooth/BluetoothRules.js`
- Create: `Titonium/Services/Bluetooth/BluetoothService.qml`
- Create: `Titonium/Services/Bluetooth/qmldir`
- Create: `scripts/check_bluetooth_rules.js`
- Create: `scripts/check_bluetooth.py`

**Interfaces:**
- Consumes: `Bluetooth.defaultAdapter`, adapter `enabled`, `discovering`, `devices.values`; native device state, battery and methods from Quickshell 0.3.1.
- Produces: read-only `available: bool`, `powered: bool`, `discovering: bool`, `adapterName: string`, `connectedCount: int`, `devices: array`, `stateKey: string`; methods `setPowered(value): bool`, `setDiscovering(value): bool`, `connectDevice(address): bool`, `disconnectDevice(address): bool`, `pairDevice(address): bool`, `cancelPair(address): bool`, `forgetDevice(address): bool`, `snapshot(): string`. Device descriptors are `{address,name,icon,section,stateKey,connected,paired,pairing,batteryAvailable,battery,blocked}`.

- [ ] **Step 1: Write failing BluetoothRules fixtures**

  Cover no adapter, powered off/on/scanning, connected count, duplicate-address removal, section order Connected/Paired/Available, case-insensitive name then address sort, pairing precedence and battery clamping to `0..100`.

- [ ] **Step 2: Prove rules RED, implement pure rules, then prove GREEN**

  Run before: `node scripts/check_bluetooth_rules.js` (expected FAIL). Implement immutable projections with no native-object retention. Run again; expected PASS.

- [ ] **Step 3: Add failing service architecture gate**

  Require `BluetoothService.qml` as the sole `Quickshell.Bluetooth` importer, a private `nativeDeviceForAddress(address)` lookup before every mutation, false returns for stale objects, and absence of `Process`, DBus wrappers, CLI strings and timers.

- [ ] **Step 4: Implement native service and prove GREEN**

  Bind the default adapter safely, project devices through `BluetoothRules`, turn discovery off before power-off, call native device methods only after relookup and log bounded failures. Run: `node scripts/check_bluetooth_rules.js && python3 scripts/check_bluetooth.py && ./scripts/check.sh`. Expected: PASS without changing host Bluetooth state.

- [ ] **Step 5: Commit**

  ```bash
  git add Titonium/Services/Bluetooth scripts/check_bluetooth_rules.js scripts/check_bluetooth.py
  git commit -m "feat: add native bluetooth service"
  ```

### Task 5: Build the DP-1 Dock presentation

**Files:**
- Create: `Titonium/Dock/DockHost.qml`
- Create: `Titonium/Dock/DockWindow.qml`
- Create: `Titonium/Dock/DockSurface.qml`
- Create: `Titonium/Dock/DockAppButton.qml`
- Create: `Titonium/Dock/DockItemMenuCoordinator.qml`
- Create: `Titonium/Dock/DockItemMenuSurface.qml`
- Create: `Titonium/Dock/qmldir`
- Create: `scripts/check_dock_layout.js`
- Modify: `scripts/check_dock.py`

**Interfaces:**
- Consumes: Task 3 `DockService`, `ScreenPolicy.screens`, `SurfaceManager.open(ownerId, descriptor, screen)`, Theme/Metrics/Motion and `I18n.tr()`.
- Produces: `DockHost`; `DockItemMenuCoordinator.open(appId, invoker, screen): bool`, `close(): bool`; a `PanelWindow` namespace `titonium-dock` with 56px body, 8px margin, 4px edge reveal and exclusive zone `64` only when pinned open.

- [ ] **Step 1: Add failing layout/lifecycle fixtures**

  Assert body/icon/margin/spacing `56/40/8/6`, hover scale/lift `1.12/4`, edge reveal `4`, reserve `64` pinned and `0` auto-hide, reduced-motion duration `0`, `Variants.model: ScreenPolicy.screens`, mask limited to Dock/reveal, and no forbidden render/runtime primitive.

- [ ] **Step 2: Prove RED**

  Run: `node scripts/check_dock_layout.js && python3 scripts/check_dock.py`

  Expected: FAIL because Dock presentation files are absent.

- [ ] **Step 3: Implement host, window and surface**

  Build one bottom-centered `PanelWindow` per allowed screen; bind visibility to `DockRules.shouldReveal`; reserve only pinned-open mode; implement bounded opacity/translation/scale transitions; preserve click-through outside the visible body and 4px reveal strip.

- [ ] **Step 4: Implement application and item-menu interaction**

  Put Arch/Applications first and pin control last. Left/middle/right and keyboard actions call only Dock service/coordinator contracts. The lazy item menu exposes New Window, Pin/Unpin and Close Active Window, closes on outside click/Escape and returns focus to its invoker.

- [ ] **Step 5: Prove GREEN**

  Run: `node scripts/check_dock_layout.js && python3 scripts/check_dock.py && ./scripts/check.sh`

  Expected: PASS with no new qmllint warning.

- [ ] **Step 6: Commit**

  ```bash
  git add Titonium/Dock scripts/check_dock_layout.js scripts/check_dock.py
  git commit -m "feat: add reactive DP-1 dock surface"
  ```

### Task 6: Build Bluetooth popup and Bar button

**Files:**
- Create: `Titonium/Overlays/Bluetooth/BluetoothPopupCoordinator.qml`
- Create: `Titonium/Overlays/Bluetooth/BluetoothPopupSurface.qml`
- Create: `Titonium/Overlays/Bluetooth/BluetoothDeviceRow.qml`
- Create: `Titonium/Overlays/Bluetooth/qmldir`
- Modify: `Titonium/Bar/islands/ConnectivityPill.qml`
- Modify: `scripts/check_bluetooth.py`

**Interfaces:**
- Consumes: Task 4 `BluetoothService`, `SurfaceManager`, `ScreenRouter`, Theme/Metrics/Motion and `I18n.tr()`.
- Produces: `BluetoothPopupCoordinator.open(screen): bool`, `toggle(screen): bool`, `close(): bool`, `active: bool`; owner ID prefix `bluetooth:`; state-aware Bar button.

- [ ] **Step 1: Extend the gate for lazy and state-aware presentation**

  Require coordinator descriptor source, shared transient manager, no eager popup instance, content-driven capped height, collapsible Connected/Paired/Available sections, inline two-step Forget confirmation, Escape/outside close and accessible names.

- [ ] **Step 2: Prove RED**

  Run: `python3 scripts/check_bluetooth.py`

  Expected: FAIL because popup files and native Bar binding are absent.

- [ ] **Step 3: Implement coordinator and popup**

  Open on the routed DP-1 screen, render header adapter/power/scan controls, group normalized device rows, cap panel height to available screen height, reset confirmation on row/state change and call only Bluetooth service intents.

- [ ] **Step 4: Replace the diagnostic Bluetooth glyph**

  Keep Wi-Fi diagnostic. Bind icon/tone/accessibility to unavailable/off/on/scanning/connected-count state and open the coordinator from the button.

- [ ] **Step 5: Prove GREEN**

  Run: `node scripts/check_bluetooth_rules.js && python3 scripts/check_bluetooth.py && ./scripts/check.sh`

  Expected: PASS with the popup tree unloaded while closed.

- [ ] **Step 6: Commit**

  ```bash
  git add Titonium/Overlays/Bluetooth Titonium/Bar/islands/ConnectivityPill.qml scripts/check_bluetooth.py
  git commit -m "feat: add native bluetooth popup"
  ```

### Task 7: Integrate App, i18n, IPC and static gates

**Files:**
- Modify: `Titonium/App.qml`
- Modify: `config/i18n/en.json`
- Modify: `config/i18n/vi.json`
- Modify: `scripts/check.sh`
- Create: `scripts/dock_acceptance.sh`
- Create: `scripts/bluetooth_acceptance.sh`
- Modify: `scripts/protected_acceptance.sh`

**Interfaces:**
- Consumes: `DockHost`, `DockService.snapshot()`, `BluetoothService.snapshot()`, `BluetoothPopupCoordinator` and existing `openSpotlight("applications", "", "browse")`.
- Produces: read-only IPC targets `dock.state()`, `bluetooth.state()`, `bluetooth.popup()`, `bluetooth.closePopup()`, `bluetooth.popupState()`; no mutating Dock/Bluetooth IPC.

- [ ] **Step 1: Add failing integration/locale assertions**

  Extend static gates to require `DockHost {}`, exact IPC allowlists, Spotlight Applications routing, EN/VI key parity and syntax-valid acceptance scripts. Explicitly reject Dock focus/launch/close/pin IPC and Bluetooth power/scan/device-mutation IPC.

- [ ] **Step 2: Prove RED**

  Run: `./scripts/check.sh`

  Expected: FAIL on missing composition, IPC and locale keys.

- [ ] **Step 3: Compose and localize**

  Add one `DockHost`, imports and read-only IPC. Route Dock Applications to existing Spotlight on the policy screen. Add complete namespaced strings for actions, device states, section labels, tooltips and accessible names in both locales.

- [ ] **Step 4: Add safe read-only acceptance scripts**

  `dock_acceptance.sh` reads state/layers/reserves only. `bluetooth_acceptance.sh` reads state, opens/closes the popup and checks transient mutual exclusion only. Both reject DP-3 Titonium surfaces and never invoke a mutation intent.

- [ ] **Step 5: Prove integration GREEN**

  Run: `./scripts/check.sh && bash -n scripts/dock_acceptance.sh scripts/bluetooth_acceptance.sh scripts/protected_acceptance.sh`

  Expected: PASS.

- [ ] **Step 6: Commit**

  ```bash
  git add Titonium/App.qml config/i18n/en.json config/i18n/vi.json scripts/check.sh scripts/dock_acceptance.sh scripts/bluetooth_acceptance.sh scripts/protected_acceptance.sh
  git commit -m "feat: integrate dock and bluetooth surfaces"
  ```

### Task 8: Verify live behavior, provenance and handoff

**Files:**
- Create: `docs/references/AMBXST_DOCK.md`
- Modify: `docs/TESTING.md`
- Modify: `docs/ROADMAP.md`

**Interfaces:**
- Consumes: all prior tasks and required repository gates.
- Produces: provenance record, repeatable safe QA commands and a clean single-daemon DP-1 runtime ready for the user's visual checkpoint.

- [ ] **Step 1: Record immutable pre-live evidence**

  Save hashes of both `hyprland.lua` files, `git status --short`, current Bluetooth powered/discovery/connection state and current Titonium process list in `/tmp/titonium-native-dock-bluetooth-pre.txt`.

- [ ] **Step 2: Run the full static/foreground gates**

  Run: `./scripts/check.sh && ./scripts/smoke.sh`

  Expected: `Configuration Loaded`, no `ERROR`, `TypeError`, unavailable type, illegal method name or unexpected qmllint warning.

- [ ] **Step 3: Run protected read-only live acceptance**

  Stop only the existing Titonium shell ID, launch one foreground `qs -p /home/cole/Projects/titonium`, then run `./scripts/protected_acceptance.sh`, `./scripts/dock_acceptance.sh`, `./scripts/bluetooth_acceptance.sh` and `hyprctl configerrors`.

  Expected: DP-1 has exactly one Bar and Dock, DP-3 has neither Titonium layer nor reserve, transient mutual exclusion passes, config errors are empty and acceptance does not alter applications/Bluetooth devices.

- [ ] **Step 4: Document provenance and operation**

  Record Ambxst URL, inspected revision, AGPL-3.0 license, the three inspected Dock paths and which interaction ideas were independently reimplemented. Add static/live/manual commands, state restoration procedure and the explicit deferral of Network/Wi-Fi.

- [ ] **Step 5: Restore and verify the host session**

  Restore original Bluetooth power/discovery/connection state only if manual QA changed it; leave exactly one daemon via `qs -d -p /home/cole/Projects/titonium`. Compare both Hyprland hashes and verify `git status --short` contains only the intended documentation changes.

- [ ] **Step 6: Run final verification and commit**

  Run: `./scripts/check.sh && ./scripts/smoke.sh && ./scripts/protected_acceptance.sh && hyprctl configerrors && git diff --check`

  Expected: all pass, empty config errors and unchanged Hyprland hashes.

  ```bash
  git add docs/references/AMBXST_DOCK.md docs/TESTING.md docs/ROADMAP.md
  git commit -m "docs: record dock and bluetooth acceptance"
  ```

- [ ] **Step 7: Stop for the user's visual checkpoint**

  Ask the user to approve corrected Audio geometry, Dock geometry/reveal/pin/click-through/keyboard/app interactions on DP-1, DP-3 isolation and Bluetooth unavailable/off/on/scanning/connect/pair/forget-confirmation behavior before any Network/Wi-Fi work begins.
