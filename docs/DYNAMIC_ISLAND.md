# Center surface system and interaction specification

Status: canonical. The Center is one logical surface; Pill, Notch, Connected, and Classic are
presentation profiles rather than independent behavior owners.

## State and ownership

`CenterSurfaceController` owns the `closed`, `compact`, `banner`, and `expanded` modes, stable
context selection, owner screen, timeout, focus policy, drag settlement, and generation. A
secondary live activity is domain data and never creates another lifecycle mode. Stale animation
callbacks cannot complete a newer generation.

`CenterSurfaceHost` is composed once for each eligible `ScreenPolicy` output. Its compact and
overlay helpers are the only Center code allowed to own layer-shell roles, input regions, stacking,
or keyboard focus. Compact accepts pointer input only inside renderer bounds. Banner/expanded may
accept outside clicks for dismissal; expanded owns exclusive keyboard focus.

`SurfaceRouter` arbitrates Center with Settings, Spotlight, Right Pill, and general transient
surfaces through `openCenter`, `presentCenterBanner`, and `closeCenter`.

## Semantic domain

`CenterDomain` combines Capture, Media, Notification, Agent Approval, Focus, Timer, and Job adapters
into one recursively frozen snapshot. Context priority, primary/secondary selection, business
expiry, indicators, and advertised actions are domain decisions. Renderers never import those
source services.

Actions cross the presentation boundary as `invoke-action` intents containing an action ID and
context ID. The dispatcher revalidates the current capability, calls exactly one owning adapter,
and returns a frozen result with a neutral close policy.

## Presentations and input

`CenterRenderer` selects a static profile and renderer. Presentations receive only `snapshot`,
`viewState`, and `profile`; they may own shape, geometry, layout, and animation and may emit only
neutral intents. Changing the Top Bar style does not recreate or reset domain/controller state.

- Compact activation requests expanded Center.
- Banner and expanded content render the selected semantic context and its current capabilities.
- Escape, outside click, timeout, or an action close policy returns to compact.
- Drag settlement uses the controller-owned 48px/500px-per-second thresholds.
- Agent Approval requests expanded exclusive focus and uses the same capability dispatch path.

The historical `centerNotch` IPC target remains for compatibility with deterministic lifecycle
tests. Its responses expose neutral `mode` values rather than presentation page/state names.

## Acceptance

Pure fixtures cover recursive snapshot freezing, arbitration, action validation, deadline
pause/resume, owner generations, selection recovery, and drag thresholds. Static checks enforce
adapter/listener boundaries, presentation independence, neutral routing, and sole native ownership.
Runtime gates cover foreground loading, Center mode transitions, Spotlight exclusion, notification
projection, DP-1 ownership, repository isolation, and unchanged Hyprland configuration hashes.
