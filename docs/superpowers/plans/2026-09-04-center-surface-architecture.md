# Center Surface Architecture Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace theme-owned Center Island behavior with one neutral domain, controller, host, and renderer contract while preserving the behavior on `main` at `4ff9471`.

**Architecture:** Existing Center source services feed narrow adapters owned by `CenterDomain`, which publishes one immutable semantic snapshot and dispatches advertised actions. `CenterSurfaceController` owns screen, mode, selection, deadlines, focus, drag settlement, and generations; `CenterSurfaceHost` alone owns native windows, while Pill, Notch, Connected, and Classic renderers bind state and emit intents.

**Tech Stack:** QML/QtQuick, Quickshell/Wayland layer shell, QML JavaScript pure-rule modules, Node.js assertion fixtures, Python static architecture checks, shell acceptance tests.

**Spec:** `docs/superpowers/specs/2026-09-04-center-surface-architecture-design.md`

## Global Constraints

- Work only in `/home/cole/Projects/titonium/.worktrees/center-surface-architecture` on branch `refactor/center-surface-architecture`; do not modify, stash, reset, or clean the user's `main` checkout.
- Preserve behavior delivered on `main` at commit `4ff9471`; this is a refactor, not a Center redesign.
- Backend modules must not contain Pill, Notch, Connected, or Classic vocabulary and must not know the active theme.
- Themes must not import Capture, MPRIS, Notification, Agent Approval, Focus, Timer, or Job services.
- Existing singleton services remain sole runtime-listener owners; adapters are read-only projections plus explicit action dispatch.
- Only the neutral host and native-window helpers may use Center layer-shell, native-window, input-region, keyboard-focus, or stacking primitives.
- Pure rules receive time and geometry as arguments; they do not call `Date.now()`, use QML singletons, timers, or mutable globals.
- Snapshot values, nested details, arrays, indicators, capabilities, view state, presentation requests, and action results are frozen.
- Do not stop a user-owned Titonium/Quickshell instance. Use an isolated configuration ID only when the existing harness supports it safely.
- Keep commits scoped to the deliverable of each task. Do not merge until every required gate passes.

## File map

### New neutral domain files

- `Titonium/Services/Center/CenterDomainRules.js`: normalize and combine source projections, choose primary/secondary, freeze snapshots, and validate action results.
- `Titonium/Services/Center/CenterDomain.qml`: bind existing service/adapters, publish `snapshot` and `presentationRequested`, and expose `dispatch(intent)`.
- `Titonium/Services/Center/CenterActionDispatcher.qml`: validate current capabilities and route exactly one action to the owning adapter.
- `Titonium/Services/Center/adapters/*CenterAdapter.qml`: one projection/dispatch boundary per Capture, Media, Notification, Agent Approval, Focus, Timer, and Job service.

### New neutral surface files

- `Titonium/Core/Surfaces/Center/CenterSurfaceState.js`: pure lifecycle, selection, deadline, drag, and generation transitions.
- `Titonium/Core/Surfaces/Center/CenterSurfaceController.qml`: own mutable Center surface state and translate renderer/router/domain events into pure transitions.
- `Titonium/Core/Surfaces/Center/CenterSurfaceHost.qml`: compose screen-local native helpers with the chosen renderer/profile.
- `Titonium/Core/Surfaces/Center/CenterCompactWindow.qml`: compact layer-shell role only.
- `Titonium/Core/Surfaces/Center/CenterOverlayWindow.qml`: banner/expanded/dismissing layer-shell role only.
- `Titonium/Core/Surfaces/Center/qmldir`: neutral Center surface module exports.

### Presentation files

- `Titonium/Bar/center/CenterRenderer.qml`: common renderer entry point and intent forwarding.
- `Titonium/Bar/center/CenterPresentationRules.js`: pure profile normalization and available-geometry calculation.
- `Titonium/Bar/center/presentations/{Pill,Notch,Connected,Classic}/`: theme-specific static profile and renderer components.
- `Titonium/Bar/center/qmldir` and presentation `qmldir` files: QML exports.

### Existing files migrated or removed

