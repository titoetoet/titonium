# Center Activity and Native Notification Toast Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the static Center label with active-window context, lower the Center popup, add a native unread bell and DP-1 toast stack, and close the Dock Pin one-click bug using captured evidence.

**Architecture:** Extend the existing Hyprland projection rather than adding another window listener. Add one Notifications singleton as the sole native `NotificationServer` owner, expose immutable descriptors to a cheap Bar bell and a DP-1-only lazy toast host, and keep all popup/notification presentation free of commands and persistence.

**Tech Stack:** Qt 6 QML/JavaScript, Quickshell 0.3.1 Hyprland and Notifications modules, Wayland layer shell, Node.js/Python static fixtures, Bash live acceptance.

**Spec:** `docs/superpowers/specs/2026-08-27-center-activity-native-notifications-design.md`

## Global Constraints

- Pure QML/JavaScript shell runtime: no `Process`, `Quickshell.execDetached`, Python, Go or external helper script.
- Titonium surfaces remain DP-1-only through `ScreenPolicy.screens`; DP-3 remains available to the reference shell.
- `NotificationService` is the only source file allowed to import `Quickshell.Services.Notifications`.
- Notification views receive descriptors only; native notification objects remain in a private service lookup.
- Toasts use no glass, blur, shader, gradient, `MultiEffect`, infinite animation or repeating timer.
- Input Method source and service remain unchanged.
- Both Hyprland configuration files remain unchanged.
- Runtime acceptance starts Titonium before sending its notification fixture because the notification bus name is session-global; preflight on 2026-08-27 found no owner, with swaync only activatable.
- Every production change follows RED → GREEN, focused verification, review and a separate commit.

## File map

```text
Titonium/Services/Hyprland/HyprlandService.qml     # add read-only activeWindow projection
Titonium/Bar/islands/CenterActivityRules.js        # pure app/title label normalization
Titonium/Bar/islands/CenterIsland.qml              # adaptive icon + active task trigger
Titonium/Bar/notch/CenterNotchSurface.qml          # shared top gap and remaining-height bound
Titonium/Bar/notch/CenterNotch.qml                 # four rounded popup corners

Titonium/Services/Notifications/NotificationRules.js   # pure projection/unread/toast rules
Titonium/Services/Notifications/NotificationService.qml # sole native owner + mutation boundary
Titonium/Services/Notifications/qmldir
Titonium/Bar/widgets/NotificationBell.qml          # unread bell presentation
Titonium/Notifications/ToastHost.qml               # ScreenPolicy Variants
Titonium/Notifications/ToastWindow.qml             # lightweight DP-1 layer window + lazy Loader
Titonium/Notifications/ToastStack.qml              # bounded vertical stack
Titonium/Notifications/ToastCard.qml               # one descriptor + one-shot expiry timer
Titonium/Notifications/qmldir
Titonium/App.qml                                    # compose ToastHost and read-only notification IPC

scripts/check_center_activity.js
scripts/check_notifications_rules.js
scripts/check_notifications.py
scripts/notifications_acceptance.sh
```

---

### Task 1: Diagnose and fix exactly-once Dock Pin activation

**Files:**
- Modify: `Titonium/Dock/DockSurface.qml`
- Modify if evidence selects store boundary: `Titonium/Services/Dock/DockStore.qml`
- Modify: `scripts/check_dock_layout.js`
- Modify if store boundary changes: `scripts/check_dock_store.py`
- Modify: `docs/TESTING.md`

**Interfaces:**
- Consumes: `DockStore.pinnedOpen: bool`, `DockStore.setPinnedOpen(value: bool): bool`.
- Produces: one pointer activation causes one `pinnedOpen` transition and one atomic persistence write.

- [ ] **Step 1: Capture the failing click at each boundary**

Temporarily add category-scoped diagnostics around the existing pin activation and store call:

```qml
TapHandler {
    onTapped: {
        Logger.info("dock.pin.probe", "tap before=" + DockStore.pinnedOpen);
        pinControl.togglePinnedOpen();
        Logger.info("dock.pin.probe", "tap after=" + DockStore.pinnedOpen);
    }
}
```

and temporarily log `DockStore.apply()` before `state` assignment and from `runtimeFile.onFileChanged`.
Run one daemon, record `qs -p /home/cole/Projects/titonium ipc call dock state`, ask for exactly one
manual Pin click, then read the qs log and state again. Remove all probe logging before Step 4.

