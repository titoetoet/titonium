# Architecture

Titonium is deliberately a composition of vertical slices around a small stable skeleton.

```text
shell.qml
└── Titonium/App.qml
    ├── Orchestration/ServiceBootstrap + SurfaceRouter + BluetoothAudioBridge
    ├── Ipc/CoreIpc + CenterIpc + DeviceIpc + AgentApprovalIpc
    ├── Bar/BarHost.qml ── Variants(Quickshell.screens)
    │   ├── BarSurface → Start / Center / End islands
    │   │   ├── Start → Workspaces + ActiveWindowPill
    │   │   └── CenterGroup → CenterIsland + independent Bar pin
    │   └── CenterNotchWindow → Loader(active for owner screen only)
    │       └── CenterNotch → Rail + lazy StackView viewport
    ├── Dock/DockHost.qml ── Variants(ScreenPolicy.screens)
    ├── Notifications/ToastHost.qml ── Variants(ScreenPolicy.screens)
    │   └── ToastWindow → Loader(active only while toast IDs exist)
    ├── Settings/SettingsHost.qml ── Variants(ScreenPolicy.screens)
    │   └── SettingsWindow → Loader(active for DP-1 owner only)
    └── Core/Surfaces/OverlayHost.qml ── Variants(ScreenPolicy.screens)
        └── Loader(active only for SurfaceManager owner)
            └── Overlays/Spotlight

Views ──read──> Services ──adapt──> Quickshell / Hyprland / DBus
  │                  │
  └── Theme/Shared   └── Core Runtime (preferences, i18n, logging)
```

`App.qml` is intentionally a thin composition root. `ServiceBootstrap` preserves root-level
activation order, `SurfaceRouter` owns cross-surface mutual exclusion and screen resolution, and
`BluetoothAudioBridge` is the explicit semantic bridge between otherwise independent services.
IPC adapters retain public target names and response formats but own no persistent or native state.

## Agent approval bridge

`AgentApprovalService` owns one local Unix socket and a bounded, sequential approval queue.
Antigravity reaches that contract through its documented `PreToolUse` command hook. ChatGPT
Desktop reaches the same contract through a local Codex JSON-RPC proxy selected by
`CODEX_CLI_PATH`; the proxy forwards all non-approval traffic byte-for-byte and translates only
Codex command, file-change and permission approval requests. The view receives normalized value
descriptors and emits only `allow once`, `allow for session` or `deny` intents.

The two adapters retain different failure policies. Antigravity falls back to its native review
with an `ask` decision when Titonium is unavailable. An intercepted ChatGPT request fails closed
with `decline`, because the Desktop client never receives that held JSON-RPC request. Neither
adapter calls the OpenAI API or persists approval payloads.

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

The true-center `CenterGroup` remains positioned from the full screen width and contains the
attention `CenterIsland` followed by the independently targetable TopBar pin. The Active Window
pill sits directly after the five-slot Workspace group, sizes naturally up to
520 logical pixels, and projects the active descriptor as app icon plus an optional
`Application · app-provided tray context`. For a conservatively matched tray item, a `Running`
DBusMenu entry takes precedence over tooltip metadata and activating the pill opens that item's
platform menu; without a menu it retains the centered four-corner popup fallback. It never uses
compositor window titles, omits the separator when no matching context exists and falls back to
Titonium. The full Bar input mask is composed from the three island hitboxes, preserving
click-through elsewhere. The End island orders native Wi-Fi, Bluetooth, Audio and Notification
Bell controls before the protected Input Method. Clock remains temporarily disabled.

### Selectable Top Bar styles

`modules.bar.style` is a transactional preference with two values: `connected` and `classic`.
The shipped default is `connected`; the v7 preference projection also supplies `connected` for
missing, malformed, or unknown values, so existing runtime settings migrate without a separate
write. The Bar page patches this path inside the normal Settings preview: Cancel immediately
restores the committed effective style, while Apply persists the selected style only after the
atomic settings write succeeds.

`BarSurface` is the exclusive composition boundary. It activates exactly one style Loader at a
time, keyed by `RightPillCoordinator.presentedStyle`. Before publishing a different style, the
coordinator closes the old style's transient owner and finalizes its exit state; stale close
callbacks are guarded by the retained owner/generation snapshot and cannot clear a newer owner.
`CenterPillWindow` and `EdgeMenuWindow` are active only for Connected, while `OverlayHost` loads
only non-Connected descriptors. Consequently an OverlayHost never loads a Connected popup and
the two style trees cannot expose overlapping Bar hitboxes.

Connected keeps the continuous left/right pill layout and makes `EdgeMenuWindow` the sole owner
of connected Wi-Fi, Bluetooth, Audio, Active Window, and Input Method popups. The frozen
descriptor selects the correct control anchor for the expanding right-pill branch until its exit
animation completes. Classic restores detached `Shared.Surface` trees: launcher, Workspaces and
Active Window on the left; a centered Dynamic Island and notification bell; and separate pin,
connectivity, and status surfaces on the right. Classic Network, Bluetooth, Audio, and System Tray
popups use their existing OverlayHost surfaces rather than the Connected Edge window.

