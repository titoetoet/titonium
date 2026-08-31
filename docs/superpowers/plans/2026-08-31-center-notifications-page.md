# Center Notifications Page Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a Center Notch Notifications page that shows native notification history, clears viewed state on inspection, exposes an unread rail badge, and supports single or bulk dismissal.

**Architecture:** `NotificationService` remains the only native notification owner and gains a value-only bulk-dismiss boundary. `CenterNotchState` owns primary page ordering, while a lazy `NotificationsPage` consumes frozen descriptors and invokes service operations without importing native notification APIs.

**Tech Stack:** Quickshell/QML, pure JavaScript, Node.js fixtures, Python static architecture checks, Bash runtime acceptance, Titonium Shared/Theme components.

**Spec:** `docs/superpowers/specs/2026-08-31-center-notifications-system-monitoring-design.md`

## Global Constraints

- This plan ships Notifications independently; System Monitoring is added by the following plan.
- Notification history remains newest-first and bounded by the existing 100-descriptor service limit.
- Opening the page marks current notifications viewed but does not dismiss history or suppress existing Attention/toast publication.
- A notification received while the page is visible is immediately marked viewed and remains in history.
- Bulk dismissal continues after stale native objects or individual native-dismiss failures.
- Native `NotificationServer` ownership remains unique to `NotificationService.qml`.
- The page consumes value descriptors only and owns no `Process`, `FileView`, `NotificationServer` or repeating timer.
- The popup remains at its existing `900x430` maximum size; history scrolls internally.
- Use existing Shared components, Theme/Metrics tokens and English/Vietnamese i18n catalogs.
- Do not add notification actions, inline reply, filters, archive persistence or a new public mutation IPC.

---

## File structure

```text
Titonium/Services/Notifications/
├── NotificationRules.js          # immutable bulk-removal helper
└── NotificationService.qml       # native single/bulk dismissal and viewed state

Titonium/Bar/notch/
├── CenterNotchState.js           # canonical ordered primary pages
├── CenterNotchRail.qml           # Notifications button and unread badge
├── CenterNotchViewport.qml       # lazy Notifications page factory
├── NotificationsPage.qml        # page header, lifecycle and history list
├── NotificationHistoryRow.qml   # value-only notification presentation
└── qmldir                        # page component registration

scripts/
├── check_notifications_rules.js  # pure bulk-removal fixtures
├── check_notifications.py        # service/page ownership contract
├── check_center_notch.js          # navigation-order fixtures
├── notifications_acceptance.sh   # native viewed/history regression gate
└── check.sh                       # repository gate registration

config/i18n/{en,vi}.json           # page, actions, empty state and accessibility copy
docs/TESTING.md                    # manual Center page acceptance steps
```

### Task 1: Define immutable bulk-removal rules

**Files:**
- Modify: `Titonium/Services/Notifications/NotificationRules.js`
- Modify: `scripts/check_notifications_rules.js`

**Interfaces:**
- Consumes: descriptor or numeric-ID arrays already accepted by `removeId(values, id)`.
- Produces: `removeIds(values, ids) -> Object.freeze(Array)` preserving source order for IDs not removed.

- [ ] **Step 1: Add failing bulk-removal fixtures**

Append exact assertions:

```js
assert.deepEqual(
    plain(rules.removeIds([{ id: 9 }, { id: 8 }, { id: 7 }], [8, 7, 7, 0])),
    [{ id: 9 }],
);
assert.deepEqual(plain(rules.removeIds([9, 8, 7], [9, 7])), [8]);
assert.deepEqual(plain(rules.removeIds([9, 8], [])), [9, 8]);
assert.equal(Object.isFrozen(rules.removeIds([9], [9])), true);
```

- [ ] **Step 2: Run the fixture and verify it fails**

Run: `node scripts/check_notifications_rules.js`

Expected: FAIL with `rules.removeIds is not a function`.

- [ ] **Step 3: Implement the minimal frozen helper**

Add a positive-ID set and filter without mutating either input:

```js
function removeIds(values, ids) {
    const source = Array.isArray(values) ? values : [];
    const removals = new Set((Array.isArray(ids) ? ids : [])
        .map(value => typeof value === "object" ? value?.id : value)
        .filter(value => positiveId(value) > 0));
    return Object.freeze(source.filter(value => {
        const candidate = typeof value === "object" ? value?.id : value;
        return !removals.has(positiveId(candidate));
    }));
}
```

- [ ] **Step 4: Run the rule gate and commit**

