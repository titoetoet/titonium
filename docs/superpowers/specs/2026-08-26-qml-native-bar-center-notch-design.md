# Titonium QML-Native Bar and Center Notch

**Date:** 2026-08-26
**Status:** Approved

## Purpose

Build the next Titonium shell slice on the contracted skeleton without reintroducing the previous
all-at-once architecture. The slice establishes a three-island MenuBar, an Ambxst-informed center
notch, and safe mock Tools and Session pages. Later slices add native Quickshell Audio, Bluetooth
and Network behavior behind Titonium-owned services.

Spotlight, Input Method, their keybindings and the existing dynamic screen/overlay lifecycle remain
protected. This project does not redesign those features.

## Chosen approach

Use **QML-native vertical slices**. Each real capability is completed as a service contract, a view,
focused tests and live acceptance before the next capability begins. The first slice contains only
Bar geometry and the Center Notch; Audio, Bluetooth and Network each receive a separate plan after
the preceding slice is visually accepted.

Rejected approaches:

- Building every Bar module with mock data before connecting any real service would postpone the
  discovery of service/view contract errors.
- Copying a reference shell and removing its backend later would retain its global state, theme,
  runtime dependencies and licensing constraints.
- Creating a generic plugin framework before real modules exist would add abstractions without a
  tested consumer.

## Technology and dependency policy

- Runtime implementation is QML, QtQuick and repository-local JavaScript helpers.
- UI does not instantiate `Process`, `FileView`, persistence adapters or raw platform commands.
- No Go, Python, shell helper, external daemon or copied script is added to the runtime.
- Native Quickshell APIs are the preferred platform boundary: `Quickshell.Networking`,
  `Quickshell.Bluetooth` and `Quickshell.Services.Pipewire`.
- A platform action unavailable through the agreed native boundary is deferred instead of being
  simulated with polling or an external helper.
- No blur, shader, `MultiEffect`, infinite animation or always-loaded heavy page is introduced.
- Reduced motion resolves all nonessential transition durations to zero.

Repository-local JavaScript remains suitable for pure ordering, filtering and state-transition
rules. It must not execute commands or perform persistence.

## Protected baseline

The work must preserve:

- Spotlight Applications, Clipboard and mock System scopes;
- the `Super + Space` and `Super + V` bindings and their existing IPC targets;
- application visibility, search, calculator and keyboard behavior in Spotlight;
- the event-driven Fcitx Input Method service and Bar widget;
- one Bar and one lightweight overlay host per entry in `Quickshell.screens`;
- focused-screen fallback, outside-click and lazy overlay destruction;
- runtime data outside Git and the existing Neutral Utility fallback;
- current protected, static and foreground smoke gates.

Workspaces and Clock remain replaceable convenience widgets. Their presence is retained during the
first Bar slice, but their current presentation is not a protected interface.

## Reference boundary

The Center Notch studies `https://github.com/Axenide/Ambxst` at inspected revision `65b7940`:

- `modules/notch/Notch.qml` for top-edge silhouette, compact/expanded sizing and view transitions;
- `modules/notch/NotchContent.qml` for per-screen placement, hitbox and reveal lifecycle;
- `modules/widgets/dashboard/Dashboard.qml` for the vertical rail, moving selection highlight,
  separator and lazy page area;
- `modules/widgets/dashboard/DashboardView.qml` for dashboard proportions and focus containment.

The implementation reproduces layout behavior rather than copying source. Ambxst is AGPL-3.0 and
its global state, theme, backend, mask effects, persistent loaders and large dashboard pages are not
imported. Caelestia remains a secondary reference for load-before-enter and unload-after-exit
sequencing. DMS remains a later reference for Settings navigation and consumer-driven monitoring;
neither component graph is imported into this slice.

Add a provenance document when implementation begins. It must record upstream repository URL,
license, inspected revision, exact files, learned behavior and local deviations.

## MenuBar geometry

`BarHost` continues to use `Variants` over `Quickshell.screens`. Each output owns one 40 logical
pixel `PanelWindow` with an exclusive zone of 40. No output name, scale or resolution is hardcoded.

The presentation is divided into three independently measured islands:

```text
Bar
├── StartIsland
│   ├── Arch/Menu entry
│   ├── Workspaces
│   └── Active Window — later researched slice
├── CenterIsland
│   └── CenterNotch
└── EndIsland
    ├── ConnectivityPill
    │   ├── Network
    │   ├── Bluetooth
    │   └── Audio
    └── StatusPill
        ├── Input Method
        ├── System Tray — later slice
        ├── Notifications — later slice
        └── Clock
```

The Center Island is anchored to the physical horizontal center of its `BarSurface`; it is not a
middle child in a spacing layout. Changing either outer island must not move it. Start and End are
allowed to grow toward the center but must expose a collision state if an unusually narrow screen
cannot fit all three islands. The first implementation resolves collision by hiding unimplemented
optional entries before protected Input Method or the Center Notch.

Transparent Bar space is click-through. Interactive regions consist only of the measured island
hitboxes. The first slice does not port Ambxst's GPU mask; it uses ordinary QML geometry and a
composed `Region` mask.