- Migrate behavior from `Titonium/Bar/notch/CenterNotchCoordinator.qml`, `CenterNotchState.js`, `CenterNotchSurface.qml`, `CenterNotch.qml`, and `CenterPillWindow.qml`, then remove theme-owned lifecycle exports.
- Replace direct coordinator usage in `Titonium/App.qml`, `Bar/Bar.qml`, `Bar/BarHost.qml`, `Bar/BarSurface.qml`, `Bar/classic/ClassicCenterGroup.qml`, `Bar/islands/CenterIsland.qml`, `Bar/right/EdgeMenuSurface.qml`, `Bar/right/RightPillCoordinator.qml`, `Bar/widgets/NotificationBell.qml`, `Ipc/CoreIpc.qml`, `Orchestration/SurfaceRouter.qml`, and `Osd/Audio/AudioOsdCoordinator.qml`.
- Update Center checks in `scripts/check_center_notch.js`, `scripts/check_bar.py`, `scripts/check_classic_bar.js`, `scripts/check_top_bar_style_lifecycle.js`, and source-specific static checks.
- Add `scripts/check_center_domain.js`, `scripts/check_center_surface_state.js`, and `scripts/check_center_architecture.py`; register them in `scripts/check.sh`.
- Update `scripts/center_notch_acceptance.sh`, `docs/ARCHITECTURE.md`, `docs/MODULE_CONTRACT.md`, `docs/TESTING.md`, and `docs/THEMING_AND_GLASS.md`.

---

### Task 1: Freeze the Center Domain value contract

**Files:**
- Create: `scripts/check_center_domain.js`
- Create: `Titonium/Services/Center/CenterDomainRules.js`
- Modify: `scripts/check.sh`

**Interfaces:**
- Consumes: source projection arrays and an explicit `now` number.
- Produces: `normalizeContext(raw, now)`, `normalizeIndicator(raw)`, `normalizeCapability(raw, contextIds)`, `snapshot(previous, raw, now)`, and `actionResult(raw)` frozen values.

- [ ] **Step 1: Write failing domain contract fixtures**

Create a Node `vm` harness matching the existing Center rule tests. Assert exact normalization for all seven source names, recursive freezing, malformed-field rejection, primary/secondary membership, stable revision on equal semantic input, and incremented revision on change:

```js
const raw = {
  contexts: [
    { id: "focus:daily", source: "focus", kind: "daily", title: "Ship Center",
      subtitle: "", icon: "center_focus_strong", tone: "normal", attention: "ambient",
      progress: null, occurredAt: 10, expiresAt: 0, details: {}, actionIds: [] },
    { id: "media:vlc", source: "media", kind: "playback", title: "Track",
      subtitle: "Artist", icon: "music_note", tone: "normal", attention: "ambient",
      progress: 0.5, occurredAt: 20, expiresAt: 0,
      details: { identity: "VLC" }, actionIds: ["media.toggle"] }
  ],
  indicators: [],
  actions: [{ id: "media.toggle", contextId: "media:vlc", role: "primary",
    label: "Pause", icon: "pause", enabled: true }]
};
const first = rules.snapshot(null, raw, 100);
assert.equal(first.primary.id, "focus:daily");
assert.equal(first.secondary.id, "media:vlc");
assert.ok(Object.isFrozen(first) && Object.isFrozen(first.contexts[1].details));
assert.strictEqual(rules.snapshot(first, raw, 101), first);
assert.equal(rules.snapshot(first, { ...raw, indicators: [{ id: "recording", icon: "screen_record",
  accessibleName: "Recording", tone: "critical", active: true }] }, 102).revision, 2);
```

- [ ] **Step 2: Run the fixture and verify RED**

Run: `node scripts/check_center_domain.js`

Expected: FAIL because `CenterDomainRules.js` or its exported functions do not exist.

- [ ] **Step 3: Implement the minimal pure contract**

Implement allowlists for source, tone, attention, role, and field names. Clone/freeze `details`,
`actionIds`, arrays, capabilities, and the outer snapshot. Reuse the prior snapshot object when the
semantic serialization is equal; otherwise assign `revision = previous.revision + 1` or `1`.
Keep arbitration policy equivalent to current `CenterAttentionRules`, `CenterActivityRules`, and
`CenterNotchState.activitySlots`: transient attention first, Focus primary when enabled, Media next,
then current activity rank/recency, with deterministic ID tie-breaking.

- [ ] **Step 4: Run focused and existing Center rule tests**

Run:

```bash
node scripts/check_center_domain.js
node scripts/check_center_attention_rules.js
node scripts/check_center_activity_rules.js
node scripts/check_center_notch.js
```

