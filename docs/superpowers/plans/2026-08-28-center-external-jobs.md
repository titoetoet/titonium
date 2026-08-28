# Center External Jobs Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let builds, downloads, renders and other opt-in external tasks report explicit lifecycle events to Center without process/output/filesystem detection.

**Architecture:** `CenterJobService` owns a bounded session-only map of value descriptors and derives semantic transitions through pure `CenterJobRules`. A dedicated Quickshell IPC handler accepts only lifecycle fields; Center policy remains the sole owner of priority/TTL. A convenience wrapper forwards arguments but contains no state or arbitration.

**Tech Stack:** Quickshell/QML IPC, pure JavaScript, Node.js fixtures, Python static contracts, POSIX shell wrapper and Bash acceptance.

**Spec:** `docs/superpowers/specs/2026-08-28-center-attention-system-design.md`

## Global Constraints

- Complete and approve Core, MPRIS and Timer plans first.
- Jobs are explicit opt-in only; never inspect processes, terminal output or download directories.
- State is session-only, bounded to 64 active jobs and exposes value descriptors only.
- Allowed importance is exactly `normal` or `important`; external callers cannot set priority/TTL.
- Progress updates state but never take over Center text.
- Start/complete/fail/requires-action publish through `CenterAttentionService` policy.
- Active jobs use one passive indicator ID `jobs`; no per-job Bar icons.
- Unknown IDs and invalid transitions fail closed with stable results and category-capped logs.
- Acceptance may mutate only IDs with its unique fixture prefix and must clear them in a trap.

---

## File structure

```text
Titonium/Services/Center/
├── CenterJobRules.js
└── CenterJobService.qml

scripts/
├── check_center_job_rules.js
├── check_center_jobs.py
├── titonium-center-job
└── center_jobs_acceptance.sh
```

### Task 1: Define the pure job lifecycle state machine

**Files:**
- Create: `Titonium/Services/Center/CenterJobRules.js`
- Create: `scripts/check_center_job_rules.js`
- Modify: `scripts/check.sh`

**Interfaces:**
- Consumes: current jobs plus `start`, `progress`, `complete`, `fail`, `requireAction`, `clear` intents.
- Produces: `{ accepted, error, jobs, event }` from `transition(jobs, intent, now)`, plus
  `activeCount(jobs)` and `snapshot(jobs)`.

- [ ] **Step 1: Write failing lifecycle fixtures**

```js
let result = rules.transition([], {
    action: "start", id: "build:titonium", label: "Build Titonium",
    importance: "normal",
}, 1000);
assert.equal(result.accepted, true);
assert.equal(result.event.kind, "job_started");
assert.equal(result.jobs.length, 1);

result = rules.transition(result.jobs, {
    action: "progress", id: "build:titonium", percent: 50, label: "Compiling",
}, 2000);
assert.equal(result.event, null);
assert.equal(result.jobs[0].percent, 50);

result = rules.transition(result.jobs, {
    action: "fail", id: "build:titonium", summary: "Build failed",
}, 3000);
assert.equal(result.event.kind, "job_failed");
assert.equal(result.jobs.length, 0);
```

Also cover same-ID start replacement, complete, requireAction retention, clear, unknown ID,
out-of-range/non-finite progress, blank ID/label/summary, invalid importance/action, frozen
descriptors, 64-job bound and importance propagation without any numeric priority field.

- [ ] **Step 2: Run the fixture and verify it fails**

Run: `node scripts/check_center_job_rules.js`

Expected: FAIL because `CenterJobRules.js` is missing.

- [ ] **Step 3: Implement normalized transitions**

Use this stable result vocabulary:

```js
return { accepted: false, error: "unknown-id", jobs: current, event: null };
return { accepted: true, error: "", jobs: Object.freeze(next), event: event };
```