- [ ] **Step 2: Select the causal branch from literal evidence**

Use this fixed decision table:

```text
no tap log                         → pointer routing is the failing boundary
one tap, no immediate bool change → DockStore transaction is the failing boundary
one tap and bool change, then revert onFileChanged → atomic reload is the failing boundary
one tap and stable bool change     → state is correct; delayed/ambiguous presentation is the bug
```

Do not combine branches. Record the observed branch and before/after values in `docs/TESTING.md`.

- [ ] **Step 3: Write the failing regression for the observed branch**

For pointer routing, require one stable `Shared.Button` activation boundary and reject a second raw
`TapHandler` in `pinControl`. For store reversion, add a DockStore fixture where save notification
replays the just-written state and assert one normalized value. For presentation-only evidence,
require immediate selected/icon feedback bound directly to `DockStore.pinnedOpen`.

Run the focused gate and confirm it fails for the observed missing contract:

```bash
node scripts/check_dock_layout.js
python3 scripts/check_dock_store.py
```

- [ ] **Step 4: Implement only the evidence-selected fix**

Pointer branch uses the already-tested shared control:

```qml
Shared.Button {
    anchors.fill: parent
    iconName: DockStore.pinnedOpen ? "keep" : "keep_off"
    selected: DockStore.pinnedOpen
    showFocusRing: false
    backgroundRadius: width / 2
    onTriggered: DockStore.setPinnedOpen(!DockStore.pinnedOpen)
}
```

Store branch keeps one in-memory transaction authoritative until the atomic save completes; it must
not add a timer or second write. Presentation branch adds no store mutation and binds immediate
selected state to the committed singleton value.

- [ ] **Step 5: Verify and commit**

Run:

```bash
node scripts/check_dock_layout.js
python3 scripts/check_dock_store.py
./scripts/check.sh
git diff --check
```

Manually verify one click changes state once and pin/unpin/pin does not steal typing focus, then:

```bash
git add Titonium/Dock/DockSurface.qml Titonium/Services/Dock/DockStore.qml \
  scripts/check_dock_layout.js scripts/check_dock_store.py docs/TESTING.md
git commit -m "fix: make dock pin activation exactly once"
```

Only add the store files if evidence required them.

---

### Task 2: Add active-window projection and Center label rules

**Files:**
- Create: `Titonium/Bar/islands/CenterActivityRules.js`
- Create: `scripts/check_center_activity.js`
- Modify: `Titonium/Services/Hyprland/HyprlandService.qml`
- Modify: `scripts/check_windows.js`
- Modify: `scripts/check.sh`

**Interfaces:**
- Consumes: `HyprlandService.windows`, `ApplicationService.nameForAppId(appId)`.
- Produces: `HyprlandService.activeWindow: var`, `CenterActivityRules.label(appName, title): string`.

- [ ] **Step 1: Write failing pure fixtures**

Create `scripts/check_center_activity.js` with literal expectations:

```js
assert.equal(rules.label("Codex", "Phân tích Titonium"),
  "Codex · Phân tích Titonium");
assert.equal(rules.label("Firefox", "Firefox"), "Firefox");
assert.equal(rules.label("", ""), "Titonium");
assert.equal(rules.label("Kitty", "   "), "Kitty");
```

Extend `scripts/check_windows.js` to require `readonly property var activeWindow` and a fixture in
which the one descriptor with `active: true` is selected, otherwise `null`.

- [ ] **Step 2: Run RED**

```bash
node scripts/check_center_activity.js
node scripts/check_windows.js
```

Expected: missing rules file and missing active-window contract.

- [ ] **Step 3: Implement the pure label helper**

```js
.pragma library

function text(value) {
    return typeof value === "string" ? value.trim() : "";
}

function label(appName, title) {
    const app = text(appName);
    const task = text(title);
    if (!app && !task) return "Titonium";
    if (!app) return task;
    if (!task || task.toLocaleLowerCase() === app.toLocaleLowerCase()) return app;
    return app + " · " + task;
}
```

Add a read-only projection in `HyprlandService.qml` derived only from `projectedWindows`:

```qml
readonly property var activeWindow: {
    for (let index = 0; index < root.projectedWindows.length; index++)
        if (root.projectedWindows[index]?.active === true)
            return root.projectedWindows[index];
    return null;
}
```

- [ ] **Step 4: Run GREEN and integrate the gate**