Expected: all PASS.

- [ ] **Step 5: Register the test and commit**

Add `node "$project_root/scripts/check_center_domain.js"` beside the other Center checks in
`scripts/check.sh`.

```bash
git add scripts/check.sh scripts/check_center_domain.js Titonium/Services/Center/CenterDomainRules.js
git commit -m "test: define center domain value contract"
```

### Task 2: Add source adapters and exactly-once action dispatch

**Files:**
- Create: `Titonium/Services/Center/CenterDomain.qml`
- Create: `Titonium/Services/Center/CenterActionDispatcher.qml`
- Create: `Titonium/Services/Center/adapters/CaptureCenterAdapter.qml`
- Create: `Titonium/Services/Center/adapters/MediaCenterAdapter.qml`
- Create: `Titonium/Services/Center/adapters/NotificationCenterAdapter.qml`
- Create: `Titonium/Services/Center/adapters/AgentApprovalCenterAdapter.qml`
- Create: `Titonium/Services/Center/adapters/FocusCenterAdapter.qml`
- Create: `Titonium/Services/Center/adapters/TimerCenterAdapter.qml`
- Create: `Titonium/Services/Center/adapters/JobCenterAdapter.qml`
- Create: `Titonium/Services/Center/adapters/qmldir`
- Modify: `Titonium/Services/Center/qmldir`
- Modify: `scripts/check_center_domain.js`
- Modify: `scripts/check_center_attention.py`
- Modify: `scripts/check_mpris.py`
- Modify: `scripts/check_agent_approval.js`

**Interfaces:**
- Consumes: existing singleton state and actions from Capture, MPRIS, Notifications, Agent Approval, Focus, Timer, and Job.
- Produces: singleton `CenterDomain.snapshot`, signal `presentationRequested(var request)`, and `dispatch({type, actionId, contextId, idempotencyKey})`.

- [ ] **Step 1: Add failing static and dispatch fixtures**

Require every adapter to expose `readonly property var contexts`, `readonly property var indicators`,
`readonly property var actions`, and `function dispatch(actionId, contextId, idempotencyKey): var`.
Require `CenterActionDispatcher.dispatch(snapshot, intent)` to reject missing/stale/disabled actions
and call one injected adapter route once. Include this pure seam in the dispatcher:

```qml
property var routes: Object.freeze({})
function dispatch(snapshot: var, intent: var): var
```

Assert returned objects use only `accepted`, `status`, `reason`, and `closePolicy`, and are frozen.
Extend source architecture checks to require service imports only in the matching adapter and to
forbid new listener/process/timer ownership in adapters.

- [ ] **Step 2: Run tests and verify RED**

Run:

```bash
node scripts/check_center_domain.js
python3 scripts/check_center_attention.py
python3 scripts/check_mpris.py
node scripts/check_agent_approval.js
```

Expected: FAIL on missing domain/adapter contracts.

- [ ] **Step 3: Implement adapters and dispatcher**

Project existing state without changing source services. Map current actions explicitly: Capture
stop/open where currently available; Media toggle/previous/next/raise; Notification acknowledge/open;
Agent Approval approve/deny; Focus open/toggle; Timer pause/cancel where supported; Job clear or
required-action flow where supported. Do not advertise an action the existing service cannot perform.

Construct `CenterDomain.snapshot` by passing adapter values to `CenterDomainRules.snapshot()`.
Forward existing eligible attention changes as frozen `presentationRequested` values with
`contextId`, requested mode, timeout, and focus policy. Use explicit `now` only at the QML scheduling
boundary.

- [ ] **Step 4: Verify adapter boundaries and full static suite**

Run the four focused commands from Step 2, then `./scripts/check.sh`.

Expected: all PASS; qmllint may retain only existing allowlisted warnings.

- [ ] **Step 5: Commit**

```bash
git add Titonium/Services/Center scripts/check_center_domain.js \
  scripts/check_center_attention.py scripts/check_mpris.py scripts/check_agent_approval.js
git commit -m "feat: add neutral center domain adapters"
```

### Task 3: Define the pure Center surface state machine

**Files:**
- Create: `Titonium/Core/Surfaces/Center/CenterSurfaceState.js`
- Create: `scripts/check_center_surface_state.js`
- Modify: `scripts/check.sh`

