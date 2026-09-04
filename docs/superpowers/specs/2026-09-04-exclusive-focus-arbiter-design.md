# Exclusive Focus Arbiter Design

## Problem

Titonium currently derives `WlrLayershell.keyboardFocus` independently in each
exclusive surface. Routing closes the previous owner and opens the next owner in
the same QML call stack. State properties change synchronously, but the old
layer-shell keyboard-interactivity update is not guaranteed to reach Hyprland
before the new layer requests exclusive focus.

The live runtime trace proved the race with an Edge Menu to Center transition:

```text
acquired edge-menu:DP-1
exclusive-focus-conflict:edge-menu:DP-1:center:DP-1
released edge-menu:DP-1
```

Bluetooth was only the trigger visible near this occurrence. The same race is
possible for any transition among Center, Edge Menu, Spotlight or another
`OverlayHost` surface, Settings, and the optional Agent Approval surface.

## Goals

- At most one Titonium layer may expose `WlrKeyboardFocus.Exclusive` at a time.
- A new owner must not receive exclusive focus until the old owner has observed
  revocation and one event-loop boundary has elapsed.
- Rapid or stale requests must not reclaim focus after a newer request.
- Existing surface presentation, animation, screen routing, and lazy lifecycle
  remain intact.
- Focus coordination must be independent of the event that opened a surface.

## Non-goals

- Changing Bluetooth behavior or audio-device selection.
- Replacing `SurfaceManager`, `RightPillCoordinator`, `SettingsCoordinator`, or
  `CenterSurfaceController` as presentation-state owners.
- Serializing non-keyboard surfaces such as Dock, notifications, or Audio OSD.
- Changing Hyprland configuration.

## Ownership model

`FocusArbiter` is a Core singleton and is the only source of truth for which
Titonium owner may project exclusive keyboard focus. Presentation coordinators
continue to decide whether their surfaces are logically open. Each exclusive
window derives a stable logical owner ID and allocates a unique requester lease
for that delegate incarnation. It submits both the logical ID and lease with
its desired-focus state to the arbiter. Logical IDs remain stable in diagnostics
and logs; leases are internal instance identity and are never used as log IDs.

The arbiter exposes immutable state containing:

- `owner`: the owner currently allowed to project exclusive focus;
- `pendingOwner`: the newest owner waiting for handoff;
- `ownerLease` and `pendingLease`: the requester leases paired with those IDs;
- `generation`: a monotonically increasing request token;
- `phase`: `idle`, `owned`, or `releasing`.

An owner ID includes the surface family and screen, for example
`center:DP-1`, `edge-menu:DP-1`, `overlay:spotlight:DP-1`, or
`settings:DP-1`.

## State transitions

When no owner exists, a valid request is granted immediately. Repeating a
request from the current owner is idempotent.

When another owner or a newer requester lease requests focus, the arbiter records
only the newest request, increments the generation, clears the current grant,
and enters `releasing`. A request is idempotent only when both its logical owner
ID and requester lease match the current owner (or current pending request).
Clearing the grant makes every window bind `WlrKeyboardFocus.None`. The arbiter
then schedules a single `Qt.callLater` callback. That callback grants the
pending owner only if its generation and requester lease are still current and
it still desires focus. A current-owner withdrawal also enters this ownerless
`releasing` cooldown; the callback settles to `idle` when no successor remains.

If a pending owner withdraws, it is removed while preserving the ownerless
cooldown. A release is accepted only when both logical owner ID and requester
lease match the current or pending request. A stale release—including a
destruction from an older window incarnation with the same logical ID—cannot
clear a newer grant.

This event-loop barrier is centralized in the arbiter. Routers and feature
services must not add their own focus delays.

## Window integration

Each exclusive surface retains its existing logical ownership expression, but
uses that expression only as its `wantsExclusiveFocus` input. The effective
binding is true only when both `FocusArbiter.owner` and `FocusArbiter.ownerLease`
match the window's stable logical owner ID and unique requester lease.
Overlapping delegates with the same logical ID therefore cannot both project
exclusive focus.

The following windows participate:

- `Core/Surfaces/Center/CenterOverlayWindow.qml`;
- `Core/Surfaces/OverlayHost.qml` for Spotlight and generic overlays;
- `Bar/right/EdgeMenuWindow.qml`;
- `Settings/SettingsWindow.qml`;
- `AgentApproval/AgentApprovalWindow.qml` when its approval requires keyboard
  input.

`FocusDiagnostics` observes arbiter grants rather than raw logical visibility.
It remains a diagnostic guard, not a second state owner.

Window destruction withdraws its request. Screen removal therefore cannot leave
a grant attached to a destroyed layer.

## Pure rules and QML boundary

The transition rules live in a pure JavaScript module so ordering, replacement,
withdrawal, and stale generations can be tested without a compositor. The QML
singleton owns the one-shot `Qt.callLater` scheduling boundary and projects the
pure state.

The pure module must freeze every returned snapshot and reject blank owners or
leases. Request, withdraw, and grant callbacks must carry the requester lease;
stale leases and non-canonical input snapshots fail closed. It must not import
feature-specific code or encode Bluetooth, Center content, or presentation policy.

## Testing

The focused regression test must first fail against the current diagnostic-only
implementation. It will cover:

1. immediate first-owner grant;
2. Edge Menu to Center enters `releasing` with no effective owner;
3. Center to Spotlight uses the same generic handoff;
4. Spotlight to Settings uses the same generic handoff;
5. newest request wins during rapid replacement;
6. stale scheduled grants are ignored by generation;
7. pending and current withdrawal;
8. release from an old owner cannot clear a newer owner;
9. every exclusive window binds keyboard focus to the arbiter;
10. no feature router contains an independent focus-handoff timer.

After the focused red-green cycle, run `./scripts/check.sh`,
`./scripts/smoke.sh` in the documented isolated lifecycle, the relevant
protected acceptance gates, and `hyprctl configerrors`. Runtime verification
must confirm that an Edge Menu to Center transition logs release before acquire
and never emits `exclusive-focus-conflict`.

## Failure behavior

Fail closed: while ownership is ambiguous, every Titonium layer projects
`WlrKeyboardFocus.None`. A missed grant may require the user to invoke a surface
again, but it cannot lock input away from normal applications.

The arbiter does not attempt to recover external compositor state. It logs
invalid owner requests, rejected stale callbacks, and ownership replacement so
runtime traces remain actionable.
