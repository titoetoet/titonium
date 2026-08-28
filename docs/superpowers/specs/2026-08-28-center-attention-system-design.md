# Center Attention System Design

**Date:** 2026-08-28
**Status:** Approved for implementation planning
**Scope:** Daily Focus, passive activity indicators, priority arbitration, MPRIS media events,
user timers and explicit external job events for the true center of the TopBar

## Objective

Turn the physical center of the Titonium TopBar into a quiet attention surface. The center keeps a
user-defined Daily Focus as a mental anchor, shows small indicators for ongoing background state,
and temporarily replaces the focus text only when a bounded event deserves attention.

This slice does not duplicate information that already has a permanent Bar location. Volume,
active window, ordinary Wi-Fi/Bluetooth state, input method and notification count remain in their
existing controls.

## Existing-state correction

`Titonium/Bar/islands/CenterIsland.qml` is not currently in the physical center. `StartIsland.qml`
places it after Workspaces and uses it as the active-window pill. The actual `CenterGroup.qml` at
the screen center currently contains only the Bar visibility pin.

The implementation will:

- rename the current `CenterIsland.qml` and `CenterActivityRules.js` to active-window vocabulary;
- preserve the active-window pill's icon, natural sizing and Center Notch activation in
  `StartIsland`;
- create a new `CenterIsland.qml` for the attention surface;
- compose that new island beside the existing Bar pin in `CenterGroup` and continue centering the
  whole group from the full screen width.

The old component's final name is `ActiveWindowPill`. `FocusWindow` is rejected because “focus”
would be ambiguous between the active compositor window, keyboard focus and the Daily Focus mental
anchor introduced by this system.

## Locked behavior

### Daily Focus baseline

- Daily Focus is the primary text whenever no transient event wins arbitration.
- It has conceptual priority `0` and no expiry.
- It remains stable for the local calendar day; it does not rotate while the user is working.
- A line explicitly written for the current day wins. Otherwise Titonium chooses one deterministic
  fallback line for that day from a user-editable plain-text prompt file.
- One click on the Daily Focus surface opens the user's scratchpad/todo Markdown through a narrow
  service action. The view never executes a command or owns a file.
- Missing, empty or malformed files fail to a translated `Focus for today` label and never hide the
  center.

Runtime files live outside Git in Titonium's Quickshell data directory:

```text
center/daily-focus.md       # first non-empty line is today's explicit focus; remaining text is notes
center/focus-prompts.txt    # one fallback phrase per non-empty line
```

The explicit focus is considered current when `daily-focus.md` was modified on the current local
date. At the next local date, an unchanged file no longer overrides the deterministic daily
fallback. Titonium watches these two files reactively; it does not poll them.

### Passive indicators

Indicators describe ongoing state but never enter priority arbitration or replace Daily Focus:

- media icon while the selected MPRIS player is playing;
- timer icon while at least one user timer is active;
- job icon while at least one externally reported job is active.

Indicators use bounded geometry and accessible descriptions. In this slice they are informational;
the Center's primary click remains the scratchpad action. Per-indicator controls and a Center task
panel are deferred.

### Transient presentation

The winning event replaces only the primary text/icon presentation for its bounded lifetime. When
it expires or is acknowledged, Center returns to Daily Focus while any still-valid passive
indicators remain visible.

Initial policy:

| Priority | Event | Presentation lifetime |
|---:|---|---:|
| 100 | critical Center/system integration failure | until acknowledged |
| 80 | external job requires user action | until acknowledged or source clears it |
| 70 | timer finished; external job failed; Center action failed | 15 seconds unless acknowledged |
| 40 | external job completed | 5 seconds |
| 30 | timer has 5 minutes or 1 minute remaining | 4 or 6 seconds |
| 20 | media track changed, resumed or paused | 6, 3 or 2 seconds |
| 10 | external job started; lightweight Center feedback | 2 seconds |
| 0 | Daily Focus fallback | no expiry |

Calendar events, battery/storage warnings, privacy indicators and notification previews are not in
this slice. They may later publish through the same contract. Ordinary notifications remain owned
by the existing Bell/toast flow and do not enter Center.