**Interfaces:**
- Consumes: immutable current state, domain snapshot, a neutral intent, and explicit `now`.
- Produces: `initialState()`, `transition(state, snapshot, intent, now)`, `dragSettlePlan(progress, offset, velocity)`, `pauseDeadline(state, now)`, and `resumeDeadline(state, now)`.

- [ ] **Step 1: Write exhaustive failing transition fixtures**

Cover `closed/compact/banner/expanded`, selection fallback, explicit expanded-to-banner only,
transient refusal during expanded interaction, timed-banner pause/resume with remaining duration,
blocking focus policy, owner-screen loss, and stale generations:

```js
let state = rules.initialState();
state = rules.transition(state, snapshot, { type: "surface-granted", screenName: "DP-1" }, 1000);
assert.equal(state.mode, "compact");
state = rules.transition(state, snapshot, { type: "present", contextId: "notification:42",
  requestedMode: "banner", timeoutMs: 4000, focusPolicy: "none" }, 1100);
assert.deepEqual([state.mode, state.deadline], ["banner", 5100]);
const generation = state.generation;
assert.strictEqual(rules.transition(state, snapshot,
  { type: "transition-finished", generation: generation - 1 }, 1200), state);
```

Verify `dragSettlePlan(0.2, 48, 0)` and `dragSettlePlan(0.2, 0, 500)` target expanded,
while lower distance/velocity targets banner.

- [ ] **Step 2: Run and verify RED**

Run: `node scripts/check_center_surface_state.js`

Expected: FAIL because the rules module is missing.

- [ ] **Step 3: Implement pure state transitions**

Represent state with only the fields in the design spec. Every accepted change returns a new frozen
state. Every invalid or no-op intent returns the identical object. Increment generation on owner
changes and open/close cycles. Store paused remaining milliseconds separately in internal state but
exclude implementation-only data from the public `viewState()` result.

- [ ] **Step 4: Run focused tests**

Run:

```bash
node scripts/check_center_surface_state.js
node scripts/check_center_notch.js
```

Expected: PASS.

- [ ] **Step 5: Register and commit**

```bash
git add scripts/check.sh scripts/check_center_surface_state.js \
  Titonium/Core/Surfaces/Center/CenterSurfaceState.js
git commit -m "test: define neutral center surface state"
```

### Task 4: Implement the neutral controller and router handshake

**Files:**
- Create: `Titonium/Core/Surfaces/Center/CenterSurfaceController.qml`
- Create: `Titonium/Core/Surfaces/Center/qmldir`
- Modify: `Titonium/Core/Surfaces/qmldir`
- Modify: `Titonium/Orchestration/SurfaceRouter.qml`
- Modify: `scripts/check_center_surface_state.js`
- Create: `scripts/check_center_architecture.py`
- Modify: `scripts/check.sh`

**Interfaces:**
- Consumes: `CenterDomain.snapshot`, `CenterDomain.dispatch(intent)`, router grant/deny/revoke intents, screen names, and renderer intents.
- Produces: singleton properties from the spec, frozen `viewState`, `surfaceRequested(var request)`, `navigationRequested(var request)`, `dispatch(intent)`, and `finishClose(screenName, generation)`.

- [ ] **Step 1: Write failing controller/router architecture checks**

Require neutral API names `openCenter`, `presentCenterBanner`, and `closeCenter`. Reject imports or
references to `CenterNotchCoordinator` in `SurfaceRouter.qml`. Require the controller to expose:

```qml
signal surfaceRequested(var request)
signal navigationRequested(var request)
function dispatch(intent: var): var
function finishClose(screenName: string, generation: int): bool
```

Check that the controller does not import Bar presentation modules, Right Pill, Settings, Spotlight,
or individual business services.

- [ ] **Step 2: Run and verify RED**

Run:

```bash
node scripts/check_center_surface_state.js
python3 scripts/check_center_architecture.py
```

Expected: FAIL because controller and neutral router API are absent.

- [ ] **Step 3: Implement controller scheduling and handshake**

Keep one non-repeating QML `Timer` in the controller solely for the current presentation deadline.
On timeout dispatch `{ type: "timeout", generation }`. Feed all state mutations through
`CenterSurfaceState.transition()`. Resolve action intents with `CenterDomain.dispatch()` and apply
the returned close policy through another state transition. Emit surface acquisition/release and
navigation requests instead of importing other coordinators.

