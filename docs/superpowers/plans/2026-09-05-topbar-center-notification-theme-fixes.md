# Topbar Center and Notification Theme Fixes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove Connected shoulders from the Classic Center, place a fixed non-bell Notification Center control at the rightmost end of both Topbar styles, render unread bell motion only in Center's secondary pill, and make the history panel attach to the right pill in Connected while remaining detached in Classic.

**Architecture:** Preserve the existing neutral Center domain/controller/host and split only the Classic presentation renderer from the Connected shape. Keep `NotificationCoordinator` as the single notification-state owner; route one shared notification-history content component through the existing style-aware `SurfaceManager`/`RightPillCoordinator` connected-surface contract.

**Tech Stack:** QML, QtQuick, Quickshell Layer Shell, JavaScript contract rules, Node/Python static tests, shell acceptance tests.

**Spec:** User brief in the 2026-09-05 task, constrained by `docs/ARCHITECTURE.md`, `docs/MODULE_CONTRACT.md`, `docs/THEMING_AND_GLASS.md`, and `docs/TESTING.md`.

## Global Constraints

- Do not change Center domain priority, Center controller lifecycle, notification policy, toast behavior, or critical-notification FIFO behavior.
- `NotificationService` remains the sole native `NotificationServer` owner and `NotificationCoordinator` remains the sole history/unread/panel-state owner.
- Classic Notification Center remains a detached overlay; Connected Notification Center uses the existing right-pill connected surface and its owner/generation guards.
- Notification Center is the rightmost Topbar control in both styles.
- The Topbar control always uses one dedicated non-bell Notification Center/history icon; unread state never changes that glyph into a bell.
- The notification bell and its at-most-three-cycle wobble render only in Center's secondary pill while unread notifications exist.
- Do not redesign or implement Center's primary pill in this slice; primary-pill work is explicitly deferred.
- Do not edit either `hyprland.lua` file.

---

### Task 1: Give Classic Center a shoulder-free renderer

**Files:**
- Modify: `Titonium/Bar/center/presentations/Classic/ClassicRenderer.qml`
- Modify: `Titonium/Bar/center/CenterPresentationRules.js`
- Modify: `scripts/check_center_presentation_rules.js`
- Modify: `scripts/check_classic_bar.js`

**Interfaces:**
- Consumes: the existing `snapshot`, `viewState`, `profile`, `intentRequested(intent)`, and `transitionFinished(generation)` renderer contract.
- Produces: `visualBounds` and `interactiveBounds` for a top-centered, rounded Classic body with no `ConnectedPillShape` or shoulder geometry.

- [ ] **Step 1: Add failing renderer contract tests**

  Extend `scripts/check_center_presentation_rules.js` to read `ClassicRenderer.qml` and assert that it does not instantiate or import `ConnectedRenderer`/`ConnectedPillShape`, does render a shoulder-free `Shared.Surface`, and still exposes the common renderer properties/signals/bounds. Extend `scripts/check_classic_bar.js` to assert that Classic compact geometry is inset from the top edge and has no shoulder width term.

  ```js
  assert.doesNotMatch(classicRenderer,
      /Connected\.ConnectedRenderer|ConnectedPillShape|shoulderSize/);
  assert.match(classicRenderer, /Shared\.Surface\s*\{/);
  assert.match(classicRenderer,
      /readonly property rect visualBounds:[\s\S]*?classicBody/);
  ```

- [ ] **Step 2: Run the focused tests and confirm the current implementation fails**

  Run:

  ```bash
  node scripts/check_center_presentation_rules.js
  node scripts/check_classic_bar.js
  ```

  Expected: failure because `ClassicRenderer.qml` currently delegates directly to `ConnectedRenderer.qml`.

- [ ] **Step 3: Implement a dedicated Classic renderer**

  Replace the Connected wrapper with a focused Classic renderer that preserves the existing context selection, action dispatch, banner timeout pause/resume, context crossfade, Reduced Motion behavior, and transition completion contract. Draw only a top-centered `Shared.Surface`/rounded body using `profile.compact.inset`, mode-specific width/height/radius, with no concave shoulder path. Keep presentation code service-free and route actions only through `intentRequested`.

