# Center Core and Daily Focus Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the empty true-center Bar slot with a Daily Focus attention surface backed by a deterministic priority arbiter, while renaming the existing misnamed active-window component to `ActiveWindowPill`.

**Architecture:** `CenterAttentionService` owns one normalized transient presentation, actionable pending events, generation-safe expiry and passive indicator descriptors. `CenterFocusStore` owns the two runtime text files and scratchpad launch boundary. The new true-center `CenterIsland` reads both services; the renamed `ActiveWindowPill` preserves the existing Start-island/Center-Notch behavior.

**Tech Stack:** Quickshell/QML, QtQuick, Quickshell.Io `FileView`/`Process`, pure JavaScript rules, Node.js fixtures, Python static contracts, Bash acceptance.

**Spec:** `docs/superpowers/specs/2026-08-28-center-attention-system-design.md`

## Global Constraints

- Final old-component name: `ActiveWindowPill`; never use `FocusWindow`.
- Daily Focus is priority 0, stable for one local date, and falls back deterministically.
- Views own no `Process`, `FileView`, persistence, raw command or timer.
- External publishers never choose raw priority or TTL.
- Ephemeral lower-priority events are dropped; only actionable events may remain pending.
- Exactly one non-repeating expiry timer lives in `CenterAttentionService`; no polling.
- Active Window stays directly after Workspaces and retains Center Notch activation.
- Center and its existing Bar pin remain centered as one `CenterGroup` from full screen width.
- Runtime files remain outside Git under `Quickshell.dataPath("center/")`.
- Preserve Spotlight, Input Method, screen lifecycle and both Hyprland files.

---

## File structure

```text
Titonium/Services/Center/
├── CenterAttentionRules.js   # normalize/reduce/expire/ack/indicator pure rules
├── CenterAttentionService.qml # shared presentation, pending state and one expiry timer
├── CenterFocusRules.js       # daily explicit/fallback selection
├── CenterFocusStore.qml      # reactive runtime files and scratchpad action
└── qmldir

Titonium/Bar/islands/
├── ActiveWindowPill.qml      # renamed old CenterIsland, behavior preserved
├── ActiveWindowRules.js      # renamed old CenterActivityRules
├── CenterIsland.qml          # new attention renderer
├── CenterGroup.qml           # CenterIsland plus existing Bar pin
└── StartIsland.qml           # Workspaces plus ActiveWindowPill

scripts/
├── check_active_window.js
├── check_center_attention_rules.js
├── check_center_focus.js
├── check_center_attention.py
└── center_attention_acceptance.sh
```

### Task 1: Rename the active-window component without behavior change

**Files:**
- Rename: `Titonium/Bar/islands/CenterIsland.qml` → `Titonium/Bar/islands/ActiveWindowPill.qml`
- Rename: `Titonium/Bar/islands/CenterActivityRules.js` → `Titonium/Bar/islands/ActiveWindowRules.js`
- Rename: `scripts/check_center_activity.js` → `scripts/check_active_window.js`
- Modify: `Titonium/Bar/islands/StartIsland.qml`
- Modify: `Titonium/Bar/islands/qmldir`
- Modify: `scripts/check_bar.py`
- Modify: `scripts/check.sh`

**Interfaces:**
- Consumes: existing `HyprlandService.activeWindow`, `ApplicationService.nameForAppId()` and `CenterNotchCoordinator.toggle(screenName)`.
- Produces: `ActiveWindowPill { required property var screen }` and pure `ActiveWindowRules.label()` / `presentation()`.

- [ ] **Step 1: Change the static and fixture tests to require the new vocabulary**

In `scripts/check_active_window.js`, change the paths and failure messages:

```js
const rulesPath = path.join(root, "Titonium", "Bar", "islands", "ActiveWindowRules.js");
const pillPath = path.join(root, "Titonium", "Bar", "islands", "ActiveWindowPill.qml");
assert.equal(fs.existsSync(rulesPath), true, "missing ActiveWindowRules.js");
assert.equal(fs.existsSync(pillPath), true, "missing ActiveWindowPill.qml");
```