Update `SurfaceRouter` to resolve screens and Settings yield, coordinate `SurfaceManager` and Right
Pill, then respond with `surface-granted`, `surface-denied`, or `surface-revoked`. Do not yet remove
the old entry points needed by unmigrated callers; make them private temporary delegates marked for
removal in Task 8, not exported aliases.

- [ ] **Step 4: Run focused and router tests**

Run:

```bash
node scripts/check_center_surface_state.js
python3 scripts/check_center_architecture.py
node scripts/check_bar_popup_routing.js
python3 scripts/check_skeleton.py
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Titonium/Core/Surfaces Titonium/Orchestration/SurfaceRouter.qml \
  scripts/check_center_surface_state.js scripts/check_center_architecture.py scripts/check.sh
git commit -m "feat: add neutral center surface controller"
```

### Task 5: Extract presentation profiles and the renderer contract

**Files:**
- Create: `Titonium/Bar/center/CenterPresentationRules.js`
- Create: `Titonium/Bar/center/CenterRenderer.qml`
- Create: `Titonium/Bar/center/qmldir`
- Create: `Titonium/Bar/center/presentations/Connected/ConnectedProfile.js`
- Create: `Titonium/Bar/center/presentations/Connected/ConnectedRenderer.qml`
- Create: `Titonium/Bar/center/presentations/Connected/qmldir`
- Modify: `scripts/check_center_presentation_rules.js`
- Modify: `scripts/check_center_notch.js`
- Modify: `scripts/check_center_architecture.py`

**Interfaces:**
- Consumes: `snapshot`, `viewState`, static `profile`, and `availableGeometry`.
- Produces: `profile(style)`, `geometry(profile, availableGeometry, mode)`, renderer signal `intentRequested(var intent)`, transition signal `transitionFinished(int generation)`, and visual/interactive bounds.

- [ ] **Step 1: Write failing profile and renderer-boundary tests**

Assert profile values from the spec, clamped geometry on narrow/ultrawide screens, immutable output,
and fail-closed style normalization. Static checks must reject business service imports, `Timer`,
`Process`, `FileView`, `SurfaceManager`, `ScreenRouter`, and coordinator imports in renderer paths.

```js
const connected = rules.profile("connected");
assert.deepEqual(plain(connected.compact),
  { inset: 4, minWidth: 160, maxWidth: 480, height: 32, radius: 16 });
assert.equal(rules.geometry(connected, { width: 360, height: 800 }, "expanded").width, 320);
assert.ok(Object.isFrozen(connected.capabilities));
```

- [ ] **Step 2: Run and verify RED**

Run:

```bash
node scripts/check_center_presentation_rules.js
node scripts/check_center_notch.js
python3 scripts/check_center_architecture.py
```

Expected: FAIL on missing profile and renderer contract.

- [ ] **Step 3: Move Connected visuals behind the contract**

Move only visual/layout/animation code from the existing `CenterNotchSurface.qml`, `CenterNotch.qml`,
and `CenterIsland.qml` into `ConnectedRenderer.qml` and focused child components. Replace all service
reads with snapshot lookup and every direct coordinator/service call with `intentRequested()`.
Keep transition animation presentation-only and echo the supplied generation when finished.

`CenterRenderer.qml` selects a component from the presentation mapping, binds the three required
properties, and forwards intent/transition signals. It contains no business source branches.

- [ ] **Step 4: Run presentation tests**

Run the three commands from Step 2 plus `python3 scripts/check_bar.py`.

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Titonium/Bar/center scripts/check_center_presentation_rules.js \
  scripts/check_center_notch.js scripts/check_center_architecture.py scripts/check_bar.py