## State and presentation

Singleton services expose reactive state once for all consumers:

- `ApplicationService`: DesktopEntries catalog, visibility and launch boundary.
- `ClipboardService`: Quickshell clipboard events and atomic history persistence.
- `HyprlandService`: focused monitor and workspace state/actions.
- `SystemTrayService`: the exported value/intent facade for tray consumers. Its private
  `internal/SystemTrayBackend` is the sole native SystemTray owner; the facade projects immutable
  metadata, conservatively matches app-owned context for StartIsland, exposes narrow app-selection
  and native-menu display intents, and routes Fcitx descriptors away from app context.
- `InputMethodService`: event-driven Fcitx state derived from `SystemTrayService`; its dedicated
  Bar icon and language semantics remain unchanged.

The SystemTray menu pattern was adapted from Caelestia Shell revision
`1b7052d108677a7ca0d3d3365511bfe8281a6868` (GPL-3.0), specifically
`modules/bar/popouts/TrayMenu.qml` and `modules/bar/popouts/Content.qml`. Titonium retains only the
`QsMenuOpener`/DBusMenu idea behind its own service contract and uses Quickshell's platform menu
display instead of copying Caelestia's view or theme system.
- `AudioService`: the sole PipeWire owner. Its `PwObjectTracker` observes audio-capable nodes and
  exposes normalized output, input, selectable output-device and playback-stream view data; Bar
  and overlay code never imports PipeWire or writes raw node audio fields. Output selection
  re-resolves the requested descriptor ID inside the service before assigning PipeWire's preferred
  default sink.
- `NotificationService`: the sole `NotificationServer` owner. It turns native objects into frozen,
  newest-first value descriptors and exposes bounded history, toast IDs and session-only unread
  state. Native objects never escape the service.
- `SystemMonitorService`: an on-demand singleton retained for a standalone System Monitoring
  window. It is intentionally detached from Center and remains inactive until that window owns
  its lifecycle. When active, hot CPU/RAM/GPU metrics sample once per second while the process
  ranking refreshes every two seconds. The CPU utilization chart uses a software-rendered Shape path,
  a fixed zero-to-100-percent scale and a bounded 60-second history. CPU clock is the current
  average across all logical CPUs reported by `/proc/cpuinfo`, rather than one volatile cpufreq
  policy. No continuous metric animation runs between samples, allowing the scene graph to sleep.
  It reads CPU model and counters from `/proc`, memory capacity from `/proc/meminfo`, and AMD GPU
  utilization, VRAM, temperature and active clock from discovered sysfs files. A bounded one-shot
  `lspci -mm` process supplies the human GPU model because the selected DRM sysfs group exposes no
  stable human-readable product name; failure leaves the name unavailable. Process rows aggregate
  matching executable names before CPU/RSS ranking and expose no action or status mutation.

QML views draw, animate and emit intent. They do not spawn commands, store files or duplicate
system listeners. Pure JavaScript helpers contain searchable/testable domain rules.

## Center attention and Daily Focus

`CenterAttentionService` is the sole priority-arbitration owner. Publishers submit semantic
`source`/`kind` events; `CenterAttentionRules.js` assigns the allowlisted priority and lifetime,
drops stale lower-priority ephemeral events, retains only bounded actionable pending events and
uses a generation token to make its one-shot expiry timer safe against preemption. Passive status
indicators remain a separate frozen service projection and never replace the primary text or its
matching icon.

`CenterActivityService` owns ongoing Timer, Job and playing-Media presentations. The first active
descriptor replaces Daily Focus immediately. Up to three activities rotate every eight seconds in
derived rank order (`Timer → Important Job → Normal Job → Media`) without inserting a Focus slot;
Daily Focus returns only when the activity registry is empty. Attention pauses the current slot and
restores its full dwell time. `CenterIsland` renders exactly one icon from the presentation that
currently owns its text, with `center_focus_strong` as the Daily Focus fallback.

`CenterFocusStore` owns `daily-focus.md` and `focus-prompts.txt` beneath
`Quickshell.dataPath("center/")`. It watches both files, checks the explicit file mtime only at
startup or a file event, and uses one non-repeating midnight timer to invalidate the local-day
selection. `CenterFocusRules.js` chooses the first same-day non-heading Markdown line or a
date-stable prompt fallback. Startup is read-only. The service creates the directory/file and
invokes `xdg-open` only after explicit `openScratchpad()` intent from the view. Overview may also
submit an explicit `saveToday(text)` intent; the service normalizes it to one line and performs the
atomic file write, while the card owns only the transient inline-editing state.

`CenterIsland` consumes only immutable Attention/Activity presentations and focus text. Its primary
click always requests the scratchpad action, including while a transient event is visible. It owns
no process, file watcher, timer or system listener. `ActiveWindowPill` remains a separate Start
island concern and continues to open Center Notch.