- [ ] **Step 4: Run focused Center tests**

  Run:

  ```bash
  node scripts/check_center_presentation_rules.js
  node scripts/check_classic_bar.js
  node scripts/check_center_surface_state.js
  python3 scripts/check_center_architecture.py
  ```

  Expected: all pass; Classic is shoulder-free and the neutral Center lifecycle is unchanged.

- [ ] **Step 5: Commit the isolated Classic fix**

  ```bash
  git add Titonium/Bar/center/presentations/Classic/ClassicRenderer.qml Titonium/Bar/center/CenterPresentationRules.js scripts/check_center_presentation_rules.js scripts/check_classic_bar.js
  git commit -m "fix: remove connected shoulders from classic center"
  ```

### Task 2: Make the Notification Center control rightmost with a fixed non-bell icon

**Files:**
- Modify: `Titonium/Bar/widgets/NotificationBell.qml`
- Modify: `Titonium/Bar/islands/EndIsland.qml`
- Modify: `Titonium/Bar/classic/ClassicEndIsland.qml`
- Modify: `config/i18n/en.json`
- Modify: `config/i18n/vi.json`
- Modify: `scripts/check_notification_panel.py`
- Modify: `scripts/check_right_pill.js`
- Modify: `scripts/check_classic_bar.js`

**Interfaces:**
- Consumes: `NotificationCoordinator.unreadCount` for accessible count/badge text and the existing `toggleRequested(screen, invoker)` intent.
- Produces: one 28dp Notification Center control with a fixed, dedicated non-bell history/notification-center glyph and rightmost placement in both style rows.

- [ ] **Step 1: Add failing fixed-icon and ordering tests**

  Update the notification contract test to require one explicit non-bell icon in every unread state and to forbid bell wobble/rotation from the Topbar control. Add ordering assertions that the Notification component appears after connectivity/status/pin components in both source rows.

  ```python
  require(bell, "Notification Center control", (
      'readonly property string iconName: "notification_center"',
      'name: root.iconName',
  ), errors)
  if 'SequentialAnimation' in bell or 'property: "rotation"' in bell:
      errors.append("Topbar Notification Center must not own bell motion")
  if connected_end.rfind("NotificationBell {") < connected_end.rfind("ConnectivityPill {"):
      errors.append("Connected Notification Center must be the rightmost control")
  if classic_end.rfind("NotificationBell {") < classic_end.rfind("StatusPill {"):
      errors.append("Classic Notification Center must be the rightmost surface")
  ```

- [ ] **Step 2: Run focused tests and confirm failures**

  Run:

  ```bash
  python3 scripts/check_notification_panel.py
  node scripts/check_right_pill.js
  node scripts/check_classic_bar.js
  ```

  Expected: failure because the icon is hard-coded to the bell glyph `notifications`, wobble is owned by the Topbar control, and the control is currently first in both right-side rows.

- [ ] **Step 3: Implement the fixed icon and reorder both rows**

  Rename the component to `NotificationCenterButton.qml` if static reference migration remains local; otherwise retain the filename only as a compatibility name. Bind it permanently to the project-supported dedicated `notification_center`/history glyph, remove rotation and wobble from the Topbar component, and retain unread count only as a badge/accessibility fact if the product still wants the count visible there. Move the control/surface after all other right-side controls in `EndIsland.qml` and `ClassicEndIsland.qml`, preserving the 28dp hitbox, spacing, preferred-width reporting, and Classic mask aliasing.

- [ ] **Step 4: Run focused tests**

  Run:

  ```bash
  python3 scripts/check_notification_panel.py
  node scripts/check_right_pill.js
  node scripts/check_classic_bar.js
  node scripts/check_icon_rules.js
  ```

  Expected: all pass; the Topbar glyph stays non-bell before and after unread changes, and the control is rightmost in both styles.

