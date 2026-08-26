# Titonium Skeleton-First Source Contraction Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Contract Titonium in place to a dynamic multi-monitor skeleton that preserves Spotlight, Input Method, Workspaces, Clock and the existing Spotlight keybindings while removing unused runtime architecture.

**Architecture:** Build the replacement Core, Services, Theme, Shared, Bar and Overlays modules beside the current composition, then move one protected vertical slice at a time. `shell.qml` changes only after the replacement App, Bar and Spotlight pass static and isolated runtime tests; obsolete source is deleted only after the live cutover and a reachability gate pass.

**Tech Stack:** Quickshell QML, QtQuick, Hyprland services, Fcitx StatusNotifier integration, JavaScript model tests, Python architecture/config gates and Bash live acceptance.

**Spec:** `docs/superpowers/specs/2026-08-26-skeleton-first-source-contraction-design.md`

## Global Constraints

- Work directly in `/home/cole/Projects/titonium`; do not create another project or long-lived branch.
- Preserve Spotlight Applications, Clipboard and mock System scopes, application visibility, calculator, search, keyboard lifecycle and focused-screen routing.
- Preserve the event-driven Input Method integration with no polling or `Process`.
- Keep Workspaces and a text Clock visible as replaceable convenience widgets.
- Keep `Super + Space` and `Super + V` byte-for-byte unchanged in both Hyprland configuration copies.
- Never edit `/home/cole/.config/hypr/hyprland.lua` or its dotfiles copy during this plan.
- UI must not instantiate `Process`, call `Quickshell.execDetached`, access raw platform APIs or persist data.
- Runtime data remains outside the repository; loading corrupt runtime data falls back safely.
- Do not add Wi-Fi, Bluetooth, audio, MPRIS, System Tray, notification, Control Center or OSD stubs.
- Use `apply_patch` for source edits and preserve unrelated user changes.
- Never launch a real application or write clipboard contents during automated tests.

## Target file map

```text
shell.qml                              # Stable Quickshell entry point
Titonium/App.qml                       # Minimal composition root and app/spotlight IPC
Titonium/Core/Screens/ScreenRouter.qml # Focused/explicit screen resolution
Titonium/Core/Surfaces/SurfaceManager.qml
Titonium/Core/Surfaces/OverlayHost.qml
Titonium/Core/Runtime/Logger.qml
Titonium/Core/Runtime/Preferences.qml  # Read-only projection of protected v5 preferences
Titonium/Core/Runtime/I18n.qml
Titonium/Services/Applications/*       # Desktop discovery, visibility and launch
Titonium/Services/Clipboard/*          # Clipboard adapter and lazy history state
Titonium/Services/Hyprland/*           # Workspace and focused-output state
Titonium/Services/InputMethod/*        # Fcitx StatusNotifier state
Titonium/Bar/BarHost.qml
Titonium/Bar/BarSurface.qml
Titonium/Bar/Bar.qml
Titonium/Bar/widgets/{Workspaces,InputMethod,Clock}.qml
Titonium/Overlays/Spotlight/*           # Preserved Spotlight vertical slice
Titonium/Theme/{Theme,Metrics,Typography,Motion}.qml
Titonium/Shared/{Surface,Panel,Button,Icon,TextLabel}.qml
config/defaults/settings.json          # Protected preferences only
config/i18n/{vi,en}.json               # Reachable strings only after final prune
scripts/check_skeleton.py              # Target architecture and reachability gate
scripts/protected_acceptance.sh         # Live protected-flow acceptance
```

The target keeps the public singleton names `Preferences`, `I18n`, `SurfaceManager`,
`ApplicationService`, `ClipboardService`, `HyprlandService` and `InputMethodService`. Views import
the narrow module that owns the name; no umbrella `Foundation`, `Platform`, `Composition` or
`Design` import remains after deletion.

---

### Task 1: Lock protected runtime behavior and immutable keybindings

**Files:**
- Create: `scripts/check_protected_contract.py`
- Create: `scripts/protected_acceptance.sh`
- Modify: `scripts/check.sh`
- Modify: `docs/TESTING.md`

**Interfaces:**
- Consumes: current IPC `app.status()`, `spotlight.toggle()`, `spotlight.clipboard()`, `spotlight.setQuery(query)`, `spotlight.setScope(scope)`, `spotlight.close()`.
- Produces: `scripts/protected_acceptance.sh` as the cutover gate and `check_protected_contract.py` as the static invariant gate.

- [ ] **Step 1: Capture both Hyprland file paths and current binding lines without editing them**

Run:

```bash
rg -n 'ipc call spotlight (toggle|clipboard)' \
  /home/cole/.config/hypr/hyprland.lua \
  /home/cole/Projects/dotfiles
sha256sum /home/cole/.config/hypr/hyprland.lua \
  /home/cole/Projects/titonium-hyprland/config/hypr/hyprland.lua
```

Expected: each configuration copy contains exactly one `spotlight toggle` and one
`spotlight clipboard` binding. The dotfiles copy is
`/home/cole/Projects/titonium-hyprland/config/hypr/hyprland.lua`; do not use a glob in later hash
checks.

- [ ] **Step 2: Write the failing protected static gate**

Create `scripts/check_protected_contract.py` with exact checks:

```python
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LIVE_HYPR = Path("/home/cole/.config/hypr/hyprland.lua")
DOTFILES_HYPR = Path("/home/cole/Projects/titonium-hyprland/config/hypr/hyprland.lua")

EXPECTED = {
    'hl.bind(mainMod .. " + V", hl.dsp.exec_cmd("qs -p /home/cole/Projects/titonium ipc call spotlight clipboard"))',
    'hl.bind(mainMod .. " + space", hl.dsp.exec_cmd("qs -p /home/cole/Projects/titonium ipc call spotlight toggle"))',
}

errors = []
for path in (LIVE_HYPR, DOTFILES_HYPR):
    text = path.read_text(encoding="utf-8")
    for line in EXPECTED:
        if text.count(line) != 1:
            errors.append(f"{path}: expected exactly one protected binding: {line}")

if not (ROOT / "scripts/protected_acceptance.sh").is_file():
    errors.append("missing scripts/protected_acceptance.sh")

if errors:
    raise SystemExit("FAIL protected contract\n" + "\n".join(errors))
print("PASS protected contract")
```

Run: `python3 scripts/check_protected_contract.py`

Expected: FAIL because `scripts/protected_acceptance.sh` does not exist.

- [ ] **Step 3: Add the live characterization acceptance**

Create `scripts/protected_acceptance.sh` by extracting the safe shell startup, IPC polling,
Applications/Clipboard/System scope sequence and log rejection pattern from
`scripts/spotlight_acceptance.sh`. Add static Input Method assertions:

```bash
if rg -n 'Process\s*\{|Timer\s*\{' \
  "$project_root/Titonium/Modules/MenuBar/InputMethod" \
  "$project_root/Titonium/Platform/Input"; then
    echo "FAIL Input Method owns a Process or Timer" >&2
    exit 1
fi
```

The acceptance must call only query/state/close IPC methods. It must not call
`activateSelected`, `ApplicationCatalog.launch`, clipboard copy/delete/clear or any session action.
Snapshot both Hyprland hashes before startup and compare them after cleanup.

- [ ] **Step 4: Register and run the gates**

Add these lines before `qmllint` in `scripts/check.sh`:

```bash
python3 "$project_root/scripts/check_protected_contract.py"
```

Run:

```bash
python3 scripts/check_protected_contract.py
./scripts/check.sh
./scripts/protected_acceptance.sh
```

Expected: all PASS on the current implementation; the live acceptance log contains
`Configuration Loaded` and no runtime rejection pattern.

- [ ] **Step 5: Document and commit the protected baseline**

Add `protected_acceptance.sh` and its no-side-effect rules to `docs/TESTING.md`.

```bash
git add scripts/check_protected_contract.py scripts/protected_acceptance.sh scripts/check.sh docs/TESTING.md
git commit -m "test: lock spotlight input and keybind behavior"
```

---

### Task 2: Introduce the minimal Core, Theme and Shared modules off-runtime

**Files:**
- Create: `Titonium/Core/Screens/{ScreenRouter.qml,qmldir}`
- Create: `Titonium/Core/Surfaces/{SurfaceManager.qml,OverlayHost.qml,qmldir}`
- Create: `Titonium/Core/Runtime/{Logger.qml,Preferences.qml,I18n.qml,PreferencesValidator.js,qmldir}`
- Create: `Titonium/Theme/{Theme.qml,Metrics.qml,Typography.qml,Motion.qml,qmldir}`
- Create: `Titonium/Shared/{Surface.qml,Panel.qml,Button.qml,Icon.qml,TextLabel.qml,qmldir}`
- Create: `scripts/check_skeleton.py`
- Modify: `scripts/check.sh`

