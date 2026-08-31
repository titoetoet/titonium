# Center System Monitoring Page Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an on-demand Center System Monitoring page with aligned CPU/GPU, RAM/VRAM, Disk/Network metrics, top-five processes and read-only Center activities.

**Architecture:** Pure `SystemMonitorRules` parses Linux text/counter sources into frozen values. A singleton `SystemMonitorService` owns one deadline scheduler, direct `FileView` reloads and bounded `Process` collectors only while the lazy page is visible; page-local components render values but never sample the system.

**Tech Stack:** Quickshell/QML and Quickshell.Io, Linux `/proc` and `/sys`, `ps`, `df`, pure JavaScript, Node.js fixtures, Python architecture checks, Bash runtime acceptance.

**Spec:** `docs/superpowers/specs/2026-08-31-center-notifications-system-monitoring-design.md`

## Global Constraints

- Monitoring is read-only; add no kill, renice, stop-job or tuning action.
- Hardware layout is exactly two equal columns and three equal-height blocks: CPU/RAM/Disk left,
  GPU/VRAM/Network right.
- Metric icons share the primary line with the bar or network values; visible CPU/GPU/RAM labels are
  replaced by translated icon tooltips and accessible names.
- Percentage text is centered inside CPU, GPU, RAM, VRAM and Disk bars.
- CPU/GPU show available temperature and watts; RAM/VRAM/Disk show used/total capacity.
- Do not compute or display total-system power. Unsupported values are unavailable, never fake zero.
- Hot metrics sample every 2 seconds, processes every 5 seconds and root disk capacity every 10 seconds.
- Sampling runs only while the Monitoring page is visible. One non-repeating scheduler owns all deadlines.
- Hardware discovery runs at activation and does not hard-code DRM card or hwmon indices.
- Use QML/JavaScript only; add no Python/Go/Rust/eBPF runtime helper or Hyprland plugin.
- Keep Center Attention/Activity/Focus priority and collapsed rotation behavior unchanged.
- V1 has no persistent history, graphs, SMART, fan, battery, motherboard or VRM telemetry.

---

## File structure

```text
Titonium/Services/SystemMonitor/
├── SystemMonitorRules.js       # parsing, deltas, units, severity and ranking
├── SystemMonitorService.qml    # activation lease, discovery, scheduler and collectors
└── qmldir                      # singleton registration

Titonium/Services/Center/
└── CenterActivityService.qml   # frozen read-only activity registry projection

Titonium/Bar/notch/
├── CenterNotchState.js         # insert Monitoring after Notifications
├── CenterNotchRail.qml         # Monitoring navigation icon
├── CenterNotchViewport.qml     # lazy page factory
├── SystemMonitoringPage.qml    # scrollable page composition and lifecycle
├── SystemMetricBlock.qml       # aligned icon/bar/telemetry block
├── SystemProcessRow.qml        # value-only process row
├── CenterActivityCard.qml      # value-only activity card
└── qmldir                      # component registration

scripts/
├── check_system_monitor_rules.js
├── check_system_monitor.py
├── system_monitor_acceptance.sh
├── check_center_notch.js
├── check_center_activity.py
└── check.sh

config/i18n/{en,vi}.json
docs/TESTING.md
```

### Task 1: Parse CPU, memory and network sources with guarded deltas

**Files:**
- Create: `Titonium/Services/SystemMonitor/SystemMonitorRules.js`
- Create: `scripts/check_system_monitor_rules.js`
- Modify: `scripts/check.sh`

**Interfaces:**
- Produces `parseCpuStat(text) -> { total, idle } | null`.
- Produces `cpuPercent(previous, current) -> number | null`.
- Produces `parseMeminfo(text) -> { totalBytes, usedBytes, percent } | null`.
- Produces `parseNetDev(text) -> { rxBytes, txBytes } | null` excluding `lo`.
- Produces `networkRate(previous, current, elapsedMs) -> { downBps, upBps } | null`.
- All returned objects are frozen and unavailable numeric fields use `null`.

- [ ] **Step 1: Write failing `/proc/stat` fixtures**

Load the rules file through Node `vm` and assert:

```js
const firstCpu = rules.parseCpuStat("cpu  100 20 30 400 10 5 3 2 0 0\n");
const nextCpu = rules.parseCpuStat("cpu  130 20 40 450 10 5 3 2 0 0\n");
assert.deepEqual(plain(firstCpu), { total: 570, idle: 410 });
assert.equal(rules.cpuPercent(firstCpu, nextCpu), 44.44444444444444);
assert.equal(rules.cpuPercent(null, nextCpu), null);
assert.equal(rules.cpuPercent(nextCpu, firstCpu), null);
assert.equal(rules.parseCpuStat("cpu broken"), null);
```

- [ ] **Step 2: Run the rule gate and verify it fails**

Run: `node scripts/check_system_monitor_rules.js`

Expected: FAIL because `SystemMonitorRules.js` does not exist.

- [ ] **Step 3: Implement CPU parsing and clamped delta calculation**

Parse the aggregate `cpu` row only. Total is the sum of the first eight finite non-negative columns;
idle is `idle + iowait`. Return `null` until both samples exist, total delta is positive and active
delta is non-negative.
Clamp the published percentage to `0...100` without rounding in the rules layer.

- [ ] **Step 4: Add failing memory/network fixtures**

Use exact samples:

```js
assert.deepEqual(plain(rules.parseMeminfo(
    "MemTotal: 32768000 kB\nMemAvailable: 14000000 kB\n"
)), { totalBytes: 33554432000, usedBytes: 19218432000, percent: 57.275390625 });

const netA = rules.parseNetDev(
    "lo: 99 0 0 0 0 0 0 0 99 0 0 0 0 0 0 0\n" +
    "enp1s0: 1000 0 0 0 0 0 0 0 2000 0 0 0 0 0 0 0\n");
const netB = rules.parseNetDev(
    "enp1s0: 5000 0 0 0 0 0 0 0 6000 0 0 0 0 0 0 0\n");
assert.deepEqual(plain(rules.networkRate(netA, netB, 2000)), {
    downBps: 2000, upBps: 2000,
});
assert.equal(rules.networkRate(netB, netA, 2000), null);
```

- [ ] **Step 5: Implement memory and aggregate non-loopback network rules**

Use `MemAvailable`, not `MemFree`, and convert kB by multiplying by 1024. Sum RX column 0 and TX
column 8 for every syntactically valid interface except `lo`. Reject negative counter deltas and
non-positive elapsed time.

- [ ] **Step 6: Register and run the focused gate**

Add `node "$project_root/scripts/check_system_monitor_rules.js"` after notification rules in
`scripts/check.sh`.

Run:

```bash
node scripts/check_system_monitor_rules.js
bash -n scripts/check.sh
```

Expected: CPU, memory and network fixtures PASS.

- [ ] **Step 7: Commit the base rules**

```bash
git add Titonium/Services/SystemMonitor/SystemMonitorRules.js scripts/check_system_monitor_rules.js scripts/check.sh
git commit -m "feat: parse system monitor proc metrics"
```

### Task 2: Normalize sensors, disk and top processes

**Files:**
- Modify: `Titonium/Services/SystemMonitor/SystemMonitorRules.js`
- Modify: `scripts/check_system_monitor_rules.js`

**Interfaces:**
- Produces `scalar(text, divisor) -> number | null`.
- Produces `powerFromEnergy(previousUj, currentUj, elapsedMs, maxRangeUj) -> number | null`.
- Produces `capacity(usedBytes, totalBytes) -> frozen capacity | null`.
- Produces `parseDf(text) -> capacity | null`.
- Produces `parseProcesses(text) -> frozen top-five [{ pid, name, cpuPercent, rssBytes }]`.
- Produces `severity(percent, temperatureC) -> "neutral"|"warning"|"critical"`.
- Produces `selectSensorPaths(paths) -> frozen known-key path map` from absolute `/sys/` candidates.

- [ ] **Step 1: Add failing scalar, energy and capacity fixtures**