## Architecture

```text
DailyFocusStore ───────────────────────────────────────┐
                                                      │
MprisService ── state indicator + transient events ─┐ │
TimerService ── state indicator + transient events ─┼─┼──► CenterAttentionService
Center job IPC ─ active jobs + transient events ────┘ │       ├── presentation
                                                      │       ├── indicators
                                                      │       └── expiry/ack actions
                                                      ▼
                                               CenterIsland

Existing Hyprland/Application projection ─► ActiveWindowPill ─► Center Notch
```

All runtime listeners and mutable state live in singleton services. `CenterIsland` reads immutable
value descriptors and emits user intent only. Pure JavaScript helpers own normalization,
arbitration, deterministic daily selection, timer milestones and job lifecycle transitions.

### Center event descriptor

Publishers submit semantic source/kind/content values to `CenterAttentionService.publish(event)`.
The service policy validates them and produces this normalized descriptor:

```text
id                 stable event instance ID
source             media | timer | job | center | system
kind               semantic transition such as track_changed or job_failed
title              normalized single-line presentation
icon                semantic icon name
priority            bounded integer 0...100
createdAt           wall-clock milliseconds
expiresAt           absolute wall-clock milliseconds, or 0 when there is no automatic expiry
deduplicationKey    stable replacement key
actionable          whether the event may remain pending
```

Callers do not provide arbitrary QML objects, callbacks, commands, colors or geometry. The service
normalizes and freezes the public descriptor. External callers cannot choose raw priority or TTL;
those values are derived from the allowlisted `source`, `kind` and normalized job `importance`.
`actionable` is independent of expiry: an actionable timer-completion event may be acknowledged
early but still expire automatically after 15 seconds, while a requires-action job may use
`expiresAt: 0` and remain until cleared.

### Arbitration rules

The arbiter maintains one current event and a bounded pending list containing actionable events
only.

1. An event with the current `deduplicationKey` replaces the current descriptor and advances the
   generation, including when the priority is unchanged.
2. A higher-priority event preempts immediately.
3. A different event at equal priority uses newest-wins ordering.
4. A lower-priority ephemeral event is dropped rather than queued for stale replay.
5. A lower-priority actionable event remains pending while it has not been cleared.
6. On expiry, acknowledgement or source clear, the highest-priority newest actionable event wins;
   otherwise presentation falls back directly to Daily Focus.

The service also exposes exact-ID clear for timer/job cancellation. Exact clear removes only the
matching current/pending descriptor; source clear is reserved for producer shutdown or reload.

Each accepted presentation change increments a generation token. The single non-repeating expiry
timer captures that generation and event ID. A timeout mutates state only when both still match,
so an old timeout cannot dismiss a newer event. `expiresAt`, not a paused TTL, determines whether a
pending event is still relevant.

The service does not keep an unbounded history. Completed ephemeral descriptors disappear after
presentation; active timers/jobs remain only in their capability services.

## Capability contracts

### MPRIS media

`Titonium/Services/Mpris/MprisService.qml` is the sole owner of
`Quickshell.Services.Mpris`. It projects value-only selected-player state and publishes semantic
transitions to Center.

Player selection is deterministic: a playing player wins over paused players; among equivalent
candidates, the most recently changed valid player wins. Initial discovery establishes state
without emitting a false startup event. Duplicate property notifications that do not change the
normalized track/playback signature emit nothing.

Transitions:

- track change while a valid title exists: priority 20 for 6 seconds;
- resume: priority 20 for 3 seconds;
- pause: priority 20 for 2 seconds;
- player disappearance/stop: clear media indicator without a Center takeover.

While the selected player is playing, the passive media indicator remains after transient text
returns to Daily Focus.

### User timers

`Titonium/Services/Center/CenterTimerService.qml` owns named countdown descriptors. The first slice
uses explicit IPC rather than a timer-creation UI:

```text
start(id, durationSeconds, label)
cancel(id)
acknowledge(id)
state()
```