**Interfaces:**
- Produces: `ScreenRouter.screenForName(name): ShellScreen|null`;
  `SurfaceManager.open(ownerId, descriptor, screen): bool`;
  `SurfaceManager.close(ownerId): bool`;
  `Preferences.ready: bool`, `Preferences.settings: var`, `Preferences.locale: string`,
  `Preferences.reducedMotion: bool`, `Preferences.hiddenApplicationIds: var`,
  `Preferences.spotlight: var`, `Preferences.use24Hour: bool`;
  and semantic `Theme`, `Metrics`, `Typography`, `Motion` tokens.
- Consumes: shipped `config/defaults/settings.json`, runtime `Quickshell.dataPath("settings.json")`,
  and existing `config/i18n/{vi,en}.json`.

- [ ] **Step 1: Write the failing skeleton structure gate**

Create `scripts/check_skeleton.py` with a `required` list covering every Task 2 path and these
source invariants:

```python
ui_roots = [ROOT / "Titonium/Bar", ROOT / "Titonium/Overlays", ROOT / "Titonium/Shared"]
for ui_root in ui_roots:
    if not ui_root.exists():
        continue
    for path in ui_root.rglob("*.qml"):
        text = path.read_text(encoding="utf-8")
        for forbidden in ("Process {", "Quickshell.execDetached", "FileView {"):
            if forbidden in text:
                errors.append(f"UI platform/persistence boundary: {path}: {forbidden}")
```

Run: `python3 scripts/check_skeleton.py`

Expected: FAIL listing the missing Core, Theme and Shared files.

- [ ] **Step 2: Add runtime preferences with safe v5 projection**

Implement `PreferencesValidator.js` as a pure function:

```javascript
function project(document, defaults) {
    const source = document && typeof document === "object" ? document : {};
    const fallback = defaults && typeof defaults === "object" ? defaults : {};
    return {
        locale: source.locale === "en" ? "en" : (fallback.locale || "vi"),
        appearance: { mode: source.appearance?.mode === "light" ? "light" : "dark" },
        accessibility: { reducedMotion: source.accessibility?.reducedMotion === true },
        applications: {
            hiddenIds: Array.isArray(source.applications?.hiddenIds)
                ? source.applications.hiddenIds.filter(id => typeof id === "string") : []
        },
        modules: {
            spotlight: {
                pageTransition: ["slide-fade", "fade", "none"].includes(
                    source.modules?.spotlight?.pageTransition)
                    ? source.modules.spotlight.pageTransition : "slide-fade",
                transitionDuration: Number.isInteger(source.modules?.spotlight?.transitionDuration)
                    ? Math.max(0, Math.min(500, source.modules.spotlight.transitionDuration)) : 220
            },
            clock: { use24Hour: source.modules?.clock?.use24Hour !== false }
        }
    };
}
```

`Preferences.qml` loads defaults first, then runtime if parseable, and exposes the typed readonly
properties named in Interfaces. It is read-only during this contraction and never rewrites the
user's v5 runtime document.

- [ ] **Step 3: Port the screen and surface behavior**

Copy the focused-screen fallback behavior from `Foundation/ScreenRouter.qml` into Core. Port only
`ownerId`, `descriptor`, `screen`, `active`, `open()` and `close()` from
`Foundation/SurfaceCoordinator.qml`; omit preview transactions and session-action guards because
no retained surface consumes them.

Port `Surfaces/OverlayHost.qml` to Core and replace its imports/references with `SurfaceManager`.
Keep `Variants { model: Quickshell.screens }`, Loader activation, keyboard focus and focused-monitor
close behavior exactly.

- [ ] **Step 4: Port the solid semantic theme and five reachable controls**

Copy only the public properties actually referenced by Spotlight and the three Bar widgets.
`Theme.qml` contains the immutable Neutral Utility dark/light semantic color maps directly and
selects one using `Preferences.settings.appearance.mode`; it does not load a theme catalog.
`Metrics.qml`, `Typography.qml` and `Motion.qml` contain the approved Neutral token values directly.
`Shared.Surface` and `Shared.Panel` must be solid Rectangles with opacity `1.0`. Do not import
`QtQuick.Effects`, `MaterialSurface`, ThemeCatalog or compositor capabilities.

The Shared module exports exactly:

```text
Surface 1.0 Surface.qml
Panel 1.0 Panel.qml
Button 1.0 Button.qml
Icon 1.0 Icon.qml
TextLabel 1.0 TextLabel.qml
```

- [ ] **Step 5: Run RED/GREEN gates and commit**

Register `python3 "$project_root/scripts/check_skeleton.py"` in `scripts/check.sh`.

Run:

```bash
node -e 'const v=require("fs").readFileSync("Titonium/Core/Runtime/PreferencesValidator.js","utf8"); eval(v); const x=project({applications:{hiddenIds:["a",1]}},{locale:"vi"}); if (JSON.stringify(x.applications.hiddenIds)!=="[\"a\"]") process.exit(1)'
python3 scripts/check_skeleton.py
./scripts/check.sh
```

Expected: PASS; the live shell is still on the old composition.

```bash
git add Titonium/Core Titonium/Theme Titonium/Shared scripts/check_skeleton.py scripts/check.sh
git commit -m "refactor: add minimal skeleton primitives"
```

---

### Task 3: Move shared platform state into narrow Services

**Files:**
- Create: `Titonium/Services/Applications/{ApplicationService.qml,ApplicationLaunch.js,Visibility.js,qmldir}`
- Create: `Titonium/Services/Clipboard/{ClipboardService.qml,ClipboardAccess.js,ClipboardHistory.js,qmldir}`
- Create: `Titonium/Services/Hyprland/{HyprlandService.qml,qmldir}`
- Create: `Titonium/Services/InputMethod/{InputMethodService.qml,qmldir}`
- Create: `scripts/check_services.py`
- Modify: `scripts/check.sh`

**Interfaces:**
- `ApplicationService.allApplications: var`, `visibleApplications: var`,
  `launch(entryId: string): bool` and `isVisible(entryId: string): bool`.
- `ClipboardService.available: bool`, `items: var`, `copy(id: string): bool`,
  `remove(id: string): bool`, `clear(): bool`; tests inject fakes and never call mutating methods live.
- `HyprlandService.focusedMonitorName: string`, `workspaceSnapshot(screen,count): var`,
  `activeWorkspaceId(screen): int`, `activateWorkspace(id): void`.
- `InputMethodService.available: bool`, `shortLabel: string`, `displayName: string`.

- [ ] **Step 1: Write failing service boundary checks**

`scripts/check_services.py` must require the four module directories and reject `Process {`,
`Timer {` and `Quickshell.execDetached` in InputMethod, Hyprland workspace projection and
Applications view-facing singleton files. It must require only Services—not UI—to import
`Quickshell.Services.SystemTray`, `Quickshell.Hyprland`, `Quickshell.Io` or platform namespaces.

Run: `python3 scripts/check_services.py`

Expected: FAIL because the Services modules do not exist.

- [ ] **Step 2: Port Applications and visibility without changing behavior**

Move desktop discovery and icon/execution normalization from
`Platform/Applications/ApplicationCatalog.qml`; combine the visible projection from
`Foundation/ApplicationVisibilityStore.qml` using `Preferences.hiddenApplicationIds`.
Reuse the tested pure `ApplicationLaunch.js` and `ApplicationVisibility.js` logic under the new
names. Keep application list identity stable and incremental.

- [ ] **Step 3: Port Clipboard history and access**

Combine the current `ClipboardHistoryStore` and `ClipboardAdapter` facade into one service while
retaining pure `ClipboardHistory.js` and `ClipboardAccess.js`. The process implementation remains
inside Services and is consumer-gated; no process starts because Spotlight is closed.

- [ ] **Step 4: Port Hyprland and Input Method services**

Rename the adapter-facing public API to the Interfaces names without changing its Quickshell event
sources. Input Method must keep the current Fcitx StatusNotifier item matching and fallback label
`IM`. Do not add a DBus process fallback.

- [ ] **Step 5: Update pure tests, run gates and commit**

Point existing application launch/visibility, clipboard history/access and workspace-related tests
at the new paths. Register `check_services.py` in `check.sh`.

```bash
python3 scripts/check_services.py
node scripts/check_application_launch.js
node scripts/check_application_visibility.js
node scripts/check_clipboard_history.js
node scripts/check_clipboard_access.js
./scripts/check.sh
git add Titonium/Services scripts
git commit -m "refactor: consolidate protected platform services"
```

---

### Task 4: Move Spotlight as a protected overlay vertical slice

**Files:**
- Create: `Titonium/Overlays/Spotlight/` containing the current Spotlight QML/JS files and `qmldir`
- Modify: every moved Spotlight QML import
- Modify: `scripts/check_spotlight.js`
- Modify: `scripts/spotlight_acceptance.sh`
- Modify: `scripts/protected_acceptance.sh`
- Modify: `scripts/check_skeleton.py`

**Interfaces:**
- Consumes: `ApplicationService`, `ClipboardService`, `Preferences`, `I18n`, `SurfaceManager`,
  `Theme.*` and `Shared.*`.
- Produces: `SpotlightSurface.qml` accepting `descriptor` and `screen`; public IPC behavior remains
  owned by the later `Titonium/App.qml` task.

