# Center Surface Architecture Design

**Date:** 2026-09-04
**Status:** Approved in conversation; awaiting written-spec review

## Purpose

Titonium presents one logical Center surface. Pill, Notch, Connected, and Classic are presentation
themes for that surface, not independent behavior owners. A theme may change shape, geometry,
animation, and supported layout affordances without changing source selection, priority, expiry,
actions, screen ownership, focus, or surface lifecycle.

This refactor replaces the current theme-owned coordination in `CenterNotchCoordinator.qml`,
`CenterNotchSurface.qml`, `CenterNotch.qml`, and `CenterIsland.qml` with four neutral boundaries:

1. `Center Domain` aggregates business sources into an immutable semantic snapshot and dispatches
   advertised actions.
2. `Center Surface Controller` owns interaction and lifecycle state for the one logical surface.
3. `Neutral Surface Host` owns all native-window and layer-shell behavior.
4. Presentation profiles and renderers own appearance and emit neutral intents.

`SurfaceRouter` coordinates Center with other application surfaces exclusively through the neutral
controller API.

## Goals

- Preserve the behavior delivered on `main` at commit `4ff9471` while removing presentation-owned
  business and lifecycle logic.
- Give Capture, MPRIS, Notification, Agent Approval, Focus, Timer, and Job one normalized Center
  contract.
- Make theme changes preserve the selected context, current mode, timeout, owner screen, and action
  semantics.
- Make business rules and controller transitions deterministic and independently testable.
- Keep the protected Spotlight, Input Method, and dynamic screen lifecycle behavior intact.

## Non-goals

- Adding a new business source or redesigning existing Center content.
- Changing the priority policy, notification policy, timer/job semantics, or MPRIS ownership except
  where required to express the existing behavior through the new contracts.
- Persisting session-only Timer, Job, or controller state across shell restarts.
- Replacing the general `SurfaceManager`, Settings lifecycle, or Right Pill architecture.
- Forcing one native window when separate compact and overlay windows are required by layer-shell.
- Retaining a public compatibility alias from `CenterNotchCoordinator` to the neutral controller.

## Architectural constraints

- Backend modules must not contain Pill, Notch, Connected, or Classic vocabulary and must not know
  the active theme.
- Themes must not import business services directly.
- Renderers bind immutable state and emit intents; they do not resolve sources or execute actions.
- Only the neutral host and its native-window helpers may know layer-shell windows, input regions,
  keyboard focus, or stacking.
- `SurfaceRouter` communicates with `CenterSurfaceController`, never a theme coordinator.
- Existing singleton services remain the sole runtime listener owners. Center adapters project their
  state and do not duplicate listeners.

## 1. Center Domain

### Public contract

`CenterDomain` exposes exactly one reactive value and one command boundary:

```qml
readonly property var snapshot
function dispatch(intent: var): var
```

The snapshot and every nested object or array are frozen values. They contain no QML object,
callback, screen, native-window handle, or theme name.

```js
{
    revision: 42,
    primary: Context | null,
    secondary: Context | null,
    contexts: Object.freeze([Context, ...]),
    indicators: Object.freeze([Indicator, ...]),
    capabilities: Object.freeze({
        actions: Object.freeze([ActionCapability, ...])
    })
}
```

`revision` increases only when semantic snapshot content changes. Snapshot construction time is not
part of the contract because it would produce render churn.

### Context

All seven sources normalize to a common descriptor:

```js
{
    id: "timer:tea",
    source: "timer",
    kind: "countdown",
    title: "Tea",
    subtitle: "02:14",
    icon: "timer",
    tone: "normal",
    attention: "ambient",
    progress: 0.62,
    occurredAt: 1234,
    expiresAt: 5678,
    details: Object.freeze({}),
    actionIds: Object.freeze(["timer.pause", "timer.cancel"])
}
```

Allowed `tone` values are `neutral`, `normal`, `positive`, `warning`, and `critical`. Allowed
`attention` values are `ambient`, `transient`, and `blocking`. `progress` is `null` when it does not
apply; `expiresAt` is `0` when the context has no business expiry.

Source-specific data belongs in a frozen `details` value normalized for the declared `kind`.
Examples include media artwork and position, an approval command summary, or job metadata. A
renderer may ignore unsupported details but must not derive lifecycle or priority from them.

`primary` and `secondary` reference values also present in `contexts`. Their selection, priority,
deduplication, and business expiry belong to the domain. The controller never recomputes them.

### Indicators and action capabilities

Indicators describe passive ongoing state and never become contexts merely because a renderer has
space for them. Each indicator has a stable ID, semantic icon, accessible label, tone, and active
state.

An action capability describes an operation that is valid for a current context:

```js
{
    id: "media.toggle",
    contextId: "media:player-id",
    role: "primary",
    label: "Pause",
    icon: "pause",
    enabled: true
}
```

Allowed roles are `primary`, `secondary`, and `destructive`. Capabilities never contain functions
or service references. Every advertised `contextId` must resolve in the same snapshot.

### Domain action dispatch

The only renderer-originated domain intent is:

```js
{ type: "invoke-action", actionId: "media.toggle", contextId: "media:player-id",
  idempotencyKey: "optional-caller-key" }
```

`CenterActionDispatcher` resolves the current capability and invokes the owning adapter exactly
once. It returns a frozen result:

```js
{
    accepted: true,
    status: "completed",
    reason: "",
    closePolicy: "keep"
}
```

Allowed statuses are `completed`, `pending`, `rejected`, `stale`, and `unavailable`. Allowed close
policies are `keep`, `compact`, and `dismiss`. The controller applies the close policy; the domain
never controls a window. An action that disappeared between render and dispatch returns `stale`.
Side-effecting actions are never retried without an idempotency key.

### Source adapters

Capture, Media, Notification, Agent Approval, Focus, Timer, and Job each have a narrow Center
adapter. An adapter reads its existing service singleton, creates normalized frozen descriptors,
and maps advertised action IDs back to that service. It owns neither a runtime listener nor surface
state. Source services do not import Center views.

Business expiry remains in the domain. Banner auto-dismiss is separately owned by the controller;
the expiry of a notification and the four-second presentation of a banner are not the same event.

## 2. Center Surface Controller

### Public state and commands

`CenterSurfaceController` is a theme-neutral singleton. It references business data only by stable
context ID.

```qml
readonly property string ownerScreenName
readonly property string exitingScreenName
readonly property string mode
readonly property string selectedContextId
readonly property string destination
readonly property real dragProgress
readonly property bool active
readonly property int generation
readonly property var viewState

function dispatch(intent: var): var
function finishClose(screenName: string, generation: int): bool
```

Allowed modes are `closed`, `compact`, `banner`, and `expanded`. `viewState` is frozen:

```js
{
    generation: 18,
    ownerScreenName: "DP-1",
    exitingScreenName: "",
    mode: "banner",
    selectedContextId: "notification:42",
    destination: "overview",
    dragProgress: 0,
    focusPolicy: "none",
    dismissalPolicy: "timed",
    deadline: 123456
}
```

Allowed focus policies are `none` and `exclusive`. Allowed dismissal policies are `none`,
`outside`, and `timed`.

### Surface intents

Renderers may emit only neutral surface intents:

```js
{ type: "activate-context", contextId }
{ type: "request-mode", mode: "compact" | "banner" | "expanded" }
{ type: "dismiss" }
{ type: "navigate", destination, contextId }
{ type: "drag-update", progress }
{ type: "drag-end", offset, velocity }
```

An intent invalid for the current state or generation fails closed without side effects.

### State machine

- `closed -> compact` occurs when an eligible screen hosts the logical Center.
- `compact -> banner` selects a valid context and may install an auto-dismiss deadline.
- `compact|banner -> expanded` occurs through activation, keyboard input, or drag settlement and
  preserves a still-valid selected context.
- `expanded -> banner` requires an explicit intent; a domain update never collapses an active
  expanded session.
- `banner|expanded -> compact` occurs through dismissal, timeout, or an action close policy.
- If the selected context disappears, selection falls back to domain `primary`, then `secondary`,
  then an empty ID. This is selection recovery, not priority calculation.
- Losing the owner screen causes selection of a valid screen through `ScreenRouter`; with no valid
  screen, the controller enters `closed`.

Every owner change and every open/close cycle increments `generation`. Transition completion from a
host or renderer is accepted only when its generation matches, preventing stale animation callbacks
from completing a newer lifecycle.

Auto-dismiss applies only in `banner`. Hover, keyboard focus, or drag pauses the existing deadline;
resumption uses the remaining duration rather than resetting it. `expanded` uses exclusive keyboard
focus. A blocking context such as Agent Approval may request exclusive focus semantically; a theme
must not infer this from the source name.

Drag settlement is a pure controller rule. Profiles can disable the gesture, but they cannot change
its threshold, velocity policy, or target state.

### Mutual exclusion

The controller never calls `SurfaceManager`, Settings, Right Pill, or Spotlight directly. It emits
an acquisition or release request:

```js
{ type: "acquire-surface", owner: "center", screenName, focusPolicy }
{ type: "release-surface", owner: "center", generation }
```

The router responds through controller intents:

```js
{ type: "surface-granted", screenName }
{ type: "surface-denied", reason }
{ type: "surface-revoked", reason }
```

