# Center Live Activity Rotation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rotate active Timer and Job progress through the physical Center TopBar while preserving transient-event precedence and Daily Focus fallback.

**Architecture:** A new session-only `CenterActivityService` owns the rotation clock and delegates normalization, ranking and cursor transitions to pure `CenterActivityRules`. Existing Timer and Job services publish internal value descriptors to this registry; `CenterIsland` selects Attention, then Activity, then Daily Focus without changing Center Notch.

**Tech Stack:** Quickshell/QML, pure JavaScript, Node.js rule fixtures, Python static architecture checks and Bash runtime acceptance.

**Spec:** `docs/superpowers/specs/2026-08-28-center-live-activity-rotation-design.md`

## Global Constraints

- Presentation precedence is exactly Attention event, then Activity slot, then Daily Focus.
- A round is Daily Focus for 10 seconds followed by at most three activities for 6 seconds each.
- Ranking is timer, important job, normal job; ties use `updatedAt` descending then ID ascending.
- External callers cannot set numeric priority, rotation rank or dwell time.
- Attention pauses rotation; hidden slots are never consumed.
- Media remains a passive icon plus existing transient media events and never joins rotation.
- Existing passive Timer and Job indicators remain unchanged.
- Use exactly one non-repeating rotation `Timer`; add no repeating poller.
- Add no process enumeration, `/proc` scan, terminal parsing or download-directory watcher.
- Center Notch layout, content and click routing are outside this slice.
- Activity state is session-only, bounded to 32 descriptors and exposes frozen value data only.

---

## File structure

```text
Titonium/Services/Center/
├── CenterActivityRules.js       # normalize, rank and advance rotation state
├── CenterActivityService.qml    # registry, non-repeating scheduler and translated title
├── CenterJobService.qml         # publish/remove active job descriptors
├── CenterTimerService.qml       # publish/remove active timer descriptors
└── qmldir                       # register the singleton

Titonium/Bar/islands/
└── CenterIsland.qml             # Attention > Activity > Focus projection

scripts/
├── check_center_activity_rules.js
├── check_center_activity.py
├── center_activity_acceptance.sh
└── check.sh

config/i18n/
├── en.json
└── vi.json
```

### Task 1: Define the pure activity registry and rotation rules

**Files:**
- Create: `Titonium/Services/Center/CenterActivityRules.js`
- Create: `scripts/check_center_activity_rules.js`
- Modify: `scripts/check.sh`

**Interfaces:**
- Consumes: `upsert(state, descriptor, now)`, `remove(state, id)`, `advance(state)`.
- Produces: frozen `{ activities, currentId, showingFocus, generation }`,
  `current(state)`, `visiblePool(state)` and `remainingMinutes(deadline, now)`.
- Descriptor fields are exactly `id`, `source`, `label`, `icon`, `importance`, `progress`,
  `deadline`, `updatedAt`.

- [ ] **Step 1: Write the failing normalization and bound fixtures**

Create a Node fixture that loads the `.pragma library` file through `vm`, then assert:

```js
let state = rules.initialState();
state = rules.upsert(state, {
    id: " job:build ", source: "job", label: " Build   Titonium ",
    icon: "work", importance: "important", progress: 62,
    deadline: 0, updatedAt: 1000,
}, 1000);
assert.deepEqual(plain(state.activities[0]), {
    id: "job:build", source: "job", label: "Build Titonium",
    icon: "work", importance: "important", progress: 62,
    deadline: 0, updatedAt: 1000,
});
assert.equal(Object.isFrozen(state.activities[0]), true);
```

Reject blank IDs/labels, sources other than `timer|job`, job progress outside `0...100`, timer
descriptors without a future deadline, raw `priority`, raw `rank`, raw `ttl`, commands and
callbacks. Insert 33 valid IDs and assert only the highest-ranked/newest 32 remain.

- [ ] **Step 2: Run the fixture and verify it fails**

