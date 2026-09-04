# Center Notifications and System Monitoring Design

**Date:** 2026-08-31
**Status:** Superseded by `docs/DYNAMIC_ISLAND.md` on 2026-09-03
**Scope:** Add Notifications and System Monitoring pages to the existing Center Notch popup

## Objective

Turn the Center Notch into a useful inspection surface without changing the collapsed Center
Island scheduler. Notifications provides a viewed/unviewed history backed by the existing native
notification service. System Monitoring provides an on-demand, read-only snapshot of current
hardware load, top processes and the already-normalized Center activities.

This slice does not redesign the Overview dashboard, change Attention/Activity/Daily Focus
precedence, poll arbitrary processes while the popup is closed, or add process-management actions.

## Locked product decisions

- The rail order is Overview, Notifications, System Monitoring, Tools and Session. Settings remains
  anchored at the bottom.
- Notifications carries an unread-count badge. Opening its page marks all current notifications as
  viewed; notification history remains until dismissed.
- Notifications supports dismissing one item and clearing the complete visible history.
- System Monitoring is read-only in V1. It does not kill processes, stop jobs or expose tuning
  controls.
- Monitoring uses a two-column, three-row hardware grid: CPU/RAM/Disk on the left and
  GPU/VRAM/Network on the right.
- Each hardware block has one primary metric line plus an optional aligned telemetry line. Its
  semantic icon sits on the primary line beside the bar or network values; there is no textual
  CPU/GPU/RAM label in the block. The icon has an accessible name and hover tooltip.
- CPU, GPU, RAM, VRAM and Disk percentages are rendered inside their horizontal bars. CPU and GPU
  show available temperature and watts; memory and storage show used/total capacity.
- There is no total-system-power estimate. Missing sensor values are omitted rather than rendered
  as zero.
- Monitoring samples only while its page is the visible Center Notch page. Closing the popup or
  changing page stops timers, file reloads and child processes.
- QML remains the runtime owner. No Python, Go, Rust, eBPF sidecar or Hyprland plugin is introduced.

## Center rail and navigation

The primary rail pages become:

```text
Overview
Notifications  [unread badge]
System Monitoring
Tools
Session

Settings       [bottom anchored]
```

`CenterNotchState.js` remains the canonical ordered-page registry for normalization, keyboard
navigation, wheel navigation and transition direction. Unknown IDs still normalize to Overview.
The rail and viewport consume the same page order so selection geometry cannot diverge from
navigation order.

The existing `900x430` maximum Center Notch size is retained. Each new page owns an internal
scrolling content area; the rail and page header remain fixed. The popup is not enlarged to fit all
process and activity rows at once.

## Notifications page

The page header contains its title, current unread count and a `Clear all` action. The content is a
newest-first list of projected notification descriptors. Each row contains application icon,
application name, summary, optional body, relative received time and a dismiss action. Urgency may
affect the semantic accent but does not reorder history.

Opening the page calls the existing viewed-state boundary and clears all current unread IDs. If a
notification arrives while the page is visible, it is projected into history and treated as viewed
immediately because its content is already on the open inspection surface. Native toast and Center
Attention publication remain governed by their existing policy; viewing the page does not suppress
the new-notification event.

`NotificationService` remains the single notification owner and gains one bulk-dismiss operation.
Bulk dismissal takes a stable snapshot of the current descriptor IDs, attempts native dismissal for
each and removes each projected descriptor regardless of native staleness. It also clears matching
toast and unread IDs. Failures use the existing bounded-warning policy and do not prevent the rest
of the snapshot from being cleared.

An empty history renders one quiet empty state. The page does not invent archive persistence,
notification actions, inline reply or per-application filtering in this slice.

## System Monitoring presentation

The fixed header shows `System Monitoring` and a live indicator. `Live · 2s` is active only while
the page owns an active sampling lease. The hardware grid is:

```text
+----------------------------+  +----------------------------+
| CPU icon [bar 34%] 54C     |  | GPU icon [bar 42%] 56C     |
|                      38W   |  |                      41W   |
+----------------------------+  +----------------------------+
| RAM icon [bar 57%]         |  | VRAM icon [bar 8%]         |
|              18.2 / 32 GB |  |               1.3 / 16 GB |
+----------------------------+  +----------------------------+
| Disk icon [bar 61%]        |  | Network icon               |
|            612 / 1000 GB  |  |  down 12.4 / up 1.2 MB/s  |
+----------------------------+  +----------------------------+
```

Both columns have equal width and all six blocks have equal height. Icons, bars and trailing values
use fixed grid columns so corresponding blocks align. Percentage text is centered over the bar
track with a theme-contrast foreground; fill never changes the text color midway. Normal values use
neutral theme colors. Warning and critical accents are driven by explicit threshold rules, not by
arbitrary per-widget colors.

Utilization and capacity remain neutral below 70%, warn from 70% through 89% and become critical at
90% or above. CPU/GPU temperature remains neutral below 80C, warns from 80C through 89C and becomes
critical at 90C or above. An unavailable sensor never receives a warning color. These thresholds
are presentation constants in the pure rules layer rather than user preferences in V1.

Below the hardware grid, `Top processes` renders at most five rows with process name, CPU percent
and resident memory. Rows are sorted by CPU descending with PID as the stable tie-break. V1 does
not make rows clickable.

The final `Active` section projects the complete current Center activity registry into compact
horizontal cards. Each card uses the descriptor's source icon and label, plus progress for jobs or
remaining time for timers. Media, Timer and Job use the same read-only card component. Cards retain
the Center activity priority order and scroll horizontally when they exceed the viewport. Updates
replace the matching activity by ID rather than creating duplicate cards.

## Monitoring service boundary

`SystemMonitorService` is a singleton responsible for sampling lifecycle, parsing and immutable
presentation values. Pages request `start()` when visible and `stop()` when hidden. Calls are
idempotent. The service exposes status, the latest hardware snapshot and the latest frozen top-five
process list; it does not expose its `FileView`, timers or child processes to the page.

One non-repeating QML scheduler wakes at the nearest due sample boundary:

- every 2 seconds: CPU, GPU, RAM, VRAM and network;
- every 5 seconds: top processes;
- every 10 seconds: root-filesystem capacity.

Activation performs an immediate first refresh, then establishes those independent deadlines.
Stopping cancels the scheduler and prevents late process output from publishing into the inactive
page generation.

The service follows a QML-first data path:

- `/proc/stat` supplies CPU utilization through deltas between valid samples;
- `/proc/meminfo` supplies total and available RAM;
- `/proc/net/dev` supplies aggregate non-loopback receive/transmit byte deltas;
- discovered DRM/sysfs files supply supported GPU busy percentage and VRAM used/total;
- discovered `hwmon` or powercap files supply available CPU/GPU temperature and power values;
- one `ps` invocation supplies process PID, command name, CPU percent and RSS for parsing and
  ranking in JavaScript;
- one `df` invocation supplies total and used bytes for the filesystem mounted at `/`.

Hardware paths are discovered on activation and never hard-code `card1`, `hwmon2` or another boot-
order-dependent name. Discovery prefers the active DRM device and validates every chosen file
before sampling. CPU power may be a direct power sensor or a rate derived from a valid energy
counter delta. GPU power uses an available average/input board-power sensor. These are presented as
CPU/GPU telemetry only; they are never summed or relabeled as whole-system power.

Pure `SystemMonitorRules.js` functions parse source text, calculate guarded deltas, normalize units,
rank processes, resolve display thresholds and return frozen value objects. Counter resets, missing
fields, negative deltas, non-finite numbers and impossible capacities produce an unavailable field,
not a synthetic zero.

## Availability and failure behavior

- The first activation displays a quiet loading skeleton until the first valid snapshot arrives.
- A missing optional sensor hides only that suffix. For example CPU utilization can remain visible
  without CPU watts.
- If no supported GPU exists, GPU and VRAM blocks render an unavailable state without starting a
  retry loop. Discovery runs again on the next page activation.
- A failed `ps` refresh preserves the previous process list for that activation and marks it stale;
  it does not clear the list to imply that no processes exist.