In `scripts/check_bar.py`, require `ActiveWindowPill.qml`, require `ActiveWindowPill {` after
`Workspaces {`, and reject `CenterIsland {` inside `StartIsland.qml`.

- [ ] **Step 2: Run the renamed contract and verify it fails**

Run: `node scripts/check_active_window.js && python3 scripts/check_bar.py`

Expected: FAIL because `ActiveWindowRules.js` and `ActiveWindowPill.qml` do not exist yet.

- [ ] **Step 3: Perform the mechanical rename and update imports/composition**

Use `git mv` for all three files. In the renamed QML use:

```qml
import "ActiveWindowRules.js" as ActiveWindowRules

readonly property string activityLabel: ActiveWindowRules.label(
    root.appName, root.activeWindow?.title || "")
readonly property var presentation: ActiveWindowRules.presentation(
    root.appName,
    root.activeWindow?.title || "",
    I18n.tr("menubar.center_notch.active"),
    I18n.tr("menubar.center_notch.desktop"))
```

Change `StartIsland.qml` to instantiate `ActiveWindowPill { screen: root.screen }`, update `qmldir`
to `ActiveWindowPill 1.0 ActiveWindowPill.qml`, and update `scripts/check.sh` to call
`check_active_window.js`.

- [ ] **Step 4: Run focused tests and verify behavior is preserved**

Run: `node scripts/check_active_window.js && python3 scripts/check_bar.py && node scripts/check_center_notch.js`

Expected: PASS; the pill still contains `CenterNotchCoordinator.toggle`, keyboard activation and
the existing accessibility key.

- [ ] **Step 5: Commit the rename**

```bash
git add Titonium/Bar/islands scripts/check_active_window.js scripts/check_bar.py scripts/check.sh
git commit -m "refactor: name active window pill explicitly"
```

### Task 2: Build the pure priority arbiter

**Files:**
- Create: `Titonium/Services/Center/CenterAttentionRules.js`
- Create: `scripts/check_center_attention_rules.js`
- Modify: `scripts/check.sh`

**Interfaces:**
- Consumes: semantic raw event `{ id, source, kind, title, icon, createdAt, importance? }`.
- Produces: `initialState()`, `normalizeEvent(raw, now)`, `publish(state, raw, now)`,
  `expire(state, id, generation, now)`, `acknowledge(state, id, now)`,
  `clear(state, id, now)`, `clearSource(state, source, now)`, and
  `setIndicator(indicators, descriptor)`.

- [ ] **Step 1: Write fixtures for normalization and all arbitration branches**

Create a Node VM fixture following `scripts/check_center_activity.js`. Include these exact outcomes:

```js
let state = rules.initialState();
state = rules.publish(state, {
    id: "media:track", source: "media", kind: "track_changed",
    title: "Tycho · Awake", icon: "music_note", createdAt: 1000,
}, 1000);
assert.equal(state.current.priority, 20);
assert.equal(state.current.expiresAt, 7000);
assert.equal(state.generation, 1);

state = rules.publish(state, {
    id: "job:build", source: "job", kind: "job_failed",
    title: "Build failed", icon: "error", createdAt: 2000,
}, 2000);
assert.equal(state.current.id, "job:build");
assert.equal(state.current.priority, 70);

const afterOldTimer = rules.expire(state, "media:track", 1, 7000);
assert.equal(afterOldTimer.current.id, "job:build");
```

Also assert: invalid sources/kinds return unchanged state; equal priority newest wins; same
deduplication key replaces and increments generation; lower ephemeral is dropped; lower actionable
is pending; acknowledgement reveals the highest-priority newest non-expired actionable event;
important job priority is base +10 capped at 90; frozen descriptors contain no callback/command.

- [ ] **Step 2: Run the fixture and verify it fails**