- [ ] **Step 5: Commit the control behavior**

  ```bash
  git add Titonium/Bar/widgets/NotificationBell.qml Titonium/Bar/islands/EndIsland.qml Titonium/Bar/classic/ClassicEndIsland.qml config/i18n/en.json config/i18n/vi.json scripts/check_notification_panel.py scripts/check_right_pill.js scripts/check_classic_bar.js
  git commit -m "fix: place notification center at topbar end"
  ```

### Task 3: Restore the notification bell as Center's secondary pill

**Files:**
- Create: `Titonium/Bar/center/CenterSecondaryPill.qml`
- Modify: `Titonium/Bar/center/qmldir`
- Modify: `Titonium/Bar/center/presentations/Connected/ConnectedRenderer.qml`
- Modify: `Titonium/Bar/center/presentations/Classic/ClassicRenderer.qml`
- Modify: `Titonium/Services/Center/adapters/NotificationCenterAdapter.qml`
- Modify: `scripts/check_center_presentation_rules.js`
- Modify: `scripts/check_center_activity.py`
- Modify: `scripts/check_notifications.py`

**Interfaces:**
- Consumes: the existing frozen `snapshot.indicators` entry with `id === "notification:unread"`; it does not consume `NotificationCoordinator` or any native notification object directly.
- Produces: a secondary compact pill beside the existing Center primary body, visible only while the unread indicator is active, with a bell glyph, unread count presentation supplied as semantic data, and an at-most-three-cycle wobble when the unread revision/count increases.

- [ ] **Step 1: Add failing secondary-pill ownership tests**

  Require a focused `CenterSecondaryPill` component, require both active renderers to compose it from immutable snapshot data, and forbid it from importing notification services. Require the Topbar button to contain no bell animation. Preserve the controller contract that `satellite` is not a lifecycle mode: the secondary pill is renderer-owned compact presentation only.

  ```js
  assert.match(connectedRenderer, /CenterSecondaryPill\s*\{/);
  assert.match(classicRenderer, /CenterSecondaryPill\s*\{/);
  assert.doesNotMatch(secondaryPill,
      /Services\.Notifications|NotificationCoordinator|NotificationService/);
  assert.match(secondaryPill, /name:\s*"notifications"/);
  assert.match(secondaryPill, /loops:\s*3/);
  ```

- [ ] **Step 2: Run focused tests and confirm failure**

  Run:

  ```bash
  node scripts/check_center_presentation_rules.js
  python3 scripts/check_center_activity.py
  python3 scripts/check_notifications.py
  node scripts/check_center_surface_state.js
  ```

  Expected: failure because the current renderers show only one Center body and bell motion still lives in the Topbar widget.

- [ ] **Step 3: Project the minimum semantic unread data**

  Extend the existing `notification:unread` indicator value with the minimum immutable presentation facts needed by the secondary pill, such as normalized count and revision, updating `CenterDomainRules.normalizeIndicator` only if those fields must cross the domain allowlist. Do not create a notification context, do not select it as `snapshot.primary`, and do not change context ranking or automatic critical-banner routing.

- [ ] **Step 4: Implement the secondary pill without touching primary-pill behavior**

  Add `CenterSecondaryPill.qml` as a presentation-only component. It appears adjacent to the current compact Center body when the unread indicator becomes active, caches the last valid indicator through its exit animation, renders the bell glyph, and runs no more than three wobble cycles per unread-count increase. It emits a neutral secondary activation intent only if click behavior is included; the renderer may map that intent to the existing notification-history routing in a later approved slice. In this plan, do not change the primary body's layout, content, click action, or semantic selection beyond reserving non-overlapping space for the secondary pill.

- [ ] **Step 5: Preserve profile-specific silhouettes**

  Connected may visually join the secondary pill to the Center silhouette only through renderer geometry; Classic renders it as a detached rounded pill with no concave shoulders. In both styles, the secondary pill must have its own exact input bounds, stop all motion when hidden or Reduced Motion is enabled, and must not introduce a new `satellite` controller mode or a second layer-shell owner.