Run: `node scripts/check_notifications_rules.js`

Expected: existing notification fixtures and the four new bulk-removal fixtures print PASS.

```bash
git add Titonium/Services/Notifications/NotificationRules.js scripts/check_notifications_rules.js
git commit -m "feat: add notification bulk removal rules"
```

### Task 2: Add resilient bulk dismissal to the notification service

**Files:**
- Modify: `Titonium/Services/Notifications/NotificationService.qml`
- Modify: `scripts/check_notifications.py`

**Interfaces:**
- Consumes: `NotificationService.notifications`, native tracked-notification lookup and existing `dismiss(id)`.
- Produces: `dismissAll() -> int`, returning the number of projected IDs present in its stable starting snapshot.

- [ ] **Step 1: Extend the failing architecture gate**

Require these service fragments:

```python
"function dismissAll(): int",
"const ids = root.projectedNotifications.map(item => item.id)",
"for (let index = 0; index < ids.length; index++)",
"root.dismiss(ids[index])",
```

Also assert `NotificationService.qml` still owns exactly one `NotificationServer`, has no `Process`,
`FileView` or `Timer`, and exposes no native object through a root property or return value.

- [ ] **Step 2: Run the gate and verify it fails**

Run: `python3 scripts/check_notifications.py`

Expected: FAIL with `notification service missing contract: function dismissAll(): int`.

- [ ] **Step 3: Implement snapshot-based bulk dismissal**

Add the narrow operation:

```qml
function dismissAll(): int {
    const ids = root.projectedNotifications.map(item => item.id);
    for (let index = 0; index < ids.length; index++)
        root.dismiss(ids[index]);
    return ids.length;
}
```

Do not clear arrays before the loop: `dismiss(id)` already handles native dismissal, projected
history, toast IDs, unread IDs and bounded warnings for stale objects. Snapshotting IDs prevents
model mutation from skipping later entries.

- [ ] **Step 4: Run focused gates and commit**

Run:

```bash
python3 scripts/check_notifications.py
node scripts/check_notifications_rules.js
```

Expected: both gates PASS.

```bash
git add Titonium/Services/Notifications/NotificationService.qml scripts/check_notifications.py
git commit -m "feat: dismiss notification history in bulk"
```

### Task 3: Make Notifications a canonical Center page with unread badge

**Files:**
- Modify: `Titonium/Bar/notch/CenterNotchState.js`
- Modify: `Titonium/Bar/notch/CenterNotchRail.qml`
- Modify: `scripts/check_center_notch.js`
- Modify: `config/i18n/en.json`
- Modify: `config/i18n/vi.json`

**Interfaces:**
- Produces: `primaryPages() -> frozen copied descriptor array` ordered as Overview,
  Notifications, Tools, Session for this independently shippable slice.
- Each descriptor is `{ id, icon }`; rail badge state is read directly from `NotificationService`.

- [ ] **Step 1: Write failing page-order fixtures**

Replace old three-page navigation expectations with:

```js
assert.deepEqual(plain(context.primaryPages()), [
    { id: "overview", icon: "dashboard" },
    { id: "notifications", icon: "notifications" },
    { id: "tools", icon: "construction" },
    { id: "session", icon: "power_settings_new" },
]);
assert.equal(context.normalizePage("notifications"), "notifications");
assert.equal(context.arrowPage("overview", -1), "session");
assert.equal(context.arrowPage("notifications", 1), "tools");
assert.equal(context.wheelPage("notifications", -1), "overview");
assert.equal(context.transitionPlan("tools", "notifications", false, 160).offset, -12);
```

- [ ] **Step 2: Run the state gate and verify it fails**

Run: `node scripts/check_center_notch.js`

Expected: FAIL because `primaryPages()` and the `notifications` page ID are absent.

- [ ] **Step 3: Centralize page descriptors in the state helper**

Use one internal descriptor array:

```js
var PRIMARY_PAGES = Object.freeze([
    Object.freeze({ id: "overview", icon: "dashboard" }),
    Object.freeze({ id: "notifications", icon: "notifications" }),
    Object.freeze({ id: "tools", icon: "construction" }),
    Object.freeze({ id: "session", icon: "power_settings_new" }),
]);
var pages = PRIMARY_PAGES.map(page => page.id);

function primaryPages() {
    return Object.freeze(PRIMARY_PAGES.slice());
}
```

Keep `normalizePage`, arrows, wheel and transition planning based on the derived `pages` IDs.