- [ ] **Step 1: Make the structure gate fail on the missing protected overlay**

Extend `check_skeleton.py` to require all current Spotlight basenames under
`Titonium/Overlays/Spotlight` and reject imports containing:

```text
qs.Titonium.Foundation
qs.Titonium.Platform
qs.Titonium.Design
qs.Titonium.Composition
```

Run: `python3 scripts/check_skeleton.py`

Expected: FAIL listing the missing overlay files.

- [ ] **Step 2: Recreate the Spotlight slice under Overlays**

Use `apply_patch` to add each current Spotlight file under the new directory. Change imports only:

```qml
import qs.Titonium.Core.Runtime
import qs.Titonium.Core.Surfaces
import qs.Titonium.Services.Applications
import qs.Titonium.Services.Clipboard
import qs.Titonium.Theme
import qs.Titonium.Shared as Shared
```

Replace `ConfigStore.previewState` reads with `Preferences` typed properties,
`ApplicationVisibilityStore`/`ApplicationCatalog` with `ApplicationService`,
`ClipboardHistoryStore`/`ClipboardAdapter` with `ClipboardService`, Controls with `Shared`, and
`SurfaceCoordinator` with `SurfaceManager`. Do not redesign layout, motion or interaction.

- [ ] **Step 3: Point pure tests at the moved JS files**

Update exact source paths in `scripts/check_spotlight.js`. Preserve all existing 68 domain fixtures
and add an import scan assertion preventing old module URIs.

Run:

```bash
node scripts/check_spotlight.js
python3 scripts/check_skeleton.py
./scripts/check.sh
```

Expected: PASS; the live App still uses the old Spotlight path until Task 6.

- [ ] **Step 4: Commit the off-runtime Spotlight slice**

```bash
git add Titonium/Overlays/Spotlight scripts
git commit -m "refactor: move spotlight into a protected overlay"
```

---

### Task 5: Build the direct dynamic Bar without registry or recursive layout

**Files:**
- Create: `Titonium/Bar/{BarHost.qml,BarSurface.qml,Bar.qml,qmldir}`
- Create: `Titonium/Bar/widgets/{Workspaces.qml,InputMethod.qml,Clock.qml,qmldir}`
- Modify: `scripts/check_skeleton.py`
- Create: `scripts/check_bar.py`
- Modify: `scripts/protected_acceptance.sh`
- Modify: `scripts/check.sh`

**Interfaces:**
- `BarHost` creates one `BarSurface` for each `Quickshell.screens` item.
- `BarSurface.screenModel: ShellScreen` owns a 40 logical pixel top exclusive zone.
- Each widget accepts `screen: ShellScreen`; Workspaces also accepts `count: int` defaulting to 5.

- [ ] **Step 1: Write the failing direct-Bar contract**

`scripts/check_bar.py` must require:

```python
required = {
    "BarHost.qml": ("Variants {", "model: Quickshell.screens"),
    "BarSurface.qml": ("PanelWindow {", "exclusiveZone: 40"),
    "Bar.qml": ("Workspaces {", "InputMethod {", "Clock {"),
}
```

It must reject `WidgetRegistry`, `LayoutRenderer`, `ConfigStore`, `layout.json`, `Process {` and
`Timer {` in `Titonium/Bar`.

Run: `python3 scripts/check_bar.py`

Expected: FAIL because the new Bar does not exist.

- [ ] **Step 2: Add Bar host and surface**

Port the current `Variants + PanelWindow` screen lifecycle. Keep top/left/right anchors,
`WlrLayer.Top`, `aboveWindows: true`, namespace `titonium-menubar`, 40 logical pixel height and
exclusive zone. Bar background uses `Shared.Surface` with solid Neutral tokens.

- [ ] **Step 3: Port the three direct widgets**

Workspaces reads `HyprlandService` through a small local model and remains event-driven.
Input Method reads `InputMethodService` directly and preserves the exact icon/label/fallback.
Clock owns a `SystemClock { precision: SystemClock.Minutes }`, reads `Preferences.use24Hour`, and
has no click panel, seconds display or animation. Update `protected_acceptance.sh` Input Method
static paths to `Titonium/Bar/widgets/InputMethod.qml` and
`Titonium/Services/InputMethod/InputMethodService.qml` in the same change.
Remove `WidgetBase`, node/context props and SurfaceManager ownership from all three widgets.

Compose directly:

```qml
Item {
    required property var screen
    Shared.Surface { anchors.fill: parent }
    Row {
        anchors.left: parent.left
        anchors.leftMargin: Metrics.barPadding
        anchors.verticalCenter: parent.verticalCenter
        Workspaces { screen: root.screen; count: 5 }
    }
    Row {
        anchors.right: parent.right
        anchors.rightMargin: Metrics.barPadding
        anchors.verticalCenter: parent.verticalCenter
        InputMethod { screen: root.screen }
        Clock { screen: root.screen }
    }
}
```

Use the exported `Metrics` singleton consistently; do not create a second metrics object just for
Bar.

- [ ] **Step 4: Run gates and commit**

Register `check_bar.py` in `check.sh`.

```bash
python3 scripts/check_bar.py
python3 scripts/check_skeleton.py
./scripts/check.sh
git add Titonium/Bar scripts
git commit -m "refactor: add direct dynamic menubar skeleton"
```

---

### Task 6: Cut over the minimal App and protected IPC

**Files:**
- Create: `Titonium/App.qml`
- Modify: `shell.qml`
- Modify: `Titonium/qmldir` or add it if absent
- Modify: `scripts/check_skeleton.py`
- Modify: `scripts/protected_acceptance.sh`
- Modify: `scripts/smoke.sh`

**Interfaces:**
- `app.status(): string` returns `ready` after Preferences and protected services initialize.
- Spotlight IPC preserves `toggle`, `clipboard`, `close`, `state`, `setQuery`, `setScope`,
  `firstVisibleApplicationId` and `visibleApplicationCount` signatures and result formats.

- [ ] **Step 1: Make the composition-root gate fail**

Extend `check_skeleton.py` to require `shell.qml` import `qs.Titonium` and instantiate `App {}`;
require `Titonium/App.qml` to instantiate only `BarHost {}` and `OverlayHost {}` as hosts; reject
imports or identifiers for Frame, Settings, Gallery, Arch Menu, Session Actions, Calendar,
WidgetRegistry, LayoutRenderer and old Spotlight paths.

Run: `python3 scripts/check_skeleton.py`

Expected: FAIL on the current `AppShell` composition.

- [ ] **Step 2: Implement the minimal App root**

Create a `Scope` with `BarHost`, Core `OverlayHost`, this helper and only two IPC targets:

```qml
function openSpotlight(scope: string, query: string, stateMode: string): string {
    const screen = ScreenRouter.screenForName(HyprlandService.focusedMonitorName);
    if (!screen)
        return "unavailable:no-screen";
    const owner = "spotlight:" + screen.name;
    SurfaceManager.open(owner, {
        "source": Qt.resolvedUrl("Overlays/Spotlight/SpotlightSurface.qml"),
        "keyboardFocus": "exclusive",
        "closeOnMonitorChange": true,
        "ownerId": owner,
        "mode": scope,
        "query": query,
        "stateMode": stateMode,
        "selectedIndex": 0
    }, screen);
    return "open:" + scope + ":" + screen.name;
}

IpcHandler {
    target: "app"
    function status(): string { return Preferences.ready ? "ready" : "not-ready" }
    function closeTransient(): void { SurfaceManager.close("") }
}

IpcHandler {
    id: spotlightIpc
    target: "spotlight"

    function toggle(): string {
        if (SurfaceManager.ownerId.indexOf("spotlight:") === 0) {
            SurfaceManager.close(SurfaceManager.ownerId);
            return "closed";
        }
        return root.openSpotlight("applications", "", "browse");
    }

    function clipboard(): string {
        return root.openSpotlight("clipboard", "", "clipboard");
    }

    function close(): string {
        if (SurfaceManager.ownerId.indexOf("spotlight:") === 0)
            SurfaceManager.close(SurfaceManager.ownerId);
        return "closed";
    }

    function state(): string {
        if (SurfaceManager.ownerId.indexOf("spotlight:") !== 0)
            return "closed";
        const d = SurfaceManager.descriptor || {};
        return "open:" + (d.mode || "applications") + ":" + (SurfaceManager.screen?.name || "")
            + ";mode=" + (d.stateMode || "browse") + ";query=" + (d.query || "")
            + ";selected=" + (d.selectedIndex || 0);
    }

    function setQuery(query: string): string {
        if (SurfaceManager.ownerId.indexOf("spotlight:") !== 0)
            return "unavailable:closed";
        const scope = SurfaceManager.descriptor?.mode || "applications";
        const mode = scope === "clipboard" ? "clipboard"
            : (scope === "system" ? "system" : (query.trim().length ? "results" : "browse"));
        root.openSpotlight(scope, query, mode);
        return state();
    }

    function setScope(scope: string): string {
        if (SurfaceManager.ownerId.indexOf("spotlight:") !== 0)
            return "unavailable:closed";
        if (["applications", "clipboard", "system"].indexOf(scope) < 0)
            return "unavailable:unknown-scope";
        const query = SurfaceManager.descriptor?.query || "";
        const mode = scope === "clipboard" ? "clipboard"
            : (scope === "system" ? "system" : (query.trim().length ? "results" : "browse"));
        root.openSpotlight(scope, query, mode);
        return state();
    }

    function firstVisibleApplicationId(): string {
        return ApplicationService.visibleApplications[0]?.id || "";
    }

    function visibleApplicationCount(): int {
        return ApplicationService.visibleApplications.length;
    }
}
```