Run: `node scripts/check_center_activity_rules.js`

Expected: FAIL because `CenterActivityRules.js` does not exist.

- [ ] **Step 3: Implement immutable normalization and ranking**

Use this internal rank function; never retain the numeric result on a public descriptor:

```js
function activityRank(activity) {
    if (activity.source === "timer") return 30;
    return activity.importance === "important" ? 25 : 20;
}
```

Sort rank descending, `updatedAt` descending, then ID ascending. `visiblePool(state)` returns the
first three descriptors. Upserting the same ID replaces its value while preserving the current
slot. Removing the visible ID returns a state with `showingFocus: true` and `currentId: ""`.

- [ ] **Step 4: Add failing cursor and duration-independent fixtures**

Assert the exact sequence with three ranked items:

```js
assert.equal(rules.current(state), null);
state = rules.advance(state);
assert.equal(rules.current(state).id, "timer:tea");
state = rules.advance(state);
assert.equal(rules.current(state).id, "job:important");
state = rules.advance(state);
assert.equal(rules.current(state).id, "job:normal");
state = rules.advance(state);
assert.equal(rules.current(state), null);
```

Also assert that a fourth lower-ranked item is absent from `visiblePool`, an updated current item
does not reset the cursor, removal of a non-current item preserves the cursor, an empty registry
stays on Focus, and generations advance only when presentation changes.

- [ ] **Step 5: Implement cursor transitions and timer formatting helper**

`advance(state)` moves Focus to pool index zero, advances by current ID through the current pool,
and moves the final item back to Focus. Implement:

```js
function remainingMinutes(deadline, now) {
    return Math.max(0, Math.ceil((deadline - now) / 60000));
}
```

Return `0` for invalid inputs. Do not call `Date.now()`, translate strings or create timers in the
rules file.

- [ ] **Step 6: Run the unit gate and commit**

Add `node "$project_root/scripts/check_center_activity_rules.js"` after Center Attention rules in
`scripts/check.sh`.

Run:

```bash
node scripts/check_center_activity_rules.js
bash -n scripts/check.sh
```

Expected: all activity rule fixtures print PASS.

```bash
git add Titonium/Services/Center/CenterActivityRules.js scripts/check_center_activity_rules.js scripts/check.sh
git commit -m "feat: define center activity rotation rules"
```

### Task 2: Add the activity singleton and event-driven scheduler

**Files:**
- Create: `Titonium/Services/Center/CenterActivityService.qml`
- Create: `scripts/check_center_activity.py`
- Modify: `Titonium/Services/Center/qmldir`
- Modify: `Titonium/App.qml`
- Modify: `scripts/check.sh`
- Modify: `config/i18n/en.json`
- Modify: `config/i18n/vi.json`

**Interfaces:**
- Consumes: `upsert(descriptor)`, `remove(id)` and `CenterAttentionService.hasTransient`.
- Produces: readonly `presentation`, `hasActivity`, `showingFocus`, `activeCount`, and `snapshot()`.
- `presentation` is either `null` or a frozen `{ id, source, icon, title, progress }` value.

- [ ] **Step 1: Write a failing service architecture check**

Require these exact contracts in `scripts/check_center_activity.py`:

```qml
pragma Singleton
readonly property var presentation:
readonly property bool hasActivity:
readonly property bool showingFocus:
readonly property int activeCount:
function upsert(descriptor: var): bool
function remove(activityId: string): bool
function snapshot(): string
```

Require `CenterActivityRules.upsert`, `.remove`, `.advance`, `.current`,
`.remainingMinutes`, `CenterAttentionService.hasTransient`, exactly one `Timer {`, and
`repeat: false`. Reject `Process`, `FileView`, `repeat: true`, `/proc`, `ps`, `pgrep`, shell
commands, public priority/TTL arguments and more than one timer.

- [ ] **Step 2: Run the architecture check and verify it fails**