- [ ] **Step 6: Run focused Center and notification tests**

  Run:

  ```bash
  node scripts/check_center_presentation_rules.js
  node scripts/check_center_surface_state.js
  python3 scripts/check_center_activity.py
  python3 scripts/check_notifications.py
  python3 scripts/check_center_architecture.py
  ```

  Expected: all pass; notification bell motion exists only in the Center secondary pill, while primary Center and controller state remain unchanged.

- [ ] **Step 7: Commit the secondary pill independently**

  ```bash
  git add Titonium/Bar/center/CenterSecondaryPill.qml Titonium/Bar/center/qmldir Titonium/Bar/center/presentations/Connected/ConnectedRenderer.qml Titonium/Bar/center/presentations/Classic/ClassicRenderer.qml Titonium/Services/Center/adapters/NotificationCenterAdapter.qml scripts/check_center_presentation_rules.js scripts/check_center_activity.py scripts/check_notifications.py
  git commit -m "feat: move notification bell to center secondary pill"
  ```

### Task 4: Split notification history into shared content and Classic shell

**Files:**
- Create: `Titonium/Notifications/NotificationHistoryContent.qml`
- Create: `Titonium/Notifications/ClassicNotificationPanel.qml`
- Modify: `Titonium/Notifications/NotificationPanel.qml`
- Modify: `Titonium/Notifications/qmldir`
- Modify: `scripts/check_notification_panel.py`
- Modify: `scripts/check_notification_panel_lifecycle.js`

**Interfaces:**
- Consumes: immutable `NotificationCoordinator.history` and narrow `action`, `dismiss`, `dismissAll`, `panelMounted`, `panelUnmounted`, and `markAllRead` intents.
- Produces: reusable `NotificationHistoryContent` with `implicitContentWidth`, `implicitContentHeight`, and `dismissRequested()`; Classic shell retains descriptor/screen/invoker ownership, focus return, outside-click, and entrance/exit animation.

- [ ] **Step 1: Add failing shared-content boundary tests**

  Require the content file and qmldir export; require history/header/clear/dismiss behavior to live in it; forbid `SurfaceManager`, `PanelWindow`, descriptor ownership, and native Notification imports from the content component. Require the Classic shell to retain identity-guarded close/reopen and lifecycle calls.

- [ ] **Step 2: Run notification panel tests and confirm failure**

  Run:

  ```bash
  python3 scripts/check_notification_panel.py
  node scripts/check_notification_panel_lifecycle.js
  ```

  Expected: failure because view content and detached-shell lifecycle currently coexist in `NotificationPanel.qml`.

- [ ] **Step 3: Extract reusable history content**

  Move the header, clear-all action, divider, bounded history list, empty state, row delegates, and intrinsic size calculation into `NotificationHistoryContent.qml`. Keep it coordinator-only and expose a dismiss signal for its close button. Turn `ClassicNotificationPanel.qml` into the current detached top-right shell around that content. Keep `NotificationPanel.qml` as a compatibility wrapper or migrate all references in Task 5 and then remove the wrapper only after static references reach zero.

- [ ] **Step 4: Verify the extraction**

  Run:

  ```bash
  python3 scripts/check_notification_panel.py
  node scripts/check_notification_panel_lifecycle.js
  python3 scripts/check_notification_coordinator.py
  ```

  Expected: all pass; extraction does not change mark-read timing, list ordering, actions, dismissal, or focus return.

- [ ] **Step 5: Commit the reusable view boundary**

  ```bash
  git add Titonium/Notifications/NotificationHistoryContent.qml Titonium/Notifications/ClassicNotificationPanel.qml Titonium/Notifications/NotificationPanel.qml Titonium/Notifications/qmldir scripts/check_notification_panel.py scripts/check_notification_panel_lifecycle.js
  git commit -m "refactor: share notification history content"
  ```

### Task 5: Route Connected Notification Center through the right-pill chassis

