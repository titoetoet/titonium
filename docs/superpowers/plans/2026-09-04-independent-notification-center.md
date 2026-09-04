# Independent Notification Center Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a configurable top-right Notification Center and route only policy-resolved critical events through a hover-pausable FIFO Center banner.

**Architecture:** Keep native objects private in `NotificationService`, move deterministic classification/state transitions into pure JavaScript rules, and expose presentation state through a notification coordinator. Reuse the neutral Center surface/controller contract for critical banners instead of adding another center owner.

**Tech Stack:** QML, JavaScript, Quickshell Notifications, Node/Python static contract tests, shell acceptance tests.

**Spec:** `docs/superpowers/specs/2026-09-04-independent-notification-center-design.md`

## Global Constraints

- Preserve protected Spotlight, Input Method, dynamic screen lifecycle, and runtime settings files.
- No title/body keyword classification, new daemon, Python sidecar, or system-battery listener.
- History cap 100, toast cap 3, critical queue cap 16, readable deadline 4000 ms.
- Automatic is the default policy; inline reply and notification images remain disabled.
- Follow TDD: every production behavior begins with a failing focused test.

---

### Task 1: Policy rules and settings schema

**Files:** Modify notification rules, preference validator/default/schema, settings tests; create focused policy-rule tests.

**Interfaces:** Produce normalized descriptors with namespaced `key`, `source`, `appId`, `nativeUrgency`, `severity`, `route`, `category`, `actions`, and `receivedAt`; produce `resolvePolicy(descriptor, preferences)` with block → custom override → internal policy → native urgency → normal fallback.

- [ ] Add failing tests for urgency normalization, internal mappings, all five app overrides, invalid fallback, no content inference, caps, and immutable values.
- [ ] Run the focused tests and confirm failures are caused by missing policy/schema behavior.
- [ ] Implement minimal pure rules and settings projection for `policyMode`, `allowCriticalOnIsland`, `keepCriticalUnread`, and sanitized `applicationOverrides`.
- [ ] Update shipped defaults/schema and both existing preference validation test suites.
- [ ] Run focused notification/preferences tests and `./scripts/check.sh`.
- [ ] Commit the task.

### Task 2: Native service boundary and action support

**Files:** Modify `NotificationService.qml`, its qmldir/static gate, and notification rules/service tests.

**Interfaces:** Service emits normalized native descriptors, exposes dismiss/action invocation by stable key, and never imports Center services; native objects remain private.

- [ ] Add failing tests proving new notifications enqueue toast state, native actions are projected, Center imports/calls are absent, and native identity never leaks.
- [ ] Run focused tests to verify the intended failures.
- [ ] Refactor the native server around stable keys and enable standard actions while leaving inline reply/images disabled.
- [ ] Add bounded failure handling for missing/stale action or dismissal targets.
- [ ] Run focused tests and the full static gate.
- [ ] Commit the task.

### Task 3: Notification coordinator and internal bridge

**Files:** Create coordinator/rules and orchestration bridge; modify Job/Timer producers and their tests.

**Interfaces:** Expose immutable history/toasts/unread/currentCritical/criticalQueueCount plus publish, read, dismiss, action, pause/resume/complete, and reclassification intents. Job/Timer emit value-only notification signals.

- [ ] Add failing pure tests for passive/critical routing, FIFO, dedup, caps, no duplicate critical toast, pause/resume remaining time, non-preemption eligibility, and settings reclassification.
- [ ] Add failing contract tests for value-only Job/Timer signals and orchestration ownership.
- [ ] Implement coordinator state and the bridge without creating Center → Notifications imports.
- [ ] Keep the visible current item stable during settings changes; reclassify only pending items.
- [ ] Run focused tests and `./scripts/check.sh`.
- [ ] Commit the task.

### Task 4: Top-right panel, bell, and toast routing

**Files:** Extend `Titonium/Notifications`, update App composition, bell, surface routing, settings page, i18n, and UI/static tests.

**Interfaces:** Bell always renders and requests panel toggle for its screen; one lazy panel renders unified newest-first history and invokes coordinator intents.

- [ ] Add failing static/UI tests for always-present bell, focused/clicked-screen ownership, lazy panel, route replacement, read-on-success, actions, dismiss/clear, empty state, and policy controls.
- [ ] Implement a single-owner top-right panel with mutual exclusion against Settings, Spotlight, Right Pill, and open Center surfaces.
- [ ] Bind passive toasts to the coordinator, preserving top-right geometry and expiry-without-dismiss semantics.
- [ ] Implement Automatic/Custom controls, global toggles, app override rows, per-row reset, and reset all using translated strings.
- [ ] Run settings, notification, routing, i18n, and full static checks.
- [ ] Commit the task.

### Task 5: Critical FIFO integration with neutral Center

**Files:** Modify notification Center adapter/controller integration and active Center renderer/presentation tests without changing the neutral ownership boundary.

**Interfaces:** Critical current item becomes a normalized Center notification context; Center hover calls pause/resume; timeout/action/dismiss advances FIFO; surface availability gates presentation.

- [ ] Add failing tests for compact/satellite auto-entry, expanded/user interaction non-preemption, FIFO advancement, 4000 ms readable deadlines, hover pause/resume, queue exhaustion collapse, and stable banner geometry.
- [ ] Route only coordinator-resolved critical items into Center; do not reconnect `NotificationService` directly.
- [ ] Keep the banner owner and geometry mounted while notification content transitions; use instant content replacement under Reduced Motion.
- [ ] Ensure critical items never create a duplicate toast and remain in history according to `keepCriticalUnread`.
- [ ] Run Center domain/controller/presentation and notification tests plus `./scripts/check.sh`.
- [ ] Commit the task.

### Task 6: Acceptance, documentation, and hardening

**Files:** Update notification/Center acceptance scripts and canonical architecture/testing documentation.

**Interfaces:** Preserve `notifications state|markRead`; add read-only panel/queue/policy fields and no mutation/injection IPC.

- [ ] Add acceptance assertions for passive toast/history, critical routing, FIFO, hover pause seam, actions, custom overrides, screen ownership, and monitor-loss cleanup.
- [ ] Update docs to remove the bell/Notification Center contradictions and document the final policy precedence.
- [ ] Run `./scripts/check.sh`, `./scripts/smoke.sh`, `./scripts/protected_acceptance.sh`, `./scripts/notifications_acceptance.sh`, `./scripts/center_notch_acceptance.sh`, and `hyprctl configerrors` where the environment supports them.
- [ ] Review the complete diff for unrelated changes, native-object leaks, untranslated strings, and violations of protected boundaries.
- [ ] Commit the task.