```js
assert.equal(rules.scalar("54000\n", 1000), 54);
assert.equal(rules.scalar("bad", 1000), null);
assert.equal(rules.powerFromEnergy(1000000, 3000000, 2000, 0), 1);
assert.equal(rules.powerFromEnergy(9000000, 1000000, 2000, 10000000), 1);
assert.equal(rules.powerFromEnergy(3, 2, 0, 10), null);
assert.deepEqual(plain(rules.capacity(612, 1000)), {
    usedBytes: 612, totalBytes: 1000, percent: 61.199999999999996,
});
assert.equal(rules.capacity(20, 0), null);
```

- [ ] **Step 2: Implement guarded unit and capacity helpers**

`scalar` accepts one finite non-negative number and a finite positive divisor. Energy counters are
microjoules; derive watts as delta joules divided by elapsed seconds, honoring a positive wrap range
only when current is below previous. `capacity` rejects impossible totals and clamps used to total.

- [ ] **Step 3: Add failing `df`, `ps` and severity fixtures**

```js
assert.deepEqual(plain(rules.parseDf(
    "1B-blocks Used Available Use% Mounted on\n1000 612 388 62% /\n"
)), { usedBytes: 612, totalBytes: 1000, percent: 61.199999999999996 });

assert.deepEqual(plain(rules.parseProcesses(
    "22 Firefox 12.5 1800000\n7 Hyprland 4.0 310000\n9 ChatGPT 4.0 820000\n"
)), [
    { pid: 22, name: "Firefox", cpuPercent: 12.5, rssBytes: 1843200000 },
    { pid: 7, name: "Hyprland", cpuPercent: 4, rssBytes: 317440000 },
    { pid: 9, name: "ChatGPT", cpuPercent: 4, rssBytes: 839680000 },
]);
assert.equal(rules.severity(69, null), "neutral");
assert.equal(rules.severity(70, null), "warning");
assert.equal(rules.severity(90, null), "critical");
assert.equal(rules.severity(20, 80), "warning");
assert.equal(rules.severity(20, 90), "critical");
assert.deepEqual(plain(rules.selectSensorPaths([
    "/sys/class/drm/card1/device/gpu_busy_percent",
    "/sys/class/drm/card1/device/mem_info_vram_used",
    "/sys/class/drm/card1/device/mem_info_vram_total",
])), {
    gpuBusy: "/sys/class/drm/card1/device/gpu_busy_percent",
    vramUsed: "/sys/class/drm/card1/device/mem_info_vram_used",
    vramTotal: "/sys/class/drm/card1/device/mem_info_vram_total",
});
```

- [ ] **Step 4: Implement deterministic parsing and ranking**

Invoke `ps` later with `-eo pid=,comm=,%cpu=,rss=` so each fixture row is PID, command token, CPU and
RSS kB. Reject malformed rows, sort CPU descending then PID ascending and freeze the first five.
Parse the first numeric `df` data row and ignore the reported rounded `Use%` in favor of `capacity`.
Severity is the maximum of utilization/capacity and temperature thresholds locked by the spec.
`selectSensorPaths` accepts only absolute `/sys/` paths with known sensor basenames, keeps the first
complete GPU group from one DRM device, and never invents a missing path.

- [ ] **Step 5: Run all rule fixtures and commit**

Run: `node scripts/check_system_monitor_rules.js`

Expected: all proc, sensor, disk, process and severity fixtures PASS.

```bash
git add Titonium/Services/SystemMonitor/SystemMonitorRules.js scripts/check_system_monitor_rules.js
git commit -m "feat: normalize system hardware metrics"
```

### Task 3: Build the visibility-owned monitoring singleton

**Files:**
- Create: `Titonium/Services/SystemMonitor/SystemMonitorService.qml`
- Create: `Titonium/Services/SystemMonitor/qmldir`
- Create: `scripts/check_system_monitor.py`
- Modify: `scripts/check.sh`

**Interfaces:**
- Produces readonly `active: bool`, `live: bool`, `hotSampleAt: double`, `snapshot: var`,
  `processes: var`, `processesStale: bool`.
- Produces idempotent `start(): bool`, `stop(): bool`, `refreshDue(now: double): void`, `state(): string`.
- Snapshot fields are exactly `cpu|gpu|ram|vram|disk|network`, each a frozen value object or `null`.

- [ ] **Step 1: Write a failing architecture gate**

