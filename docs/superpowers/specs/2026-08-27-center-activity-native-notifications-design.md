# Center Activity and Native Notification Toast Design

**Date:** 2026-08-27  
**Status:** Proposed for user review  
**Scope:** Dock Pin diagnosis, active-window Center trigger, detached Center popup geometry,
notification bell/unread state and notification toasts

## Objective

Replace the static Titonium Center label with useful active-window context, align its popup with the
existing connectivity popups, and add the first native notification slice without importing the
legacy shell architecture. The batch also closes the still-reproducible Dock Pin double-click bug
through evidence-led diagnosis rather than another pointer-handler guess.

The result remains pure QML/JavaScript. It adds no Process, detached command, Python, Go, polling,
shader, glass or `MultiEffect` dependency and changes no Hyprland source or configuration.

## Locked user behavior

### Center activity trigger

- The Center trigger shows the active application's real icon followed by
  `Application name · window title`.
- Example: `Codex · Phân tích và tái cấu trúc Titonium`.
- The fallback when no active window can be resolved is the current Titonium icon and `Titonium`.
- The trigger grows with its content from a compact minimum to at most 520 logical pixels. Text
  beyond the available width uses right elision; it never wraps or changes Bar height.
- Clicking the trigger keeps the existing Center Notch lifecycle and content.

### Center popup geometry

- The Center popup begins at `Metrics.barHeight + Metrics.barSpacing`, the same top edge used by the
  Wi-Fi, Bluetooth and Audio popups.
- It remains horizontally centered and at most 900 logical pixels wide.
- Its maximum height is recomputed from the remaining screen height after the new top gap.
- Because the popup no longer touches the Bar, all four corners are rounded.
- Outside click, Escape, pinning, Spotlight mutual exclusion and focused-monitor close behavior are
  preserved.

### End-island ordering

The visual order from left to right is:

```text
Wi-Fi → Bluetooth → Sound → Notification bell → Input Method
```

The bell is packed into the connectivity pill after Sound so it sits directly beside that group.
The protected Input Method component and service remain unchanged and follow in their existing
separate Status pill.

### Bell and unread behavior

- The bell shows a small semantic accent dot when `unreadCount > 0`.
- Clicking the bell calls only `NotificationService.markAllRead()` and removes the dot.
- Clicking the bell does not dismiss stored notifications, close visible toasts or open a panel.
- A later Notification Center will consume the same projected service state; it is explicitly not
  part of this batch.

### Toast behavior

- New or replaced notification events create or update one toast identified by notification ID.
- At most three toasts are visible, newest first.
- A toast automatically leaves the visible stack after five seconds without dismissing the native
  notification or changing unread state.
- Each toast contains the application icon, application name, summary, a plain-text body preview
  and an explicit dismiss control.
- Dismiss removes the toast, calls the native notification's dismiss boundary through the service,
  and removes that notification from the projected list.
- Toasts appear at the top-right of DP-1 below the 44-pixel Bar with the shared 8-pixel gap. They do
  not reserve screen space or request keyboard focus.
- This slice does not expose notification action buttons, inline reply, images in the body, a
  notification history panel or persistence across shell restarts.

## Architecture

```text
Quickshell NotificationServer
          │ native events / native objects (private)
          ▼
Services/Notifications/NotificationService
          ├── NotificationRules.js → immutable descriptors, ordering, unread IDs
          ├── descriptors / unreadCount / visibleToastDescriptors
          ├── markAllRead()
          └── dismiss(id)
                    │
        ┌───────────┴────────────┐
        ▼                        ▼
Bar NotificationBell       Notifications/ToastHost
inside ConnectivityPill    Variants(ScreenPolicy.screens)
                                  └── Loader(active only with toasts)
                                      └── ToastStack / ToastCard

HyprlandService.activeWindow ──► CenterIsland
ApplicationService name/icon ──► CenterIsland
CenterNotchCoordinator ─────────► existing lazy CenterNotchWindow
```

Dependency direction remains `App/View → Services/Core/Shared/Theme`. Notification views never
receive native notification objects. `NotificationService` is the sole owner of
`Quickshell.Services.Notifications` and retains native objects in a private lookup used only by
the dismiss boundary.

## Notification service contract

`NotificationService` is a singleton with the following public contract:

- `notifications: var` — immutable newest-first descriptor array, bounded to 100 session entries;
- `toastNotifications: var` — immutable newest-first descriptor array, bounded to three active
  toast IDs;
- `unreadCount: int` and `hasUnread: bool`;
- `markAllRead(): bool`;
- `dismiss(id: int): bool`;
- `expireToast(id: int): bool` — presentation expiry only, with no native dismissal.

A public descriptor contains only stable values:

```text
id, appName, appIcon, summary, body, urgency, receivedAt
```

`NotificationRules.js` owns normalization, plain-text body cleanup, ID upsert, newest-first
ordering, the 100-entry history bound, the three-toast bound and unread-ID transitions. Replacing
an existing ID updates its descriptor, moves it to the front and marks that ID unread without
duplicating it.

The server advertises only capabilities this slice actually presents: body text, a standard app
icon and persistence while Titonium owns the daemon. Markup, hyperlinks, body images, action icons
and inline reply are not advertised. No exception is silently swallowed: a failed native dismiss
is category-capped in the Logger and still leaves service state internally consistent.

## Toast lifecycle and screen policy

`ToastHost` uses `Variants` over `ScreenPolicy.screens`, so only DP-1 receives a lightweight
`PanelWindow`. The window is transparent, top/right anchored, uses `ExclusionMode.Ignore`, and has
`WlrKeyboardFocus.None`. Its input mask contains only the visible toast stack.

