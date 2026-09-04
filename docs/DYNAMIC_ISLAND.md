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

## Notification routing

`NotificationCoordinator` is the session-only notification history and routing authority.
Low/normal native notifications create history and, when enabled, passive top-right toasts.
Native critical notifications and the allowlisted internal `job_failed`, `job_requires_action`, and
`timer_finished` events create history plus a FIFO Center banner entry, never a duplicate toast.
The 16-item critical queue is presented by the existing controller, which supplies 4000 ms per item
and pauses/resumes its remaining deadline on banner hover. A banner must not preempt expanded or
otherwise user-owned Center interaction.

The always-visible Notification Bell opens one independent, lazy history panel on the clicked
eligible screen. The panel marks history read only after it has mounted; matching teardown releases
its owner, while stale or monitor-loss cleanup cannot close a newer panel. Standard actions,
per-item dismissal and clear-all are user-only panel/Center intents.

Policy precedence is block, native application override in Custom mode, allowlisted internal event,
native urgency, then normal fallback. `follow` proceeds to the later rules; `quiet`, `normal`, and
`critical` route to history, toast, and Center respectively. `allowCriticalOnIsland=false` reduces
critical routing to history. Text is never used to infer severity.

## Acceptance

Pure fixtures cover recursive snapshot freezing, arbitration, action validation, deadline
pause/resume, owner generations, selection recovery, and drag thresholds. Static checks enforce
adapter/listener boundaries, presentation independence, neutral routing, and sole native ownership.
Runtime gates cover foreground loading, Center mode transitions, Spotlight exclusion, passive and
critical notification projection, DP-1 ownership, repository isolation, and unchanged Hyprland
configuration hashes. The notification fixture runs only when no resident Titonium process owns
the session's `org.freedesktop.Notifications` name; it never stops the user's shell.
