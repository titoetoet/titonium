# Unified Dynamic Island Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Complete one four-state Dynamic Island shared by Connected and Classic Top Bar styles, with lossless contexts, one visual owner, reversible motion, and canonical live acceptance.

**Architecture:** `CenterNotchCoordinator` remains the sole UI state machine while one always-mounted `CenterPillWindow` owns the connected silhouette and input lifecycle on every eligible screen. Connected and Classic provide only immutable compact style profiles; focused presentation components render Compact, Satellite, Banner, and Expanded content without introducing a second window or Loader.

**Tech Stack:** Qt 6 QML/QtQuick, Quickshell/Wayland layer shell, JavaScript pure rules tested with Node.js, Python static contract tests, Bash foreground/live acceptance.

**Spec:** `docs/superpowers/specs/2026-09-04-unified-dynamic-island-design.md`

## Global Constraints

- `docs/DYNAMIC_ISLAND.md` is the canonical product contract.
- Stable states are exactly `compact`, `satellite`, `banner`, and `expanded`.
- Every eligible screen owns exactly one always-mounted `CenterPillWindow` in both Bar styles.
- The Dynamic Island tree contains exactly one `Shared.ConnectedPillShape` and no Loader.
- Standard compact geometry is 180–260 × 36dp; logical aspect ratio `>= 2.1` uses 180–340 × 42dp.
- Satellite ceilings are 320dp standard and 340dp ultrawide, with one 32×28dp nested chip and 44dp trailing reservation.
- Banner is 480×72 at radius 22; Expanded is 720×440 at radius 28, clamped only for a smaller screen.
- Opening lasts 220–250ms; closing lasts 180–200ms; drag settle lasts 90–180ms.
- Reduced Motion sets geometry and content durations to zero and no hidden component runs an infinite animation.
- Views read services and emit intents; they never own Process, FileView, raw commands, persistence, or native listeners.
- User-facing strings use `I18n.tr()` with matching English and Vietnamese entries.
- Do not modify either protected `hyprland.lua`; do not restore Notification Center, System Monitoring, or legacy Overview pages.
- Preserve unrelated user changes in the dirty worktree and stage only task-owned paths.

---

### Task 1: Make state selection and context projection lossless

**Files:**
- Modify: `Titonium/Bar/notch/CenterNotchState.js`
- Modify: `Titonium/Bar/notch/CenterNotchCoordinator.qml`
- Modify: `scripts/check_center_notch.js`

**Interfaces:**
- Consumes: ordered `CenterActivityService.activities`, `CenterFocusStore.text`, optional notification descriptor, and session `focusEnabled`.
- Produces: `contextIdentity(context): string`, `normalizeContext(context): object`, and `activitySlots(activities, focusActivity, secondaryOverride, focusEnabled): { primary, secondary }` using `(source,id)` identity.

- [ ] **Step 1: Add failing pure fixtures for lossless normalization and source-qualified identity**

Add these fixtures after the existing `contextForActivity` assertion in `scripts/check_center_notch.js`:

```js
const richTimer = {
    id: "shared", source: "timer", label: "Build", icon: "timer",
    progress: 37, deadline: 123456, customField: "retained"
};
const richContext = plain(context.normalizeContext(richTimer));
assert.deepEqual(richContext, {
    id: "shared", source: "timer", label: "Build", icon: "timer",
    progress: 37, deadline: 123456, customField: "retained", title: "Build"
}, "context normalization retains service-owned fields");
assert.equal(context.contextIdentity({ source: "timer", id: "shared" }), "timer\u0000shared");
assert.notEqual(
    context.contextIdentity({ source: "timer", id: "shared" }),
    context.contextIdentity({ source: "job", id: "shared" }),
    "independent sources may reuse an id"
);
const colliding = [richTimer, { id: "shared", source: "job", label: "Render" }];
assert.deepEqual(plain(context.activitySlots(colliding, null, null, false)), {
    primary: richTimer,
    secondary: colliding[1]
}, "secondary selection compares source and id together");
```

- [ ] **Step 2: Run the focused pure test and verify failure**

Run: `node scripts/check_center_notch.js`

