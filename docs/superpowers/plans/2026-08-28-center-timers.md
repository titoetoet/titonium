# Center Timers Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add session-only named countdown timers whose five-minute, one-minute and completion milestones publish into Center without per-second polling.

**Architecture:** Pure `CenterTimerRules` stores absolute deadlines and calculates the next single wake. `CenterTimerService` owns active descriptors plus one non-repeating scheduler, publishes milestone events to `CenterAttentionService`, and exposes a narrow explicit IPC lifecycle.

**Tech Stack:** Quickshell/QML, QtQuick one-shot `Timer`, pure JavaScript, Node.js fixtures, Python static contracts, Bash IPC acceptance.

**Spec:** `docs/superpowers/specs/2026-08-28-center-attention-system-design.md`

## Global Constraints

- Complete Center Core/Daily Focus before this plan; MPRIS is optional but precedes this plan in the approved sequence.
- Timer state is session-only; no `FileView`, persistence or restart recovery.
- Store absolute deadlines; never decrement counters or use `repeat: true`.
- Exactly one non-repeating scheduler covers every active timer.
- Publish only five-minute, one-minute and completion milestones.
- Timer running state uses passive indicator ID `timer`; milestones alone compete for Center text.
- External IPC chooses ID/duration/label, never priority or TTL.
- Runtime acceptance mutates only timer fixtures owned by its unique test prefix.

---

## File structure

```text
Titonium/Services/Center/
├── CenterTimerRules.js
└── CenterTimerService.qml

scripts/
├── check_center_timer_rules.js
├── check_center_timers.py
└── center_timers_acceptance.sh
```

### Task 1: Define deadline and milestone rules

**Files:**
- Create: `Titonium/Services/Center/CenterTimerRules.js`
- Create: `scripts/check_center_timer_rules.js`
- Modify: `scripts/check.sh`

**Interfaces:**
- Consumes: timer descriptors `{ id, label, startedAt, deadline, emittedMilestones }[]`.
- Produces: `start(timers, id, durationSeconds, label, now)`, `cancel(timers, id)`,
  `due(timers, now)`, `applyDue(timers, dueItems)`, `nextWake(timers, now)` and `activeCount(timers)`.

- [ ] **Step 1: Write failing deadline fixtures**

```js
let timers = rules.start([], "focus", 360, "Focus session", 1000);
assert.equal(timers[0].deadline, 361000);
assert.equal(rules.nextWake(timers, 1000), 61000); // five-minute milestone

let due = rules.due(timers, 61000);
assert.deepEqual(Array.from(due, item => item.kind), ["timer_five_minutes"]);
timers = rules.applyDue(timers, due);
assert.equal(rules.nextWake(timers, 61000), 301000); // one-minute milestone

due = rules.due(timers, 361000);
assert.equal(due.some(item => item.kind === "timer_finished"), true);
```

Also cover timers starting below five minutes, below one minute, simultaneous deadlines, replacement
of the same ID, invalid/non-finite duration, blank labels, cancellation, overdue completion exactly
once, stable ordering and a maximum of 32 active timers.

- [ ] **Step 2: Run the fixture and verify it fails**

Run: `node scripts/check_center_timer_rules.js`

Expected: FAIL because `CenterTimerRules.js` is missing.

- [ ] **Step 3: Implement absolute-deadline rules**

Milestone times are `deadline - 300000`, `deadline - 60000` and `deadline`. Omit milestones at or
before `startedAt`; `nextWake()` returns the earliest future unemitted milestone or `0` when idle.
`due()` returns all overdue unemitted milestones ordered by scheduled time then timer ID, and
`applyDue()` removes completed timers after emitting completion.

- [ ] **Step 4: Run tests, add gate and commit**

Run: `node scripts/check_center_timer_rules.js`

Expected: PASS. Add it after Center focus fixtures in `scripts/check.sh`.

```bash
git add Titonium/Services/Center/CenterTimerRules.js scripts/check_center_timer_rules.js scripts/check.sh
git commit -m "feat: define center timer milestones"
```

### Task 2: Implement the one-shot timer service and explicit IPC

**Files:**
- Create: `Titonium/Services/Center/CenterTimerService.qml`
- Create: `scripts/check_center_timers.py`
- Modify: `Titonium/Services/Center/qmldir`
- Modify: `Titonium/App.qml`
- Modify: `scripts/check.sh`
- Modify: `config/i18n/vi.json`
- Modify: `config/i18n/en.json`