Timers store absolute deadlines. One non-repeating scheduler wakes only for the next required
milestone across all active timers; there is no per-second or per-timer polling. Milestones publish
at five minutes, one minute and completion when the timer duration crosses those thresholds. A
timer that starts below a threshold schedules only future applicable milestones and completion.

The timer indicator remains while at least one deadline is active. Completion removes the active
timer and publishes a priority-70 event. Acknowledgement removes its actionable Center event.
Timers are session-only in this slice; persistence across shell restarts is deferred.

### Explicit external jobs

Builds, downloads, renders, backups and similar work integrate through a dedicated read/write
`IpcHandler` composed in `App.qml`. Titonium does not inspect processes, terminal output or download
directories.

The narrow lifecycle is:

```text
start(id, label, importance)
progress(id, percent, label)
complete(id, summary)
fail(id, summary)
requireAction(id, summary)
clear(id)
state()
```

`importance` is normalized to a small allowlist (`normal`, `important`). `normal` uses the policy
table unchanged. `important` adds 10 points to start, complete, fail and requires-action outcomes,
capped at 90 so priority 100 remains reserved for Titonium/system-critical failures. Progress
updates active state and deduplicate by job ID but do not repeatedly replace Center text. Start,
complete, fail and requires-action transitions publish according to this derived policy.

Unknown IDs, malformed percentages, empty labels and invalid transitions fail closed with a stable
IPC error string and category-capped logging. A convenience shell wrapper may translate friendly
commands to `qs ipc call`, but it contains no arbitration logic.

## View and interaction

The new `CenterIsland` renders:

```text
[bounded passive icons] [one-line primary text]
```

It grows naturally to a defined maximum, elides right, never wraps and never changes Bar height.
Daily Focus uses a quiet secondary tone. A transient event may use semantic tone based on severity,
but the Bar remains solid and avoids shaders, gradients and infinite animation. Width and content
changes use only short bounded transitions.

Clicking Center always requests the scratchpad action, including while an ephemeral event is
visible, so the mental-anchor interaction remains predictable. Actionable event acknowledgement is
available through IPC in this slice; a visible inline acknowledge control is deferred until its
interaction can be designed without stealing the primary click.

The renamed `ActiveWindowPill` retains its current click, keyboard and accessibility contract for
opening Center Notch. The existing Bar visibility pin remains a separate control in `CenterGroup`.

## Failure and reload behavior

- Missing MPRIS support produces no media indicator and no error event storm.
- Invalid publisher events are rejected before arbitration and logged with category caps.
- A wall-clock jump recomputes deadlines at the next native/file/event wake; overdue timer events
  complete once, never repeatedly.
- Hot reload reconstructs session-only timers/jobs as empty. Daily Focus reloads from its runtime
  files. MPRIS establishes a fresh baseline without a false track-change event.
- Scratchpad launch failure publishes one bounded priority-70 Center feedback event and remains
  available for retry; automated tests never launch an editor.

## Files and ownership

Expected new paths:

```text
Titonium/Services/Center/
├── CenterAttentionRules.js
├── CenterAttentionService.qml
├── CenterFocusRules.js
├── CenterFocusStore.qml
├── CenterTimerRules.js
├── CenterTimerService.qml
├── CenterJobRules.js
└── qmldir

Titonium/Services/Mpris/
├── MprisRules.js
├── MprisService.qml
└── qmldir
```

Expected Bar changes:

```text
Titonium/Bar/islands/ActiveWindowPill.qml       # renamed current CenterIsland
Titonium/Bar/islands/ActiveWindowRules.js       # renamed current helper
Titonium/Bar/islands/CenterIsland.qml           # new true-center attention view
Titonium/Bar/islands/CenterGroup.qml            # attention island + existing Bar pin
Titonium/Bar/islands/StartIsland.qml            # ActiveWindowPill composition
Titonium/Bar/islands/qmldir
Titonium/App.qml                                # service composition and narrow Center IPC
```

Locale, architecture/testing documentation and capability-specific scripts change only as needed.
The protected Input Method, Spotlight behavior, screen lifecycle and both Hyprland configuration
files remain unchanged.