Run: `python3 scripts/check_center_activity.py`

Expected: FAIL because the service and singleton registration are missing.

- [ ] **Step 3: Implement the registry boundary and translated projection**

The service stores only rule state. `upsert` and `remove` apply pure rule results and call one
`reschedule()` method. Build presentation titles at slot activation:

```qml
function titleFor(activity: var, now: double): string {
    if (activity.source === "timer") {
        const minutes = CenterActivityRules.remainingMinutes(activity.deadline, now);
        const key = minutes < 1
            ? "menubar.center.activity.timer_under_minute"
            : "menubar.center.activity.timer_minutes";
        return I18n.tr(key, { "label": activity.label, "minutes": minutes });
    }
    return I18n.tr("menubar.center.activity.job_progress", {
        "label": activity.label,
        "percent": Math.round(activity.progress)
    });
}
```

Add exact translations:

```json
"menubar.center.activity.job_progress": "{label} · {percent}%",
"menubar.center.activity.timer_minutes": "{label} · {minutes} min remaining",
"menubar.center.activity.timer_under_minute": "{label} · less than 1 min"
```

```json
"menubar.center.activity.job_progress": "{label} · {percent}%",
"menubar.center.activity.timer_minutes": "{label} · còn {minutes} phút",
"menubar.center.activity.timer_under_minute": "{label} · còn dưới 1 phút"
```

- [ ] **Step 4: Implement one non-repeating scheduler**

`reschedule()` stops the timer first. It leaves the timer stopped when there are no activities or
when `CenterAttentionService.hasTransient` is true. Otherwise it schedules 10000 ms for a Focus
slot and 6000 ms for an activity slot. `onTriggered` applies `CenterActivityRules.advance`, rebuilds
the frozen presentation with one `Date.now()` sample and schedules the next boundary.

Add a `Connections` handler for `CenterAttentionService.hasTransientChanged`: stop while true;
when false, rebuild the current slot title and grant it a fresh full dwell interval. Hidden slots
must never call `advance`.

- [ ] **Step 5: Register, pin and expose read-only diagnostics**

Add:

```text
singleton CenterActivityService 1.0 CenterActivityService.qml
```

Call `CenterActivityService.activate()` beside existing Job/Timer activation in `App.qml`. Add only
this read-only method to the existing `center` IPC handler:

```qml
function activityState(): string { return CenterActivityService.snapshot(); }
```

Do not expose activity mutation through IPC; external integrations continue through `centerJob`.

- [ ] **Step 6: Run service/static gates and commit**

Add `python3 "$project_root/scripts/check_center_activity.py"` after the activity rule fixture in
`scripts/check.sh`.

Run:

```bash
node scripts/check_center_activity_rules.js
python3 scripts/check_center_activity.py
python3 scripts/validate_config.py
```

Expected: PASS, with matching English/Vietnamese key sets.

```bash
git add Titonium/Services/Center/CenterActivityService.qml Titonium/Services/Center/qmldir Titonium/App.qml config/i18n scripts/check_center_activity.py scripts/check.sh
git commit -m "feat: add center activity rotation service"
```

### Task 3: Feed active Timer and Job state into the registry

**Files:**
- Modify: `Titonium/Services/Center/CenterJobService.qml`
- Modify: `Titonium/Services/Center/CenterTimerService.qml`
- Modify: `scripts/check_center_job.py`
- Modify: `scripts/check_center_timer.py`

**Interfaces:**
- Consumes: existing normalized Job and Timer service state.
- Produces: `job:<id>` activities on job start/progress and `timer:<id>` activities while timers
  remain active.

- [ ] **Step 1: Add failing Job integration contracts**

Require `CenterJobService` to call `CenterActivityService.upsert` after accepted start/progress and
`CenterActivityService.remove("job:" + normalizedId)` after complete/fail/requireAction/clear.
Assert the descriptor mapping contains:

```qml
{
    "id": "job:" + job.id,
    "source": "job",
    "label": job.label,
    "icon": "work",
    "importance": job.importance,
    "progress": job.percent,
    "deadline": 0,
    "updatedAt": job.changedAt
}
```

Keep `CenterAttentionService.publish`, `.clear` and `.setIndicator` contracts intact.

- [ ] **Step 2: Run the Job check and verify it fails**

Run: `python3 scripts/check_center_job.py`

Expected: FAIL on missing Center Activity integration.

- [ ] **Step 3: Implement Job synchronization**

Add `syncActivity(job)` and `removeActivity(id)` helpers. Call synchronization only after an
accepted state transition. A progress update replaces the same registry ID and never publishes a
new attention event. Remove requires-action jobs from rotation because their actionable descriptor
is already owned by `CenterAttentionService`.

- [ ] **Step 4: Add failing Timer integration contracts**

Require an upsert after start with:

```qml
{
    "id": "timer:" + timer.id,
    "source": "timer",
    "label": timer.label,
    "icon": "timer",
    "importance": "normal",
    "progress": -1,
    "deadline": timer.deadline,
    "updatedAt": now
}
```

Require removal on cancel and when `processDue()` removes a completed timer. Preserve the one
existing milestone timer, milestone publications, indicator updates and exact-ID attention clear.

- [ ] **Step 5: Run the Timer check and verify it fails**

Run: `python3 scripts/check_center_timer.py`

Expected: FAIL on missing Center Activity integration.

- [ ] **Step 6: Implement Timer synchronization**

Capture the previous timer IDs before `advance`; after applying `result.next`, remove only IDs no
longer present. Do not upsert unchanged timers on every milestone wake. On start, locate the newly
created timer by exact normalized ID and upsert once. On cancel, remove the same normalized ID even
when only a stale activity remains.

- [ ] **Step 7: Run producer regression gates and commit**

Run:

```bash
node scripts/check_center_job_rules.js
python3 scripts/check_center_job.py
node scripts/check_center_timer_rules.js
python3 scripts/check_center_timer.py
node scripts/check_center_attention_rules.js
python3 scripts/check_center_attention.py
```

Expected: all existing event, indicator and lifecycle checks remain PASS.

```bash
git add Titonium/Services/Center/CenterJobService.qml Titonium/Services/Center/CenterTimerService.qml scripts/check_center_job.py scripts/check_center_timer.py
git commit -m "feat: project active jobs and timers into center"
```

### Task 4: Project the precedence into CenterIsland

**Files:**
- Modify: `Titonium/Bar/islands/CenterIsland.qml`
- Modify: `scripts/check_center_attention.py`
- Modify: `scripts/check_center_activity.py`

**Interfaces:**
- Consumes: `CenterAttentionService.presentation`, `CenterActivityService.presentation`,
  `CenterFocusStore.text`.
- Produces: one bounded one-line primary presentation and the existing notch request action.

- [ ] **Step 1: Add a failing projection contract**

Require the view to expose:

```qml
readonly property var eventPresentation: CenterAttentionService.presentation
readonly property var activityPresentation: CenterActivityService.presentation
readonly property var primaryPresentation: root.eventPresentation || root.activityPresentation
```

Require `primaryText` to select `primaryPresentation.title` before `CenterFocusStore.text`.
Require event severity tone to remain based on event priority only; activity tone is `primary` and
Daily Focus tone is `secondary`. Reject `Timer`, `Process`, `FileView`, registry mutation and direct
scratchpad launch in the view.

- [ ] **Step 2: Run the projection checks and verify they fail**

Run:

```bash
python3 scripts/check_center_activity.py
python3 scripts/check_center_attention.py
```

Expected: FAIL because `CenterIsland` has no Activity projection.

- [ ] **Step 3: Implement three-level selection without layout changes**