**Interfaces:**
- Consumes: `start(id, durationSeconds, label)`, `cancel(id)`, `acknowledge(id)`.
- Produces: frozen `timers`, `activeCount`, `snapshot()`; Center events with IDs
  `timer:<id>:five`, `timer:<id>:one`, `timer:<id>:finished`; passive indicator ID `timer`.

- [ ] **Step 1: Write the failing static service/IPC contract**

Require `singleton CenterTimerService 1.0`, exactly one `Timer {`, `repeat: false`, calls to
`CenterTimerRules.nextWake`, `CenterAttentionService.publish`, `.acknowledge` and `.setIndicator`.
Reject `repeat: true`, `FileView`, `Process`, duration-to-priority conversion and timers inside Bar.

Require the explicit handler:

```qml
IpcHandler {
    target: "centerTimer"
    function start(id: string, durationSeconds: int, label: string): string
    function cancel(id: string): string
    function acknowledge(id: string): string
    function state(): string
}
```

- [ ] **Step 2: Run the contract and verify it fails**

Run: `python3 scripts/check_center_timers.py`

Expected: FAIL because `CenterTimerService.qml` and IPC are absent.

- [ ] **Step 3: Implement service scheduling and publication**

Use this scheduler shape:

```qml
Timer {
    id: milestoneTimer
    repeat: false
    onTriggered: root.processDue(Date.now())
}

function reschedule(now: double): void {
    milestoneTimer.stop();
    const wake = CenterTimerRules.nextWake(root.timerState, now);
    if (wake > 0) {
        milestoneTimer.interval = Math.max(1, wake - now);
        milestoneTimer.start();
    }
}
```

`processDue()` publishes each due semantic event, applies the pure result, updates the passive
indicator to `activeCount > 0`, then schedules the next wake. `start()` replaces the same ID;
`cancel()` clears its pending/current Center source events by exact timer event IDs; `acknowledge()`
only acknowledges `timer:<id>:finished`.

- [ ] **Step 4: Normalize IPC results and translations**

Return `started:<id>`, `cancelled:<id>`, `acknowledged:<id>` or stable
`unavailable:<reason>` strings. Add equal translations for five minutes, one minute, time up and
the timer indicator accessible name; interpolate the timer label rather than assembling sentences
in the view.

- [ ] **Step 5: Run focused/static verification and commit**

```bash
node scripts/check_center_timer_rules.js
python3 scripts/check_center_timers.py
python3 scripts/check_center_attention.py
./scripts/check.sh
```

Expected: PASS with no repeating Center timer.

```bash
git add Titonium/Services/Center Titonium/App.qml config/i18n scripts/check_center_timers.py scripts/check.sh
git commit -m "feat: add event driven center timers"
```

### Task 3: Prove timer priority and cleanup through IPC acceptance

**Files:**
- Create: `scripts/center_timers_acceptance.sh`
- Modify: `scripts/check.sh`
- Modify: `scripts/protected_acceptance.sh`
- Modify: `docs/ARCHITECTURE.md`
- Modify: `docs/TESTING.md`

**Interfaces:**
- Consumes: public `centerTimer` IPC and read-only `center.state()`.
- Produces: isolated runtime evidence for milestone, completion, acknowledgement and cleanup.

- [ ] **Step 1: Add syntax/static gates for the acceptance script**

Add `bash -n "$project_root/scripts/center_timers_acceptance.sh"` to `check.sh`. Require a unique
fixture prefix such as `titonium-acceptance-$$` and a cleanup trap that cancels only that ID.

- [ ] **Step 2: Implement bounded acceptance scenarios**

Start a two-second fixture, require `activeCount=1` and the timer indicator, wait boundedly for a
priority-70 `timer_finished` presentation, acknowledge it, then require fallback Daily Focus and
`activeCount=0`. Start a second fixture and cancel it before expiry. Reject repository/user-file and
Hyprland hash changes and QML/runtime errors.

- [ ] **Step 3: Run full gates**

```bash
bash -n scripts/center_timers_acceptance.sh
./scripts/check.sh
./scripts/smoke.sh
./scripts/center_timers_acceptance.sh
./scripts/center_attention_acceptance.sh
./scripts/protected_acceptance.sh
hyprctl configerrors
git diff --check
```

Expected: PASS with no leftover fixture timers.

- [ ] **Step 4: Document, commit and request manual review**

```bash
git add scripts docs/ARCHITECTURE.md docs/TESTING.md
git commit -m "test: cover center timer lifecycle"
```

Manually start a six-minute timer and verify: passive icon immediately; five-minute message for four
seconds; Daily Focus restoration; one-minute message for six seconds; completion for up to 15
seconds; no per-second visual churn. Approve before starting External Jobs.