```bash
node scripts/check_center_activity.js
node scripts/check_windows.js
./scripts/check.sh
```

Add `node "$root/scripts/check_center_activity.js"` beside the existing window fixtures in
`scripts/check.sh`.

- [ ] **Step 5: Commit**

```bash
git add Titonium/Bar/islands/CenterActivityRules.js \
  Titonium/Services/Hyprland/HyprlandService.qml scripts/check_center_activity.js \
  scripts/check_windows.js scripts/check.sh
git commit -m "feat: project active window for bar center"
```

---

### Task 3: Render adaptive Center activity and lower the popup

**Files:**
- Modify: `Titonium/Bar/islands/CenterIsland.qml`
- Modify: `Titonium/Bar/notch/CenterNotchSurface.qml`
- Modify: `Titonium/Bar/notch/CenterNotch.qml`
- Modify: `scripts/check_bar.py`
- Modify: `scripts/check_center_activity.js`
- Modify: `scripts/center_notch_acceptance.sh`

**Interfaces:**
- Consumes: `HyprlandService.activeWindow`, `ApplicationService.nameForAppId(string)`,
  `CenterActivityRules.label(string, string)`.
- Produces: adaptive Center trigger capped at 520 and popup top gap `Metrics.barHeight + Metrics.barSpacing`.

- [ ] **Step 1: Strengthen RED contracts**

Require these consumer-visible constraints in the Bar gate:

```text
CenterIsland maximum width = 520
one-line Text.ElideRight label
SystemIcon uses active descriptor icon with Titonium fallback
CenterNotchSurface panelTop = Metrics.barHeight + Metrics.barSpacing
CenterNotch has four 20px corner radii
```

Change the Center acceptance expected layer top from `0` to the shared 52 logical-pixel gap and run:

```bash
python3 scripts/check_bar.py
bash -n scripts/center_notch_acceptance.sh
```

Expected: Bar contract fails for static label/geometry.

- [ ] **Step 2: Implement adaptive Center content**

Replace the fixed `Shared.Button` label content with one clickable `FocusScope` containing a
rounded shared surface, `Shared.SystemIcon`, and `Shared.TextLabel`:

```qml
readonly property var activeWindow: HyprlandService.activeWindow
readonly property string appName: root.activeWindow
    ? ApplicationService.nameForAppId(root.activeWindow.appId) : ""
readonly property string activityLabel: CenterActivityRules.label(
    root.appName, root.activeWindow?.title || "")
implicitWidth: Math.min(520, Math.max(180,
    activityRow.implicitWidth + Metrics.spacingLarge * 2))
```

The label has `elide: Text.ElideRight`, `maximumLineCount: 1`, fills remaining width, and the full
FocusScope retains click/keyboard activation of `CenterNotchCoordinator.toggle(root.screen.name)`.

- [ ] **Step 3: Implement detached popup geometry**

In `CenterNotchSurface.qml`:

```qml
readonly property real panelTop: Metrics.barHeight + Metrics.barSpacing

CenterNotch {
    anchors.top: parent.top
    anchors.topMargin: root.panelTop
    height: Math.min(430, root.height - root.panelTop - Metrics.barPadding)
}
```

In `CenterNotch.qml`, replace zero top radii with 20 on all four corners.

- [ ] **Step 4: Verify and commit**

```bash
node scripts/check_center_activity.js
python3 scripts/check_bar.py
./scripts/check.sh
./scripts/center_notch_acceptance.sh
git diff --check
git add Titonium/Bar/islands/CenterIsland.qml Titonium/Bar/notch/CenterNotchSurface.qml \
  Titonium/Bar/notch/CenterNotch.qml scripts/check_bar.py \
  scripts/check_center_activity.js scripts/center_notch_acceptance.sh
git commit -m "feat: show active task in detached center popup"
```

---

### Task 4: Build pure notification projection rules

**Files:**
- Create: `Titonium/Services/Notifications/NotificationRules.js`
- Create: `scripts/check_notifications_rules.js`

**Interfaces:**
- Produces: `descriptor(raw, receivedAt)`, `upsert(list, descriptor, limit)`,
  `addToast(ids, id, limit)`, `removeId(values, id)`, `markUnread(ids, id)`, `unreadCount(ids)`.

- [ ] **Step 1: Write literal RED fixtures**