Expected: FAIL because `normalizeContext` and `contextIdentity` do not exist and same-ID activities are currently deduplicated incorrectly.

- [ ] **Step 3: Implement immutable, lossless context helpers**

Add to `CenterNotchState.js`:

```js
function contextIdentity(context) {
    if (!context || typeof context !== "object")
        return "idle\u0000";
    return String(context.source || "idle") + "\u0000" + String(context.id || "");
}

function normalizeContext(context) {
    if (!context || typeof context !== "object")
        return Object.freeze({ source: "idle", id: "", title: "", icon: "" });
    const result = Object.assign({}, context);
    result.source = String(result.source || "idle");
    result.id = String(result.id || "");
    result.title = String(result.title || result.label || "");
    result.icon = String(result.icon || "bolt");
    return Object.freeze(result);
}
```

Make `contextForActivity()` delegate to `normalizeContext()`. In `activitySlots()`, replace the
`source[index]?.id !== primary.id` comparison with:

```js
contextIdentity(source[index]) !== contextIdentity(primary)
```

Normalize `primaryContext`, `secondaryContext`, and every assignment to `selectedContext` in
`CenterNotchCoordinator.qml` through `CenterNotchState.normalizeContext()`.

- [ ] **Step 4: Cover notification fallback and Focus-disabled Media promotion**

Add fixtures proving a notification replaces only Secondary, expiry returns the first ordered
activity, and Media is Primary when Focus is disabled even when Media is not array index zero.

- [ ] **Step 5: Run focused Center tests**

Run:

```bash
node scripts/check_center_notch.js
node scripts/check_center_activity_rules.js
python3 scripts/check_center_activity.py
node scripts/check_center_attention_rules.js
python3 scripts/check_center_attention.py
```

Expected: all commands print `PASS` and exit 0.

- [ ] **Step 6: Commit the pure contract**

```bash
git add Titonium/Bar/notch/CenterNotchState.js Titonium/Bar/notch/CenterNotchCoordinator.qml scripts/check_center_notch.js
git commit -m "refactor: preserve dynamic island contexts"
```

---

### Task 2: Unify Connected and Classic under one window owner

**Files:**
- Create: `Titonium/Bar/notch/CenterStyleProfile.js`
- Modify: `Titonium/Bar/notch/CenterPillWindow.qml`
- Modify: `Titonium/Bar/notch/CenterNotchSurface.qml`
- Modify: `Titonium/Bar/BarHost.qml`
- Modify: `Titonium/Bar/BarSurface.qml`
- Modify: `Titonium/Bar/classic/ClassicBar.qml`
- Modify: `Titonium/Bar/classic/ClassicCenterGroup.qml`
- Modify: `Titonium/Bar/classic/qmldir`
- Delete: `Titonium/Bar/classic/ClassicCenterNotchWindow.qml`
- Delete: `Titonium/Bar/classic/ClassicCenterNotchSurface.qml`
- Modify: `scripts/check_center_notch.js`
- Modify: `scripts/check_classic_bar.js`
- Modify: `scripts/check_top_bar_style_lifecycle.js`
- Modify: `scripts/check_bar.py`

**Interfaces:**
- Consumes: `RightPillCoordinator.presentedStyle`, screen logical dimensions, Bar reveal geometry.
- Produces: `CenterStyleProfile.profile(style, screenWidth, screenHeight): { style, compactY, surfaceTone, horizontalPadding }`; one `CenterPillWindow { styleName }` for both styles.

- [ ] **Step 1: Write failing ownership and style-profile tests**

Extend `scripts/check_center_notch.js` to require exactly one `CenterPillWindow` in `BarHost.qml`,
reject `ClassicCenterNotchWindow` and `ClassicCenterNotchSurface`, and assert their files do not
exist. Extend `scripts/check_classic_bar.js` to reject `CenterIsland`, `Shared.Surface`, and
`NotificationBell` inside `ClassicCenterGroup.qml`.

Add pure profile fixtures:

```js
assert.deepEqual(plain(styleProfile.profile("connected", 1920, 1080)), {
    style: "connected", compactY: 0, surfaceTone: "connected", horizontalPadding: 0
});
assert.deepEqual(plain(styleProfile.profile("classic", 1920, 1080)), {
    style: "classic", compactY: 4, surfaceTone: "elevated", horizontalPadding: 12
});
assert.equal(styleProfile.profile("unknown", 1920, 1080).style, "connected");
```

