#!/usr/bin/env python3
"""Exercise the real Center deadline controller without a compositor."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='titonium-center-deadline-') as directory:
    base = Path(directory)
    domain = base / 'qs/Titonium/Services/Center'
    domain.mkdir(parents=True)
    (domain / 'qmldir').write_text('module qs.Titonium.Services.Center\nsingleton CenterDomain 1.0 CenterDomain.qml\n')
    (domain / 'CenterDomain.qml').write_text('''pragma Singleton
import QtQuick
QtObject {
 property var snapshot: ({contexts: [{id: "notification:test", source: "notification", attention: "transient"}], primary: {id: "notification:test"}})
 property var presentationSnapshot: ({compact: {primary: null, secondary: null}})
 property string retainedCaptureId: ""
 function selectCaptureContext(contextId) { retainedCaptureId = contextId; }
 property int completed: 0
 signal presentationRequested(var request)
 signal presentationEnded(var request)
 function setPresentationEligible(eligible) { return false; }
 function completePresentation(contextId) { completed++; return {accepted: true, closePolicy: "compact"}; }
 function dispatch(intent) { return {accepted: false}; }
}
''')
    for module_name, type_name, body in (
        ('Services/Mpris', 'MprisService', 'property bool detailsActive: false; property int calls: 0; function adjustVolume(identity, delta) { calls++; return true; }'),
        ('Services/SystemMonitor', 'SystemMonitorService', 'property bool active: false; property int starts: 0; function start() { starts++; active = true; return true; } function stop() { active = false; return true; }'),
        ('Services/MediaSpectrum', 'MediaSpectrumService', 'property bool enabled: false'),
        ('Core/Runtime', 'BarVisibilityState', 'property bool revealed: true'),
        ('Theme', 'Motion', 'property bool reduced: false'),
    ):
        folder = base / 'qs/Titonium' / module_name
        folder.mkdir(parents=True, exist_ok=True)
        (folder / 'qmldir').write_text('module qs.Titonium.' + module_name.replace('/', '.') + '\nsingleton ' + type_name + ' 1.0 ' + type_name + '.qml\n')
        (folder / (type_name + '.qml')).write_text('pragma Singleton\nimport QtQuick\nQtObject {' + body + '}')
    controller = base / 'qs/Titonium/Core/Surfaces/Center' 
    controller.mkdir(parents=True)
    (controller / 'qmldir').write_text('module qs.Titonium.Core.Surfaces.Center\nsingleton CenterSurfaceController 1.0 CenterSurfaceController.qml\n')
    for name in ('CenterSurfaceController.qml', 'CenterSurfaceState.js', 'CenterPreviewRules.js', 'ExpandedNavigation.js'):
        shutil.copyfile(ROOT / 'Titonium/Core/Surfaces/Center' / name, controller / name)
    (base / 'tst_deadline.qml').write_text('''import QtQuick
import QtTest
import qs.Titonium.Services.Center
import qs.Titonium.Core.Surfaces.Center
import qs.Titonium.Services.MediaSpectrum
import qs.Titonium.Services.Mpris
import qs.Titonium.Services.SystemMonitor
import qs.Titonium.Core.Runtime
import qs.Titonium.Theme
TestCase {
 name: "CenterDeadline"
 function init() {
  CenterDomain.completed = 0;
  CenterDomain.snapshot = {contexts: [{id: "notification:test", source: "notification", attention: "transient"}], primary: {id: "notification:test"}};
  CenterSurfaceController.dispatch({type: "surface-granted", screenName: "test"});
  CenterSurfaceController.dispatch({type: "present", contextId: "notification:test", requestedMode: "banner", timeoutMs: 60000, presentationOwner: "notification-critical"});
  verify(CenterSurfaceController.deadlineTimer.running);
 }
 function cleanup() { CenterSurfaceController.dispatch({type: "dismiss"}); }
 SignalSpy { id: openSpy; target: CenterSurfaceController; signalName: "surfaceRequested" }
 // Advance only the preview clock; callbacks still exercise the real controller.
 function firePreview(action) {
  const changes = action === "open" ? {openAt: Date.now() - 1} : {openAt: 0, closeAt: Date.now() - 1};
  CenterSurfaceController.preview = Object.assign({}, CenterSurfaceController.preview, changes);
  CenterSurfaceController.previewTimer.stop();
  CenterSurfaceController.previewTimer.triggered();
 }
 function openHover() {
  CenterSurfaceController.dispatch({type: "surface-granted", screenName: "test"});
  CenterSurfaceController.dispatch({type: "set-presentation-available", available: true});
  CenterSurfaceController.dispatch({type: "preview-enter", region: "primary", contextId: "notification:test"});
  firePreview("open");
  compare(CenterSurfaceController.mode, "banner");
  compare(CenterSurfaceController.presentationOwner, "hover");
 }
 function test_empty_compact_hover_does_not_reopen_selected_focus() {
  CenterSurfaceController.dispatch({type: "surface-granted", screenName: "test"});
  CenterSurfaceController.dispatch({type: "set-presentation-available", available: true});
  const focus = {id: "focus:today", source: "focus", attention: "ambient"};
  CenterDomain.snapshot = {contexts: [focus], primary: focus};
  CenterSurfaceController.dispatch({type: "present", contextId: focus.id, requestedMode: "banner"});
  CenterSurfaceController.dispatch({type: "request-mode", mode: "compact"});
  compare(CenterSurfaceController.selectedContextId, focus.id);
  CenterSurfaceController.dispatch({type: "preview-enter", region: "primary", contextId: ""});
  wait(400);
  compare(CenterSurfaceController.mode, "compact");
  compare(CenterSurfaceController.preview.openAt, 0);
 }
 function test_hover_open_retains_content_without_second_enter() {
  openHover();
  compare(CenterSurfaceController.heldPreviewContext.id, "notification:test");
  CenterDomain.snapshot = {contexts: [], primary: null};
  compare(CenterSurfaceController.viewState.previewContext.id, "notification:test");
  CenterSurfaceController.dispatch({type: "preview-leave", region: "primary"});
  firePreview("close");
  compare(CenterSurfaceController.mode, "compact");
  compare(CenterSurfaceController.heldPreviewContext, null);
 }
 function test_timed_replacement_pauses_and_resumes_after_shared_leave() {
  CenterSurfaceController.dispatch({type: "preview-enter", region: "primary"});
  CenterSurfaceController.dispatch({type: "preview-enter", region: "banner"});
  const stale = CenterSurfaceController.previewDeadlineIntent("timeout");
  const replacement = {id: "notification:next", source: "notification", attention: "transient"};
  CenterDomain.snapshot = {contexts: [replacement], primary: replacement};
  CenterSurfaceController.dispatch({type: "present", contextId: replacement.id, requestedMode: "banner", timeoutMs: 60000, presentationOwner: "notification-critical"});
  compare(CenterSurfaceController.internalState.deadline, 0);
  verify(CenterSurfaceController.internalState.remainingMs > 0);
  compare(CenterSurfaceController.heldPreviewContext.id, replacement.id);
  CenterSurfaceController.dispatch(stale);
  compare(CenterDomain.completed, 0);
  CenterSurfaceController.dispatch({type: "preview-leave", region: "primary"});
  verify(!CenterSurfaceController.previewTimer.running);
  compare(CenterSurfaceController.internalState.deadline, 0);
  CenterSurfaceController.dispatch({type: "preview-leave", region: "banner"});
  verify(CenterSurfaceController.previewTimer.running);
  compare(CenterSurfaceController.internalState.deadline, 0);
  firePreview("close");
  verify(CenterSurfaceController.deadlineTimer.running);
  compare(CenterSurfaceController.mode, "banner");
  compare(CenterSurfaceController.internalState.remainingMs, 0);
 }
 function test_retained_banner_click_routes_source_without_stale_id() {
  const focus = {id: "focus:expired", source: "focus", attention: "ambient"};
  CenterSurfaceController.dispatch({type: "surface-granted", screenName: "test"});
  CenterDomain.snapshot = {contexts: [focus], primary: focus};
  CenterSurfaceController.dispatch({type: "present", contextId: focus.id, requestedMode: "banner", presentationOwner: "hover"});
  CenterSurfaceController.dispatch({type: "preview-enter", region: "banner"});
  CenterDomain.snapshot = {contexts: [], primary: null};
  openSpy.clear();
  verify(CenterSurfaceController.dispatch({type: "activate-preview", contextId: focus.id}));
  compare(openSpy.count, 1);
  const request = openSpy.signalArguments[0][0];
  compare(request.mode, "expanded");
  compare(request.destination, "tasks");
  compare(request.contextId, "");
  compare(CenterDomain.completed, 0);
 }
 function test_rejected_present_preserves_retained_banner() {
  openHover();
  const retained = CenterSurfaceController.heldPreviewContext;
  CenterDomain.snapshot = {contexts: [], primary: null};
  verify(!CenterSurfaceController.dispatch({type: "present", contextId: "missing", requestedMode: "banner", presentationOwner: "other"}));
  compare(CenterSurfaceController.heldPreviewContext, retained);
 }
 function test_replacement_during_leave_grace_still_closes_hover() {
  openHover();
  CenterSurfaceController.dispatch({type: "preview-leave", region: "primary"});
  const replacement = {id: "media:current", source: "media", attention: "ambient"};
  CenterDomain.snapshot = {contexts: [replacement], primary: replacement};
  verify(CenterSurfaceController.dispatch({type: "present", contextId: replacement.id, requestedMode: "banner", presentationOwner: "hover"}));
  firePreview("close");
  compare(CenterSurfaceController.mode, "compact", "accepted replacement must not strand an untimed hover banner");
 }
 function test_normal_request_defers_until_hover_leave() {
  openHover();
  const next = {id: "media:current", source: "media", attention: "ambient"};
  CenterDomain.snapshot = {contexts: [CenterSurfaceController.heldPreviewContext, next], primary: next};
  const request = {contextId: next.id, ownerId: "media", requestedMode: "banner", timeoutMs: 3000};
  openSpy.clear();
  CenterDomain.presentationRequested(request);
  compare(openSpy.count, 0);
  compare(CenterSurfaceController.pendingPreviewPresentation.contextId, next.id);
  CenterSurfaceController.dispatch({type: "preview-leave", region: "primary"});
  firePreview("close");
  compare(openSpy.count, 1);
  compare(openSpy.signalArguments[0][0].contextId, next.id);
  compare(CenterSurfaceController.pendingPreviewPresentation, null);
 }
 function test_deferred_normal_does_not_preempt_approval() {
  openHover();
  const normal = {id: "media:current", source: "media", attention: "ambient"};
  const approval = {id: "agent:pending", source: "agent", attention: "blocking"};
  CenterDomain.snapshot = {contexts: [CenterSurfaceController.heldPreviewContext, normal, approval], primary: approval};
  openSpy.clear();
  CenterDomain.presentationRequested({contextId: normal.id, ownerId: "media", acquisitionPolicy: "preemptive", requestedMode: "banner", timeoutMs: 3000});
  compare(openSpy.count, 0);
  compare(CenterSurfaceController.pendingPreviewPresentation.contextId, normal.id);
  CenterDomain.presentationRequested({contextId: approval.id, ownerId: "agent", acquisitionPolicy: "preemptive", requestedMode: "banner", focusPolicy: "exclusive", timeoutMs: 0});
  compare(openSpy.count, 1, "blocking approval must bypass normal deferral");
  compare(openSpy.signalArguments[0][0].contextId, approval.id);
  // Apply the synchronous grant/present sequence used by SurfaceRouter.
  CenterSurfaceController.dispatch({type: "surface-granted", screenName: "test"});
  CenterSurfaceController.dispatch({type: "present", contextId: approval.id, requestedMode: "banner", presentationOwner: "agent", focusPolicy: "exclusive", timeoutMs: 0});
  compare(CenterSurfaceController.presentationOwner, "agent");
  openSpy.clear();
  CenterDomain.presentationRequested({contextId: normal.id, ownerId: "media", acquisitionPolicy: "preemptive", requestedMode: "banner", timeoutMs: 3000});
  compare(openSpy.count, 0, "new normal work must also respect the blocking owner");
  compare(CenterSurfaceController.pendingPreviewPresentation, null);
  CenterSurfaceController.dispatch({type: "preview-leave", region: "primary"});
  firePreview("close");
  compare(openSpy.count, 0, "normal replay must not acquire over a blocking approval");
  compare(CenterSurfaceController.presentationOwner, "agent");
  compare(CenterSurfaceController.internalState.focusPolicy, "exclusive");
  compare(CenterSurfaceController.internalState.deadline, 0);
 }
 function test_ended_deferred_request_is_discarded() {
  openHover();
  const normal = {id: "media:current", source: "media", attention: "ambient"};
  const original = CenterSurfaceController.heldPreviewContext;
  CenterDomain.snapshot = {contexts: [original, normal], primary: normal};
  CenterDomain.presentationRequested({id: "media:event:presentation", contextId: normal.id, ownerId: "media", acquisitionPolicy: "preemptive", requestedMode: "banner", timeoutMs: 3000});
  compare(CenterSurfaceController.pendingPreviewPresentation.contextId, normal.id);
  CenterDomain.snapshot = {contexts: [original], primary: original};
  CenterDomain.presentationEnded({id: "media:event:presentation", contextId: normal.id, ownerId: "media"});
  compare(CenterSurfaceController.pendingPreviewPresentation, null, "end signal must cancel before deferred replay");
  openSpy.clear();
  CenterSurfaceController.dispatch({type: "preview-leave", region: "primary"});
  firePreview("close");
  compare(openSpy.count, 0, "ended or missing deferred content must not reacquire a surface");
  compare(CenterSurfaceController.pendingPreviewPresentation, null);
  compare(CenterSurfaceController.mode, "compact");
 }
 function test_expand_or_revoke_cancels_preview_and_deadlines() {
  for (const intent of [{type: "request-mode", mode: "expanded"}, {type: "surface-revoked"}]) {
   CenterSurfaceController.dispatch({type: "surface-granted", screenName: "test"});
   CenterSurfaceController.dispatch({type: "present", contextId: "notification:test", requestedMode: "banner", timeoutMs: 60000, presentationOwner: "notification-critical"});
   CenterSurfaceController.dispatch({type: "preview-enter", region: "banner"});
   const stale = CenterSurfaceController.previewDeadlineIntent("timeout");
   CenterSurfaceController.dispatch({type: "preview-leave", region: "banner"});
   CenterSurfaceController.pendingPreviewPresentation = {contextId: "pending"};
   CenterSurfaceController.dispatch(intent);
   const expectedMode = intent.type === "surface-revoked" ? "closed" : "expanded";
   compare(CenterSurfaceController.mode, expectedMode);
   verify(!CenterSurfaceController.previewTimer.running);
   verify(!CenterSurfaceController.deadlineTimer.running);
   compare(CenterSurfaceController.preview.regions.length, 0);
   compare(CenterSurfaceController.pendingPreviewPresentation, null);
   compare(CenterSurfaceController.heldPreviewContext, null);
   compare(CenterSurfaceController.internalState.deadlineToken, 0);
   CenterSurfaceController.dispatch(stale);
   CenterSurfaceController.previewTimer.triggered();
   compare(CenterSurfaceController.mode, expectedMode);
   compare(CenterDomain.completed, 0);
  }
 }
 function test_satellite_opens_its_context_without_reassignment() {
  CenterSurfaceController.dispatch({type: "surface-granted", screenName: "test"});
  const primary = {id: "focus:session", source: "focus"};
  const satellite = {id: "media:current", source: "media"};
  CenterDomain.presentationSnapshot = {compact: {primary: primary, secondary: satellite}};
  CenterDomain.snapshot = {contexts: [primary, satellite], primary: primary};
  openSpy.clear();
  verify(CenterSurfaceController.dispatch({type: "activate-compact", contextId: satellite.id}));
  compare(openSpy.count, 1);
  compare(openSpy.signalArguments[0][0].contextId, satellite.id);
  compare(openSpy.signalArguments[0][0].mode, "expanded");
  compare(openSpy.signalArguments[0][0].destination, "dashboard");
  compare(openSpy.signalArguments[0][0].timeoutMs, 0);
  compare(CenterDomain.presentationSnapshot.compact.primary.id, primary.id);
  verify(!CenterSurfaceController.dispatch({type: "activate-compact", contextId: "stale"}));
  compare(openSpy.count, 1);
 }
 function test_expanded_services_follow_visible_tab() {
  CenterSurfaceController.dispatch({type:"request-mode",mode:"expanded"});
  CenterSurfaceController.dispatch({type:"select-tab",tab:"dashboard"});
  verify(MprisService.detailsActive);
  verify(!SystemMonitorService.active);
  CenterSurfaceController.dispatch({type:"select-tab",tab:"monitoring"});
  verify(SystemMonitorService.active);
  verify(!MprisService.detailsActive);
  const starts = SystemMonitorService.starts;
  CenterSurfaceController.dispatch({type:"select-tab",tab:"monitoring"});
  compare(SystemMonitorService.starts, starts);
  CenterSurfaceController.dispatch({type:"select-tab",tab:"tasks"});
  verify(!SystemMonitorService.active);
  CenterSurfaceController.dispatch({type:"select-tab",tab:"monitoring"});
  verify(SystemMonitorService.active);
  CenterSurfaceController.dispatch({type:"surface-revoked"});
  verify(!SystemMonitorService.active);
  verify(!MprisService.detailsActive);
 }
 function test_compact_audio_demand_and_scoping() {
  CenterSurfaceController.dispatch({type: "surface-granted", screenName: "test"});
  CenterDomain.presentationSnapshot = {compact: {primary: {id: "media:current", source: "media", details: {playing: true}}, secondary: null}};
  compare(MediaSpectrumService.enabled, true);
  BarVisibilityState.revealed = false;
  compare(MediaSpectrumService.enabled, false);
  BarVisibilityState.revealed = true;
  Motion.reduced = true;
  compare(MediaSpectrumService.enabled, false);
  Motion.reduced = false;
  compare(CenterSurfaceController.dispatch({type: "compact-volume", contextId: "stale", identity: "player", delta: .05}), false);
  compare(CenterSurfaceController.dispatch({type: "compact-volume", contextId: "media:current", identity: "player", delta: .05}), true);
  CenterDomain.presentationSnapshot = {compact: {primary: null, secondary: null}};
  compare(MediaSpectrumService.enabled, false);
 }
 function test_privacy_rejects_replaced_session() {
  CenterSurfaceController.dispatch({type: "surface-granted", screenName: "test"});
  CenterDomain.snapshot = {contexts: [{id: "capture:recording", source: "capture", occurredAt: 200}]};
  compare(CenterSurfaceController.dispatch({type: "compact-privacy-action", contextId: "capture:recording", occurredAt: 100, actionId: "capture.stop"}), false);
  CenterDomain.snapshot = {contexts: [{id: "notification:test", source: "notification", attention: "transient"}], primary: {id: "notification:test"}};
 }
 function test_earlyCallbackRearms() {
  const before = CenterSurfaceController.internalState;
  // A one-shot timer is already stopped when its callback arrives.
  CenterSurfaceController.deadlineTimer.stop();
  CenterSurfaceController.deadlineTimer.triggered();
  compare(CenterDomain.completed, 0, "an early callback must not expire the banner");
  compare(CenterSurfaceController.internalState, before);
  verify(CenterSurfaceController.deadlineTimer.running, "an early callback must rearm the remaining deadline");
 }
 function test_staleCallbackDoesNotRearm() {
  const stale = CenterSurfaceController.scheduledDeadlineIntent();
  CenterSurfaceController.dispatch({type: "present", contextId: "notification:test", requestedMode: "banner", timeoutMs: 120000, presentationOwner: "notification-critical"});
  CenterSurfaceController.deadlineTimer.stop();
  compare(CenterSurfaceController.dispatch(stale), false);
  verify(!CenterSurfaceController.deadlineTimer.running, "stale callbacks must not schedule work");
  compare(CenterDomain.completed, 0);
 }
 function test_pausedCallbackStaysPaused() {
  const scheduled = CenterSurfaceController.scheduledDeadlineIntent();
  CenterSurfaceController.dispatch(Object.assign({}, scheduled, {type: "pause-timeout"}));
  CenterSurfaceController.dispatch(scheduled);
  verify(!CenterSurfaceController.deadlineTimer.running);
  compare(CenterSurfaceController.internalState.deadline, 0);
  compare(CenterDomain.completed, 0);
 }
 function test_dueCallbackCompletesOnce() {
  const due = Date.now() - 1;
  CenterSurfaceController.internalState = Object.assign({}, CenterSurfaceController.internalState, {deadline: due, deadlineToken: due});
  const intent = {type: "timeout", generation: CenterSurfaceController.generation, contextId: "notification:test", deadline: due};
  CenterSurfaceController.dispatch(intent);
  compare(CenterDomain.completed, 1);
  compare(CenterSurfaceController.mode, "compact");
  CenterSurfaceController.dispatch(intent);
  compare(CenterDomain.completed, 1);
  verify(!CenterSurfaceController.deadlineTimer.running);
 }
}
''')
    runner = shutil.which('qmltestrunner') or '/usr/lib/qt6/bin/qmltestrunner'
    result = subprocess.run([runner, '-input', str(base), '-import', str(base)],
                            env=dict(os.environ, QT_QPA_PLATFORM='offscreen', QML_DISABLE_DISK_CACHE='1'))
    raise SystemExit(result.returncode)