Fixtures must cover descriptor fields exactly
`id,appName,appIcon,summary,body,urgency,receivedAt`; newline cleanup to spaces; invalid ID rejection;
replacement moving to front; 100-entry history trimming; toast IDs trimming to three; unique unread IDs;
remove and clear behavior.

Example:

```js
assert.deepEqual(rules.descriptor({
  id: 7, appName: "Mail", summary: "Hello", body: "one\ntwo", urgency: 1
}, 1234), Object.freeze({
  id: 7, appName: "Mail", appIcon: "", summary: "Hello",
  body: "one two", urgency: 1, receivedAt: 1234
}));
assert.deepEqual(rules.addToast([3, 2, 1], 4, 3), [4, 3, 2]);
assert.deepEqual(rules.markUnread([7], 7), [7]);
```

- [ ] **Step 2: Run RED**

```bash
node scripts/check_notifications_rules.js
```

Expected: missing `NotificationRules.js`.

- [ ] **Step 3: Implement minimal pure rules**

Use immutable return arrays, numeric positive IDs, trimmed strings, `String(body).replace(/\s+/g,
" ").trim()`, exact descriptor keys, newest-first ID replacement and literal default limits 100/3.
Do not reference QML native objects outside `descriptor()` input normalization.

- [ ] **Step 4: Run GREEN and commit**

```bash
node scripts/check_notifications_rules.js
git diff --check
git add Titonium/Services/Notifications/NotificationRules.js scripts/check_notifications_rules.js
git commit -m "feat: add notification projection rules"
```

---

### Task 5: Add the sole native NotificationService

**Files:**
- Create: `Titonium/Services/Notifications/NotificationService.qml`
- Create: `Titonium/Services/Notifications/qmldir`
- Create: `scripts/check_notifications.py`
- Modify: `scripts/check.sh`

**Interfaces:**
- Consumes: Task 4 rules.
- Produces: `notifications`, `toastNotifications`, `unreadCount`, `hasUnread`,
  `markAllRead(): bool`, `dismiss(id: int): bool`, `expireToast(id: int): bool`.

- [ ] **Step 1: Write RED architecture tests**

The Python gate must require one singleton and one `NotificationServer`, exact public properties and
methods, `notification.tracked = true`, private lexical native lookup, capability flags matching the
spec, and category-capped Logger warnings. It must scan all other QML and reject
`import Quickshell.Services.Notifications` outside this file. Add malicious fixtures proving the
gate rejects a public native property and a public function returning a native object.

- [ ] **Step 2: Run RED**

```bash
node scripts/check_notifications_rules.js
python3 scripts/check_notifications.py
```

Expected: missing service/qmldir and contract failures.

- [ ] **Step 3: Implement the singleton**

Use service-owned state arrays plus a lexical native map:

```qml
property var projectedNotifications: Object.freeze([])
property var toastIds: Object.freeze([])
property var unreadIds: Object.freeze([])
readonly property var notifications: root.projectedNotifications
readonly property var toastNotifications: root.toastIds.map(id =>
    root.projectedNotifications.find(item => item.id === id)).filter(Boolean)
readonly property int unreadCount: root.unreadIds.length
readonly property bool hasUnread: root.unreadCount > 0
```

`onNotification(notification)` sets `tracked = true`, creates the descriptor, upserts history,
updates the native lexical map, toast IDs and unread IDs. `expireToast()` removes only the toast ID.
`dismiss()` calls the looked-up native `dismiss()` once, then removes ID from all projected arrays.
`markAllRead()` replaces unread IDs with a frozen empty array.

Configure the server with body support and standard app icon support only; set markup, hyperlinks,
body images, actions, action icons and inline reply false. Set `keepOnReload: true` and
`persistenceSupported: true`.

- [ ] **Step 4: Integrate gate, verify and commit**

```bash
node scripts/check_notifications_rules.js
python3 scripts/check_notifications.py
./scripts/check.sh
git diff --check
git add Titonium/Services/Notifications scripts/check_notifications.py scripts/check.sh
git commit -m "feat: add native notification service"
```

---

### Task 6: Add DP-1 lazy toast presentation

**Files:**
- Create: `Titonium/Notifications/ToastHost.qml`
- Create: `Titonium/Notifications/ToastWindow.qml`
- Create: `Titonium/Notifications/ToastStack.qml`
- Create: `Titonium/Notifications/ToastCard.qml`
- Create: `Titonium/Notifications/qmldir`
- Extend: `scripts/check_notifications.py`