Run: `node scripts/check_center_attention_rules.js`

Expected: FAIL because `CenterAttentionRules.js` is missing.

- [ ] **Step 3: Implement the minimal pure reducer**

Use a policy table owned by the rules file:

```js
var POLICY = Object.freeze({
    "center:critical": { priority: 100, ttl: 0, actionable: true },
    "center:error": { priority: 70, ttl: 15000, actionable: false },
    "job:job_requires_action": { priority: 80, ttl: 0, actionable: true },
    "job:job_failed": { priority: 70, ttl: 15000, actionable: true },
    "timer:timer_finished": { priority: 70, ttl: 15000, actionable: true },
    "job:job_completed": { priority: 40, ttl: 5000, actionable: false },
    "timer:timer_five_minutes": { priority: 30, ttl: 4000, actionable: false },
    "timer:timer_one_minute": { priority: 30, ttl: 6000, actionable: false },
    "media:track_changed": { priority: 20, ttl: 6000, actionable: false },
    "media:resumed": { priority: 20, ttl: 3000, actionable: false },
    "media:paused": { priority: 20, ttl: 2000, actionable: false },
    "job:job_started": { priority: 10, ttl: 2000, actionable: false },
    "center:feedback": { priority: 10, ttl: 2000, actionable: false },
});
```

Keep `pending` bounded to 16 unique actionable IDs. Sort candidates by priority descending,
`createdAt` descending, then ID for deterministic ties. Return fresh frozen arrays/descriptors.

- [ ] **Step 4: Run the pure fixture**

Run: `node scripts/check_center_attention_rules.js`

Expected: PASS with one line per arbitration group.

- [ ] **Step 5: Add the fixture to the static gate and commit**

Insert `node "$project_root/scripts/check_center_attention_rules.js"` immediately after the active
window fixture in `scripts/check.sh`.

```bash
git add Titonium/Services/Center/CenterAttentionRules.js scripts/check_center_attention_rules.js scripts/check.sh
git commit -m "feat: add center attention arbitration rules"
```

### Task 3: Wrap arbitration in the singleton attention service

**Files:**
- Create: `Titonium/Services/Center/CenterAttentionService.qml`
- Create: `Titonium/Services/Center/qmldir`
- Create: `scripts/check_center_attention.py`
- Modify: `Titonium/App.qml`
- Modify: `scripts/check.sh`

**Interfaces:**
- Consumes: `publish(event)`, `acknowledge(id)`, `clearSource(source)`,
  `setIndicator(id, icon, accessibleName, active)`.
- Produces: readonly `presentation`, frozen `indicators`, `hasTransient`, `snapshot()` and exact
  `clear(eventId)` for timer/job cancellation.

- [ ] **Step 1: Write a static service contract that fails first**

`scripts/check_center_attention.py` must require one Center module owner and these fragments:

```python
required = (
    "readonly property var presentation:",
    "readonly property var indicators:",
    "function publish(event: var): bool",
    "function acknowledge(eventId: string): bool",
    "function clear(eventId: string): bool",
    "function clearSource(source: string): bool",
    "function setIndicator(id: string, icon: string, accessibleName: string, active: bool): bool",
    "repeat: false",
    "CenterAttentionRules.expire",
)
```

Reject `repeat: true`, more than one `Timer {`, `Process {`, `FileView {`, raw priority parameters,
and imports from Bar/feature views. Require `singleton CenterAttentionService 1.0` in `qmldir` and
one `import qs.Titonium.Services.Center` in `App.qml`.

- [ ] **Step 2: Run the contract and verify it fails**

Run: `python3 scripts/check_center_attention.py`

Expected: FAIL because the Center service module is missing.

- [ ] **Step 3: Implement service state and the generation-safe one-shot timer**

Use this public shape:

```qml
pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import qs.Titonium.Core.Runtime
import "CenterAttentionRules.js" as CenterAttentionRules

QtObject {
    id: root
    property var arbiterState: CenterAttentionRules.initialState()
    property var indicatorState: Object.freeze([])
    readonly property var presentation: root.arbiterState.current
    readonly property var indicators: root.indicatorState
    readonly property bool hasTransient: root.presentation !== null

    Timer {
        id: expiryTimer
        repeat: false
        onTriggered: root.expireCurrent()
    }
}
```

After every accepted transition, stop the timer and schedule `expiresAt - Date.now()` only when
positive. Capture `scheduledId` and `scheduledGeneration` as service properties. `expireCurrent()`
passes both to `CenterAttentionRules.expire`; it must not clear state directly.

- [ ] **Step 4: Compose the singleton and run focused gates**

Instantiate no duplicate service object; importing the singleton in `App.qml` is sufficient to
ensure composition. Add the Python check after the pure Center rules fixture.

Run: `node scripts/check_center_attention_rules.js && python3 scripts/check_center_attention.py && ./scripts/check.sh`

Expected: all static checks and qmllint PASS.

- [ ] **Step 5: Commit the service boundary**

```bash
git add Titonium/Services/Center Titonium/App.qml scripts/check_center_attention.py scripts/check.sh
git commit -m "feat: add center attention service"
```

### Task 4: Add deterministic Daily Focus storage and scratchpad action

**Files:**
- Create: `Titonium/Services/Center/CenterFocusRules.js`
- Create: `Titonium/Services/Center/CenterFocusStore.qml`
- Create: `scripts/check_center_focus.js`
- Modify: `Titonium/Services/Center/qmldir`
- Modify: `Titonium/App.qml`
- Modify: `scripts/check.sh`

**Interfaces:**
- Consumes: contents/mtime of `daily-focus.md`, contents of `focus-prompts.txt`, current local date.
- Produces: readonly `text`, `focusPath`, `promptsPath`, `ready`, `openScratchpad()` and
  `snapshot()`.

- [ ] **Step 1: Write failing pure focus fixtures**

Use fixed local dates and assert:

```js
assert.equal(rules.select({
    markdown: "Deep Work Mode\n\n- ship Center",
    modifiedAt: new Date(2026, 7, 28, 8, 0).getTime(),
    prompts: "Calm is fast\nProtect the goal",
}, new Date(2026, 7, 28, 12, 0)), "Deep Work Mode");

const first = rules.select({ markdown: "", modifiedAt: 0,
    prompts: "Calm is fast\nProtect the goal" }, new Date(2026, 7, 29, 9, 0));
const second = rules.select({ markdown: "", modifiedAt: 0,
    prompts: "Calm is fast\nProtect the goal" }, new Date(2026, 7, 29, 21, 0));
assert.equal(first, second);
assert.equal(rules.select({ markdown: "", modifiedAt: 0, prompts: "" },
    new Date(2026, 7, 29)), "");
```

Also cover whitespace, Markdown headings, CRLF, previous-day mtime and deterministic date hashing.

- [ ] **Step 2: Run the fixture and verify it fails**

Run: `node scripts/check_center_focus.js`

Expected: FAIL because `CenterFocusRules.js` is missing.

- [ ] **Step 3: Implement the pure selection rules**

Export `dateKey(date)`, `lines(text)`, `explicitFocus(markdown, modifiedAt, now)`,
`deterministicFallback(prompts, now)` and `select(state, now)`. Treat the first non-empty,
non-heading Markdown line as explicit focus only when mtime and `now` share the same local date.
Hash `YYYY-MM-DD` with a stable integer reducer and modulo the normalized prompt count.

- [ ] **Step 4: Implement the reactive store and narrow launch boundary**

Declare both runtime paths with `Quickshell.dataPath("center/...")`. Use two `FileView` objects with
`watchChanges: true`, `blockLoading: true` and `printErrors: false`. Because the installed FileView
has no mtime property, run `Process { command: ["stat", "-c", "%Y", root.focusPath] }` once at
startup and again only from `onFileChanged`; parse its epoch-seconds output with `StdioCollector`
and multiply by 1000 before passing it to `CenterFocusRules`. Missing-file exit is a normal
`modifiedAt: 0` state. Recompute on file change and at local date rollover via one non-repeating
timer scheduled to the next midnight; none of these processes/timers polls.

