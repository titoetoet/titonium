# Unified Dynamic Island Design

**Status:** Proposed for implementation

**Canonical product contract:** `docs/DYNAMIC_ISLAND.md`

## Objective

Complete Titonium's Dynamic Island as one screen-local, always-mounted visual and input owner
shared by the Connected and Classic Top Bar styles. The owner implements the four canonical
states—`compact`, `satellite`, `banner`, and `expanded`—without duplicating coordinator state,
content, animation, or Wayland surface lifecycle between styles.

This work finishes the partially implemented Dynamic Island. Existing working behavior is retained
where it already satisfies `docs/DYNAMIC_ISLAND.md`; the migration focuses on removing the Classic
fork, preserving complete context descriptors, separating presentation responsibilities, and adding
the missing runtime acceptance coverage.

## Scope

The implementation includes:

- one `CenterPillWindow` per eligible screen for both Top Bar styles;
- one `CenterNotchSurface` and one `Shared.ConnectedPillShape` per owner;
- all four canonical states and their reversible transitions;
- Daily Focus Primary selection, live-activity and notification Secondary selection, and
  Focus-disabled promotion rules;
- Music, Notification, generic activity, AI approval, and clean canvas content;
- Connected and Classic compact presentation profiles without separate open-state surfaces;
- complete mouse, keyboard, drag, outside-click, screen-focus, and global-shortcut behavior;
- Reduced Motion, accessibility, localization, static checks, foreground checks, and focused live
  acceptance.

The implementation does not add Notification Center, System Monitoring, legacy Overview pages,
new activity sources, persistent Focus-mode state, or automatic edits to Hyprland configuration.

## Existing Baseline

The repository already contains most of the behavioral skeleton:

- `CenterNotchState.js` derives the four stable states, layout profiles, drag decisions, and
  notification auto-open policy.
- `CenterNotchCoordinator.qml` owns screen selection, page/context selection, Focus session state,
  activity slots, drag progress, and the four-second urgent-notification timer.
- `CenterPillWindow.qml` and `CenterNotchSurface.qml` provide an always-mounted Connected owner,
  one connected silhouette, compact/satellite rendering, open-state input, and geometry motion.
- `CenterNotch.qml` renders Music and Notification banners plus AI approval and clean Expanded
  content.
- The compact presentation already contains recording, media, notification, agent, timer/job, and
  idle visual treatments.
- The global `titonium:dynamicIsland` shortcut and compatibility `centerNotch` IPC routes exist.
- Static tests already cover many state, geometry, shape-count, and retired-component contracts.

The incomplete areas are the duplicated Classic owner, lossy context projection, coupled content
files, incomplete accessibility/localization, incomplete failure fallbacks, and insufficient live
acceptance for the canonical contract.

## Architecture

### One owner across styles

`BarHost` creates exactly one `CenterPillWindow` for every eligible screen. That window remains
mounted regardless of the selected Top Bar style. It is the only Dynamic Island layer-shell owner,
the only owner of open-state keyboard focus, and the only screen-level input mask for Dynamic
Island content.

`ClassicCenterNotchWindow.qml` and `ClassicCenterNotchSurface.qml` are removed. Classic no longer
creates a second open-state window or implements its own drag, outside-click, focus, close, or
content lifecycle.

The active Bar implementation publishes a passive compact style profile to the shared owner. The
profile contains only presentation inputs such as compact availability, vertical position, height,
width ceilings, radius, tone, and any style-specific padding. It cannot open or close the Island,
select contexts, own timers, or render Banner/Expanded content.

Changing style while Banner or Expanded is active first collapses the shared owner. The coordinator
retains the outgoing style profile until close animation completion, then the new compact profile is
presented. This prevents a mid-animation geometry jump or a transient loss of the input owner.

### State and data ownership

`CenterNotchCoordinator` remains the sole UI state machine. It publishes:

- `visualState` with exactly `compact`, `satellite`, `banner`, or `expanded`;
- `primaryContext`, `secondaryContext`, and `selectedContext`;
- `dragProgress`;
- owner and exiting screen names;
- session-only `focusEnabled`.

The coordinator exposes only the canonical intents: `openBanner`, `openExpanded`, `collapse`,
`selectActivity`, `setDragProgress`, and `finishDrag`, plus the existing compatibility operations
needed by IPC and AI routing. Compatibility operations delegate to canonical intents instead of
forming an alternative state path.

Domain data remains in existing services:

- `CenterFocusStore` owns Daily Focus text and its file lifecycle.
- `CenterActivityService` owns the ordered live-activity registry.
- `CenterAttentionService` owns bounded ephemeral notification presentation.
- `AgentApprovalService` owns normalized approval requests and their queue.
- `MprisService` owns native player facts and playback intents.

Views consume immutable descriptors and emit narrow intents. They do not own native listeners,
processes, persistence, activity rotation, or notification expiry.