A denied acquisition preserves the prior stable state and reports `unavailable:busy`.

## 3. Neutral Surface Host and presentation

### Neutral host

`CenterSurfaceHost` is the only Center component that knows the native/layer-shell implementation.
It may coordinate a compact window attached to the Bar and a transparent overlay window for banner
or expanded modes. Both represent one logical surface and consume the same snapshot, view state,
profile, and generation.

The host owns:

- creation and activation of native windows on the owner screen;
- layer, anchors, exclusion mode, stacking, and transparent backing;
- input regions limited to visible interactive content;
- keyboard focus matching the controller focus policy;
- owner transfer and generation-safe close completion; and
- application of geometry produced by pure profile rules.

It does not own content, selection, priority, timeout, drag settlement, navigation, action dispatch,
or mutual exclusion.

### Presentation profiles

A profile is static data containing only anchor, geometry, inset, radius, transition names, and
layout capabilities:

```js
{
    id: "connected",
    anchor: "top-center",
    compact: { inset: 4, minWidth: 160, maxWidth: 480, height: 32, radius: 16 },
    banner: { width: 480, height: 72, radius: 22 },
    expanded: { minWidth: 320, maxWidth: 720, height: 440, radius: 28 },
    transitions: { open: "morph", close: "morph", contextChange: "crossfade" },
    capabilities: {
        secondaryContext: true,
        dragToExpand: true,
        navigationRail: true,
        outsideDismiss: true
    }
}
```

Geometry is computed from `profile + availableGeometry + mode` by pure presentation rules. A
profile contains no source test, timeout, service action, callback, or mutable state.

### Renderer contract

Each Pill, Notch, Connected, or Classic implementation satisfies the same boundary:

```qml
required property var snapshot
required property var viewState
required property var profile
signal intentRequested(var intent)
signal transitionFinished(int generation)
readonly property rect visualBounds
readonly property rect interactiveBounds
```

A renderer may choose layout, bind contexts/indicators/capabilities, run presentation animation,
and emit approved intents. It may not import a business service, router, surface manager, screen
router, settings coordinator, or another theme coordinator. It may not choose priority, create a
lifecycle timer, call a native action, or change business behavior based on its theme name.

### Theme switching

The composition boundary selects a new profile and renderer from Preferences. The controller's
owner, mode, selected context, timeout, and generation remain authoritative. The old renderer stops
receiving input and the new renderer consumes the same snapshot and view state. Unsupported layout
capabilities remove only their affordance; for example, a profile without drag still supports
explicit banner-to-expanded intents. No business context is discarded. Stale transition callbacks
are rejected by generation.

## 4. Routing, navigation, and event presentation

### Router API

`SurfaceRouter` exposes neutral Center entry points:

```qml
function openCenter(requestedScreen: var, destination: string,
                    contextId: string): string
function presentCenterBanner(requestedScreen: var, contextId: string,
                             policy: var): string
function closeCenter(reason: string): bool
```

The router resolves the requested/focused screen, checks Settings yield rules, and coordinates
mutual exclusion with `SurfaceManager` and Right Pill. It does not select contexts, calculate
timeouts, inspect a source, or know the active theme.

Opening Center follows this flow:

```text
UI or IPC -> SurfaceRouter -> mutual-exclusion decision
          -> CenterSurfaceController -> CenterSurfaceHost -> renderer
```

Renderer action flow is:

```text
renderer intent -> CenterSurfaceController
                -> CenterDomain.dispatch for invoke-action
                -> controller applies returned closePolicy
```

### Navigation

Navigation destinations are semantic values such as `notifications`, `clipboard`, `settings`, or
`source`. The router maps them to an expanded Center destination, Spotlight, Settings, or an
external source. Media raising is a Media action capability handled by the domain adapter, not a
hard-coded MPRIS branch in `SurfaceRouter`.

### Presentation requests

When a business event is eligible to request attention, the domain updates its snapshot and emits a
separate frozen presentation request:

```js
{
    id: "notification:42:arrival",
    contextId: "notification:42",
    requestedMode: "banner",
    attention: "transient",
    timeoutMs: 4000,
    focusPolicy: "none"
}
```

The domain owns whether the business event is eligible under priority and lifecycle policy. The
router requests surface access. The controller decides whether the request can interrupt the
current interaction and owns the resulting deadline. Rejecting or deferring the presentation does
not remove its context from the snapshot. An active expanded interaction is not collapsed by a
transient request.

### Failure behavior

- A vanished context or capability returns `stale`, then the controller refreshes selection.
- A failed service action is reflected through domain state or semantic feedback; the renderer does
  not call the service directly as a fallback.