Implement `openScratchpad()` with service-owned argument-array processes. On the first click only,
run `["mkdir", "-p", Quickshell.dataPath("center")]`; if the focus file is empty/missing, write a
translated starter line through the existing `FileView`; then run `["xdg-open", root.focusPath]`
only from successful directory/file completion. Reject concurrent launches and on failure publish
one `center:error` event through `CenterAttentionService` with a stable dedup key. Component startup
must not create directories or mutate runtime files.

- [ ] **Step 5: Add static assertions and run focused tests**

Extend `scripts/check_center_attention.py` to require `FileView`/`Process` only in
`CenterFocusStore.qml`, data paths beginning `center/`, reactive watchers, exact argument-array
commands for `mkdir`, `stat` and `xdg-open`, a non-repeating midnight timer and no shell command
string. Add both `CenterFocusStore` and `CenterAttentionService` to `qmldir`.

Run: `node scripts/check_center_focus.js && python3 scripts/check_center_attention.py && ./scripts/check.sh`

Expected: PASS; automated tests do not call `openScratchpad()`.

- [ ] **Step 6: Commit Daily Focus storage**

```bash
git add Titonium/Services/Center Titonium/App.qml scripts/check_center_focus.js scripts/check_center_attention.py scripts/check.sh
git commit -m "feat: add daily focus store"
```

### Task 5: Render the true-center attention island

**Files:**
- Create: `Titonium/Bar/islands/CenterIsland.qml`
- Modify: `Titonium/Bar/islands/CenterGroup.qml`
- Modify: `Titonium/Bar/islands/qmldir`
- Modify: `Titonium/Bar/Bar.qml`
- Modify: `scripts/check_bar.py`
- Modify: `scripts/check_center_attention.py`
- Modify: `config/i18n/vi.json`
- Modify: `config/i18n/en.json`

**Interfaces:**
- Consumes: `CenterAttentionService.presentation`, `.indicators`,
  `CenterFocusStore.text`, `.openScratchpad()`.
- Produces: `CenterIsland { required property var screen }` with bounded natural width and one
  primary click; `CenterGroup` remains the Bar center hitbox.

- [ ] **Step 1: Update Bar contracts to require the new center composition**

Require these source fragments before creating the view:

```python
center_group_contract = (
    "CenterIsland {",
    "id: centerIsland",
    "id: pinPill",
    "Row {",
)
center_view_contract = (
    "CenterAttentionService.presentation",
    "CenterAttentionService.indicators",
    "CenterFocusStore.text",
    "CenterFocusStore.openScratchpad()",
    "Text.ElideRight",
    "maximumLineCount: 1",
)
```

Reject Hyprland/Application/Notification/Audio imports, `Timer`, `Process`, `FileView`, shaders,
infinite animations and any active-window title in the new Center view.

- [ ] **Step 2: Run Bar checks and verify they fail**

Run: `python3 scripts/check_bar.py && python3 scripts/check_center_attention.py`

Expected: FAIL because the new true-center view/composition is absent.

- [ ] **Step 3: Implement `CenterIsland` and compose it beside the pin**

Use one elevated `Shared.Surface`, a bounded `RowLayout`, a small `Repeater` for frozen indicator
descriptors, and one primary `Shared.TextLabel`:

```qml
readonly property var eventPresentation: CenterAttentionService.presentation
readonly property string primaryText: root.eventPresentation
    ? root.eventPresentation.title
    : (CenterFocusStore.text || I18n.tr("menubar.center.focus_fallback"))

TapHandler { onTapped: CenterFocusStore.openScratchpad() }
```