Require singleton registration and these service fragments:

```python
"pragma Singleton",
"import Quickshell.Io",
"readonly property bool live:",
"readonly property var snapshot:",
"readonly property var processes:",
"function start(): bool",
"function stop(): bool",
"function refreshDue(now: double): void",
"property Timer scheduler: Timer",
"repeat: false",
"property int generation:",
```

Require exactly one `Timer {`; direct command arrays for `ps`, `df` and `find -L`; `FileView`
ownership only in this service; no `repeat: true`, `Quickshell.execDetached`,
`notify-send`, Hyprland import, DBus, Python/Go/Rust command or total-power property.

- [ ] **Step 2: Run the architecture gate and verify it fails**

Run: `python3 scripts/check_system_monitor.py`

Expected: FAIL because the service module is missing.

- [ ] **Step 3: Implement idempotent lifecycle and deadline scheduling**

Use wall-clock deadlines and one non-repeating timer:

```qml
function start(): bool {
    if (root.samplingActive)
        return false;
    root.samplingActive = true;
    root.generation++;
    const now = Date.now();
    root.activationStartedAt = now;
    root.nextHotAt = now;
    root.nextProcessAt = now;
    root.nextDiskAt = now;
    root.beginDiscovery(root.generation);
    root.refreshDue(now);
    return true;
}

function stop(): bool {
    if (!root.samplingActive)
        return false;
    root.samplingActive = false;
    root.generation++;
    scheduler.stop();
    psProcess.running = false;
    dfProcess.running = false;
    discoveryProcess.running = false;
    return true;
}
```

Back these projections with `property bool samplingActive: false`,
`readonly property bool active: root.samplingActive` and
`readonly property bool live: root.active && root.hotSampleAt >= root.activationStartedAt`.
`activationStartedAt` prevents cached values from appearing live before the immediate activation
refresh publishes.

`refreshDue(now)` advances overdue deadlines by `2000`, `5000` and `10000` until each is in the
future, starts only the due collectors, then schedules the nearest deadline. A collector captures
the current generation before launch and publishes output only when it still matches and
`root.active` is true.

- [ ] **Step 4: Add direct proc FileViews and immutable publication**

Create `FileView` owners for `/proc/stat`, `/proc/meminfo` and `/proc/net/dev` with `preload: false`,
`blockLoading: true`, `printErrors: false`. Hot refresh calls `reload()`, reads text, applies the pure
rules and keeps the last valid baselines. Build a new frozen snapshot object rather than mutating a
nested prior object.

Use exact commands without a shell for periodic collectors:

```qml
command: ["ps", "-eo", "pid=,comm=,%cpu=,rss="]
command: ["df", "-P", "-B1", "--output=size,used,avail,pcent,target", "/"]
```

`ps` output is parsed and ranked in JavaScript. `df` output updates only the disk field. A failed
exit preserves the previous value and marks its stale flag.

Maintain `property var warningCounts: ({})` and a `warn(category, message)` helper capped at three
messages per category, matching NotificationService's bounded-warning pattern. Invalid proc text,
collector failure and sensor discovery failure use separate categories. Unsupported optional
sensor paths are availability state and do not log on every hot refresh.

`state()` returns JSON with exactly `active`, `live`, `hotSampleAt`, `processSampleAt`,
`diskSampleAt`, `psRunning`, `dfRunning`, `discoveryRunning`, `snapshot`, `processCount` and
`processesStale`. Process-running fields mirror their owned `Process.running` properties.

- [ ] **Step 5: Implement boot-order-independent sensor discovery**

Run one activation discovery process that enumerates readable files beneath `/sys/class/drm`,
`/sys/class/hwmon` and `/sys/class/powercap` without embedding device indices:

```qml
command: ["find", "-L", "/sys/class/drm", "/sys/class/hwmon",
    "/sys/class/powercap", "-maxdepth", "8", "-type", "f", "-readable"]
```

Collect stdout with `SplitParser`, then pass the absolute candidate-path array through
`SystemMonitorRules.selectSensorPaths`. Resolve these optional keys:

```text
gpu_busy, vram_used, vram_total, gpu_temp, gpu_power,
cpu_temp, cpu_power, cpu_energy, cpu_energy_max
```

Prefer the DRM device whose `device/driver` resolves to the active GPU driver and its attached hwmon
directory. CPU temperature/power must come from a non-GPU hwmon/powercap source. Do not embed
`card1`, `hwmon2` or another numeric device index. Missing keys remain empty until the next page
activation.

- [ ] **Step 6: Read optional sensor FileViews and derive telemetry**

After discovery, assign paths to optional FileViews and reload them only on hot refresh. Normalize
GPU busy directly, VRAM bytes directly, millidegree temperature by divisor 1000, microwatt power by
divisor 1000000, and CPU energy using `powerFromEnergy`. Preserve CPU/GPU utilization even when an
optional temperature or power sample is unavailable.

On malformed CPU/network counters, preserve the last published metric and the last valid baseline.
If a counter decreases, clear only that baseline so the next valid sample establishes a new one
without publishing a synthetic zero rate.

- [ ] **Step 7: Register service, run gates and commit**

Register:

```text
module Titonium.Services.SystemMonitor
singleton SystemMonitorService 1.0 SystemMonitorService.qml
```

Add `python3 "$project_root/scripts/check_system_monitor.py"` after service checks in `scripts/check.sh`.

Run:

```bash
node scripts/check_system_monitor_rules.js
python3 scripts/check_system_monitor.py
bash -n scripts/check.sh
```

Expected: rules and architecture gates PASS.

```bash
git add Titonium/Services/SystemMonitor scripts/check_system_monitor.py scripts/check.sh
git commit -m "feat: add on-demand system monitor service"
```

### Task 4: Expose the frozen Center activity registry for inspection

**Files:**
- Modify: `Titonium/Services/Center/CenterActivityService.qml`
- Modify: `scripts/check_center_activity.py`

**Interfaces:**
- Produces `readonly property var activities: root.activityState.activities`.
- Monitoring consumes the already ranked, frozen descriptor array without changing rotation state.

- [ ] **Step 1: Add the failing read-only contract check**

Require:

```python
"readonly property var activities: root.activityState.activities"
```

Continue rejecting mutable activity models, native objects and monitoring imports inside the Center
service.

- [ ] **Step 2: Run the gate and verify it fails**

Run: `python3 scripts/check_center_activity.py`

Expected: FAIL with the missing activities projection.

- [ ] **Step 3: Add the one-line projection**

Add beside `activeCount`:

```qml
readonly property var activities: root.activityState.activities
```

Do not re-sort, clone, schedule or translate the registry for the inspector.

- [ ] **Step 4: Run focused activity gates and commit**

Run:

```bash
python3 scripts/check_center_activity.py
node scripts/check_center_activity_rules.js
```

Expected: both gates PASS and existing rotation fixtures remain unchanged.

```bash
git add Titonium/Services/Center/CenterActivityService.qml scripts/check_center_activity.py
git commit -m "feat: expose center activities for inspection"
```

### Task 5: Build aligned metric, process and activity presentation components

**Files:**
- Create: `Titonium/Bar/notch/SystemMetricBlock.qml`
- Create: `Titonium/Bar/notch/SystemProcessRow.qml`
- Create: `Titonium/Bar/notch/CenterActivityCard.qml`
- Create: `Titonium/Bar/notch/SystemMonitoringPage.qml`
- Modify: `Titonium/Bar/notch/qmldir`
- Modify: `scripts/check_system_monitor.py`
- Modify: `config/i18n/en.json`
- Modify: `config/i18n/vi.json`

**Interfaces:**
- `SystemMetricBlock` consumes `iconName`, `accessibleName`, `percent`, `primarySuffix`,
  `secondaryText`, `severity` and `networkMode`.
- `SystemProcessRow` consumes one frozen `{ pid, name, cpuPercent, rssBytes }` descriptor.
- `CenterActivityCard` consumes one existing Center activity descriptor and `now` captured by the page.
- `SystemMonitoringPage` calls service `start()` on construction and `stop()` on destruction.

- [ ] **Step 1: Add failing page/component architecture checks**