Do not leave IPC handlers for removed features. If the current acceptance exposes a re-entrant
descriptor update, keep the existing deferred model publication in Spotlight; do not add a second
IPC state store.

- [ ] **Step 3: Cut over shell.qml and prove RED/GREEN in foreground**

Change the entry point to:

```qml
import Quickshell
import qs.Titonium

ShellRoot { App {} }
```

Run:

```bash
python3 scripts/check_skeleton.py
./scripts/check.sh
qs kill -p /home/cole/Projects/titonium
./scripts/smoke.sh
```

Expected: all PASS and foreground log contains `Configuration Loaded` without Loader/type errors.
If smoke fails, restart the last green commit before changing any obsolete source.

- [ ] **Step 4: Run isolated protected acceptance and live daemon cutover**

```bash
./scripts/protected_acceptance.sh
qs -d -p /home/cole/Projects/titonium
qs -p /home/cole/Projects/titonium ipc call app status
qs -p /home/cole/Projects/titonium ipc call spotlight toggle
qs -p /home/cole/Projects/titonium ipc call spotlight close
hyprctl configerrors
```

Expected: `ready`, Spotlight opens/closes, Hyprland errors are empty and both keybinding hashes are
unchanged. Leave the daemon running for the user.

- [ ] **Step 5: Commit the cutover**

```bash
git add shell.qml Titonium/App.qml Titonium/qmldir scripts
git commit -m "refactor: cut over to the skeleton composition"
```

---

### Task 7: Delete unreachable architecture and prune configuration

**Files:**
- Delete: `Titonium/App/`
- Delete: `Titonium/Composition/`
- Delete: `Titonium/Design/`
- Delete: `Titonium/Foundation/`
- Delete: `Titonium/Modules/`
- Delete: `Titonium/Platform/`
- Delete: `Titonium/Surfaces/`
- Delete: `config/defaults/layout.json`
- Delete: `config/themes/`
- Delete: layout/theme schemas and their fixtures
- Delete: obsolete tests for Arch Menu, Settings, Frame, Gallery, session actions, lunar UI and deleted validators
- Modify: `config/defaults/settings.json`
- Modify: `config/schemas/settings.schema.json`
- Modify: `config/i18n/{vi,en}.json`
- Modify: `scripts/validate_config.py`
- Modify: `scripts/check.sh`
- Modify: `scripts/check_skeleton.py`

**Interfaces:**
- Consumes: the live replacement composition from Tasks 2–6.
- Produces: no runtime import or test reference to the deleted architecture; minimal protected
  settings projection remains compatible with an existing v5 runtime document.

- [ ] **Step 1: Generate and inspect a reachability inventory before deletion**

Run:

```bash
rg -n 'qs\.Titonium\.(App|Composition|Design|Foundation|Modules|Platform|Surfaces)|Titonium/(App|Composition|Design|Foundation|Modules|Platform|Surfaces)' \
  shell.qml Titonium scripts config README.md AGENTS.md docs
```

Classify every match as runtime, current test/documentation or historical plan/spec. Historical
documents under `docs/superpowers/` remain immutable history and are excluded from deletion gates.
All runtime and current-tool matches must be migrated before deleting their source.

- [ ] **Step 2: Make the no-legacy gate fail**

Extend `check_skeleton.py` so it fails when any old top-level source directory exists or when
current runtime/scripts/config/current docs reference an old URI. Explicitly exclude
`docs/superpowers/plans` and `docs/superpowers/specs` from the reference scan.

Run: `python3 scripts/check_skeleton.py`

Expected: FAIL listing the seven old top-level directories and remaining current references.

- [ ] **Step 3: Remove source and tests with apply_patch**

Delete only files proven unreachable. Remove their `qmldir` entries and delete now-empty
directories. Remove checks dedicated solely to deleted UI. Keep pure protected tests for Spotlight,
application launch/visibility, clipboard and the new skeleton/services/Bar contracts.

