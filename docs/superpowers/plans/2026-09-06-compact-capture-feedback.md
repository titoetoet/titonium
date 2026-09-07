# Compact capture feedback implementation plan

> Execute the approved scope in this session. Use test-driven development and a
> bounded preview subagent, followed by review. Preserve existing uncommitted work.

**Goal:** Priority-owned slots, direct activity opening, and six-second capture feedback.
**Architecture:** Pure CompactActivityRules owns ranking/projection. A shared
CaptureFeedbackService consumes existing recording and notification signals and owns
one expiry timer plus a retained selected screenshot. Domain exposes descriptors;
controller routes slot activation; renderers lazily load the same screenshot preview.
**Tech Stack:** QML, QtQuick, existing Quickshell notifications, JavaScript, Node tests.
**Spec:** ../specs/2026-09-05-center-island-idle-compact-design.md

## Constraints and rulings

- Focus > Privacy/Recording > Media; no swap or pin.
- Capture announcements override Primary for 6000ms, previous activity in Satellite.
- Keep recording indicator visible; expiry never closes a user-opened Normal.
- No new native listener, process, dependency, clipboard writes or Hyprland edits.
- Existing screenshot.sh emits `Screenshot saved` plus absolute PNG path through
  NotificationService.descriptorPublished. Consume this existing native boundary.
- Ruling: overlapping feedback is latest-wins; selected screenshot remains retained.
- Ruling: do not create a clean checkout that drops the substantial uncommitted UI
  implementation. Work in the authorized workspace; test native lifecycle in a temp copy.
- Original Titonium implementation, using existing in-repo signal/adapter patterns;
  no external code adaptation or license dependency needed.

## Task 1: Slots and activation

Files: CompactActivityRules.js, CenterDomain.qml, CenterSurfaceController.qml,
CenterCompactCapsule.qml, config/i18n/{en,vi}.json; check_center_compact.js and UI test.
- [x] Replace old swap expectations with priority, stable ties and direct opening assertions.
- [x] Run `node scripts/check_center_compact.js` and UI runner; observe expected failures.
- [x] Rank Focus at 400, capture at 300, media at 100; remove manual demotion state.
- [x] Emit `activate-compact` with contextId for Satellite and validate against visible slots.
- [x] Run focused tests, checking slot selection and volume/menu regression.

## Task 2: Capture feedback

Files: new CaptureFeedbackRules.js / CaptureFeedbackService.qml in Services/Capture;
Capture qmldir; CenterDomain.qml; CaptureCenterAdapter.qml; compact icon/capsule.
- [x] Add tests for `screenshot(descriptor, now)`, `recording(startedAt, now)` and
  `project(selection, contexts, feedback)` including expiry, exact encoded image URL,
  Focus+Recording+Screenshot, no replay on repeated metadata and selected-image retention.
- [x] Observe failing tests, then implement a 6000ms feedback service using existing signals.
- [x] Add screenshot contexts with stable event ids; retain only active and selected images.
- [x] Suppress recording_started/screenshot_saved automatic Banner routing in Domain.
- [x] Project feedback into Compact without changing open surface selection or deadlines.
- [x] Verify no source event changes an already open Normal/Expanded.

## Task 3: Preview and final verification

Files: ScreenshotPreviewContent.qml, Bar/center/qmldir, Connected/Classic renderers,
new screenshot UI test, scripts/check.sh and architecture notes.
- [x] Add a preview test with two local fixture image URLs and missing-image fallback.
- [x] Implement lazy, bounded, aspect-preserving screenshot Normal in both themes.
- [x] Verify selected-image identity across new events and expiry; test renderer integration.
- [x] Run ./scripts/check.sh, ./scripts/smoke.sh, ./scripts/protected_acceptance.sh,
  hyprctl configerrors, git diff --check; record any environment skips honestly.
- [x] Final independent review and reload after checks pass.

## Verification evidence

- Initial priority and Satellite activation tests failed against old implementation;
  updated domain and 14 Compact UI cases now pass.
- Capture feedback reducer tests cover exact escaped URL, rejection of unrelated or
  non-local paths, replacement, expiry, retained selection and privacy projection.
- Real feedback singleton QML tests cover native-boundary signals, 6s timer,
  selected image retention and recording update deduplication (4 passed).
- Screenshot UI tests exercise both actual renderers and the shared preview (4 passed).
- Recording session QML tests reject stale Stop and close expired-session Normal (3 passed).
- Real controller routing/deadline tests (9 passed), including Satellite context validation.
- `./scripts/check.sh`: exit 0; qmllint retains existing platform-type warnings.
- Final native `smoke.sh`: PASS. `protected_acceptance.sh`: PASS using temporary copy
  `/tmp/titonium-capture-acceptance-f7gq4m4h` with isolated runtime data. Native notification
  acceptance skipped because the resident shell owns its D-Bus name.
- `hyprctl configerrors`: empty. `git diff --check`: pass.
- No Hyprland configuration or clipboard data changed.

- Independent final review found no actionable issues. Resident Titonium reloaded after
  the old instance completed shutdown; Configuration Loaded successfully.