- [ ] **Step 2: Run ownership tests and verify failure**

Run:

```bash
node scripts/check_center_notch.js
node scripts/check_classic_bar.js
node scripts/check_top_bar_style_lifecycle.js
python3 scripts/check_bar.py
```

Expected: FAIL because `BarHost` still instantiates the Classic window and Classic owns Center
surface/notification hitboxes.

- [ ] **Step 3: Implement the pure style profile**

Create `CenterStyleProfile.js`:

```js
.pragma library

function normalizeStyle(style) {
    return style === "classic" ? "classic" : "connected";
}

function profile(style, screenWidth, screenHeight) {
    const normalized = normalizeStyle(style);
    return Object.freeze({
        style: normalized,
        compactY: normalized === "classic" ? 4 : 0,
        surfaceTone: normalized === "classic" ? "elevated" : "connected",
        horizontalPadding: normalized === "classic" ? 12 : 0
    });
}
```

- [ ] **Step 4: Make `CenterPillWindow` the unconditional owner**

Replace the two Center window instances in `BarHost.qml` with one:

```qml
CenterPillWindow {
    screenModel: screenScope.modelData
    styleName: RightPillCoordinator.presentedStyle
    onBannerRequested: (screen, context, autoDismiss) =>
        root.bannerRequested(screen, context, autoDismiss)
    onSettingsRequested: screen => root.settingsRequested(screen)
}
```

Remove `styleActive` gating from window visibility, mask, keyboard focus, and cleanup. Bind
`CenterNotchSurface.styleName` and use `CenterStyleProfile.profile()` for compact placement/tone.
Keep the current profile frozen while `dismissing`; adopt a changed profile only after
`finishClose()`.

- [ ] **Step 5: Convert Classic Center into an inert reservation**

Make `ClassicCenterGroup.qml` an `Item` with the canonical compact reservation width/height and no
painted child or input handler. Remove the Classic Center hitbox and detached notification hitbox
from `ClassicBar.qml` and `BarSurface.qml`. Update `ClassicBar.optionalPlan` to reserve the inert
Center width without including it in the Bar mask.

Delete both Classic notch files and remove their `qmldir` entries/imports.

- [ ] **Step 6: Run ownership, Bar, and lint checks**

Run:

```bash
node scripts/check_center_notch.js
node scripts/check_classic_bar.js
node scripts/check_top_bar_style_lifecycle.js
python3 scripts/check_bar.py
./scripts/check.sh
```

Expected: all pass; `qmllint` reports no unexpected warnings.

- [ ] **Step 7: Commit unified ownership**

```bash
git add Titonium/Bar/notch Titonium/Bar/BarHost.qml Titonium/Bar/BarSurface.qml Titonium/Bar/classic scripts/check_center_notch.js scripts/check_classic_bar.js scripts/check_top_bar_style_lifecycle.js scripts/check_bar.py
git commit -m "refactor: unify dynamic island ownership"
```

---

### Task 3: Split presentation components without changing behavior

**Files:**
- Create: `Titonium/Bar/notch/CenterCompactContent.qml`
- Create: `Titonium/Bar/notch/CenterSatelliteChip.qml`
- Create: `Titonium/Bar/notch/CenterBannerContent.qml`
- Create: `Titonium/Bar/notch/CenterExpandedContent.qml`
- Modify: `Titonium/Bar/notch/CenterNotchSurface.qml`
- Delete: `Titonium/Bar/notch/CenterNotch.qml`
- Modify: `Titonium/Bar/notch/qmldir`
- Modify: `scripts/check_center_notch.js`

**Interfaces:**
- `CenterCompactContent` consumes `screen`, `presentation`, `forcedWidth`, `forcedHeight`, and `trailingReservedWidth`; emits `primaryRequested`, `focusToggleRequested`, and `settingsRequested`.
- `CenterSatelliteChip` consumes `presentation`, `desired`, and `reducedMotion`; emits `requested(presentation)` and `exitFinished()`.
- `CenterBannerContent` consumes frozen `context`, `canvasProgress`, and `screen`; emits `expandedRequested`, `dragStarted`, and `dragFinished(offset, velocity)`.
- `CenterExpandedContent` consumes frozen `context` and exposes no service mutation beyond existing approval intents.