## Center Notch

### Compact state

The closed Center Notch is a small solid pill attached to the top edge. It is always centered on the
screen and acts as the only trigger for its expanded dashboard. Its initial content is a lightweight
Titonium status label/icon that has no timer, service subscription or system action. Final compact
content is intentionally deferred until real modules provide useful state.

### Expanded state

Opening the notch expands the same visual object horizontally and downward from the top edge. It is
not presented as a detached popup with a gap below the Bar. The expanded layout follows the Ambxst
dashboard grammar:

```text
┌──────────────────────────────────────────────────────────┐
│ ┌────────┐                                               │
│ │Overview│                                               │
│ │ Tools  │          current lazy page                    │
│ │Session │                                               │
│ │        │                                               │
│ │Settings│                                               │
│ └────────┘                                               │
└──────────────────────────────────────────────────────────┘
```

- The icon rail is 48 logical pixels wide.
- Primary tabs are stacked at the top with 8 logical pixels between entries.
- Settings is a fixed bottom rail entry and remains unavailable in Slice 1.
- A one-token vertical separator divides the rail from the clipped page viewport.
- The selected rail highlight animates between entries without creating a second highlight item.
- The page viewport occupies all remaining width and height.
- Only the selected page is active after an exit transition completes.
- Escape, clicking the active compact trigger and clicking outside close the notch.
- Moving focus to another monitor closes the notch instead of transferring an expanded surface.

Slice 1 uses the existing solid Neutral Utility surface. It does not reproduce Ambxst's inward GPU
corner mask. The top edge remains visually connected through zero top radius and rounded lower
corners; more complex inward corners are a later optional visual enhancement.

### Navigation and motion

The rail supports pointer click, wheel navigation, `Up`/`Down`, `Home`/`End`, `Enter` and Escape.
`Up` and `Down` cycle through Overview, Tools and Session; `Home` selects Overview and `End`
selects Session. Wheel input stops at the first and last primary tab instead of wrapping. Normal Tab
focus can reach the unavailable bottom Settings entry. Focus remains inside the expanded notch while
it is open.

Page changes use opacity plus a small directional vertical translation. Width and height use one
bounded easing transition. The outgoing page is retained until its exit finishes, then unloaded;
the incoming page is loaded before it enters. No transition blur is used. Repeated tab input while a
transition is active resolves to the latest requested tab without building an unbounded queue.

## Slice 1 page content

### Overview

Overview explains that the Center Notch is the Titonium system hub and exposes no live system
control. It provides enough varied content to verify grid sizing, text wrapping, focus order and
responsive behavior without polling or external data.

### Tools mock

The Tools page contains a bounded responsive action grid:

- Screenshot;
- Screen Recording;
- Color Picker;
- OCR;
- QR/Barcode Scan;
- Camera Mirror;
- Night Mode;
- More Tools.

Each action has the data contract:

```text
id · icon · labelKey · available · dangerous · intent
```

All Slice 1 actions use `available: false`. Pointer or keyboard activation produces inline feedback
inside the page, such as “Screen recording is not available yet.” It does not show a notification,
spawn a process, create a file or open another surface. Mock actions exist to validate layout and
interaction only; each real tool later requires its own capability slice.

### Session mock

The Session page presents:

- Lock;
- Logout;
- Sleep;
- Hibernate;
- Restart;
- Shutdown.

All are non-executing Slice 1 mocks and use the same inline feedback behavior as Tools. No generic
Power action duplicates Shutdown. Later implementation must detect whether Hibernate is supported
before showing it and must route every available action through a separate centered confirmation
surface. Closing the Center Notch precedes opening that confirmation surface. Double activation is
blocked until the action resolves.

The later `SessionService` may own direct system command adapters only after an explicit design
decision. This spec does not authorize `systemctl`, `loginctl`, Hyprland commands or external
scripts.

### Settings entry

The bottom Settings entry is visually present but unavailable in Slice 1. Activating it shows inline
feedback. Settings is not reconstructed until several real modules expose stable preferences; it
will receive a separate design based on the useful navigation and lazy-loading patterns in DMS.

## Connectivity and status groups

Network, Bluetooth and Audio are not Center Notch tabs. They belong to a compact
`ConnectivityPill` in the End Island. Slice 1 may render noninteractive diagnostic icons to validate
the final Bar geometry, but it must not add fake connected, enabled or volume state.

Real integration order after Center Notch acceptance is:

1. Audio through `Quickshell.Services.Pipewire`;
2. Bluetooth through `Quickshell.Bluetooth`;
3. Network through `Quickshell.Networking`.

Each capability owns a small service under `Titonium/Services/<Capability>` and a popup page owned
by that capability. Status popups are anchored to their End Island buttons and are separate from
the Center Notch. Switching between Connectivity buttons may reuse one lightweight status popup
host, but it must not route content through the Center Notch.

System Tray, notifications, MPRIS, advanced audio mixing and monitoring are later slices. Complete
CPU/GPU/process monitoring is explicitly deferred because this QML-native milestone does not add a
native helper, external daemon or polling script.