Active descriptors contain exactly `id`, `label`, `importance`, `percent`, `startedAt`, `updatedAt`
and `status`. Completion/failure removes the active job after producing its event. `requireAction`
removes it from active state and produces an actionable event that persists in the Center arbiter
until acknowledge/clear. Use deduplication key `job:<id>` for all outcomes.

- [ ] **Step 4: Run tests, add gate and commit**

Run: `node scripts/check_center_job_rules.js`

Expected: PASS. Add the fixture after timer rules in `scripts/check.sh`.

```bash
git add Titonium/Services/Center/CenterJobRules.js scripts/check_center_job_rules.js scripts/check.sh
git commit -m "feat: define external job lifecycle"
```

### Task 2: Add the job singleton and narrow IPC ingress

**Files:**
- Create: `Titonium/Services/Center/CenterJobService.qml`
- Create: `scripts/check_center_jobs.py`
- Modify: `Titonium/Services/Center/qmldir`
- Modify: `Titonium/App.qml`
- Modify: `scripts/check.sh`
- Modify: `config/i18n/vi.json`
- Modify: `config/i18n/en.json`

**Interfaces:**
- Consumes: `start(id,label,importance)`, `progress(id,percent,label)`, `complete(id,summary)`,
  `fail(id,summary)`, `requireAction(id,summary)`, `clear(id)`, `acknowledge(id)`.
- Produces: frozen `jobs`, `activeCount`, `snapshot()`; passive indicator ID `jobs`; semantic Center
  job events with policy-derived priority/TTL.

- [ ] **Step 1: Write a failing service/IPC architecture check**

Require `singleton CenterJobService 1.0`, `CenterJobRules.transition`,
`CenterAttentionService.publish`, `.setIndicator`, `.acknowledge` and exact IPC methods:

```qml
IpcHandler {
    target: "centerJob"
    function start(id: string, label: string, importance: string): string
    function progress(id: string, percent: real, label: string): string
    function complete(id: string, summary: string): string
    function fail(id: string, summary: string): string
    function requireAction(id: string, summary: string): string
    function clear(id: string): string
    function acknowledge(id: string): string
    function state(): string
}
```

Reject `Process`, `FileView`, `Timer`, process enumeration, filesystem watchers, shell parsing,
external priority/TTL args and native objects.

- [ ] **Step 2: Run the contract and verify it fails**

Run: `python3 scripts/check_center_jobs.py`

Expected: FAIL because `CenterJobService.qml` and IPC are missing.

- [ ] **Step 3: Implement one transition boundary**

Every service method builds one pure intent and passes it to a shared `apply(intent)`:

```qml
function apply(intent: var): string {
    const result = CenterJobRules.transition(root.jobState, intent, Date.now());
    if (!result.accepted) {
        root.warn(result.error);
        return "unavailable:" + result.error;
    }
    root.jobState = result.jobs;
    CenterAttentionService.setIndicator("jobs", "manufacturing",
        I18n.tr("menubar.center.indicator.jobs"), root.activeCount > 0);
    if (result.event)
        CenterAttentionService.publish(result.event);
    return "ok:" + intent.id;
}
```

`clear(id)` removes active state and clears `job:<id>` from current/pending Center events.
`acknowledge(id)` targets the same ID but does not invent a job transition. Category-cap warnings
at three messages per error code.

- [ ] **Step 4: Add translations, tests and commit**

Add equal locale keys for started/completed/failed/requires-action presentation and the jobs
indicator. Run:

```bash
node scripts/check_center_job_rules.js
python3 scripts/check_center_jobs.py
python3 scripts/check_center_attention.py
./scripts/check.sh
```

Expected: PASS with no command/process/poller in the service.

```bash
git add Titonium/Services/Center Titonium/App.qml config/i18n scripts/check_center_jobs.py scripts/check.sh
git commit -m "feat: accept explicit center job events"
```

### Task 3: Add a stateless convenience wrapper

**Files:**
- Create: `scripts/titonium-center-job`
- Modify: `scripts/check_center_jobs.py`
- Modify: `scripts/check.sh`
- Modify: `docs/TESTING.md`