**Interfaces:**
- Consumes: `ScreenPolicy.screens`, `NotificationService.toastNotifications`,
  `expireToast(id)`, `dismiss(id)`.
- Produces: DP-1-only nonexclusive toast layer with lazy heavy subtree.

- [ ] **Step 1: Extend RED presentation contracts**

Require `Variants { model: ScreenPolicy.screens }`, namespace `titonium-notification-toast`, top/right
anchors, `ExclusionMode.Ignore`, `WlrKeyboardFocus.None`, top margin
`Metrics.barHeight + Metrics.barSpacing`, `Loader.active` tied to a nonempty toast list, input mask
limited to stack, max width 360, newest-first Repeater, and one `Timer` with `repeat: false` and
`interval: 5000`. Reject native notification imports, Process/FileView, effects and infinite loops.

- [ ] **Step 2: Run RED**

```bash
python3 scripts/check_notifications.py
```

Expected: missing Toast artifacts and lifecycle contracts.

- [ ] **Step 3: Implement host/window/stack**

`ToastHost` enumerates only `ScreenPolicy.screens`. `ToastWindow` remains lightweight and loads:

```qml
Loader {
    id: stackLoader
    active: NotificationService.toastNotifications.length > 0
    sourceComponent: ToastStack { screenModel: window.screenModel }
}
```

The PanelWindow is transparent, top/right anchored, ignores exclusion, requests no keyboard focus,
and masks only `stackLoader.item` while active.

- [ ] **Step 4: Implement one descriptor-only ToastCard**

Use a 360px solid Shared Surface, real app icon with notification fallback, app name, one-line
summary, plain body capped at three lines, and a 28px dismiss Shared Button. A non-repeating timer
calls `NotificationService.expireToast(root.notification.id)` after 5000ms. Dismiss calls
`NotificationService.dismiss(id)`. Use only bounded `Motion.fast` entry/exit animation.

- [ ] **Step 5: Verify and commit**

```bash
python3 scripts/check_notifications.py
./scripts/check.sh
git diff --check
git add Titonium/Notifications scripts/check_notifications.py
git commit -m "feat: add lazy notification toast stack"
```

---

### Task 7: Add unread bell, ordering, i18n and App composition

**Files:**
- Create: `Titonium/Bar/widgets/NotificationBell.qml`
- Modify: `Titonium/Bar/widgets/qmldir`
- Modify: `Titonium/Bar/islands/ConnectivityPill.qml`
- Modify: `Titonium/App.qml`
- Modify: `config/i18n/en.json`
- Modify: `config/i18n/vi.json`
- Modify: `scripts/check_bar.py`
- Modify: `scripts/check_audio.py`
- Extend: `scripts/check_notifications.py`

**Interfaces:**
- Consumes: `NotificationService.hasUnread`, `unreadCount`, `markAllRead()` and `ToastHost`.
- Produces: icon order Wi-Fi/Bluetooth/Sound/Bell followed by unchanged Input Method.

- [ ] **Step 1: Write RED composition contracts**

Bar gate must require `NotificationBell` after `audioButton` inside `ConnectivityPill`, before
`StatusPill` at the EndIsland level, an accent dot visible only for `hasUnread`, and a single
`markAllRead()` trigger. Hash `InputMethod.qml` and `InputMethodService.qml` before the task and
assert the hashes remain unchanged afterward. Notification architecture gate requires one
`ToastHost` in `App.qml` and no second NotificationServer.

Strengthen the Audio ownership gate so `Services.Notifications` is allowlisted only at the shared
`ConnectivityPill` and `App` composition root, with malicious fixtures proving it remains rejected
from Audio overlays, OSD and service sources.

- [ ] **Step 2: Run RED**

```bash
python3 scripts/check_bar.py
python3 scripts/check_notifications.py
python3 scripts/check_audio.py
```

Expected: missing bell/composition/i18n contracts.

- [ ] **Step 3: Implement the bell and compose the host**

`NotificationBell.qml` is a 24×24 quiet button with icon `notifications`; its 6px accent dot is
top-right and visible only when unread. The accessible name uses the localized unread count. Its
only action is `NotificationService.markAllRead()`.

Add the bell immediately after Audio in `ConnectivityPill.iconRow`, include its width in
`fullImplicitWidth`, register it in `widgets/qmldir`, and add one `ToastHost {}` beside existing
top-level hosts in `App.qml`.