The toast stack itself is behind `Loader.active: NotificationService.toastNotifications.length > 0`.
Each loaded card owns one non-repeating five-second presentation timer. When the last toast expires
or is dismissed, the Loader releases the entire stack. There is no idle timer, animation loop or
render effect.

Opening Spotlight, a connectivity popup or Center Notch does not erase notifications. Toasts may
remain visible above ordinary windows, but the stack never takes exclusive focus. The bell is the
only read-state mutation in the Bar.

## Center activity data flow

`HyprlandService` adds a read-only `activeWindow` projection derived from its existing immutable
`windows` array; it does not add a native listener. `CenterIsland` combines that descriptor with
`ApplicationService.nameForAppId()` and the existing projected icon. A small pure helper normalizes
duplicate or empty titles and returns either:

```text
Application name · window title
```

or the application name alone when the title is empty or equivalent. The icon and label update
reactively on the existing `windowsChanged` signal. Center remains geometrically centered from the
full screen width even while its width changes.

## Dock Pin root-cause gate

The previous opacity change proved that visibility alone was not the full cause of the two-click
behavior. Before another production change, the implementation must capture one manual click with
temporary category-scoped diagnostics at these boundaries:

1. Pin `TapHandler` activation count;
2. `DockStore.pinnedOpen` before and immediately after `setPinnedOpen()`;
3. the state seen after atomic `FileView` save/change reload;
4. `DockWindow.exclusiveZone` and `dockRevealed` reactions.

The evidence decides the fix. A gesture-routing failure is fixed at the stable input item; a stale
file reload is fixed in the store transaction; a correct one-click state transition with delayed
visual feedback is fixed in presentation. Temporary diagnostics are removed after the causal
boundary is proven. Acceptance requires exactly one boolean transition and one persistence write
for one activation, while typing focus in the previously active application remains usable after
pin, unpin and pin again.

## Files and ownership

Expected new capability paths:

```text
Titonium/Services/Notifications/
├── NotificationRules.js
├── NotificationService.qml
└── qmldir

Titonium/Notifications/
├── ToastHost.qml
├── ToastWindow.qml
├── ToastStack.qml
├── ToastCard.qml
└── qmldir

Titonium/Bar/widgets/NotificationBell.qml
```

Expected existing integration points are `App.qml`, `CenterIsland.qml`, `CenterNotchSurface.qml`,
`CenterNotch.qml`, `ConnectivityPill.qml`, `HyprlandService.qml`, the two locale files, the relevant
architecture/testing documents and capability-specific scripts. Input Method source and both
Hyprland configuration files are protected and must remain unchanged.

## Legacy audit and provenance

The read-only legacy reference files are:

- `core/drivers/NotificationService.qml` — useful native `NotificationServer` tracking and
  distinct toast-expiry versus native-dismiss semantics;
- `windows/Notifications.qml` — useful top-right, bounded-stack and one-shot timeout behavior;
- `features/widgets/Notification.qml` — useful unread-dot behavior.

The new slice does not copy the legacy service or views. It rejects their public native-object
list, `ToplevelManager` ownership, `Quickshell.execDetached`, broad exception swallowing,
`MultiEffect`, gradients, duplicate screen enumeration and embedded Notification Center/weather/
news layout. No external repository code is adapted in this batch, so no third-party license is
introduced.

## Testing and acceptance

### Pure and static gates

- Notification rules fixtures cover malformed input, replacement IDs, newest-first ordering,
  100-entry history bound, three-toast bound, unique unread IDs, mark-all-read, expiry without
  dismissal and dismiss removal.
- Architecture checks enforce one notification native owner, private native lookup, exact public
  descriptor fields, no native import in views, ScreenPolicy ownership, lazy Loader, one-shot
  timers and the absence of Process/FileView/MultiEffect/shaders/polling in notification views.
- Bar checks enforce the order Wi-Fi/Bluetooth/Sound/Bell then Input, the unread dot contract,
  Center icon/name/title projection, 520-pixel cap and unchanged Input Method source hash.
- Center geometry fixtures enforce the shared popup top gap, available-height calculation and four
  rounded corners.

### Runtime gates

- `qmllint` has no new warning or error.
- Foreground smoke reaches `Configuration Loaded` without type/load/runtime errors.
- A focused notification acceptance process sends a controlled local DBus notification, observes
  one projected descriptor, unread dot and one DP-1 toast, then verifies five-second expiry leaves
  unread state intact. It marks all read through a narrow test IPC seam and verifies no toast or
  Titonium layer appears on DP-3.
- The acceptance cleanup dismisses its own fixture notification and leaves no runtime notification
  fixture behind. It does not launch an application, invoke a notification action or change
  clipboard/audio/network/Bluetooth/Hyprland state.
- Center acceptance verifies active-window fallback and open/close geometry without exposing a
  window mutation endpoint.
- Dock Pin receives the explicit manual one-click focus-preservation checkpoint described above.
- Full `check.sh`, smoke, protected acceptance and `hyprctl configerrors` pass; Git and both
  Hyprland configuration hashes remain unchanged by runtime tests.

## Out of scope

- Notification Center/history UI, calendar or Today page;
- notification actions, inline reply and image bodies;
- cross-restart notification persistence and do-not-disturb schedules;
- notification sounds or per-application policy;
- changes to protected Input Method behavior;
- visual glass, blur, shadow shaders or external helper processes.