### Lossless context descriptors

Context projection preserves every normalized field supplied by the owning service. A projected
context adds normalized `source`, `id`, `title`, and `icon` fields without discarding fields such as
`label`, `progress`, `trackLength`, `trackPosition`, `urgency`, or media identity.

Context identity is the tuple `(source, id)`. Slot selection and deduplication never compare `id`
alone, because independent sources may legally reuse the same identifier.

When a selected source disappears while Banner is open, the view keeps the frozen selected context
for stable geometry and readable fallback copy. Native actions are disabled when the owning service
can no longer resolve the selected entity. Collapsing clears the frozen selection after the close
animation finishes.

## Selection Rules

When Focus is enabled, Daily Focus is Primary. The first entry in
`CenterActivityService.activities` is Secondary. A current notification temporarily replaces that
Secondary entry and returns control to the activity after its bounded presentation expires.

When Focus is disabled, a Media activity is Primary when present; otherwise the first ordered live
activity is Primary. Secondary is the first remaining activity with a different `(source, id)`
identity. A current notification still temporarily owns Secondary. With no eligible Secondary,
the stable state is Compact.

Only one Secondary chip is rendered. Later activities remain in the service registry but never add
segments. Unread notification count alone does not create Satellite.

AI approval is not part of Primary/Secondary ranking. A pending approval is an interrupting request
that opens Expanded directly on its assigned eligible screen.

## Presentation Components

The current large surface/content files are split along stable responsibilities:

- `CenterNotchSurface.qml` owns connected geometry, the one shape, input-mask geometry, open/close
  progress, and composition of presentation children.
- `CenterCompactContent.qml` renders Primary identity, label, live visualization, and the independent
  Focus toggle target.
- `CenterSatelliteChip.qml` renders the Secondary chip, caches its exiting descriptor, owns its
  enter/exit motion, and emits selection.
- `CenterBannerContent.qml` renders Music, Notification, Focus, and generic activity banners.
- `CenterExpandedContent.qml` renders full AI approval or the clean extension canvas.
- `CenterStyleProfile.js` derives immutable Connected or Classic compact presentation values from
  style and screen geometry.
- `CenterNotchState.js` remains the pure state, selection, identity, auto-open, and drag policy unit.

This split does not introduce Loader boundaries inside the Dynamic Island owner. All four content
trees remain mounted so transitions can reverse immediately. Hidden infinite animations stop based
on effective presentation visibility and Reduced Motion.

### Style-specific compact presentation

Connected and Classic may differ in compact vertical placement, surface tone, padding, and Bar
reservation integration. They share content selection, hit targets, dimensions mandated by the
canonical screen profile, Satellite structure, open-state geometry, and all state transitions.

Classic's `ClassicCenterGroup` becomes an inert true-center reservation and style-profile adapter.
It no longer paints `Shared.Surface`, instantiates `CenterIsland`, or owns a Center hitbox. The
Classic notification bell adjacent to Center is removed because notification presentation belongs
to the unified Dynamic Island.

## Interaction Contract

- Clicking Primary opens its Banner; pending AI approval bypasses Banner and opens Expanded.
- Clicking Secondary opens a Banner for the cached Secondary descriptor.
- The Focus icon has an independent hitbox and toggles session Focus mode without opening Banner.
- Music artwork or designated media body and the Banner expand button open Expanded.
- Dragging the Banner lower edge updates progress continuously. Release at 48 logical pixels or
  500 logical pixels per second settles to Expanded; otherwise it settles to Banner.
- Drag settle begins from current progress and lasts 90–180 ms.
- Right-clicking compact Primary opens Settings at page `bar`.
- Escape, outside click, and focused-monitor departure collapse the open Island.
- Banner/Expanded forces Bar reveal until collapse; Compact/Satellite follows normal Bar reveal.
- `titonium:dynamicIsland` opens Expanded on the eligible focused screen.
- `centerNotch open banner|overview` remains compatible, with `overview` mapped to Expanded.

An urgent notification may auto-open Banner only from Compact or Satellite. Its timer is one-shot
and lasts 4000 ms. User navigation, manual open, another exclusive surface, or collapse cancels the
timer. Music never auto-opens.

AI approval always opens Expanded. Resolving a request keeps Expanded open when another request is
queued and refreshes the displayed normalized request. Resolving the final request collapses the
owner. Deny, native review, Allow for session, and Allow once retain the existing service intents.

## Geometry and Motion

All sizes are logical pixels. Standard screens use compact height 36, Primary width 180–260, and
Satellite ceiling 320. Screens whose logical aspect ratio is at least 2.1 use compact height 42 and
a 340 width ceiling for both Compact and Satellite. Banner is 480×72 with radius 22. Expanded is
720×440 with radius 28, clamped only when the available screen is smaller.