- [ ] **Step 4: Add exact locale keys**

Add parity-matched English/Vietnamese keys:

```text
notification.bell.none
notification.bell.unread
notification.toast.fallback_app
notification.toast.dismiss
```

- [ ] **Step 5: Verify and commit**

```bash
python3 scripts/check_bar.py
python3 scripts/check_notifications.py
python3 scripts/check_audio.py
./scripts/check.sh
git diff --check
git add Titonium/Bar/widgets/NotificationBell.qml Titonium/Bar/widgets/qmldir \
  Titonium/Bar/islands/ConnectivityPill.qml Titonium/App.qml \
  config/i18n/en.json config/i18n/vi.json scripts/check_bar.py scripts/check_audio.py \
  scripts/check_notifications.py
git commit -m "feat: add unread bell and compose notification toasts"
```

---

### Task 8: Add focused notification acceptance and close documentation

**Files:**
- Create: `scripts/notifications_acceptance.sh`
- Modify: `scripts/protected_acceptance.sh`
- Modify: `scripts/check.sh`
- Modify: `Titonium/App.qml`
- Modify: `docs/ARCHITECTURE.md`
- Modify: `docs/MODULE_CONTRACT.md`
- Modify: `docs/TESTING.md`
- Modify: `docs/ROADMAP.md`

**Interfaces:**
- Produces IPC target `notifications` with read-only `state()` and narrow `markRead()` only.
- Produces repeatable DP-1 toast/unread/expiry acceptance without persistent host mutation.

- [ ] **Step 1: Write the failing acceptance script**

The script must stop only Titonium, launch one foreground Titonium process, wait for
`Configuration Loaded`, then send one controlled fixture after the server owns the bus:

```bash
notify-send --app-name="Titonium Acceptance" --icon=dialog-information \
  "Titonium fixture" "toast acceptance"
```

Poll boundedly for `notifications state` containing the fixture, `unreadCount=1` and
`toastCount=1`; verify one toast layer on DP-1 and none on DP-3. After six seconds require
`toastCount=0` and `unreadCount=1`; call `notifications markRead`; require unread zero. Reject runtime
errors, repo changes and Hyprland hash changes. The foreground process cleanup removes all fixture
session state.

- [ ] **Step 2: Add RED IPC contract**

Extend the notification architecture gate to require exactly:

```qml
IpcHandler {
    target: "notifications"
    function state(): string
    function markRead(): string
}
```

Reject dismiss, action, inject, send, reply or arbitrary mutation methods.
Register `bash -n "$project_root/scripts/notifications_acceptance.sh"` in `scripts/check.sh` and
invoke the focused script once from `scripts/protected_acceptance.sh`.

- [ ] **Step 3: Implement the narrow IPC seam**

`state()` returns JSON with only descriptor count, toast count and unread count. `markRead()` calls
the same `NotificationService.markAllRead()` method as the Bell and returns the new count. It cannot
create or dismiss a notification.

- [ ] **Step 4: Run focused and full runtime gates**

```bash
bash -n scripts/notifications_acceptance.sh scripts/protected_acceptance.sh
./scripts/check.sh
./scripts/smoke.sh
./scripts/notifications_acceptance.sh
./scripts/center_notch_acceptance.sh
./scripts/protected_acceptance.sh
hyprctl configerrors
git diff --check
```

Verify DP-1 owns one 44px Bar, one 64px Dock and only transient toast layers during the fixture;
DP-3 owns no Titonium layer.

- [ ] **Step 5: Update docs and roadmap**

Document the sole native notification owner, descriptor boundary, session-only unread state, lazy
toast lifecycle, global D-Bus ownership caveat, acceptance command and the deferred Notification
Center/actions/persistence work. Mark only the notification-toast slice complete in the roadmap.

- [ ] **Step 6: Commit and restore the daemon**

```bash
git add Titonium/App.qml scripts/notifications_acceptance.sh scripts/protected_acceptance.sh \
  scripts/check.sh \
  docs/ARCHITECTURE.md docs/MODULE_CONTRACT.md docs/TESTING.md docs/ROADMAP.md
git commit -m "test: add native notification acceptance"
qs -d -p /home/cole/Projects/titonium
git status --short
```

Final manual review on DP-1 covers one-click Dock Pin, changing Center task text, 520px elision,
52px popup top gap, bell unread-dot clearing, three-toast stacking, dismiss and five-second expiry.