## Ownership and target source shape

Slice 1 introduces only files with live behavior:

```text
Titonium/Bar/
├── Bar.qml
├── islands/
│   ├── StartIsland.qml
│   ├── CenterIsland.qml
│   ├── EndIsland.qml
│   ├── ConnectivityPill.qml
│   └── StatusPill.qml
└── notch/
    ├── CenterNotch.qml
    ├── CenterNotchRail.qml
    ├── CenterNotchViewport.qml
    ├── OverviewPage.qml
    ├── ToolsPage.qml
    ├── SessionPage.qml
    └── CenterActionCatalog.js
```

The notch is owned by `Bar` because it is attached to the Bar's top edge and has one instance per
screen. It does not use the full-screen Spotlight `OverlayHost`. If Wayland input or clipping
constraints prove that the expanded notch cannot safely remain in the 40-pixel Bar window, the
implementation may add one per-screen transparent `PanelWindow` dedicated to the notch while
preserving the appearance of one connected object. That decision requires a focused geometry spike
before changing the source map.

No `Services/Audio`, `Services/Bluetooth`, `Services/Network`, Settings or tool service directory is
created during Slice 1.

## State and interfaces

Center Notch state is local to each screen delegate:

```text
expanded: bool
currentPage: "overview" | "tools" | "session"
pendingPage: string
transitioning: bool
feedbackKey: string
```

Opening a notch on one monitor closes any notch already open on another monitor through a small
coordinator owned by `BarHost`. This coordinator contains only ownership and screen identity; it
does not become a general shell state object. Spotlight opening also closes the Center Notch so two
exclusive interactive surfaces cannot compete for focus.

Pages consume immutable action descriptors and emit `actionRequested(intent)`. They do not inspect
the operating system or mutate global settings.

## Error and fallback behavior

- Missing icons resolve through the existing `Shared.Icon` fallback.
- An unknown page ID selects Overview and logs one warning.
- Failed page construction leaves the notch open on Overview rather than displaying an empty
  surface.
- A disconnected screen destroys its local notch and clears coordinator ownership.
- A screen too narrow for the nominal expanded width clamps the notch to screen padding and changes
  the action grid column count.
- Reduced motion never delays unloading by an animation duration greater than zero.
- Mock action activation always remains local and side-effect free.

## Testing and acceptance

### Static gates

- Every new QML directory has an explicit `qmldir`.
- `qmllint` has no error; any Quickshell-only warning is narrowly allowlisted.
- UI contains no `Process`, `FileView`, `execDetached`, raw command or persistence object.
- No Ambxst/Caelestia/DMS import path or copied theme/global singleton is present.
- Provenance records the exact upstream sources and local deviations.

### Domain and component gates

- Center calculation remains unchanged when Start or End width changes.
- Arrow navigation wraps across the three primary pages, wheel navigation clamps, and Home/End
  select Overview/Session respectively.
- Latest requested page wins during an active transition.
- Unknown page IDs fall back to Overview.
- Action catalog contains unique IDs and valid label keys.
- Every mock action is unavailable and has no executable callback.
- Narrow-screen layout reduces grid columns without clipping labels or rail controls.

### Live acceptance

- One 40-pixel Bar exists on every connected output with the correct exclusive zone.
- The compact notch is centered independently of unequal outer islands.
- Opening expands from the top edge; it does not appear as a detached popup.
- Rail pointer, wheel and keyboard navigation select the correct page.
- Page switching loads before enter and unloads after exit.
- Escape, active-trigger click, outside-click, monitor focus change and monitor removal close safely.
- Tools, Session and Settings mocks provide inline feedback and cause no system change.
- Spotlight opening closes an expanded Center Notch; protected Spotlight and Input acceptance remain
  green.
- Closed idle state has no new polling timer, infinite animation, hidden heavy Loader tree or
  `MultiEffect`.
- Runtime tests do not modify the repository or either Hyprland configuration file.

## Delivery sequence

1. Implement and visually accept Bar island geometry with a compact non-expanding Center Notch.
2. Add expanded notch window/geometry, input mask and close lifecycle.
3. Add the Ambxst-informed rail, separator, lazy viewport and transition state machine.
4. Add Overview, Tools mock, Session mock and unavailable Settings feedback.
5. Complete static, protected, foreground and multi-monitor acceptance, then obtain visual approval.
6. Create a separate Audio native spec and plan; Bluetooth and Network follow in their own reviewed
   slices.

No later slice begins automatically when Slice 1 passes. The user reviews the live Bar and Center
Notch before the next capability is planned.

## Out of scope

- executing Screenshot, recording, OCR, QR, Mirror or session actions;
- confirmation dialogs or a `SessionService`;
- real Network, Bluetooth or Audio state;
- Settings Center, Control Center, System Tray, MPRIS or notification implementation;
- system monitoring, process management or an external backend;
- glass, native corner hooks, shader masks or compositor configuration changes;
- changing Spotlight, Input Method or Hyprland keybindings.