- [ ] **Step 4: Bind the rail to canonical descriptors and unread state**

Import `qs.Titonium.Services.Notifications`, replace the inline page model with:

```qml
readonly property var pages: CenterNotchState.primaryPages()
```

In each repeated button, overlay a small theme-accent badge only when
`modelData.id === "notifications" && NotificationService.hasUnread`. Show the bounded count string
`NotificationService.unreadCount > 99 ? "99+" : String(NotificationService.unreadCount)` and expose
`I18n.tr("center_notch.notifications.unread", { "count": NotificationService.unreadCount })` as its
accessible name. Keep the button hitbox at 48x48 and do not add a second click handler.

- [ ] **Step 5: Add exact navigation translations and run gates**

Add:

```json
"center_notch.tab.notifications": "Notifications",
"center_notch.notifications.unread": "{count} unread notifications"
```

```json
"center_notch.tab.notifications": "Thông báo",
"center_notch.notifications.unread": "{count} thông báo chưa xem"
```

Run:

```bash
node scripts/check_center_notch.js
python3 scripts/check_notifications.py
```

Expected: navigation and notification architecture gates PASS.

- [ ] **Step 6: Commit the canonical rail slice**

```bash
git add Titonium/Bar/notch/CenterNotchState.js Titonium/Bar/notch/CenterNotchRail.qml scripts/check_center_notch.js config/i18n/en.json config/i18n/vi.json
git commit -m "feat: add notifications to center navigation"
```

### Task 4: Build the lazy Notifications history page

**Files:**
- Create: `Titonium/Bar/notch/NotificationsPage.qml`
- Create: `Titonium/Bar/notch/NotificationHistoryRow.qml`
- Modify: `Titonium/Bar/notch/CenterNotchViewport.qml`
- Modify: `Titonium/Bar/notch/qmldir`
- Modify: `scripts/check_notifications.py`
- Modify: `config/i18n/en.json`
- Modify: `config/i18n/vi.json`

**Interfaces:**
- `NotificationsPage.pageId: string` is supplied by `StackView.replace`.
- `NotificationHistoryRow.notification: var` consumes only descriptor fields
  `id|appName|appIcon|summary|body|urgency|receivedAt` and emits `dismissRequested(int id)`.
- The page invokes `NotificationService.markAllRead()` and `dismissAll()`.

- [ ] **Step 1: Add failing page ownership checks**

Extend `scripts/check_notifications.py` to require both new files and these fragments:

```python
"model: NotificationService.notifications",
"NotificationService.markAllRead()",
"NotificationService.dismissAll()",
"onDismissRequested: id => NotificationService.dismiss(id)",
"Shared.SystemIcon",
"ScrollView",
"Component.onCompleted:",
```

Reject `NotificationServer`, `Quickshell.Services.Notifications`, `Process`, `FileView`, `DBus`,
`execDetached` and `Timer {` across both page files. Require exactly one viewport component factory
for `NotificationsPage { pageId: "notifications" }` and one qmldir registration per page component.

- [ ] **Step 2: Run the architecture gate and verify it fails**

Run: `python3 scripts/check_notifications.py`

Expected: FAIL listing the two missing page files.

- [ ] **Step 3: Implement the value-only notification row**

Compose one outlined `Shared.Surface` with `Shared.SystemIcon`, app name, one-line summary, optional
three-line body, relative time and a quiet dismiss `Shared.Button`. Use this operation only:

```qml
onTriggered: root.dismissRequested(notification.id)
```

Fallback app copy uses `notification.appName || I18n.tr("notification.toast.fallback_app")`.
Fallback icon uses `notification.appIcon || "notifications"`. The row never stores or returns a
native notification object. Urgency `2` uses the existing danger semantic accent, urgency `1` uses
the neutral accent and urgency `0` stays neutral; urgency does not affect list order.

- [ ] **Step 4: Implement page lifecycle, header and list**

The page handles `onDismissRequested: id => NotificationService.dismiss(id)`. The header uses title,
unread count and a `Clear all` button disabled when history is empty. Put the
history `ListView` inside a `ScrollView`; use `NotificationHistoryRow` as delegate. Mark viewed at
entry and on new unread state while the page exists:

```qml
Component.onCompleted: NotificationService.markAllRead()

Connections {
    target: NotificationService
    function onUnreadCountChanged(): void {
        if (NotificationService.unreadCount > 0)
            NotificationService.markAllRead();
    }
}
```

Render a centered empty state when `NotificationService.notifications.length === 0`. Do not clear
history when marking viewed.