- A missing host/window preserves desired controller state without replaying business actions.
- Losing a screen transfers ownership or closes safely without orphaned focus or input regions.
- A rejected router acquisition preserves the previous stable state.
- No side-effecting action is automatically retried without its original idempotency key.

## 5. Module structure and migration

The target ownership is:

```text
Titonium/Services/Center/
  CenterDomain.qml
  CenterDomainRules.js
  CenterActionDispatcher.qml
  adapters/
    CaptureCenterAdapter.qml
    MediaCenterAdapter.qml
    NotificationCenterAdapter.qml
    AgentApprovalCenterAdapter.qml
    FocusCenterAdapter.qml
    TimerCenterAdapter.qml
    JobCenterAdapter.qml

Titonium/Core/Surfaces/Center/
  CenterSurfaceController.qml
  CenterSurfaceState.js
  CenterSurfaceHost.qml
  CenterCompactWindow.qml
  CenterOverlayWindow.qml

Titonium/Bar/center/
  CenterRenderer.qml
  CenterPresentationRules.js
  presentations/
    Pill/
    Notch/
    Connected/
    Classic/
```

Exact renderer filenames may follow the repository's QML module conventions, but ownership and
dependency direction are fixed by this design.

Migration occurs in vertical slices within one isolated branch and is merged only as a completed
refactor:

1. Add failing pure contract and architecture tests.
2. Build the domain and adapters while comparing semantic output with current behavior.
3. Build the controller and state-machine tests.
4. Build the neutral host and native-window roles.
5. Move the current Connected implementation behind the renderer/profile contract.
6. Adapt Pill, Notch, and Classic to the same contract.
7. Move router, Notification auto-presentation, Agent Approval, IPC, and remaining entry points to
   neutral APIs.
8. Remove the old theme coordinator only after every consumer is migrated.
9. Strengthen architecture checks so the removed dependency directions cannot return.

No `CenterNotchCoordinator` compatibility singleton remains. The migration is atomic so new code
cannot continue depending on theme vocabulary.

## 6. Verification and acceptance

### Pure tests

- Normalize all seven sources, reject malformed input, and freeze every nested value.
- Verify deterministic arbitration, deduplication, priority, expiry, and tie-breaking.
- Verify valid action-to-context references, stale actions, idempotency, and exactly-once adapter
  dispatch.
- Cover controller open/close, all modes, selection recovery, deadline pause/resume, drag
  settlement, owner migration, and stale-generation callbacks.
- Cover profile geometry for Pill, Notch, Connected, and Classic without QML singletons.

### Static architecture checks

- Business-service imports are forbidden in theme renderers.
- Presentation theme names are forbidden in backend, controller, host API, and router identifiers.
- `SurfaceRouter` may depend only on the neutral Center API.
- Layer-shell, keyboard-focus, stacking, and Center input-mask primitives are confined to the host
  and native-window helpers.
- Renderers receive only snapshot, view state, and profile, and emit intents.
- Pure rule modules may not use `Date.now()`, QML singletons, timers, or mutable global state.
- Business actions outside domain adapters are rejected.

### Integration coverage

- Each source updates its context without mutating controller state except through an explicit
  presentation request.
- Notification presentation does not interrupt an active expanded interaction.
- Agent Approval obtains required focus and dispatches each action once.
- Media, Capture, Focus, Timer, and Job behaviors remain available through capabilities.
- Theme changes in compact, banner, and expanded modes preserve owner, selection, and deadline.
- Monitor removal leaves no orphan window, keyboard focus, or input region.
- Settings, Spotlight, Right Pill, and generic surfaces remain mutually exclusive with Center.

### Runtime gates

Run:

```bash
./scripts/check.sh
./scripts/smoke.sh
./scripts/protected_acceptance.sh
./scripts/center_notch_acceptance.sh
hyprctl configerrors
```

Focused Wayland acceptance covers all four themes; compact, banner, and expanded transitions;
outside click; Escape; keyboard navigation; drag; Notification timeout; Agent Approval focus and
action; all source projections; theme switching; owner-monitor removal; and visible-only pointer
input.

Tests must not stop a user-owned Titonium instance. If the configuration ID is already active, use
an isolated ID only when the existing acceptance harness supports it without affecting user state;
otherwise report the runtime gate as blocked.

## Completion and merge policy

The work is complete only when all static, pure, integration, runtime, and protected gates pass;
the implementation matches this spec and its implementation plan; and self-review finds no
out-of-scope changes. Work stays in its isolated worktree until the entire scope is complete.

Merge to `main` is fast-forward only. Before merging, verify that the user's existing uncommitted
changes will not be overwritten or mixed into the branch. If the dirty main checkout prevents a
safe merge, stop and report the condition. Never stash, reset, discard, or stop the user's running
shell to force completion.