- [ ] **Step 1: Add failing structural contracts**

In `scripts/check_center_notch.js`, require all four new files, reject `CenterNotch.qml`, require one
instance of each new component in `CenterNotchSurface.qml`, and reject `Loader {` across all five
owner files.

- [ ] **Step 2: Run the structural test and verify failure**

Run: `node scripts/check_center_notch.js`

Expected: FAIL because the four focused presentation files do not exist.

- [ ] **Step 3: Extract Compact and Satellite presentation**

Move compact content and presentation-transition logic from `CenterIsland.qml` into
`CenterCompactContent.qml`, preserving the one-shot `setCompactWidth()` publication. Move
`nestedSatellite`, its cached `presentedSecondary`, `satellitePresented`, and `nestedExitRelease`
into `CenterSatelliteChip.qml`. Keep the exit contract explicit:

```qml
onDesiredChanged: {
    if (desired) {
        exitRelease.stop();
        cachedPresentation = presentation;
        presented = true;
    } else if (Motion.reduced) {
        presented = false;
        exitFinished();
    } else {
        exitRelease.restart();
    }
}
```

- [ ] **Step 4: Extract Banner and Expanded content**

Move Banner layers, media controls, notification copy, Focus banner, generic activity, expand
button, and drag handle into `CenterBannerContent.qml`. Move the Expanded header, clean canvas,
and `AgentApprovalCard` into `CenterExpandedContent.qml`. Compose both directly in
`CenterNotchSurface.qml` using shared transition progress.

Delete `CenterNotch.qml` and replace its `qmldir` entry with the four new component entries.

- [ ] **Step 5: Run focused static and foreground checks**

Run:

```bash
node scripts/check_center_notch.js
./scripts/check.sh
./scripts/smoke.sh
```

Expected: static checks pass, shell reaches ready state, and logs contain no QML runtime rejection.

- [ ] **Step 6: Commit component boundaries**

```bash
git add Titonium/Bar/notch Titonium/Bar/islands/CenterIsland.qml scripts/check_center_notch.js
git commit -m "refactor: split dynamic island presentation"
```

---

### Task 4: Complete Compact and Satellite behavior

**Files:**
- Modify: `Titonium/Bar/notch/CenterCompactContent.qml`
- Modify: `Titonium/Bar/notch/CenterSatelliteChip.qml`
- Modify: `Titonium/Bar/notch/CenterNotchSurface.qml`
- Modify: `Titonium/Bar/notch/CenterNotchCoordinator.qml`
- Modify: `scripts/check_center_notch.js`
- Modify: `scripts/center_notch_acceptance.sh`

**Interfaces:**
- Consumes: normalized Primary/Secondary descriptors and `focusEnabled`.
- Produces: independent Primary, Focus-toggle, and Secondary hit targets; cached Secondary exit; notification-to-activity restoration.

- [ ] **Step 1: Add failing tests for independent targets and notification restoration**

Require `focusToggleRequested`, `primaryRequested`, and `requested(root.cachedPresentation)` in the
static test. Extend live acceptance to start a timer, inject a notification fixture through the
existing notification test boundary, assert notification is Secondary, wait for its bounded expiry,
and assert the timer descriptor returns as Secondary without reopening the window.

- [ ] **Step 2: Verify the new tests fail**

Run:

```bash
node scripts/check_center_notch.js
bash -n scripts/center_notch_acceptance.sh
```

Expected: static contract fails until independent target signals and cached selection are wired.

- [ ] **Step 3: Implement independent Compact targets**

Give the Focus icon its own `TapHandler` and keyboard focus. Its handler calls only
`CenterNotchCoordinator.toggleFocus()`. The remaining Primary body emits `primaryRequested`.
Prevent event overlap by placing the Focus handler above the body handler and requiring the body
handler to ignore points inside the Focus target.

