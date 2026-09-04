# Exclusive Focus Arbiter Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Guarantee that only one Titonium layer can project interactive keyboard focus and insert a compositor-visible release boundary before focus changes owners.

**Architecture:** A pure `FocusArbiterRules.js` state machine owns generation-safe request, withdrawal, and grant transitions. A `FocusArbiter.qml` singleton schedules the sole `Qt.callLater` handoff; every interactive surface submits desire and derives effective keyboard focus from its arbiter grant.

**Tech Stack:** Quickshell 0.3.1, Qt 6 QML, JavaScript state rules, Node.js contract tests, Hyprland layer-shell IPC.

**Spec:** `docs/superpowers/specs/2026-09-04-exclusive-focus-arbiter-design.md`

## Global Constraints

- At most one Titonium layer may expose interactive keyboard focus at a time.
- Ownership handoff must include one event-loop interval with no granted owner.
- Ambiguous and stale state fails closed to `WlrKeyboardFocus.None`.
- Do not add Bluetooth-specific behavior or focus timers to feature routers.
- Preserve existing surface presentation, animation, screen routing, and lazy lifecycle.
- Do not edit either protected `hyprland.lua` file.
- Preserve all pre-existing uncommitted work.

## File map

- Create `Titonium/Core/Surfaces/FocusArbiterRules.js`: pure immutable state transitions.
- Create `Titonium/Core/Surfaces/FocusArbiter.qml`: QML scheduling and logging boundary.
- Modify `Titonium/Core/Surfaces/qmldir`: export the singleton.
- Modify five interactive window files: submit desire, withdraw on destruction, and bind effective focus to the arbiter.
- Replace `scripts/check_focus_ownership.js`: regression tests for rules and integration contracts.
- Modify `scripts/check.sh` only if the focused test is not already invoked; it currently is.

---

### Task 1: Pure generation-safe focus ownership rules

**Files:**
- Create: `Titonium/Core/Surfaces/FocusArbiterRules.js`
- Modify: `scripts/check_focus_ownership.js`

**Interfaces:**
- Produces: `initial() -> Snapshot`
- Produces: `request(current, ownerId) -> Snapshot`
- Produces: `withdraw(current, ownerId) -> Snapshot`
- Produces: `grantPending(current, generation) -> Snapshot`
- `Snapshot`: frozen `{ owner, pendingOwner, generation, phase, shouldSchedule, violation }`

- [ ] **Step 1: Write failing state-machine tests**

Replace the diagnostic-only assertions with cases that load both rules modules and assert:

```js
let state = arbiter.initial();
state = arbiter.request(state, "edge-menu:DP-1");
assert.deepEqual(plain(state), {
  owner: "edge-menu:DP-1", pendingOwner: "", generation: 1,
  phase: "owned", shouldSchedule: false, violation: ""
});

state = arbiter.request(state, "center:DP-1");
assert.equal(state.owner, "");
assert.equal(state.pendingOwner, "center:DP-1");
assert.equal(state.phase, "releasing");
assert.equal(state.shouldSchedule, true);
const centerGeneration = state.generation;

state = arbiter.request(state, "overlay:spotlight:DP-1");
assert.equal(state.pendingOwner, "overlay:spotlight:DP-1");
assert.equal(arbiter.grantPending(state, centerGeneration).owner, "");
state = arbiter.grantPending(state, state.generation);
assert.equal(state.owner, "overlay:spotlight:DP-1");

const staleRelease = arbiter.withdraw(state, "center:DP-1");
assert.equal(staleRelease.owner, "overlay:spotlight:DP-1");
assert.equal(arbiter.withdraw(state, "overlay:spotlight:DP-1").phase, "idle");
```

Also cover blank-owner rejection, idempotent current-owner request, pending withdrawal, and Center → Spotlight → Settings replacement.

- [ ] **Step 2: Run the focused test and verify RED**

Run: `node scripts/check_focus_ownership.js`

Expected: FAIL because `FocusArbiterRules.js` does not exist or the required functions are undefined.

- [ ] **Step 3: Implement the minimal pure state machine**

Implement normalized owner IDs, frozen snapshots, monotonically increasing generations, immediate first grant, owner replacement through `releasing`, newest-pending replacement, generation-checked grant, and owner-specific withdrawal. `grantPending` must clear `shouldSchedule`; stale generations return the existing state unchanged.

- [ ] **Step 4: Run focused test and verify GREEN**

Run: `node scripts/check_focus_ownership.js`

Expected: state-machine assertions pass; integration assertions may remain RED until Task 2 only if separated under a clear second failure message.

- [ ] **Step 5: Commit Task 1**

```bash
git add Titonium/Core/Surfaces/FocusArbiterRules.js scripts/check_focus_ownership.js
git commit -m "test: define exclusive focus arbitration"
```

---

### Task 2: QML arbiter and interactive-surface integration

**Files:**
- Create: `Titonium/Core/Surfaces/FocusArbiter.qml`
- Modify: `Titonium/Core/Surfaces/qmldir`
- Modify: `Titonium/Core/Surfaces/OverlayHost.qml`
- Modify: `Titonium/Core/Surfaces/Center/CenterOverlayWindow.qml`
- Modify: `Titonium/Bar/right/EdgeMenuWindow.qml`
- Modify: `Titonium/Settings/SettingsWindow.qml`
- Modify: `Titonium/AgentApproval/AgentApprovalWindow.qml`
- Modify: `scripts/check_focus_ownership.js`