The `center` IPC target exposes only `state()` and `focusState()` snapshots. It intentionally has
no publish, acknowledgement, timer/job mutation or scratchpad-launch endpoint.

`MprisService` is the only Titonium file allowed to import `Quickshell.Services.Mpris`. It projects
native players into frozen value facts, ranks playing before paused players and resolves ties by
meaningful-change time then stable D-Bus identity. The Overview consumes title, artist, artwork and
capability facts; narrow play/pause, previous, next and raise intents re-resolve the selected native
player inside the service. `MprisRules.js` establishes discovery as a silent baseline, suppresses
unchanged normalized signatures and derives only `track_changed`, `paused` and `resumed` semantic
events. Center owns their priorities and TTLs. Active playback also contributes an ongoing Media
activity; playback disappearance, pause or stop removes it without publishing a new stop takeover.
The Bar never imports native MPRIS state.

The `mpris` IPC target remains read-only and exposes only `state()`. Playback controls are local
Overview intents and are not available to remote IPC callers.

## Today Overview weather

`WeatherService` is an on-demand singleton acquired only by the lazy Overview page. It requests a
compact current-condition response from wttr.in, keeps the last successful immutable snapshot and
refreshes at a quiet thirty-minute cadence only while a consumer is visible. `WeatherRules.js`
normalizes provider codes into Titonium-owned `clear`, `clouds`, `rain`, `fog`, `snow` and
`thunderstorm` semantics. The view owns no process, network request or polling timer.

The condition-driven weather scene and MPRIS capability routing were studied from Ambxst revision
`65b7940cc325a425ddc443281b709db9bb7f3c6b` (AGPL-3.0), specifically
`modules/services/WeatherService.qml`, `modules/widgets/dashboard/widgets/WeatherWidget.qml` and
`modules/services/MprisController.qml`. Titonium retains only those interaction ideas behind its
own service contracts and does not copy Ambxst's backend, configuration, theme or animation tree.

`CenterTimerService` owns session-only named countdowns as absolute deadlines.
`CenterTimerRules.js` selects the five-minute, one-minute and completion milestones, while one
non-repeating QML timer wakes only for the nearest pending milestone across all countdowns.
Active timers contribute a passive indicator; milestones publish semantic events into the shared
Center arbiter. The dedicated `timer` IPC target exposes `start`, `cancel`, `acknowledge` and
`state` without exposing raw priority or TTL.

`CenterJobService` is an explicit session-only registry for builds, downloads, renders and other
external work. It never scans processes, terminals or download directories. Callers drive the
`start`, `progress`, `complete`, `fail`, `requireAction` and `clear` lifecycle through the
`job` IPC target. Progress updates only the frozen registry; semantic lifecycle events and the
passive jobs indicator flow through `CenterAttentionService`, which remains the sole priority and
TTL owner.

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

The expanded Center Notch owns the Dashboard plus a direct hidden Notification-history route. It
has no rail, general page navigation, Settings action or System Monitoring lifecycle. Other legacy
page requests normalize to Dashboard for a stable IPC boundary; System Monitor remains a detached
service/diagnostic seam until it receives a standalone host.

## Protected feature flow

IPC in `App.qml` resolves a screen and sends a descriptor to `SurfaceManager`. `OverlayHost`
loads `SpotlightSurface`, binds the current descriptor, and releases it on close. Spotlight reads
Applications and Clipboard services and publishes query/scope state back through the descriptor.

The dependency direction is `App/View → Core + Services + Shared + Theme`. Reverse imports and
feature-to-feature imports are architecture violations.

## Settings ownership and transactions

`SettingsCoordinator` owns the standalone Settings lifecycle and requested page; `SettingsHost`
applies the same DP-1-only `ScreenPolicy` as the Bar, Dock and overlays. The 980×700 presentation
tree is created only while Settings is open. Opening Settings closes Center Notch and transient
overlays; opening Spotlight or Center Notch cancels the Settings preview before closing it.

`Preferences` is the sole `settings.json` owner. Views emit typed paths through `patch()` and read
only `effectiveState`. `beginPreview()` copies committed state, `cancel()` restores it across all
surfaces, and `apply()` promotes the preview only after the atomic `FileView` save succeeds. The
Settings IPC is deliberately lifecycle-only: `open`, `page`, `cancel` and `state`; it cannot patch,
restore or apply preferences remotely.

Center's primary click opens the Dashboard; the Notification controls may request the hidden
history route directly. Titonium Settings is exposed as a
desktop entry in the application launcher and opens the standalone Settings surface through its
lifecycle-only IPC. Daily Focus remains an explicit Dashboard action, and the Topbar Pin is an
independent Bar control rather than a Center action.

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
`close()` and `state()`. Every page argument normalizes to Dashboard. The acceptance test verifies
that invariant, mutual exclusion with Spotlight, clean runtime logs, repository isolation and
unchanged Hyprland configuration hashes.