Keep the existing indicator `Repeater`, 320 px label maximum, right elision, single line, keyboard
activation, accessibility and `notchRequested` behavior. Set strong text for Attention or Activity,
but do not add progress bars, animation loops or a new click target.

- [ ] **Step 4: Run view and lint gates and commit**

Run:

```bash
python3 scripts/check_center_activity.py
python3 scripts/check_center_attention.py
./scripts/check.sh
```

Expected: all static checks and `qmllint` pass with no new warnings.

```bash
git add Titonium/Bar/islands/CenterIsland.qml scripts/check_center_activity.py scripts/check_center_attention.py
git commit -m "feat: rotate live activities in center island"
```

### Task 5: Prove runtime rotation, preemption and cleanup

**Files:**
- Create: `scripts/center_activity_acceptance.sh`
- Modify: `scripts/check_center_activity.py`
- Modify: `scripts/check.sh`
- Modify: `docs/TESTING.md`

**Interfaces:**
- Consumes: live `center`, `centerJob` and `centerTimer` IPC state.
- Produces: repeatable acceptance evidence without modifying user-owned runtime entries.

- [ ] **Step 1: Write the acceptance harness with isolated runtime paths**

Follow existing Center acceptance conventions: create unique `XDG_DATA_HOME`, `XDG_STATE_HOME` and
`XDG_CACHE_HOME`, launch `qs -n -p`, wait for `Configuration Loaded`, and use fixture IDs prefixed
`acceptance:activity:`. Install a trap that clears every fixture job/timer and terminates only the
acceptance-owned shell process.

- [ ] **Step 2: Assert Focus and ranked rotation**

Start one normal job, one important job and one timer. Poll read-only `center activityState` with a
bounded 45-second deadline and record distinct presentations. Assert the observed order is Focus,
timer, important job, normal job, Focus; allow IPC sampling latency but require each activity ID
exactly once in the round.

- [ ] **Step 3: Assert Attention pauses rather than consumes rotation**

While an activity is visible, publish a job-completed transition through a separate fixture job.
Assert `center state` reports the completion transient, `activityState` retains the same current
activity ID during the transient, and that ID remains visible for a fresh six-second window after
the transient expires.

- [ ] **Step 4: Assert progress replacement and cleanup**

Send two progress updates to the normal job and assert the registry contains one descriptor with
the newest label/percent. Cancel the timer, complete one job and clear the other; assert
`activeCount` becomes zero, the rotation timer is unscheduled in the snapshot, and Center returns
to Daily Focus. Verify Center Notch can still open and no new layer/window is created.

- [ ] **Step 5: Add static/runtime documentation gates**

Require executable mode `0755`, `set -euo pipefail`, isolated XDG paths, bounded waits, unique
fixture prefix, cleanup trap, `center activityState`, `center state`, `centerJob`, `centerTimer`, and
the absence of `pkill`, `/proc`, `ps`, `pgrep` and user runtime paths. Add `bash -n` to `check.sh` and
document:

```bash
./scripts/center_activity_acceptance.sh
```

- [ ] **Step 6: Run final verification and commit**

Run:

```bash
bash -n scripts/center_activity_acceptance.sh
python3 scripts/check_center_activity.py
./scripts/check.sh
./scripts/center_activity_acceptance.sh
git diff --check
```

Expected: rotation, preemption, progress replacement, cleanup, static checks and `qmllint` all
pass. The repository diff has no whitespace errors.

```bash
git add scripts/center_activity_acceptance.sh scripts/check_center_activity.py scripts/check.sh docs/TESTING.md
git commit -m "test: verify center live activity rotation"
```

## Deferred follow-up plans

The following are intentionally separate because each requires a trustworthy native event source
and its own failure policy:

1. systemd unit/build adapters over D-Bus or explicit wrappers;
2. package/download progress from PackageKit or application-specific APIs;
3. copy/backup/render adapters that can report real progress;
4. Center Notch content and controls for active activity details.