- [ ] **Step 5: Register the lazy viewport component**

Add a `notificationsComponent` factory and route it before Tools:

```qml
if (normalized === "notifications")
    return notificationsComponent;

Component {
    id: notificationsComponent
    NotificationsPage { pageId: "notifications" }
}
```

Register both page files in `Titonium/Bar/notch/qmldir`.

- [ ] **Step 6: Add exact page translations**

Add English and Vietnamese keys for title, clear all, empty state, dismiss, received-time fallback
and unread header. Use these English values:

```json
"center_notch.notifications.title": "Notifications",
"center_notch.notifications.clear_all": "Clear all",
"center_notch.notifications.empty": "No notifications",
"center_notch.notifications.dismiss": "Dismiss notification",
"center_notch.notifications.unread_header": "{count} unread",
"center_notch.notifications.time_now": "Now",
"center_notch.notifications.time_minutes": "{count}m",
"center_notch.notifications.time_hours": "{count}h",
"center_notch.notifications.time_days": "{count}d"
```

Use these Vietnamese values:

```json
"center_notch.notifications.title": "Thông báo",
"center_notch.notifications.clear_all": "Xóa tất cả",
"center_notch.notifications.empty": "Không có thông báo",
"center_notch.notifications.dismiss": "Bỏ thông báo",
"center_notch.notifications.unread_header": "{count} chưa xem",
"center_notch.notifications.time_now": "Vừa xong",
"center_notch.notifications.time_minutes": "{count} phút",
"center_notch.notifications.time_hours": "{count} giờ",
"center_notch.notifications.time_days": "{count} ngày"
```

The page owns `property double observedAt: Date.now()` and refreshes it on descriptor-model changes.
The row formats age as Now below one minute, whole minutes below one hour, whole hours below one day
and whole days thereafter; it owns no timer.

- [ ] **Step 7: Run focused tests and commit**

Run:

```bash
python3 scripts/check_notifications.py
node scripts/check_center_notch.js
./scripts/check.sh
```

Expected: static gates and the repository qmllint gate PASS with no new warning outside the allowlist.

```bash
git add Titonium/Bar/notch/NotificationsPage.qml Titonium/Bar/notch/NotificationHistoryRow.qml Titonium/Bar/notch/CenterNotchViewport.qml Titonium/Bar/notch/qmldir scripts/check_notifications.py config/i18n/en.json config/i18n/vi.json
git commit -m "feat: add center notification history page"
```

### Task 5: Verify native lifecycle and document user acceptance

**Files:**
- Modify: `scripts/notifications_acceptance.sh`
- Modify: `docs/TESTING.md`

**Interfaces:**
- Preserves the production IPC surface at exactly `state()` and `markRead()`.
- Produces a documented manual page test for rail badge, viewed semantics, individual dismiss and Clear all.

- [ ] **Step 1: Strengthen the existing runtime script without adding mutation IPC**

After `notify-send`, keep assertions that history/toast/unread become `1/1/1`, toast expiry leaves
`1/0/1`, and `markRead` produces `1/0/0`. Add a second `notify-send`, assert history/unread become
`2/1`, and confirm the repository and both Hyprland config hashes remain unchanged. Do not expose
`dismissAll` through IPC solely for the test.

- [ ] **Step 2: Run shell syntax and focused acceptance**

Run:

```bash
bash -n scripts/notifications_acceptance.sh
./scripts/notifications_acceptance.sh
```

Expected: `PASS native notification toast, unread lifecycle and DP-1-only acceptance` and no
runtime rejection in the isolated shell log.

- [ ] **Step 3: Add the manual page acceptance checklist**

Document these exact user actions in `docs/TESTING.md`:

```text
1. Send two notifications with notify-send while Center is closed; rail badge shows 2.
2. Open Center > Notifications; badge clears and both history rows remain.
3. Send another notification while the page is visible; it appears newest-first without leaving an unread badge.
4. Dismiss one row; only that row disappears.
5. Select Clear all; history enters the empty state.
6. Switch to Tools and back; Notifications is recreated lazily and does not duplicate rows.
```

- [ ] **Step 4: Run the full repository gate**

Run:

```bash
./scripts/check.sh
git diff --check
```

Expected: every repository check passes and diff check prints no output.

- [ ] **Step 5: Commit the acceptance slice**

```bash
git add scripts/notifications_acceptance.sh docs/TESTING.md
git commit -m "test: verify center notification history"
```