**Files:**
- Create: `Titonium/Notifications/ConnectedNotificationPanelContent.qml`
- Modify: `Titonium/Notifications/qmldir`
- Modify: `Titonium/Orchestration/NotificationPanelRouting.js`
- Modify: `Titonium/Orchestration/SurfaceRouter.qml`
- Modify: `Titonium/Bar/islands/EndIsland.qml`
- Modify: `Titonium/Bar/right/EdgeMenuSurface.qml`
- Modify: `scripts/check_notification_panel_routing.js`
- Modify: `scripts/check_notification_panel.py`
- Modify: `scripts/check_connected_popup_content.js`
- Modify: `scripts/check_top_bar_style_lifecycle.js`

**Interfaces:**
- Consumes: `RightPillCoordinator.presentedStyle`, the invoker item, `SurfaceManager`, `RightPillCoordinator.connectedSurface*`, and `NotificationHistoryContent`.
- Produces: a style-aware notification descriptor. Connected uses `{ barConnected: true, feature: "notifications", anchor: "notifications" }`; Classic resolves `ClassicNotificationPanel.qml` with `barConnected: false`.

- [ ] **Step 1: Add failing route tests**

  Expand `NotificationPanelRouting.js` tests so `presentation("connected")` returns an edge route and `presentation("classic")` returns a detached overlay route. Require `EndIsland` to expose `anchorRect("notifications")` for the rightmost control. Require `SurfaceRouter.toggleNotificationPanel` to reverse/close the exact same connected owner through `RightPillCoordinator`, while Classic continues using normal `SurfaceManager.close`.

  ```js
  assert.deepEqual(plain(routing.presentation("connected")), {
      owner: "edge", source: "ConnectedNotificationPanelContent.qml",
      anchor: "notifications"
  });
  assert.deepEqual(plain(routing.presentation("classic")), {
      owner: "overlay", source: "ClassicNotificationPanel.qml", anchor: ""
  });
  ```

- [ ] **Step 2: Run focused routing tests and confirm failure**

  Run:

  ```bash
  node scripts/check_notification_panel_routing.js
  python3 scripts/check_notification_panel.py
  node scripts/check_connected_popup_content.js
  node scripts/check_top_bar_style_lifecycle.js
  ```

  Expected: failure because notification routing currently has no style-aware descriptor and always opens the detached panel.

- [ ] **Step 3: Implement style-aware descriptors and connected content**

  Add a pure `presentation(style)` rule. In `SurfaceRouter.toggleNotificationPanel`, build the owner once, handle exact-owner reverse/preserve/close semantics with the existing `BarPopupRouting.existingOpenAction` and `RightPillCoordinator.toggleConnectedSurface`, then open a descriptor containing source, owner, feature, `barConnected`, anchor, invoker, keyboard focus, and monitor-close policy. `ConnectedNotificationPanelContent.qml` wraps `NotificationHistoryContent`, performs panel mount/unmount and mark-read only after the connected owner is loaded, and emits `dismissRequested()` for the shared right-pill close path. Extend `EndIsland.connectivityAnchorRect()` into a general right-control anchor lookup so `EdgeMenuSurface` branches from the Notification Center button rather than the connectivity group.

- [ ] **Step 4: Preserve mutual exclusion and style-switch cleanup**

  Ensure opening notification history closes Center and any previous right-pill menu through existing orchestration. Ensure switching Connected → Classic while notification history is open releases the captured connected owner/generation, returns focus at most once, and cannot let a stale close completion clear a newer Classic owner. Do not add a second full-screen window or notification coordinator.

- [ ] **Step 5: Run route, lifecycle, and style tests**

  Run:

  ```bash
  node scripts/check_notification_panel_routing.js
  node scripts/check_notification_panel_lifecycle.js
  python3 scripts/check_notification_panel.py
  node scripts/check_connected_popup_content.js
  node scripts/check_right_pill_state.js
  node scripts/check_top_bar_style_lifecycle.js
  python3 scripts/check_focus_ownership.js
  ```

  Expected: all pass; Connected history grows from the rightmost Notification control and Classic remains detached.