**Interfaces:**
- Consumes: Task 1 `FocusArbiterRules` functions and snapshot shape.
- Produces: `FocusArbiter.request(ownerId: string, active: bool): void`
- Produces: `FocusArbiter.withdraw(ownerId: string): void`
- Produces: `FocusArbiter.granted(ownerId: string): bool`
- Produces: readonly `owner`, `pendingOwner`, `phase`, and `generation` properties.

- [ ] **Step 1: Write failing QML integration contracts**

For each interactive window, assert source structure contains a stable `focusOwnerId`, calls `FocusArbiter.request(focusOwnerId, wantsInteractiveFocus)`, withdraws on destruction, and gates `WlrLayershell.keyboardFocus` through `FocusArbiter.granted(focusOwnerId)`. Assert `FocusArbiter.qml` has exactly one `Qt.callLater`, while `SurfaceRouter.qml`, `RightPillCoordinator.qml`, and feature services have none for focus handoff.

- [ ] **Step 2: Run focused test and verify RED**

Run: `node scripts/check_focus_ownership.js`

Expected: FAIL with missing `FocusArbiter.qml`/missing window integration.

- [ ] **Step 3: Implement `FocusArbiter.qml`**

Use a singleton `QtObject` with `property var state`, readonly projections, and:

```qml
function request(ownerId: string, active: bool): void {
    const next = active
        ? FocusArbiterRules.request(root.state, ownerId)
        : FocusArbiterRules.withdraw(root.state, ownerId);
    root.apply(next);
}

function scheduleGrant(generation: int): void {
    Qt.callLater(() => {
        const next = FocusArbiterRules.grantPending(root.state, generation);
        root.apply(next);
    });
}

function granted(ownerId: string): bool {
    return root.owner === ownerId && root.phase === "owned";
}
```

`apply` assigns changed state, logs violations/replacements, and schedules only when `shouldSchedule` is true. Prevent duplicate scheduling for the same generation.

- [ ] **Step 4: Integrate every interactive window**

Use stable IDs based on family and screen. `wantsInteractiveFocus` retains each window's current logical condition. For Agent Approval, preserve `OnDemand` rather than upgrading it to `Exclusive`, but gate it behind the same arbiter grant. Move `FocusDiagnostics.observe` to effective grant changes so diagnostics describe compositor-facing ownership.

- [ ] **Step 5: Run focused test and qmllint gate**

Run: `node scripts/check_focus_ownership.js`

Expected: PASS all state and source-contract cases.

Run: `./scripts/check.sh`

Expected: all contract checks and qmllint pass with only the repository's allowlisted warnings.

- [ ] **Step 6: Commit Task 2**

```bash
git add Titonium/Core/Surfaces/FocusArbiter.qml Titonium/Core/Surfaces/FocusArbiterRules.js Titonium/Core/Surfaces/qmldir Titonium/Core/Surfaces/OverlayHost.qml Titonium/Core/Surfaces/Center/CenterOverlayWindow.qml Titonium/Bar/right/EdgeMenuWindow.qml Titonium/Settings/SettingsWindow.qml Titonium/AgentApproval/AgentApprovalWindow.qml scripts/check_focus_ownership.js
git commit -m "fix: serialize interactive surface focus"
```

---

### Task 3: Runtime regression and full verification

**Files:**
- Modify if needed: `scripts/protected_acceptance.sh`
- Modify if needed: `docs/PERFORMANCE.md`

**Interfaces:**
- Consumes: Task 2 arbiter and integrated surfaces.
- Produces: runtime evidence that focus handoffs release before acquisition and leave no conflict warnings.

- [ ] **Step 1: Add a failing acceptance assertion before any script change**

Use the existing protected acceptance lifecycle to open Edge Menu/Spotlight/Center/Settings where public IPC exists. Capture Quickshell logs and reject:

```text
exclusive-focus-conflict
missing-focus-owner
```

Require ordered `released <old-owner>` before `acquired <new-owner>` for each exercised handoff. If Edge Menu lacks a safe public IPC seam, keep its state-machine regression in Task 1 and exercise the available Center → Spotlight → Settings transitions live rather than adding test-only production IPC.

- [ ] **Step 2: Demonstrate the assertion against the pre-fix trace**

Run the log assertion against the captured runtime sequence from the investigation.

Expected: FAIL on `exclusive-focus-conflict:edge-menu:DP-1:center:DP-1`.

- [ ] **Step 3: Run isolated runtime gates**

Stop only the existing Titonium shell through its documented shell ID, run `./scripts/smoke.sh` and `./scripts/protected_acceptance.sh`, and restore exactly one daemon afterward. Do not terminate ChatGPT, Hyprland, or unrelated Quickshell configurations.

Expected: `Configuration Loaded`, clean runtime log, and all protected acceptance checks pass.

- [ ] **Step 4: Run compositor and repository verification**

Run:

```bash
./scripts/check.sh
git diff --check
hyprctl configerrors
qs -p /home/cole/Projects/titonium ipc call app status
```

Expected: all commands exit successfully, Hyprland reports no config errors, and app status is `ready`.

- [ ] **Step 5: Inspect the final diff and preserve unrelated work**

Run: `git status --short` and `git diff -- <all files from Tasks 1-3>`.

Expected: only focus-arbiter changes are staged/committed by this plan; all unrelated pre-existing modified and untracked files remain untouched.

- [ ] **Step 6: Commit acceptance/documentation changes if created**

```bash
git add scripts/protected_acceptance.sh docs/PERFORMANCE.md
git commit -m "test: verify exclusive focus handoffs"
```