## Reference audit and provenance

The conceptual reference is FelixKratz/SketchyBar, branch `master`, revision
`6284ee816601486ace33ca48a0271832eec6de35`, reviewed 2026-08-28, GPL-3.0.

Relevant upstream material:

- `src/event.c`: native callbacks are dispatched into named bar-manager event handlers;
- `src/bar_manager.c`: normalized payload values are attached before custom-event dispatch;
- `src/custom_events.c` and `src/custom_events.h`: named custom-event registration/triggering;
- `src/misc/defines.h`: public add/subscribe/trigger event vocabulary;
- `sketchybarrc`: event subscription is preferred for responsive items while periodic refresh is
  reserved for inherently time-sampled data.

Titonium adapts only the pattern of event producers publishing semantic payloads to subscribed
presentation logic. It does not copy SketchyBar source, shell scripts, item model, animation
system, theme or macOS-specific notification machinery. The priority arbiter, event descriptor,
Daily Focus, timers and job lifecycle are Titonium-owned designs, so no GPL source is incorporated.

Quickshell's native `Quickshell.Services.Mpris` singleton is the selected Linux integration because
it exposes connected MPRIS players reactively. No process poller or external media CLI is added.
Quickshell `FileView` exposes reactive contents but no modification timestamp in the installed
runtime, so `CenterFocusStore` runs `stat -c %Y` only on startup and `fileChanged`; it never samples
the file periodically.

## Testing and acceptance

### Pure and static gates

- Arbitration fixtures cover higher/equal/lower priority, dedup replacement, actionable pending,
  ephemeral drop, acknowledgement, expiry and generation mismatch.
- Focus fixtures cover explicit-today selection, date rollover, deterministic fallback, empty and
  malformed files.
- MPRIS fixtures cover player ranking, initial baseline suppression, duplicate signatures, track
  change, resume, pause and disappearance.
- Timer fixtures cover absolute deadlines, threshold selection, simultaneous timers, cancellation,
  overdue completion and no repeating timer.
- Job fixtures cover every valid transition, unknown IDs, deduplication, importance bounds,
  malformed progress and active-indicator counts.
- Architecture checks enforce sole MPRIS ownership, frozen public descriptors, no Process/FileView
  in Bar views, one non-repeating Center expiry scheduler, one non-repeating timer milestone
  scheduler and absence of volume/active-window/notification event publishers.
- Bar checks enforce `ActiveWindowPill` in Start, `CenterIsland` in `CenterGroup`, true-center
  placement, bounded one-line geometry, passive indicators and preserved Center Notch activation.

### Runtime gates

- Center IPC acceptance starts controlled timer/job fixtures, observes indicator and presentation
  state, verifies priority preemption and generation-safe expiry, then clears only its own fixtures.
- MPRIS acceptance uses a fake or isolated test player when available; it never controls a real
  user's player. If no isolated native fixture is available, MPRIS transitions remain pure-tested
  and receive a manual checkpoint.
- Scratchpad acceptance checks the service's resolved path and launch availability through a
  read-only seam; it never starts an editor or mutates the file automatically.
- Full `check.sh`, smoke, protected acceptance, Center Notch acceptance and
  `hyprctl configerrors` pass. Runtime tests leave Git, both Hyprland configurations and user files
  unchanged.

### Manual checkpoint

On DP-1, verify Daily Focus remains visually quiet and stable, the center group stays physically
centered as indicators/text change, media transitions return to focus while retaining the playing
indicator, timer/job priority feels calm rather than noisy, and the adjacent Bar pin remains easy
to target. Confirm the active-window pill remains in Start and still opens Center Notch. DP-3 must
remain free of Titonium surfaces.

## Out of scope

- calendar integration;
- automatic build/process/download detection;
- notification previews or duplication of permanent Bar status;
- persisted timers/jobs or task history;
- progress percentages in Center text;
- per-indicator controls or a task-management popup;
- inline acknowledgement UI;
- daily-focus editor UI inside Titonium;
- media artwork, visualizers or a full media player;
- shaders, glass, polling and infinite animation.