git commit -m "refactor: isolate connected center presentation"
```

### Task 6: Introduce the sole native Center host

**Files:**
- Create: `Titonium/Core/Surfaces/Center/CenterSurfaceHost.qml`
- Create: `Titonium/Core/Surfaces/Center/CenterCompactWindow.qml`
- Create: `Titonium/Core/Surfaces/Center/CenterOverlayWindow.qml`
- Modify: `Titonium/Core/Surfaces/Center/qmldir`
- Modify: `Titonium/Bar/BarHost.qml`
- Modify: `scripts/check_center_architecture.py`
- Modify: `scripts/check_surface_passthrough.py`
- Modify: `scripts/check_bar.py`

**Interfaces:**
- Consumes: screen model, `CenterSurfaceController.viewState`, `CenterDomain.snapshot`, selected profile, renderer bounds, and transition completion.
- Produces: screen-local native compact/overlay roles with exact input masks and controller generation acknowledgements.

- [ ] **Step 1: Write failing host ownership checks**

Require `CenterSurfaceHost` in each `BarHost` screen scope. Require all Center uses of `PanelWindow`,
`WlrLayershell`, `Region`, `keyboardFocus`, `aboveWindows`, and `exclusiveZone` to live only under
`Core/Surfaces/Center`. Assert compact input uses renderer `interactiveBounds`; overlay background
receives pointer only when dismissal policy permits it; dismissing geometry stays alive until the
matching generation completes.

- [ ] **Step 2: Run and verify RED**

Run:

```bash
python3 scripts/check_center_architecture.py
python3 scripts/check_surface_passthrough.py
python3 scripts/check_bar.py
```

Expected: FAIL while `CenterPillWindow.qml` still owns layer-shell behavior.

- [ ] **Step 3: Implement compact and overlay native roles**

Move the window mechanics from `CenterPillWindow.qml` into the two helpers. Bind overlay keyboard
focus strictly from controller `focusPolicy`; bind masks from renderer bounds; keep both helpers on
the same screen/generation. `CenterSurfaceHost` chooses the active renderer/profile from the
presentation preference but does not inspect source data. Forward outside dismissal and transition
completion as controller intents.

- [ ] **Step 4: Run host checks and qmllint gate**

Run the three focused commands from Step 2, then `./scripts/check.sh`.

Expected: PASS with no new qmllint errors or warnings outside the allowlist.

- [ ] **Step 5: Commit**

```bash
git add Titonium/Core/Surfaces/Center Titonium/Bar/BarHost.qml \
  scripts/check_center_architecture.py scripts/check_surface_passthrough.py scripts/check_bar.py
git commit -m "refactor: centralize center native surface hosting"
```

### Task 7: Migrate every entry point to neutral intents

**Files:**
- Modify: `Titonium/App.qml`
- Modify: `Titonium/Bar/Bar.qml`
- Modify: `Titonium/Bar/BarSurface.qml`
- Modify: `Titonium/Bar/classic/ClassicCenterGroup.qml`
- Modify: `Titonium/Bar/islands/CenterIsland.qml`
- Modify: `Titonium/Bar/right/EdgeMenuSurface.qml`
- Modify: `Titonium/Bar/right/RightPillCoordinator.qml`
- Modify: `Titonium/Bar/widgets/NotificationBell.qml`
- Modify: `Titonium/Ipc/CoreIpc.qml`
- Modify: `Titonium/Orchestration/SurfaceRouter.qml`
- Modify: `Titonium/Osd/Audio/AudioOsdCoordinator.qml`
- Modify: relevant `qmldir` files
- Modify: `scripts/check_center_activation_rules.js`
- Modify: `scripts/check_bar_popup_routing.js`
- Modify: `scripts/check_top_bar_style_lifecycle.js`

**Interfaces:**
- Consumes: router `openCenter`, `presentCenterBanner`, `closeCenter`; controller `dispatch`; domain capability IDs.
- Produces: no call site import or use of `CenterNotchCoordinator`; no hard-coded MPRIS/service action in router or presentation.

- [ ] **Step 1: Change static tests to require neutral calls**

Require the global shortcut to call `router.openCenter(null, "overview", "")`; Notification Bell to
route a context ID/policy rather than a raw service descriptor; Audio/Right Pill/Settings mutual
exclusion to call `closeCenter(reason)`; and source actions to be capability intents. Reject
`activateCenterSource`, `openCenterNotch`, `openCenterBanner`, and direct MPRIS imports in router.

- [ ] **Step 2: Run and verify RED**

Run:

```bash
node scripts/check_center_activation_rules.js
node scripts/check_bar_popup_routing.js
node scripts/check_top_bar_style_lifecycle.js
python3 scripts/check_center_architecture.py
```

Expected: FAIL on legacy API references.

- [ ] **Step 3: Migrate call sites**

Replace raw context objects crossing the surface boundary with stable context IDs. Route UI actions
through renderer/controller intents and domain capabilities. Preserve existing IPC response strings
unless the old string exposes the removed theme name; in that case update its contract fixture to a
neutral `open:<screen>;mode=<mode>` result. Ensure Settings, Spotlight, Right Pill, Audio OSD, and
generic SurfaceManager acquisitions revoke Center through the router handshake.

- [ ] **Step 4: Run focused and complete static gates**

Run the four commands from Step 2, then `./scripts/check.sh`.

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Titonium scripts/check_center_activation_rules.js scripts/check_bar_popup_routing.js \
  scripts/check_top_bar_style_lifecycle.js scripts/check_center_architecture.py
git commit -m "refactor: route center interactions through neutral intents"
```