- [ ] **Step 4: Complete Secondary cache and identity behavior**

Bind Secondary content to `cachedPresentation`, not the live coordinator property. On click emit
the cached descriptor and call `openBanner(screenName, normalizeContext(cachedPresentation))`.
Release the 44dp trailing reservation only after `exitFinished()`.

- [ ] **Step 5: Stop hidden motion**

Gate every equalizer, wobble, aura, and mascot loop with effective component opacity/visibility,
the relevant source type, and `!Motion.reduced`. Add static assertions for those running guards.

- [ ] **Step 6: Run focused tests and live acceptance**

Run:

```bash
node scripts/check_center_notch.js
node scripts/check_center_activity_rules.js
node scripts/check_center_attention_rules.js
./scripts/check.sh
./scripts/center_notch_acceptance.sh
```

Expected: both activity and notification Satellite paths pass, expiry restores activity, and the
repository remains unchanged after acceptance.

- [ ] **Step 7: Commit Compact/Satellite completion**

```bash
git add Titonium/Bar/notch scripts/check_center_notch.js scripts/center_notch_acceptance.sh
git commit -m "feat: complete compact satellite interactions"
```

---

### Task 5: Harden Banner, Expanded, and disappearing-source fallbacks

**Files:**
- Modify: `Titonium/Bar/notch/CenterBannerContent.qml`
- Modify: `Titonium/Bar/notch/CenterExpandedContent.qml`
- Modify: `Titonium/Bar/notch/CenterNotchCoordinator.qml`
- Modify: `Titonium/Services/AgentApproval/AgentApprovalService.qml`
- Modify: `scripts/check_center_notch.js`
- Modify: `scripts/check_agent_approval.js`
- Modify: `scripts/center_notch_acceptance.sh`

**Interfaces:**
- Consumes: frozen normalized `selectedContext`, resolvable MPRIS/Notification/Approval service state.
- Produces: stable fallback presentation, action availability derived from live resolvability, and queue-stable Expanded ownership.

- [ ] **Step 1: Add failing contracts for frozen fallback and AI queue continuity**

Add static assertions requiring Banner labels to fall back to `context.title`, `context.artist`, and
`context.body` when live objects disappear. Require media buttons' `enabled` bindings to resolve the
selected player. Add a two-request fixture in `scripts/check_agent_approval.js` proving the current
request changes while `hasPending` remains true.

- [ ] **Step 2: Run focused tests and verify failure**

Run:

```bash
node scripts/check_center_notch.js
node scripts/check_agent_approval.js
```

Expected: FAIL until fallback fields and live action availability are explicit.

- [ ] **Step 3: Freeze complete Banner context on open**

Ensure `openBanner()` copies the normalized descriptor once. In `CenterBannerContent.qml`, derive
display values as live fact first and frozen fact second:

```qml
readonly property string mediaTitle: resolvedPlayer?.trackTitle
    || context?.trackTitle || context?.title || I18n.tr("menubar.center.media_unknown")
readonly property string mediaArtist: resolvedPlayer?.trackArtist
    || context?.trackArtist || ""
readonly property string notificationSummary: resolvedNotification?.summary
    || context?.summary || context?.title || I18n.tr("menubar.center.notification_new")
readonly property string notificationBody: resolvedNotification?.body || context?.body || ""
```

Disable previous/play-next controls unless `MprisService` can resolve the frozen media identity and
the corresponding capability is true.

- [ ] **Step 4: Keep Expanded open across an approval queue**

On `AgentApprovalService.current` change, update `selectedContext` to the next request without
closing or resetting transition progress. Collapse only on the edge `hasPending: true → false` when
the selected context source is `agent`.

- [ ] **Step 5: Add notification and AI live acceptance**

Extend `center_notch_acceptance.sh` with deterministic fixture helpers that enqueue two approval
requests without executing a real command. Assert request 1 opens Expanded, resolving it shows
request 2 while state remains Expanded, and resolving request 2 returns to Compact/Satellite.
Assert removed notification/media sources retain frozen readable copy and disable native actions.

- [ ] **Step 6: Run focused and repository checks**

Run:

```bash
node scripts/check_center_notch.js
node scripts/check_agent_approval.js
./scripts/check.sh
./scripts/center_notch_acceptance.sh
```

Expected: all pass with no external application launch or intercepted real approval request.

- [ ] **Step 7: Commit open-content hardening**

```bash
git add Titonium/Bar/notch Titonium/Services/AgentApproval/AgentApprovalService.qml scripts/check_center_notch.js scripts/check_agent_approval.js scripts/center_notch_acceptance.sh
git commit -m "feat: harden dynamic island open contexts"
```

---

### Task 6: Finish reversible motion, input, accessibility, and localization

**Files:**
- Modify: `Titonium/Bar/notch/CenterPillWindow.qml`
- Modify: `Titonium/Bar/notch/CenterNotchSurface.qml`
- Modify: `Titonium/Bar/notch/CenterCompactContent.qml`
- Modify: `Titonium/Bar/notch/CenterSatelliteChip.qml`
- Modify: `Titonium/Bar/notch/CenterBannerContent.qml`
- Modify: `Titonium/Bar/notch/CenterExpandedContent.qml`
- Modify: `config/i18n/en.json`
- Modify: `config/i18n/vi.json`
- Modify: `scripts/check_center_notch.js`
- Modify: `scripts/check_bar.py`
- Modify: `scripts/check_top_bar_style_lifecycle.js`

**Interfaces:**
- Consumes: `Motion.reduced`, shared transition/canvas progress, exact shape geometry, active style profile.
- Produces: reversible 220–250ms open, 180–200ms close, 90–180ms drag settle, matching masks, and translated keyboard-accessible controls.

- [ ] **Step 1: Write failing duration, mask, and accessibility contracts**

Require open duration within 220–250, close within 180–200, Reduced Motion zero-duration bindings,
and compact mask dimensions sourced from `connectedShape`. Require translated accessible names for
Primary, Secondary, Focus toggle, previous, play/pause, next, expand, and collapse.

- [ ] **Step 2: Run static tests and verify failure**

Run:

```bash
node scripts/check_center_notch.js
python3 scripts/check_bar.py
node scripts/check_top_bar_style_lifecycle.js
```

Expected: FAIL on hardcoded English Focus accessibility labels and incomplete keyboard contracts.

- [ ] **Step 3: Make geometry transitions explicitly reversible**

Use one `transitionProgress` animation whose `to` value follows ownership and whose `from` value is
the current progress whenever direction changes. Use 240ms opening and 190ms closing. Keep compact
and open content mounted; compute opacity from the shared progress. Do the same for
`canvasContentProgress` during Banner↔Expanded drag/settle.

- [ ] **Step 4: Derive mask and silhouette from the same geometry**

Compact/Satellite mask uses `connectedShape.x`, `connectedShape.y`, `connectedShape.width`, and
`compactInputHeight`. Open mask spans the eligible screen only for outside-click handling. Do not
paint a full-screen Rectangle. Confirm style switching cannot temporarily expose both Bar and
window Center hitboxes.

- [ ] **Step 5: Add translated accessibility copy**

Add matching English/Vietnamese keys for:

```text
center_island.primary.open
center_island.secondary.open
center_island.focus.enable
center_island.focus.disable
center_island.media.previous
center_island.media.play
center_island.media.pause
center_island.media.next
center_island.expand
center_island.collapse
```

Bind each interactive item's `Accessible.role`, `Accessible.name`, `Accessible.focusable`, and
Space/Enter activation. Decorative icons use an empty accessible name.

- [ ] **Step 6: Run static, lint, and smoke checks**

Run:

```bash
node scripts/check_center_notch.js
python3 scripts/check_bar.py
node scripts/check_top_bar_style_lifecycle.js
./scripts/check.sh
./scripts/smoke.sh
```

Expected: all pass in the default motion mode and no QML warning is added.

- [ ] **Step 7: Commit interaction hardening**

```bash
git add Titonium/Bar/notch config/i18n scripts/check_center_notch.js scripts/check_bar.py scripts/check_top_bar_style_lifecycle.js
git commit -m "fix: harden dynamic island interaction lifecycle"
```

---

### Task 7: Complete canonical acceptance and reconcile documentation

