# Module contract

A module is a vertical capability slice, not a widget file copied into the bar.

```text
Titonium/Services/<Capability>/   system adapter + shared reactive model
Titonium/Bar/widgets/             compact bar view, when needed
Titonium/Overlays/<Capability>/   lazy heavy surface, when needed
Titonium/Ipc/                     stateless public IPC adapters grouped by domain
Titonium/Orchestration/           shell-level routing, bootstrap and cross-service bridges
scripts/check_<capability>.*      pure and architecture checks
config/i18n/{vi,en}.json          reachable user strings
```

Create only the directories the capability actually needs.

`App.qml` is the final composition root only. It wires hosts to `SurfaceRouter`, instantiates IPC
adapters and triggers `ServiceBootstrap` after construction. It must not accumulate capability IPC
bodies, native service logic or mutual-exclusion policy.

## Service interface

A service may import Quickshell integration modules, observe native signals, persist runtime data
outside Git and expose narrow intent methods. It must:

- be a `Singleton` when state is shared;
- prefer events over polling;
- expose stable semantic state rather than DBus/IPC payloads;
- contain platform failure and provide a safe unavailable state;
- have pure JavaScript helpers for transformations worth unit testing.

Native ownership is singular. Exactly one service file may import a capability's Quickshell native
module. Views consume immutable value descriptors and semantic methods; they never retain or return
PipeWire nodes, Bluetooth devices, Network objects, Hyprland toplevels or native notifications.

## View interface

A view receives explicit context such as `screen` and reads a service singleton. It may emit user
intent or call a narrow service method. It must not instantiate `Process`, `FileView`, execute raw
commands, persist state or reach into another feature's private QML objects.

Bar widgets remain cheap while visible. Heavy panels use `SurfaceManager` plus `OverlayHost`; their
`Loader.active` becomes false on close. Only one transient surface owns exclusive keyboard focus.
Independent non-focus surfaces such as OSD and notification toasts use their own DP-1-only host,
`ExclusionMode.Ignore`, `WlrKeyboardFocus.None` and an input mask limited to visible content.

## Notification boundary

`NotificationService` is the only native `NotificationServer` owner. It emits frozen descriptors;
`NotificationCoordinator` owns bounded session history, unread state, passive toast IDs, the
critical FIFO queue and lazy-panel ownership. Neither notification view nor Center presentation may
import native Notifications objects, own a native listener, or retain one.

The rightmost Topbar `NotificationCenter` control is always present in both Bar styles. It keeps the
fixed non-bell `history` glyph as unread state changes; its unread badge may change. It routes only an
open/close request to the screen-local history panel. Connected attaches that history content to the
existing right-pill chassis at the exact Notification Center control; Classic loads its detached
overlay shell. The panel marks read only after its owner is mounted, and releases only its matching
owner on close or screen loss. Standard actions, dismissal and clear-all are local user intents
revalidated by the coordinator/service boundary.

The public `notifications` IPC target has exactly `state()` and `markRead()`. Its state is limited to
counts plus read-only panel, queue and policy metadata. It must never expose notification injection,
action invocation, dismissal, clear-all, panel lifecycle or settings-patch IPC.

## Center surface boundary

Center is a domain/controller/host/presentation pipeline. `Services/Center/CenterDomain.qml`
publishes a recursively frozen semantic snapshot and accepts only advertised capability actions.
Its source adapters are read-only projections plus explicit dispatch; existing source services
remain the sole listener owners.

`Core/Surfaces/Center/CenterSurfaceController.qml` owns the logical `closed`, `compact`, `banner`,
and `expanded` lifecycle, selection, timeout, focus policy, owner screen, and generation. Pure
transitions receive time explicitly. `SurfaceRouter` grants or denies ownership and exposes the
neutral `openCenter`, `presentCenterBanner`, and `closeCenter` orchestration API.

Only `CenterSurfaceHost`, `CenterCompactWindow`, and `CenterOverlayWindow` may use Center native
windows, layer-shell roles, input regions, or keyboard focus. A presentation receives only
`snapshot`, `viewState`, and an immutable profile. Pill, Notch, Connected, and Classic renderers may
own geometry and animation, but may not import business services, route screens, execute actions,
or mutate controller state except by emitting a neutral intent.

## Adapting third-party code

Do not copy a repository's shell root, theme engine or god service. Extract the protocol or model
logic, rename it to Titonium vocabulary, remove unused behavior and wrap it in this contract.
Preserve copyright/license notices and add provenance to the capability's documentation or source
header. Tests must use fakes and must never launch a real app, execute a power action or overwrite
clipboard contents.