The visible silhouette remains one centered connected shape. Primary reserves 44 logical pixels
for the nested 32×28 Secondary chip and its separation. The cached Secondary remains mounted until
its opacity/scale exit completes; only then may compact width contract.

Opening geometry uses 220–250 ms and closing uses 180–200 ms with the shared damped spring curve.
Compact content fades over the first 35 percent; open content fades in from 15 through 65 percent.
Banner and Expanded content cross-fade from the shared canvas progress. Transitions are reversible
without replacing the window, shape, or content tree.

Only the screen-local surface animates geometry. Content components publish one clamped compact
width target and never animate `implicitWidth` or `implicitHeight`. Reduced Motion sets content,
geometry, and settle durations to zero.

## Input, Accessibility, and Localization

Compact and Satellite restrict the shared window mask to the visible connected cluster. Banner and
Expanded enable outside-click detection across the eligible screen while painting no full-screen
background. The connected silhouette, content bounds, and compact input mask derive from the same
geometry values.

Primary, Secondary, Focus toggle, media controls, expand, collapse, and approval actions are
keyboard reachable and have translated accessible names. Space and Enter activate the focused
target; Escape collapses open content. Decorative and duplicate icons do not publish competing
accessible names.

All new user-facing strings use `I18n.tr()` with matching English and Vietnamese entries. Hardcoded
fallback strings are limited to non-user-visible diagnostics; visible fallbacks are translated.

## Failure and Lifecycle Handling

- Missing media artwork renders the existing album fallback without changing geometry.
- A disappeared media player retains frozen title/artist context but disables native controls.
- A removed notification retains frozen summary/body until collapse instead of rendering blank.
- Missing Daily Focus text uses the translated focus fallback.
- An ineligible or disconnected screen cannot acquire ownership; focused-screen changes close an
  owner that no longer matches policy.
- Style changes, owner destruction, and Reduced Motion all complete coordinator cleanup exactly
  once.
- Notification and drag timers are stopped on manual collapse and cannot mutate a newer generation
  of state.

## Verification Strategy

### Pure tests

Pure JavaScript fixtures cover:

- all four stable-state derivations;
- standard and ultrawide logical profiles;
- Focus-enabled and Focus-disabled Primary selection;
- ordered Secondary selection and `(source, id)` identity;
- notification override and fallback;
- lossless context normalization;
- auto-open policy;
- drag threshold, velocity threshold, and 90–180 ms settle duration;
- style-profile derivation and small-screen clamps.

### Static contracts

Static checks enforce:

- one `CenterPillWindow` in `BarHost` and one `ConnectedPillShape` in the Dynamic Island tree;
- removal of `ClassicCenterNotchWindow.qml`, `ClassicCenterNotchSurface.qml`, and Classic's detached
  notification owner;
- no Loader inside the owner;
- no independent shoulder, filler, seam, `RoundCorner`, or satellite bubble;
- exact geometry constants and one-shot 4000 ms notification timeout;
- no content-side implicit-size animation;
- required accessibility and i18n keys;
- preserved shortcut and IPC compatibility.

### Foreground and live acceptance

Foreground checks reject QML load errors, missing methods, duplicate IDs, and unavailable types in
both styles. Focused live acceptance exercises:

- Compact → Satellite → Banner → Expanded → Compact;
- Primary and Secondary click routing;
- both activity and notification Secondary presentations;
- notification timeout and restoration of the previous activity;
- Focus toggle and Media promotion;
- drag success, cancel, and settle from current progress;
- interrupted/reversed open and close transitions;
- two-item AI queue persistence and final collapse;
- source disappearance fallbacks;
- outside click, Escape, focused-monitor change, Settings, and Spotlight exclusion;
- Connected ↔ Classic switching in closed and open states;
- compact input masks and open outside-click masks;
- scale 1.0 and 1.5;
- Reduced Motion with no lingering hidden animation.

The final repository gates are `./scripts/check.sh`, `./scripts/smoke.sh`,
`./scripts/protected_acceptance.sh`, and `hyprctl configerrors`. Tests do not launch real
applications, mutate audio, write clipboard contents, or edit either protected Hyprland file.

## Documentation Migration

`docs/DYNAMIC_ISLAND.md` remains the canonical product contract. Architecture, audit, testing,
theming, and roadmap text are updated where they still describe activity rotation, separate
Classic ownership, or detached notification UI. Earlier Center specs and plans remain historical
and are not rewritten; their superseded status continues to be explicit.

## Delivery Boundaries

Implementation is divided into independently testable changes:

1. pure selection/context/style contracts;
2. shared owner and Classic-owner removal;
3. presentation component extraction;
4. Compact/Satellite behavior completion;
5. Banner/Expanded behavior and failure fallbacks;
6. transition, input, accessibility, and localization hardening;
7. comprehensive static, foreground, live acceptance, and documentation reconciliation.

Each change preserves a runnable shell and ends with its focused tests before the repository-wide
gates run.