### Task 8: Complete all four presentations and remove legacy ownership

**Files:**
- Create: `Titonium/Bar/center/presentations/Pill/PillProfile.js`
- Create: `Titonium/Bar/center/presentations/Pill/PillRenderer.qml`
- Create: `Titonium/Bar/center/presentations/Notch/NotchProfile.js`
- Create: `Titonium/Bar/center/presentations/Notch/NotchRenderer.qml`
- Create: `Titonium/Bar/center/presentations/Classic/ClassicProfile.js`
- Create: `Titonium/Bar/center/presentations/Classic/ClassicRenderer.qml`
- Create: corresponding `qmldir` files
- Modify: `Titonium/Bar/center/CenterRenderer.qml`
- Modify: `Titonium/Bar/center/CenterPresentationRules.js`
- Delete after migration: `Titonium/Bar/notch/CenterNotchCoordinator.qml`
- Delete after migration: `Titonium/Bar/notch/CenterNotchState.js`
- Delete after migration: `Titonium/Bar/notch/CenterNotchSurface.qml`
- Delete after migration: `Titonium/Bar/notch/CenterNotch.qml`
- Delete after migration: `Titonium/Bar/notch/CenterPillWindow.qml`
- Modify or delete: `Titonium/Bar/notch/qmldir`
- Modify: `scripts/check_center_presentation_rules.js`
- Modify: `scripts/check_center_notch.js`
- Modify: `scripts/check_classic_bar.js`
- Modify: `scripts/check_center_architecture.py`

**Interfaces:**
- Consumes: the renderer/profile contract from Task 5.
- Produces: four theme implementations with identical business behavior and no legacy coordinator export.

- [ ] **Step 1: Add failing parity and theme-switch fixtures**

For each theme assert a valid frozen profile, renderer export, all four modes, safe geometry, and
the same intent names. Static fixtures must prove theme switching never writes controller state and
that each renderer imports no business service. Require the legacy coordinator files and QML export
to be absent.

- [ ] **Step 2: Run and verify RED**

Run:

```bash
node scripts/check_center_presentation_rules.js
node scripts/check_center_notch.js
node scripts/check_classic_bar.js
python3 scripts/check_center_architecture.py
```

Expected: FAIL until all profiles exist and legacy ownership is removed.

- [ ] **Step 3: Implement the remaining renderers and delete legacy files**

Move only theme-specific geometry, shapes, layout, and animation into each presentation directory.
Share semantic content components through `Bar/center` when their behavior is identical. Map the
existing style preference to a profile/renderer only at `CenterRenderer.qml`. Remove temporary
router delegates and all obsolete `Bar/notch` exports after `rg` finds no consumer.

- [ ] **Step 4: Prove no legacy consumer remains**

Run:

```bash
rg -n "CenterNotchCoordinator|CenterPillWindow|CenterNotchSurface" Titonium scripts
node scripts/check_center_presentation_rules.js
node scripts/check_center_notch.js
node scripts/check_classic_bar.js
python3 scripts/check_center_architecture.py
./scripts/check.sh
```

Expected: `rg` returns no production-QML matches; test code may retain the names only as explicit
negative assertions. All tests PASS.

- [ ] **Step 5: Commit**

```bash
git add -A Titonium/Bar Titonium/Orchestration scripts
git commit -m "refactor: make center styles presentation-only"
```

### Task 9: Update architecture documentation and runtime acceptance

**Files:**
- Modify: `docs/ARCHITECTURE.md`
- Modify: `docs/MODULE_CONTRACT.md`
- Modify: `docs/TESTING.md`
- Modify: `docs/THEMING_AND_GLASS.md`
- Modify: `scripts/center_notch_acceptance.sh`
- Modify: `scripts/check_center_architecture.py`

