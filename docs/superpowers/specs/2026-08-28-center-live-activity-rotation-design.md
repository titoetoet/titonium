# Center Live Activity Rotation Design

**Date:** 2026-08-28
**Status:** Approved for implementation planning
**Scope:** Event-driven rotation of active Timer and Job state in the physical Center TopBar

## Objective

Keep Daily Focus as Center's mental anchor while allowing active timers and explicitly reported
jobs to take turns in the same one-line TopBar surface. This changes only the collapsed Center
presentation. Center Notch content and automatic process discovery are separate future work.

## Locked presentation order

The visible precedence is:

```text
CenterAttention transient/actionable event
    > current CenterActivity rotation slot
    > Daily Focus
```

Attention events keep the existing priority and TTL policy unchanged. While an attention event is
visible, activity rotation is suspended rather than consumed off-screen. When it clears, the
current rotation slot receives its full dwell time.

With active items and no attention event, one round is:

```text
Daily Focus (10 seconds)
→ highest-ranked active item (6 seconds)
→ next active item (6 seconds)
→ third active item (6 seconds)
→ Daily Focus
```

At most three active items participate in a round. Ranking is derived internally: timer first,
then important job, then normal job; ties use most recently updated first and ID ascending for a
stable final tie-break. External callers cannot supply a numeric priority or dwell time.

Registry changes do not create a new takeover. Existing semantic events such as job started,
failed, completed and timer milestones continue to enter `CenterAttentionService`. When a visible
activity is removed, the rotation returns to Daily Focus and starts a fresh round. An update to a
still-visible job changes its value descriptor without restarting the six-second slot.

## Activity descriptors

`CenterActivityService` owns session-only, frozen value descriptors:

```text
id          timer:<id> or job:<id>
source      timer | job
label       normalized one-line label
icon        timer | work
importance normal | important
progress    0...100 for jobs, otherwise -1
deadline    absolute wall-clock milliseconds for timers, otherwise 0
updatedAt   wall-clock milliseconds
```

The registry is bounded to 32 active descriptors. Only the top three ranked descriptors are
presented. Job progress is rendered as `<label> · <percent>%`. Timer remaining time is calculated
only when its slot becomes visible and remains stable for that slot; no per-second timer is added.

`CenterJobService` upserts activities on start/progress and removes them on complete/fail,
requires-action and clear. `CenterTimerService` upserts on start and removes on cancel/completion.
The existing passive job/timer/media indicators remain unchanged. Media playback remains an icon
plus its existing bounded semantic events; it does not enter the activity rotation.

## Runtime boundaries

- One non-repeating QML `Timer` schedules the next rotation boundary.
- Pure JavaScript owns descriptor normalization, ranking and cursor transitions.
- The QML service owns `Date.now()`, translations and timer scheduling.
- Views read immutable presentation values and do not own scheduling or producer state.
- No `Process`, `/proc` scan, terminal-output parsing, filesystem watch or repeating poll is added.
- Builds, downloads, renders and backups enter through the existing explicit Center Job contract.
- Native system/app adapters may publish the same internal activity descriptor in later slices,
  after each trustworthy event/progress source is chosen.

## Reload and failure behavior

Activity state is session-only and reconstructs from Timer/Job service mutations after reload.
Malformed descriptors fail closed. With no valid active descriptor, the scheduler stops and Center
shows Daily Focus. Center Notch behavior and its current click route remain unchanged.
