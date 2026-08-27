# Architecture

Titonium is deliberately a composition of vertical slices around a small stable skeleton.

```text
shell.qml
└── Titonium/App.qml
    ├── Bar/BarHost.qml ── Variants(Quickshell.screens)
    │   ├── BarSurface → Start / Center / End islands
    │   └── CenterNotchWindow → Loader(active for owner screen only)
    │       └── CenterNotch → Rail + lazy StackView viewport
    └── Core/Surfaces/OverlayHost.qml ── Variants(Quickshell.screens)
        └── Loader(active only for SurfaceManager owner)
            └── Overlays/Spotlight

Views ──read──> Services ──adapt──> Quickshell / Hyprland / DBus
  │                  │
  └── Theme/Shared   └── Core Runtime (preferences, i18n, logging)
```

## Screen and window lifecycle

`ScreenPolicy` filters Quickshell's reactive output list to the currently assigned Titonium output,
`DP-1`. `BarHost`, `OverlayHost` and `AudioOsdHost` all use that same eligible-screen model, so
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

The compact Center island is positioned from the full screen width rather than between the Start
and End islands. The full Bar input mask is composed from the three island hitboxes, preserving
click-through elsewhere. The End island currently shows diagnostic-only Wi-Fi and Bluetooth glyphs
beside the protected Input Method, Audio and Clock. Audio is backed by `AudioService`; only the
Wi-Fi and Bluetooth glyphs are placeholders rather than service state.

## State and presentation

Singleton services expose reactive state once for all consumers:

- `ApplicationService`: DesktopEntries catalog, visibility and launch boundary.
- `ClipboardService`: Quickshell clipboard events and atomic history persistence.
- `HyprlandService`: focused monitor and workspace state/actions.
- `InputMethodService`: event-driven Fcitx SystemTray state.
- `AudioService`: the sole PipeWire owner. Its `PwObjectTracker` observes audio-capable nodes and
  exposes normalized output, input and playback-stream view data; Bar and overlay code never
  imports PipeWire or writes raw node audio fields.

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

## Center Notch acceptance seam

The `centerNotch` IPC target exists for deterministic lifecycle tests: `open(page)`, `page(page)`,
`close()` and `state()`. It cannot invoke a mock tile. `scripts/center_notch_acceptance.sh` verifies
Overview/Tools/Session navigation, mutual exclusion with Spotlight, clean runtime logs, repository
isolation and unchanged Hyprland configuration hashes.