**Interfaces:**
- Consumes: completed neutral architecture.
- Produces: documented dependency rules and runtime assertions for the logical Center surface.

- [ ] **Step 1: Add failing acceptance/static assertions**

Extend the acceptance script to recognize neutral namespaces and exercise compact → banner →
expanded → compact, outside click, Escape, keyboard navigation, drag, timeout, isolated Agent
Approval, theme switch, and owner-monitor loss. Add repository-integrity snapshots before/after and
keep the existing refusal to manipulate a user-owned running configuration.

- [ ] **Step 2: Run syntax/static checks and verify RED where contracts are undocumented**

Run:

```bash
bash -n scripts/center_notch_acceptance.sh
python3 scripts/check_center_architecture.py
```

Expected: shell syntax PASS; architecture documentation assertions FAIL until docs are updated.

- [ ] **Step 3: Document final boundaries and operations**

Update diagrams and dependency text to name Center Domain, Controller, Host, Profile, and Renderer.
Document snapshot/action/surface intent contracts, source adapter restrictions, timeout ownership,
generation-safe theme switching, neutral router APIs, and the native-window implementation detail.
Remove statements claiming `CenterNotchSurface` or a theme coordinator owns lifecycle.

- [ ] **Step 4: Run documentation and static gates**

Run:

```bash
bash -n scripts/center_notch_acceptance.sh
python3 scripts/check_center_architecture.py
./scripts/check.sh
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add docs/ARCHITECTURE.md docs/MODULE_CONTRACT.md docs/TESTING.md \
  docs/THEMING_AND_GLASS.md scripts/center_notch_acceptance.sh \
  scripts/check_center_architecture.py
git commit -m "docs: document neutral center surface boundaries"
```

### Task 10: Run complete verification and prepare the fast-forward merge

**Files:**
- Modify only if verification exposes a scoped defect: files already listed in Tasks 1–9.

**Interfaces:**
- Consumes: completed implementation and all repository gates.
- Produces: evidence that the branch is safe to review and fast-forward, without altering user state.

- [ ] **Step 1: Run the complete static suite**

Run: `./scripts/check.sh`

Expected: exit 0. Record any pre-existing allowlisted qmllint warnings separately from failures.

- [ ] **Step 2: Run isolated foreground smoke**

Run: `./scripts/smoke.sh`

Expected: exit 0, no runtime QML error, no repository or Hyprland configuration mutation.

- [ ] **Step 3: Run protected acceptance**

Run: `./scripts/protected_acceptance.sh`

Expected: exit 0 with Spotlight, Input Method, dynamic screen lifecycle, and other protected
contracts intact.

- [ ] **Step 4: Run focused Center Wayland acceptance**

Run: `./scripts/center_notch_acceptance.sh`

Expected: exit 0 across the four themes and required interaction flows. If an existing configuration
ID owns the runtime and the harness cannot isolate safely, stop this step and report the exact
blocker; do not stop the user's instance.

- [ ] **Step 5: Check compositor errors without changing configuration**

Run: `hyprctl configerrors`

Expected: empty output or only errors proven to predate this branch.

- [ ] **Step 6: Review architecture and repository cleanliness**

Run:

```bash
python3 scripts/check_center_architecture.py
git diff 4ff9471 --check
git status --short
git log --oneline 4ff9471..HEAD
```

Expected: architecture PASS, no whitespace errors, and only scoped committed files. Inspect the
entire `git diff --stat 4ff9471..HEAD` and sampled full diff before declaring completion.

- [ ] **Step 7: Stop or confirm the verified result**

If any verification command fails, do not make an ad-hoc verification change: return to the task
that owns the failing contract, add the concrete regression assertion there, repeat that task's
RED/GREEN cycle, commit its exact scoped files using that task's commit step, and restart Task 10.
If no defect was found, create no empty commit and continue.

- [ ] **Step 8: Verify `main` can be fast-forwarded without touching user changes**

From the main checkout, run read-only checks:

```bash
git -C /home/cole/Projects/titonium status --short
git -C /home/cole/Projects/titonium merge-base --is-ancestor main refactor/center-surface-architecture
```

Expected: the ancestor check exits 0. Preserve every listed user change. If the final merge would
overlap or overwrite an uncommitted path, stop and report it. Otherwise request/confirm the final
merge action according to the active workflow; use fast-forward only and never stash/reset.