**Interfaces:**
- Consumes: commands `start|progress|complete|fail|action|clear|ack|state` plus positional values.
- Produces: one `qs ipc call centerJob ...` invocation and the exact IPC output/exit status.

- [ ] **Step 1: Add failing wrapper shape checks**

Require `set -euo pipefail`, an explicit case for each allowlisted command, one fixed project path
`/home/cole/Projects/titonium`, quoted positional arguments, usage on invalid input, and no
`eval`, `sh -c`, backgrounding, persistence, priority or TTL option.

- [ ] **Step 2: Run the static check and verify it fails**

Run: `python3 scripts/check_center_jobs.py`

Expected: FAIL because the wrapper is missing.

- [ ] **Step 3: Implement direct argument forwarding**

The start branch must be structurally equivalent to:

```bash
exec qs -p /home/cole/Projects/titonium ipc call centerJob start \
    "$job_id" "$label" "$importance"
```

Default omitted start importance to `normal`; do not default ID/label. Progress requires numeric
text but leaves semantic validation to the service. Document examples:

```bash
scripts/titonium-center-job start build:titonium "Build Titonium" important
scripts/titonium-center-job complete build:titonium "Built in 42s"
scripts/titonium-center-job fail build:titonium "Build failed"
```

- [ ] **Step 4: Run syntax/static checks and commit**

```bash
bash -n scripts/titonium-center-job
python3 scripts/check_center_jobs.py
./scripts/check.sh
```

Expected: PASS without invoking a job during static tests.

```bash
git add scripts/titonium-center-job scripts/check_center_jobs.py scripts/check.sh docs/TESTING.md
git commit -m "feat: add center job event wrapper"
```

### Task 4: Verify job priority, indicator and cleanup

**Files:**
- Create: `scripts/center_jobs_acceptance.sh`
- Modify: `scripts/check.sh`
- Modify: `scripts/protected_acceptance.sh`
- Modify: `docs/ARCHITECTURE.md`
- Modify: `docs/TESTING.md`

**Interfaces:**
- Consumes: `centerJob` lifecycle IPC plus read-only Center state.
- Produces: isolated evidence for start/progress/complete/fail/action/ack/clear.

- [ ] **Step 1: Add acceptance syntax and fixture-isolation checks**

Require `bash -n`, a unique `titonium-acceptance-$$` ID prefix and cleanup trap that calls `clear`
only for its own IDs. Reject process launch, real download/build and user-file mutation.

- [ ] **Step 2: Implement bounded lifecycle scenarios**

Verify:

```text
start normal      → priority 10 for 2s + jobs indicator
progress 50       → no new Center takeover
complete normal   → priority 40 for 5s + indicator removed
fail important    → priority 80, preempts a lower fixture event
requireAction     → remains until acknowledge
clear             → removes active/pending/current state for exact ID
```

Use service IPC only; never run a real build or download. Verify repository, runtime focus files
and both Hyprland hashes remain unchanged.

- [ ] **Step 3: Run full gates**

```bash
bash -n scripts/center_jobs_acceptance.sh scripts/titonium-center-job
./scripts/check.sh
./scripts/smoke.sh
./scripts/center_jobs_acceptance.sh
./scripts/center_attention_acceptance.sh
./scripts/protected_acceptance.sh
hyprctl configerrors
git diff --check
```

Expected: PASS with zero fixture jobs afterward.

- [ ] **Step 4: Document, commit and request final Center review**

```bash
git add scripts docs/ARCHITECTURE.md docs/TESTING.md
git commit -m "test: cover explicit center jobs"
```

Manually wrap one real Titonium build after automated tests pass. Verify start is quiet, running job
uses one icon, progress causes no text churn, completion lasts five seconds, failure preempts media,
and Center returns to Daily Focus. Confirm volume, Active Window, ordinary notification and network
state never duplicate into Center.