Require the four files, page imports for SystemMonitor and Center services, `GridLayout { columns: 2 }`,
exact model order `cpu, gpu, ram, vram, disk, network` placed by explicit row/column, top process
limit five, horizontal activity flow, `Component.onCompleted: SystemMonitorService.start()` and
`Component.onDestruction: SystemMonitorService.stop()`.

Reject `Process`, `FileView`, `/proc`, `/sys`, `ps`, `df`, `Timer {`, `execDetached` and direct
`Date.now()` calls in every presentation component. Require Shared/Theme imports and translated
accessible names.

- [ ] **Step 2: Run the architecture gate and verify it fails**

Run: `python3 scripts/check_system_monitor.py`

Expected: FAIL listing the four missing presentation files.

- [ ] **Step 3: Implement the shared metric block**

Use one outlined `Shared.Surface` with fixed-height primary and optional secondary rows. Primary row
is `Shared.Icon`, then a bar track that fills width, then temperature when present. Center percent
text over the whole track:

```qml
Rectangle {
    id: track
    Layout.fillWidth: true
    height: 18
    radius: height / 2
    color: Theme.surfaceInteractive
    Rectangle {
        width: parent.width * Math.max(0, Math.min(100, root.percent)) / 100
        height: parent.height
        radius: parent.radius
        color: root.severity === "critical" ? Theme.danger
            : root.severity === "warning" ? Theme.warning : Theme.accent
    }
    Shared.TextLabel {
        anchors.centerIn: parent
        text: Math.round(root.percent) + "%"
        variant: "caption"
        strong: true
    }
}
```

When `percent` is unavailable, render a neutral em dash and no fill. Network mode replaces the bar
with aligned download/upload values. Icon remains on the same primary line in both modes.
Expose metric name, percent, available suffix/secondary telemetry and the translated
warning/critical severity as one `Accessible.description`, so color is never the only warning cue.

- [ ] **Step 4: Implement process and activity value rows**

Process rows align name, formatted CPU percent and formatted RSS. Activity cards render icon and
label; job cards show `Math.round(activity.progress) + "%"`, media uses its label only, and timer
cards calculate `Math.max(0, Math.ceil((activity.deadline - now) / 60000))` from their required
`now` property. The page binds card `now` to `SystemMonitorService.hotSampleAt`, so cards own no
clock or timer. Cards emit no action.

Use one page-local binary formatter for capacity and RSS: bytes below 1024 remain `B`, then divide
by 1024 for `KB`, `MB`, `GB` and `TB`, showing one decimal below 10 and no decimal at 10 or above.
Network rates use the same scale with `/s`. Invalid or negative inputs render an em dash.

- [ ] **Step 5: Compose the scrollable two-column page**

Keep header fixed with title and `Live · 2s` only when `SystemMonitorService.live`; show `Paused`
otherwise. Put the body in a vertical `ScrollView`. The grid uses equal column stretch and exact
positions:

```text
row 0: CPU  | GPU
row 1: RAM  | VRAM
row 2: Disk | Network
```

Use icon names `memory` for CPU, `developer_board` for GPU, `memory_alt` for RAM,
`video_settings` for VRAM, `hard_drive` for Disk and `swap_vert` for Network. Each icon owns a
`HoverHandler` and a `ToolTip` bound to its translated accessible metric name.

Before the first valid activation snapshot, render six quiet skeleton blocks with the final grid
geometry. If GPU discovery completes without a supported GPU, keep GPU and VRAM positions stable
and render their icon plus an em dash; do not collapse the right column or start a retry loop.

Below it, render `Top processes` with at most five service descriptors and a stale marker when
needed. Render `Active` as a horizontal `ListView` bound to `CenterActivityService.activities`.
Show quiet empty states for no processes and no activities.

Attach a `WheelHandler` to the horizontal activity list. When
`Math.abs(event.angleDelta.x) > Math.abs(event.angleDelta.y)`, move `contentX` within bounds and
accept the event; otherwise set `event.accepted = false` so vertical scrolling continues in the
page `ScrollView`.

- [ ] **Step 6: Add exact translations**

Add these English values:

```json
"center_notch.monitoring.title": "System Monitoring",
"center_notch.monitoring.live": "Live · 2s",
"center_notch.monitoring.paused": "Paused",
"center_notch.monitoring.stale": "Stale",
"center_notch.monitoring.warning": "Warning",
"center_notch.monitoring.critical": "Critical",
"center_notch.monitoring.cpu": "CPU",
"center_notch.monitoring.gpu": "GPU",
"center_notch.monitoring.ram": "Memory",
"center_notch.monitoring.vram": "Video memory",
"center_notch.monitoring.disk": "Disk",
"center_notch.monitoring.network": "Network",
"center_notch.monitoring.download": "Download {rate}",
"center_notch.monitoring.upload": "Upload {rate}",
"center_notch.monitoring.top_processes": "Top processes",
"center_notch.monitoring.process_cpu": "CPU",
"center_notch.monitoring.process_memory": "Memory",
"center_notch.monitoring.active": "Active",
"center_notch.monitoring.no_processes": "Process data unavailable",
"center_notch.monitoring.no_activities": "No active activities"
```

Add these Vietnamese values:

```json
"center_notch.monitoring.title": "Giám sát hệ thống",
"center_notch.monitoring.live": "Trực tiếp · 2 giây",
"center_notch.monitoring.paused": "Đã dừng",
"center_notch.monitoring.stale": "Dữ liệu cũ",
"center_notch.monitoring.warning": "Cảnh báo",
"center_notch.monitoring.critical": "Nguy hiểm",
"center_notch.monitoring.cpu": "CPU",
"center_notch.monitoring.gpu": "GPU",
"center_notch.monitoring.ram": "Bộ nhớ",
"center_notch.monitoring.vram": "Bộ nhớ đồ họa",
"center_notch.monitoring.disk": "Ổ đĩa",
"center_notch.monitoring.network": "Mạng",
"center_notch.monitoring.download": "Tải xuống {rate}",
"center_notch.monitoring.upload": "Tải lên {rate}",
"center_notch.monitoring.top_processes": "Tiến trình hàng đầu",
"center_notch.monitoring.process_cpu": "CPU",
"center_notch.monitoring.process_memory": "Bộ nhớ",
"center_notch.monitoring.active": "Đang hoạt động",
"center_notch.monitoring.no_processes": "Không có dữ liệu tiến trình",
"center_notch.monitoring.no_activities": "Không có hoạt động đang chạy"
```

The visible hardware blocks use icons only; metric-name strings are accessibility/tooltips.

- [ ] **Step 7: Run focused checks and commit**

Run:

```bash
python3 scripts/check_system_monitor.py
./scripts/check.sh
```

Expected: static ownership and repository qmllint gates PASS with no new warning outside the allowlist.

```bash
git add Titonium/Bar/notch/SystemMetricBlock.qml Titonium/Bar/notch/SystemProcessRow.qml Titonium/Bar/notch/CenterActivityCard.qml Titonium/Bar/notch/SystemMonitoringPage.qml Titonium/Bar/notch/qmldir scripts/check_system_monitor.py config/i18n/en.json config/i18n/vi.json
git commit -m "feat: add system monitoring presentation"
```

### Task 6: Integrate Monitoring into Center navigation and verify lifecycle

**Files:**
- Modify: `Titonium/Bar/notch/CenterNotchState.js`
- Modify: `Titonium/Bar/notch/CenterNotchViewport.qml`
- Modify: `Titonium/App.qml`
- Modify: `scripts/check_center_notch.js`
- Create: `scripts/system_monitor_acceptance.sh`
- Modify: `scripts/check.sh`
- Modify: `docs/TESTING.md`
- Modify: `config/i18n/en.json`
- Modify: `config/i18n/vi.json`

**Interfaces:**
- Final `primaryPages()` order is Overview, Notifications, Monitoring, Tools, Session.
- Viewport creates `SystemMonitoringPage` only for page ID `monitoring`.
- Runtime acceptance consumes only read-only `SystemMonitorService.state()` diagnostics.

- [ ] **Step 1: Write failing final navigation fixtures**

Expect:

```js
assert.deepEqual(plain(context.primaryPages()), [
    { id: "overview", icon: "dashboard" },
    { id: "notifications", icon: "notifications" },
    { id: "monitoring", icon: "monitor_heart" },
    { id: "tools", icon: "construction" },
    { id: "session", icon: "power_settings_new" },
]);
assert.equal(context.arrowPage("notifications", 1), "monitoring");
assert.equal(context.wheelPage("monitoring", 1), "tools");
assert.equal(context.transitionPlan("tools", "monitoring", false, 160).offset, -12);
```

- [ ] **Step 2: Run the state gate and verify it fails**

Run: `node scripts/check_center_notch.js`

Expected: FAIL because `monitoring` is not yet registered.

- [ ] **Step 3: Insert the descriptor and lazy viewport factory**

Insert `{ id: "monitoring", icon: "monitor_heart" }` after Notifications. Add:

```qml
if (normalized === "monitoring")
    return monitoringComponent;

Component {
    id: monitoringComponent
    SystemMonitoringPage { pageId: "monitoring" }
}
```

Add `center_notch.tab.monitoring` translations as `System Monitoring` and `Giám sát hệ thống`.

- [ ] **Step 4: Add read-only runtime diagnostics for acceptance**

Import `qs.Titonium.Services.SystemMonitor` in `App.qml` and add this read-only method to the existing
`center` IPC target:

```qml
function monitorState(): string { return SystemMonitorService.state(); }
```

The method does not start or stop sampling; the page remains the only activation owner. Extend the
static monitor gate to require this projection and reject `SystemMonitorService.start()` or
`SystemMonitorService.stop()` inside every IPC block.

Create `scripts/system_monitor_acceptance.sh` using an isolated Quickshell instance and the same
repository/Hyprland hash preservation pattern as existing acceptance scripts. Use the production
coordinator IPC commands:

```bash
qs -p "$project_root" ipc --pid "$shell_pid" call centerNotch open monitoring
qs -p "$project_root" ipc --pid "$shell_pid" call center monitorState
qs -p "$project_root" ipc --pid "$shell_pid" call centerNotch page notifications
```

Poll the JSON state after opening until `active` and `live` are true and CPU/RAM have valid values;
capture `hotSampleAt`, wait for it to advance, then switch to Notifications. Poll until `active` is
false and `psRunning`, `dfRunning`, and `discoveryRunning` are false. Reject runtime QML errors.

- [ ] **Step 5: Register syntax/static gates**

Add to `scripts/check.sh`:

```bash
node "$project_root/scripts/check_system_monitor_rules.js"
python3 "$project_root/scripts/check_system_monitor.py"
bash -n "$project_root/scripts/system_monitor_acceptance.sh"
```

Do not duplicate entries already added by Tasks 1 and 3.

- [ ] **Step 6: Document manual visual acceptance**

Add these exact steps to `docs/TESTING.md`:

```text
1. Open Center > System Monitoring; Live activates and values appear without a startup zero flash.
2. Confirm CPU/RAM/Disk align in the left column and GPU/VRAM/Network align in the right column.
3. Confirm every icon shares the bar/value line and hover exposes its metric name.
4. Generate CPU/GPU/network load; bars and rates update in place at the expected cadence.
5. Confirm Top processes shows at most five rows and Active mirrors Media/Timer/Job without duplicates.
6. Switch to another Center page; Live stops immediately and no monitoring process remains running.
```

- [ ] **Step 7: Run focused runtime and full repository verification**

Run:

```bash
node scripts/check_system_monitor_rules.js
python3 scripts/check_system_monitor.py
node scripts/check_center_notch.js
bash -n scripts/system_monitor_acceptance.sh
./scripts/system_monitor_acceptance.sh
./scripts/check.sh
git diff --check
```

Expected: focused and full gates PASS, runtime log contains no QML rejection, and diff check prints
no output.

- [ ] **Step 8: Commit final integration**

```bash
git add Titonium/Bar/notch/CenterNotchState.js Titonium/Bar/notch/CenterNotchViewport.qml Titonium/App.qml scripts/check_center_notch.js scripts/system_monitor_acceptance.sh scripts/check.sh docs/TESTING.md config/i18n/en.json config/i18n/vi.json
git commit -m "feat: integrate center system monitoring"
```