**Files:**
- Modify: `scripts/center_notch_acceptance.sh`
- Modify: `scripts/check_center_notch.js`
- Modify: `scripts/check.sh`
- Modify: `docs/ARCHITECTURE.md`
- Modify: `docs/CURRENT_AUDIT.md`
- Modify: `docs/TESTING.md`
- Modify: `docs/THEMING_AND_GLASS.md`
- Modify: `docs/ROADMAP.md`

**Interfaces:**
- Consumes: the complete unified Dynamic Island and existing safe IPC/fixture boundaries.
- Produces: repeatable acceptance for all canonical states, both styles, scale profiles, Reduced Motion, mutual exclusion, and repository isolation.

- [ ] **Step 1: Expand the acceptance matrix before changing production code**

Add named functions to `center_notch_acceptance.sh` for `assert_state_loop`,
`assert_satellite_targets`, `assert_notification_timeout`, `assert_drag_settle`,
`assert_agent_queue`, `assert_style_switch`, `assert_masks`, and `assert_reduced_motion`. Each helper
uses only test IPC/fixtures, restores its session state, and calls `require_contains` with a unique
failure context.

Require the script to test logical profiles representing scale 1.0 and 1.5 through deterministic
state/geometry fixtures; do not change the host compositor scale during automation.

- [ ] **Step 2: Run syntax and focused acceptance**

Run:

```bash
bash -n scripts/center_notch_acceptance.sh
./scripts/center_notch_acceptance.sh
```

Expected: the syntax check passes; any uncovered production defect fails with the relevant named
acceptance context. Fix only defects inside the approved Dynamic Island scope, rerunning the
smallest failing static test before rerunning live acceptance.

- [ ] **Step 3: Register all deterministic static contracts in the main gate**

Ensure `scripts/check.sh` invokes `check_center_notch.js` once and syntax-checks the expanded live
acceptance. Do not run the live script from `check.sh`; live execution remains an explicit focused
gate.

- [ ] **Step 4: Reconcile current documentation with the shipped architecture**

Update the five docs to state:

- one shared owner across Connected and Classic;
- Focus-primary and one Secondary selection instead of UI rotation;
- no detached Classic notification bell;
- lossless frozen context fallback;
- the exact static, foreground, and live acceptance commands.

Retain earlier specs/plans as historical documents and retain `docs/DYNAMIC_ISLAND.md` as canonical.

- [ ] **Step 5: Run the full required verification gates**

Run:

```bash
./scripts/check.sh
./scripts/smoke.sh
./scripts/center_notch_acceptance.sh
./scripts/protected_acceptance.sh
hyprctl configerrors
```

Expected: every command exits 0; `hyprctl configerrors` prints no configuration errors; git status
after acceptance matches status before acceptance.

- [ ] **Step 6: Inspect the final diff for scope and protected paths**

Run:

```bash
git diff --check
git status --short
git diff --name-status HEAD
```

Expected: no whitespace errors; no `hyprland.lua`, Spotlight, Input Method, runtime-data, or unrelated
dirty-worktree path is staged by this work.

- [ ] **Step 7: Commit acceptance and documentation**

```bash
git add scripts/center_notch_acceptance.sh scripts/check_center_notch.js scripts/check.sh docs/ARCHITECTURE.md docs/CURRENT_AUDIT.md docs/TESTING.md docs/THEMING_AND_GLASS.md docs/ROADMAP.md
git commit -m "test: verify unified dynamic island lifecycle"
```

---

## Final Review Checklist

- [ ] Point every requirement in `docs/superpowers/specs/2026-09-04-unified-dynamic-island-design.md` to a completed task above.
- [ ] Search the implementation and current docs for `ClassicCenterNotch`, detached Center notification ownership, and legacy Center pages; only historical docs may match.
- [ ] Confirm all public names used across tasks match: `normalizeContext`, `contextIdentity`, `activitySlots`, `CenterStyleProfile.profile`, and the four presentation component names.
- [ ] Confirm exactly one `CenterPillWindow`, one `ConnectedPillShape`, and zero Dynamic Island Loaders are instantiated per eligible screen.
- [ ] Confirm the final verification output was generated after the last code or documentation edit.