- [ ] **Step 6: Commit Connected routing**

  ```bash
  git add Titonium/Notifications/ConnectedNotificationPanelContent.qml Titonium/Notifications/qmldir Titonium/Orchestration/NotificationPanelRouting.js Titonium/Orchestration/SurfaceRouter.qml Titonium/Bar/islands/EndIsland.qml Titonium/Bar/right/EdgeMenuSurface.qml scripts/check_notification_panel_routing.js scripts/check_notification_panel.py scripts/check_connected_popup_content.js scripts/check_top_bar_style_lifecycle.js
  git commit -m "feat: attach connected notification center to topbar"
  ```

### Task 6: Acceptance coverage and canonical documentation

**Files:**
- Modify: `scripts/notifications_acceptance.sh`
- Modify: `scripts/check.sh`
- Modify: `docs/ARCHITECTURE.md`
- Modify: `docs/MODULE_CONTRACT.md`
- Modify: `docs/THEMING_AND_GLASS.md`
- Modify: `docs/TESTING.md`

**Interfaces:**
- Consumes: the final Classic/Connected visual and lifecycle contracts from Tasks 1–5.
- Produces: regression gates and documentation matching actual style-specific behavior.

- [ ] **Step 1: Add acceptance assertions**

  Extend notification acceptance to verify the style-aware open state without injecting new mutation IPC: in Connected, the notification owner reports a connected edge presentation; in Classic, it reports a detached overlay. Add static assertions that the Topbar icon remains non-bell across unread changes, bell wobble exists only in the Center secondary pill, and Classic Center has no shoulders; wire those focused scripts into `check.sh`.

- [ ] **Step 2: Update canonical docs**

  Replace statements saying the bell is always present on the Topbar and the panel is always top-right. Document the rightmost fixed non-bell Notification Center control, bell motion in Center's secondary pill, explicit deferral of primary-pill redesign, Classic detached history shell, Connected right-pill-attached history, and unchanged critical Center-banner path.

- [ ] **Step 3: Run the full required gates**

  Run:

  ```bash
  ./scripts/check.sh
  ./scripts/smoke.sh
  ./scripts/protected_acceptance.sh
  ./scripts/notifications_acceptance.sh
  ./scripts/center_notch_acceptance.sh
  hyprctl configerrors
  ```

  Expected: all supported gates pass. If a live gate skips because a resident notification daemon owns `org.freedesktop.Notifications`, record the skip and run the visual checklist against the resident Titonium session.

- [ ] **Step 4: Perform the visual regression checklist on both themes**

  Verify: Classic compact/banner/expanded Center never shows shoulders; Notification Center is the rightmost Topbar control and its non-bell glyph never changes; a new unread notification presents the bell and wobble only in Center's secondary pill; the current primary pill remains behaviorally unchanged; Connected history opens from the Notification control as one continuous right-pill chassis; Classic opens a detached panel; Escape/outside click/same-control click close correctly; switching themes while open leaves no ghost surface or stale input mask; Reduced Motion removes transition motion without changing state.

- [ ] **Step 5: Commit acceptance and docs**

  ```bash
  git add scripts/notifications_acceptance.sh scripts/check.sh docs/ARCHITECTURE.md docs/MODULE_CONTRACT.md docs/THEMING_AND_GLASS.md docs/TESTING.md
  git commit -m "test: cover themed notification center behavior"
  ```

## Self-review

- Spec coverage: Classic shoulders map to Task 1; fixed Topbar icon/order maps to Task 2; Center secondary-pill bell maps to Task 3; style-specific history routing maps to Task 5; Tasks 4 and 6 preserve architecture and add regression coverage.
- Scope: no notification persistence, new policy, toast redesign, critical-banner redesign, or unrelated Topbar refactor.
- Type/identity consistency: one owner string per screen, one descriptor source per style, and connected close/reopen always retains owner + generation + descriptor + screen guards.
- Verification: focused red/green checks precede implementation in every task, followed by full static, smoke, protected, notification, Center, and compositor gates.