- A failed `df` refresh follows the same previous-value/stale rule.
- A malformed `/proc` sample is discarded and does not replace the last valid baseline. The next
  valid sample calculates against the last valid counter set when safe, otherwise it establishes a
  new baseline before publishing a rate.
- Individual failures produce bounded categorized warnings. Repeated unsupported hardware does not
  spam logs.
- Closing or switching away clears the live indicator immediately. Cached values may remain in the
  service for the next activation, but they are visibly stale until the immediate refresh succeeds.

## Existing activity integration

`CenterActivityService` gains a read-only frozen registry projection suitable for inspection. This
does not alter its rotation cursor, top-three collapsed presentation, priority order or six-second
dwell scheduler. The Monitoring page is only another consumer of normalized activity state.

The hardware sampler does not discover activities from arbitrary system processes. Builds,
downloads and other jobs still enter through explicit event adapters and `CenterJobService`; timers
and media continue to use their current producers. This preserves the event-driven Center model.

## Components and ownership

- `CenterNotchRail` renders the two new navigation entries and unread badge.
- `CenterNotchViewport` lazily instantiates `NotificationsPage` and `SystemMonitoringPage`.
- `NotificationsPage` renders notification descriptors and invokes service operations.
- `SystemMonitoringPage` owns only presentation and the visible-page lifecycle call.
- Small page-local components render notification rows, metric blocks, process rows and activity
  cards. They receive value properties and never perform sampling.
- `NotificationService` owns history, unread/viewed state and native dismissal.
- `SystemMonitorService` owns system sampling and publication.
- `SystemMonitorRules.js` owns deterministic parsing and calculations.
- `CenterActivityService` owns normalized activity state and exposes a read-only projection.

No Dashboard/Overview content is moved into the new pages. No common component is extracted unless
at least two real new-page consumers need it.

## Accessibility and theme behavior

All controls use existing Shared components and Theme/Metrics tokens. Metric icons have translated
accessible names and tooltips because the visible text labels are intentionally removed. Bars
expose metric name, percentage and available telemetry as one accessible description. Color is not
the only warning signal: warning and critical values also expose semantic accessible text.

Keyboard focus enters page actions and notification dismiss buttons in visual order. Horizontal
activity scrolling must not trap vertical page scrolling. Reduced Motion keeps existing instant
page transitions and adds no animated metric interpolation.

## Verification

Pure JavaScript tests cover:

- Center page normalization, wheel/arrow order and transition direction with both new pages;
- `/proc/stat`, `/proc/meminfo` and `/proc/net/dev` parsing, including first-sample baselines,
  counter reset and malformed input;
- sensor-unit normalization, power-from-energy deltas and unavailable values;
- process parsing, top-five ordering and stable tie-breaks;
- disk parsing and percentage clamping;
- threshold and frozen-presentation rules;
- notification bulk removal and viewed-state transitions.

Static QML checks cover module registration, lazy viewport components, rail badge binding,
visibility-owned sampler lifecycle, translated accessibility strings and the absence of sampling
commands in page components.

Runtime acceptance covers:

1. Open Monitoring and observe an immediate snapshot followed by the agreed 2/5/10-second cadences.
2. Switch pages and verify sampling timers/processes stop; return and verify discovery/refresh resumes.
3. Exercise CPU/GPU load and confirm percentages update in place without duplicate objects.
4. Open Notifications and confirm the unread badge clears while history remains.
5. Receive a notification while Notifications is visible and confirm it is immediately viewed but
   still enters history and follows existing Attention/toast policy.
6. Dismiss one item and clear all, including a stale native notification, without leaving projected
   unread or toast IDs.
7. Start media, a timer and a job and confirm Active cards update without changing collapsed Center
   rotation behavior.

The full repository check and diff whitespace check must pass before handoff.

## Explicitly deferred

- Redesigning the Overview dashboard.
- Killing, renicing or inspecting process details.
- Per-process historical graphs.
- Persistent monitoring history.
- SMART/NVMe health, fan RPM, motherboard/VRM sensors and laptop battery health.
- Total-system-power measurement or estimation.
- Notification actions, inline reply, filtering or archive persistence.
- A native sidecar, eBPF collector or Hyprland plugin.
