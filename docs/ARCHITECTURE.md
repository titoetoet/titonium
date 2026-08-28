# Architecture

Titonium is deliberately a composition of vertical slices around a small stable skeleton.

```text
shell.qml
└── Titonium/App.qml
    ├── Bar/BarHost.qml ── Variants(Quickshell.screens)
    │   ├── BarSurface → Start / Center / End islands
    │   └── CenterNotchWindow → Loader(active for owner screen only)
    │       └── CenterNotch → Rail + lazy StackView viewport
    ├── Dock/DockHost.qml ── Variants(ScreenPolicy.screens)
    ├── Notifications/ToastHost.qml ── Variants(ScreenPolicy.screens)
    │   └── ToastWindow → Loader(active only while toast IDs exist)
    └── Core/Surfaces/OverlayHost.qml ── Variants(ScreenPolicy.screens)
        └── Loader(active only for SurfaceManager owner)
            └── Overlays/Spotlight

Views ──read──> Services ──adapt──> Quickshell / Hyprland / DBus
  │                  │
  └── Theme/Shared   └── Core Runtime (preferences, i18n, logging)
```

## Screen and window lifecycle

`ScreenPolicy` filters Quickshell's reactive output list to the currently assigned Titonium output,
`DP-1`. `BarHost`, `DockHost`, `OverlayHost`, `AudioOsdHost` and `ToastHost` all use that same eligible-screen model, so
Titonium creates no window or exclusive zone on `DP-3`; another shell can own that output.
Disconnecting `DP-1` fails closed with no Titonium surface, and reconnecting it recreates the
delegates reactively. `ScreenRouter` resolves focused or requested outputs only inside this policy
and falls back to `DP-1`, never to another connected output.

The eligible output owns one lightweight overlay window, but its feature tree exists only when
`SurfaceManager` has a descriptor for that screen. Ineligible outputs own no Titonium window. The
manager allows one transient owner across the shell. Focused-monitor changes close Spotlight to
prevent a stranded exclusive-focus window.

The Bar owns a second, independent lightweight `CenterNotchWindow` on the eligible output. Only the screen
named by `CenterNotchCoordinator.ownerScreenName` activates its heavy Loader. Opening Spotlight
closes the notch; opening the notch closes `SurfaceManager`, so the two exclusive-focus surfaces
cannot overlap. An outside click, Escape, or focused-monitor change releases the notch window.

The TopBar pin remains positioned from the full screen width, independent of the outer islands.
The Active Window pill sits directly after the five-slot Workspace group, sizes naturally up to
520 logical pixels, and projects the active descriptor as app icon plus
`Application · window title`. It falls back to Titonium and continues to open the centered
four-corner popup 52 logical pixels below the screen edge. The full Bar input mask is composed
from the three island hitboxes, preserving click-through elsewhere. The End island orders native Wi-Fi,
Bluetooth, Audio and Notification Bell controls before the protected Input Method. Clock remains
temporarily disabled.

## State and presentation

Singleton services expose reactive state once for all consumers:

- `ApplicationService`: DesktopEntries catalog, visibility and launch boundary.
- `ClipboardService`: Quickshell clipboard events and atomic history persistence.
- `HyprlandService`: focused monitor and workspace state/actions.
- `InputMethodService`: event-driven Fcitx SystemTray state.
- `AudioService`: the sole PipeWire owner. Its `PwObjectTracker` observes audio-capable nodes and
  exposes normalized output, input, selectable output-device and playback-stream view data; Bar
  and overlay code never imports PipeWire or writes raw node audio fields. Output selection
  re-resolves the requested descriptor ID inside the service before assigning PipeWire's preferred
  default sink.
- `NotificationService`: the sole `NotificationServer` owner. It turns native objects into frozen,
  newest-first value descriptors and exposes bounded history, toast IDs and session-only unread
  state. Native objects never escape the service.

QML views draw, animate and emit intent. They do not spawn commands, store files or duplicate
system listeners. Pure JavaScript helpers contain searchable/testable domain rules.

## Audio slice boundaries

`AudioService` is the only Titonium module permitted to import `Quickshell.Services.Pipewire`.
Its normalized contract supplies readiness, availability, names, icon, volume, mute state and
playback streams to views, while narrow service methods are the only manual mutation boundary.
The Bar invokes the shared service and the popup is a lazy `SurfaceManager` descriptor rendered by
the existing `OverlayHost`; there is no independent popup Loader or audio command helper.

The OSD is separate from the popup: `AudioOsdCoordinator` owns its focused-screen, click-through
presentation and an `AudioOsdHost` creates content only for that coordinator owner. The service
captures the initial PipeWire snapshot before emitting later presentation changes, preventing a
false startup or output-change OSD. Timers only coalesce/hide OSD presentation and never poll.

`audio` IPC is intentionally read-only (`state`, popup lifecycle state and OSD state). Foreground
acceptance may open and close surfaces, but must not change volume, mute, device selection or any
other PipeWire setting. Manual visual testing is the only place to exercise those mutations, and
the tester restores the original audio level, mute state and runtime preference afterward.
The state snapshot reports the number of ready output descriptors so acceptance catches delayed
PipeWire-node binding without selecting a device.

Inside the expanded notch, the 48-pixel rail requests a page from the coordinator. A `StackView`
creates the incoming page for a bounded transition and destroys the replaced page afterward; rapid
requests retain only the latest pending page. Overview is informational. Tools and Session consume
immutable descriptors and emit translated “not available yet” feedback only. They expose no
process, callback, command or IPC execution boundary, and Settings is also a feedback-only button.

## Protected feature flow

IPC in `App.qml` resolves a screen and sends a descriptor to `SurfaceManager`. `OverlayHost`
loads `SpotlightSurface`, binds the current descriptor, and releases it on close. Spotlight reads
Applications and Clipboard services and publishes query/scope state back through the descriptor.

The dependency direction is `App/View → Core + Services + Shared + Theme`. Reverse imports and
feature-to-feature imports are architecture violations.

## Native notification boundary

Only `Titonium/Services/Notifications/NotificationService.qml` may import
`Quickshell.Services.Notifications` or instantiate `NotificationServer`. The server advertises
plain body support and session persistence only; markup, hyperlinks, images, actions and inline
reply are disabled until their UI exists. A descriptor contains only `id`, app name/icon, summary,
plain body, urgency and receive time. History is capped at 100, the active toast queue at three.

`ToastHost` follows `ScreenPolicy.screens`, so DP-3 receives no Titonium toast surface. Its heavy
stack loads only while toast IDs exist, takes no keyboard focus or exclusive zone, and masks input
to the 360px stack. Each card owns one non-repeating five-second timer. Expiry removes presentation
only; unread remains until the Bell is clicked. Notification history, unread and toast state are
session-only. Because `org.freedesktop.Notifications` is a session-global D-Bus name, only one
notification daemon can own it at a time; Titonium acceptance starts Titonium before its fixture.

## Center Notch acceptance seam

The `centerNotch` IPC target exists for deterministic lifecycle tests: `open(page)`, `page(page)`,
`close()` and `state()`. It cannot invoke a mock tile. `scripts/center_notch_acceptance.sh` verifies
Overview/Tools/Session navigation, mutual exclusion with Spotlight, clean runtime logs, repository
isolation and unchanged Hyprland configuration hashes.