Cap the text width at 320 logical pixels, keep `Metrics.controlHeight`, elide right and never wrap.
Use secondary tone for Daily Focus, ordinary primary tone for transient events, and danger tone only
for priority 70+. Give each passive icon an accessible name but no pointer handler in this slice.

Change `CenterGroup` to a `Row` containing `CenterIsland` then the unchanged `pinPill`, with
`Metrics.spacingSmall`; its `implicitWidth` is the row width. Keep `BarLayout.centerX(root.width,
centerGroup.width)` unchanged in `Bar.qml`.

- [ ] **Step 4: Add translated strings**

Add equal keys to both locale files:

```text
menubar.center.focus_fallback
menubar.center.accessible
menubar.center.scratchpad_open_failed
menubar.center.indicator.media
menubar.center.indicator.timer
menubar.center.indicator.jobs
```

Vietnamese fallback: `Tập trung cho hôm nay`. English fallback: `Focus for today`.

- [ ] **Step 5: Run static gates and commit the renderer**

Run: `python3 scripts/check_bar.py && python3 scripts/check_center_attention.py && ./scripts/check.sh`

Expected: PASS with no new qmllint warning.

```bash
git add Titonium/Bar config/i18n scripts/check_bar.py scripts/check_center_attention.py
git commit -m "feat: render daily focus in topbar center"
```

### Task 6: Add read-only Center acceptance and documentation

**Files:**
- Create: `scripts/center_attention_acceptance.sh`
- Modify: `Titonium/App.qml`
- Modify: `scripts/check.sh`
- Modify: `scripts/protected_acceptance.sh`
- Modify: `docs/ARCHITECTURE.md`
- Modify: `docs/TESTING.md`

**Interfaces:**
- Consumes: Center service state only.
- Produces: IPC `center.state()` and `center.focusState()`; no scratchpad-launch endpoint.

- [ ] **Step 1: Add a failing syntax/static contract for read-only IPC**

Require this handler in `App.qml`:

```qml
IpcHandler {
    target: "center"
    function state(): string { return CenterAttentionService.snapshot(); }
    function focusState(): string { return CenterFocusStore.snapshot(); }
}
```

Reject `openScratchpad`, `publish`, `acknowledge`, timer and job mutation methods from this base
acceptance seam.

- [ ] **Step 2: Implement snapshots and the acceptance script**

`center_attention_acceptance.sh` must start an isolated foreground Titonium instance, call both
read-only methods, require a Daily Focus fallback and `transient=false`, verify one DP-1 Bar and no
DP-3 Titonium layer, reject QML/runtime errors, and compare Git plus both Hyprland hashes before and
after. It must not create/edit focus files or launch an editor.

- [ ] **Step 3: Run focused and full verification**

Run:

```bash
bash -n scripts/center_attention_acceptance.sh
./scripts/check.sh
./scripts/smoke.sh
./scripts/center_attention_acceptance.sh
./scripts/center_notch_acceptance.sh
./scripts/protected_acceptance.sh
hyprctl configerrors
git diff --check
```

Expected: every command PASS; `hyprctl configerrors` prints no errors.

- [ ] **Step 4: Document ownership and manual review, then commit**

Document `CenterAttentionService`, `CenterFocusStore`, the renamed `ActiveWindowPill`, true-center
layout, read-only acceptance seam and manual click checkpoint. Add the acceptance script to
`protected_acceptance.sh` only after it is proven repository/user-file safe.

```bash
git add Titonium/App.qml scripts docs/ARCHITECTURE.md docs/TESTING.md
git commit -m "test: cover center daily focus lifecycle"
```

- [ ] **Step 5: Request visual/interaction review before MPRIS**

Ask the user to verify on DP-1 that the center remains physically centered, Daily Focus is visually
quiet, one click opens the configured Markdown handler, Active Window remains after Workspaces and
still opens Center Notch, and the Bar pin remains independently targetable. Do not start the MPRIS
plan until this checkpoint is approved.