Do not delete Git history or anything in the legacy Trash reference.

- [ ] **Step 4: Prune shipped settings and translations**

Keep only these projected settings keys:

```json
{
  "$schema": "titonium.settings/v5",
  "schemaVersion": 5,
  "locale": "vi",
  "appearance": { "mode": "dark" },
  "accessibility": { "reducedMotion": false },
  "applications": { "hiddenIds": [] },
  "modules": {
    "spotlight": { "pageTransition": "slide-fade", "transitionDuration": 220 },
    "clock": { "use24Hour": true }
  }
}
```

Update the schema to validate exactly this shipped document while `PreferencesValidator.project()`
continues accepting a broader existing runtime v5 document. Remove translations unreachable from
Bar and Spotlight using a key scan; keep both locale documents structurally valid. Rewrite
`validate_config.py` to validate only the minimal shipped settings and both locale JSON documents;
remove layout/theme validation branches and fixtures. The runtime preference projection remains a
separate JavaScript test because it deliberately accepts the broader historical v5 document.

- [ ] **Step 5: Run all gates and commit deletion**

```bash
python3 scripts/check_skeleton.py
./scripts/check.sh
./scripts/smoke.sh
./scripts/protected_acceptance.sh
git diff --check
git status --short
```

Expected: all PASS; only intended tracked changes are present before commit.

```bash
git add -A Titonium config scripts
git commit -m "refactor: remove superseded shell architecture"
```

---

### Task 8: Rewrite handoff documentation and perform final live acceptance

**Files:**
- Modify: `AGENTS.md`
- Modify: `README.md`
- Modify: `docs/ARCHITECTURE.md`
- Modify: `docs/CODING_FLOW.md`
- Modify: `docs/MODULE_CONTRACT.md`
- Modify: `docs/CONFIG_AND_MIGRATIONS.md`
- Modify: `docs/THEMING_AND_GLASS.md`
- Modify: `docs/PERFORMANCE.md`
- Modify: `docs/TESTING.md`
- Modify: `docs/ROADMAP.md`
- Modify: `docs/OPERATIONS.md`

**Interfaces:**
- Produces: authoritative Skeleton First / Modular Pluggable handoff and external-module ingestion
  workflow; no documentation claims removed Settings, Arch Menu, Frame or Gallery still run.

- [ ] **Step 1: Write documentation rejection checks**

Extend `check_skeleton.py` to scan current docs for claims that removed features are complete or
live. Require the phrases `Skeleton First`, `Modular Pluggable`, `Service`, `Widget`, `Panel`,
`Super + Space` and `Super + V` in the appropriate handoff/architecture/operations documents.

Run: `python3 scripts/check_skeleton.py`

Expected: FAIL because current handoff still describes the superseded greenfield milestones.

- [ ] **Step 2: Rewrite current documentation around the new source of truth**

Document:

- the target directory map and direct Bar composition;
- state-owning Services versus presentation-only Widgets/Panels;
- provenance/license/version review for imported modules;
- the two protected features and replaceable Workspaces/Clock status;
- minimal settings projection and unchanged runtime path;
- static, smoke, protected acceptance, live log and monitor lifecycle checks;
- rollback by commit without changing Hyprland bindings;
- the next activity is repository research and a new roadmap, not system-module implementation.

Keep old plans/specs as historical records.

- [ ] **Step 3: Run the final verification on committed runtime shape**

```bash
./scripts/check.sh
./scripts/smoke.sh
./scripts/protected_acceptance.sh
git diff --check
qs kill -p /home/cole/Projects/titonium
qs -d -p /home/cole/Projects/titonium
qs -p /home/cole/Projects/titonium ipc call app status
qs -p /home/cole/Projects/titonium ipc call spotlight toggle
qs -p /home/cole/Projects/titonium ipc call spotlight close
qs log -p /home/cole/Projects/titonium
hyprctl configerrors
```

Expected:

- static, smoke and protected acceptance PASS;
- app status is `ready`;
- live log contains `Configuration Loaded` and no runtime rejection pattern;
- `hyprctl configerrors` prints no errors;
- both Hyprland hashes match Task 1;
- one 40 logical pixel Bar exists on every connected screen;
- Workspaces, Input Method and Clock are visible;
- Spotlight opens on the focused monitor through both protected modes;
- Git is clean after the documentation commit.

- [ ] **Step 4: Commit documentation and leave the shell running**

```bash
git add AGENTS.md README.md docs
git commit -m "docs: adopt skeleton-first modular workflow"
git status --short
```

Expected: clean output. Leave Titonium running for visual acceptance and repository research.
