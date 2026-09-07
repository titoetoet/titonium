#!/usr/bin/env python3
"""Exercise the real compact capsule with Qt pointer events and isolated preferences."""
import os
import re
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='titonium-compact-ui-') as temp:
    base = Path(temp)
    modules = base / 'qs/Titonium'
    for relative in ('Bar', 'Core/Runtime', 'Services/MediaSpectrum', 'Services/Center'):
        (modules / relative).mkdir(parents=True, exist_ok=True)
    for name in ('Theme',):
        (modules / name).symlink_to(ROOT / 'Titonium' / name, target_is_directory=True)
    shared = modules / 'Shared'
    shared.mkdir()
    (shared / 'Mascots').symlink_to(ROOT / 'Titonium/Shared/Mascots', target_is_directory=True)
    (shared / 'TextLabel.qml').symlink_to(ROOT / 'Titonium/Shared/TextLabel.qml')
    (shared / 'ConnectedPillShape.qml').symlink_to(ROOT / 'Titonium/Shared/ConnectedPillShape.qml')
    (shared / 'styles').symlink_to(ROOT / 'Titonium/Shared/styles', target_is_directory=True)
    (shared / 'qmldir').write_text('module qs.Titonium.Shared\nTextLabel 1.0 TextLabel.qml\nConnectedPillShape 1.0 ConnectedPillShape.qml\nSystemIcon 1.0 SystemIcon.qml\nStylePaint 1.0 StylePaint.qml\n')
    for name in ('InteractionFeedback.qml', 'InteractionState.js', 'StylePaint.qml',
                 'StyleFocusRing.qml', 'StyleRules.js'):
        (shared / name).symlink_to(ROOT / 'Titonium/Shared' / name)
    with (shared / 'qmldir').open('a') as exports:
        exports.write('InteractionFeedback 1.0 InteractionFeedback.qml\n')
    # Quickshell's native icon plugin is unavailable in qmltestrunner; only that boundary is replaced.
    (shared / 'SystemIcon.qml').write_text('import QtQuick\nItem { required property string sourceName; property string fallbackName; property int size: 20 }')
    (modules / 'Bar/center').symlink_to(ROOT / 'Titonium/Bar/center', target_is_directory=True)
    (base / 'qs/demos').symlink_to(ROOT / 'demos', target_is_directory=True)
    center = modules / 'Services/Center'
    (center / 'qmldir').write_text('module qs.Titonium.Services.Center\nsingleton FocusSessionService 1.0 FocusSessionService.qml\n')
    (center / 'FocusSessionService.qml').symlink_to(ROOT / 'Titonium/Services/Center/FocusSessionService.qml')
    audio = modules / 'Services/MediaSpectrum' 
    (audio / 'qmldir').write_text('module qs.Titonium.Services.MediaSpectrum\nsingleton MediaSpectrumService 1.0 MediaSpectrumService.qml\n')
    (audio / 'MediaSpectrumService.qml').write_text('pragma Singleton\nimport QtQuick\nQtObject { property var levels: [0,0,0,0] }')
    (modules / 'Services/Appearance').symlink_to(ROOT / 'Titonium/Services/Appearance', target_is_directory=True)
    runtime = modules / 'Core/Runtime' 
    (runtime / 'qmldir').write_text('module qs.Titonium.Core.Runtime\nsingleton Preferences 1.0 Preferences.qml\nsingleton I18n 1.0 I18n.qml\n')
    (runtime / 'Preferences.qml').write_text('''pragma Singleton
import QtQuick
QtObject {
 property bool reducedMotion: false
 readonly property var effectiveState: ({appearance: settings.appearance, accessibility: {reducedMotion: reducedMotion}})
 property var settings: ({appearance: {mode: "dark"}})
 property var bar: ({mascotEnabled: true, mascot: "pig", height: 44})
}''')
    (runtime / 'I18n.qml').write_text('''pragma Singleton
import QtQuick
QtObject { function tr(key, args) { return key; } }''')
    overlay_source = (ROOT / 'Titonium/Core/Surfaces/Center/CenterOverlayWindow.qml').read_text()
    hover_handler = re.search(r'HoverHandler \{ id: compactHover[^}]*\}', overlay_source).group(0)
    hover_handler = hover_handler.replace('compactHover', 'hostHover').replace('parent: renderer', 'parent: idleRenderer').replace('window.effectiveInputMode', 'hoverScene.hoverMode')
    (base / 'tst_compact.qml').write_text('''import QtQuick
import QtTest
import qs.Titonium.Core.Runtime
import qs.Titonium.Theme
import qs.Titonium.Bar.center
import qs.Titonium.Services.Center
import qs.Titonium.Shared as Shared

Item {
 id: hoverScene
 property string hoverMode: "compact"
 width: 900; height: 240
 Item {
  x: 20; y: 20; width: 300; height: 60
  Item { anchors.fill: parent; __HOST_HOVER__ }
  CenterCompactCapsule { id: idleRenderer; anchors.centerIn: parent; monitorWidth: 1920; snapshot: ({compact:{idle:true,primary:null,secondary:null}}) }
 }
 CenterCompactCapsule { id: capsule; anchors.centerIn: parent; monitorWidth: 1920; snapshot: ({compact: {idle: true, primary: null, secondary: null}}) }
 Component { id: feedbackComponent; Shared.InteractionFeedback { width: 80; height: 28 } }
 Component { id: titleComponent; CompactMediaTitle { width: 200; height: 24 } }
 Component { id: iconComponent; CompactActivityIcon { width: 24; height: 24 } }
 QtObject {
  id: intentBridge
  signal intentRequested(var intent)
  property Connections forwarding: Connections {
   target: capsule
   function onIntentRequested(intent) {
    if (intent.type !== "preview-enter" && intent.type !== "preview-leave") intentBridge.intentRequested(intent);
   }
  }
 }
 TestCase {
  name: "CenterCompactUI"
  when: windowShown
  SignalSpy { id: spy; target: intentBridge; signalName: "intentRequested" }
  SignalSpy { id: previewSpy; target: capsule; signalName: "intentRequested" }
  property var music: ({id: "media:current", source: "media", title: "Music", subtitle: "Artist", icon: "music_note", progress: null})
  property var job: ({id: "job:build", source: "job", title: "Build", icon: "terminal", progress: 0.78})
  function init() { Preferences.reducedMotion = true; Preferences.bar = {mascotEnabled: true, mascot: "pig", height: 44}; Metrics.barHeight = 44; spy.clear(); mouseMove(capsule, -100, -100); }
  function test_feedback_states_preserve_geometry() {
   const feedback = createTemporaryObject(feedbackComponent, capsule);
   compare(feedback.feedback.hover, 0);
   feedback.hovered = true;
   compare(feedback.feedback.hover, 1);
   feedback.selected = true;
   feedback.warning = true;
   feedback.pressed = true;
   compare(feedback.feedback.hover, 0);
   compare(feedback.feedback.press, 1);
   verify(feedback.feedback.active && feedback.feedback.warning);
   compare(feedback.width, 80); compare(feedback.height, 28); compare(feedback.scale, 1);
   feedback.enabled = false;
   compare(feedback.feedback.press, 0);
   verify(!feedback.feedback.active && !feedback.feedback.warning);
  }
  function test_media_title_and_scoped_wheel() {
   capsule.snapshot = {compact: {idle: false, primary: music, secondary: job}};
   wait(30);
   compare(capsule.primaryLabel, "Music - Artist");
   mouseWheel(capsule, 30, capsule.height / 2, 0, 120);
   compare(spy.count, 1);
   compare(spy.signalArguments[0][0].type, "compact-volume");
   compare(spy.signalArguments[0][0].contextId, music.id);
   spy.clear();
   mouseWheel(capsule, capsule.width - 12, capsule.height / 2, 0, 120);
   compare(spy.count, 0);
   capsule.snapshot = {compact: {idle: false, primary: job, secondary: music}};
   wait(30);
   mouseWheel(capsule, capsule.width - 12, capsule.height / 2, 0, -120);
   compare(spy.count, 1);
   verify(spy.signalArguments[0][0].delta < 0);
  }
  function test_capture_feedback_and_persistent_recording() {
   const recording = {id: "capture:recording:123", source: "capture", kind: "screen-recording", occurredAt: 123};
   const shot = {id: "capture:screenshot:one", source: "capture", kind: "screenshot", title: "Screenshot", details: {feedbackKind: "screenshot_saved"}};
   capsule.snapshot = {compact: {idle: false, primary: shot, secondary: {id: "focus:session", source: "focus"}, recordingIndicator: recording}};
   wait(30);
   compare(capsule.numericValue, "");
   compare(capsule.primaryLabel, "capture.screenshot_saved");
   verify(findChild(capsule, "persistentRecordingIndicator").visible);
   mouseClick(capsule, 30, capsule.height / 2);
   compare(spy.signalArguments[0][0].type, "activate-compact");
   capsule.snapshot = {compact: {idle: false, primary: recording, secondary: music}};
   verify(!findChild(capsule, "persistentRecordingIndicator").visible);
  }
  function test_focus_countdown() {
   capsule.snapshot = {compact: {idle: false, primary: {id: "focus:session", source: "focus", title: "Focus", details: {deadline: Date.now() + 71000}}, secondary: music}};
   wait(30);
   capsule.now = capsule.primary.details.deadline - 71000;
   compare(capsule.numericValue, "01:11");
   const oldWidth = capsule.width;
   capsule.now += 1000;
   compare(capsule.numericValue, "01:10");
   compare(capsule.width, oldWidth);
  }
  function test_focus_session_lifecycle() {
   verify(!FocusSessionService.start(0));
   verify(FocusSessionService.start(1));
   compare(FocusSessionService.session.durationMs, 1000);
   verify(FocusSessionService.session.deadline > Date.now());
   tryCompare(FocusSessionService, "session", null, 1500);
   verify(FocusSessionService.start(1500));
   FocusSessionService.cancel();
   compare(FocusSessionService.session, null);
  }
  function test_privacy_right_click() {
   const privacy = {id: "capture:recording", source: "capture", title: "REC", occurredAt: 123};
   capsule.snapshot = {compact: {idle: false, primary: privacy, secondary: music},
       capabilities: {actions: [{id: "capture.stop", contextId: privacy.id, label: "Stop Recording", enabled: true}]}};
   wait(30);
   mouseClick(capsule, 20, capsule.height / 2, Qt.RightButton);
   compare(spy.count, 0);
   compare(capsule.privacyMenuVisible, true);
   capsule.snapshot = {compact: {idle: false, primary: music, secondary: null}};
   tryCompare(capsule, "privacyMenuVisible", false);
  }
  function test_frequency_bars_and_focus_ring() {
   Preferences.reducedMotion = false;
   const icon = createTemporaryObject(iconComponent, capsule, {context: {source: "media", details: {playing: true}}, audioLevels: [0, .25, .6, 1]});
   wait(220);
   for (let i = 0; i < 4; ++i) {
    const bar = findChild(icon, "audioBar" + i);
    verify(bar !== null);
    verify(bar.height >= 3 && bar.height <= 14);
    if (i > 0) verify(bar.height > findChild(icon, "audioBar" + (i - 1)).height);

   }
   verify(findChild(icon, "audioBar4") === null);
   icon.satellite = true;
   wait(250);
   verify(findChild(icon, "audioBar3") === null);
   verify(findChild(icon, "audioBar2") !== null);
   Preferences.reducedMotion = true;
   wait(100);
   compare(findChild(icon, "audioBar2").height, 3);
   const stillBar = findChild(icon, "audioBar2");
   compare(stillBar.mapToItem(icon, 0, stillBar.height / 2).y, icon.height / 2);
   icon.context = {source: "focus", details: {deadline: 10000, durationMs: 10000}};
   icon.satellite = true;
   icon.now = 7500;
   compare(icon.remaining, .25);
   icon.now = 11000;
   compare(icon.remaining, 0);
  }
  function test_connected_notch_bounds_and_clicks() {
   capsule.connected = true;
   capsule.snapshot = {compact: {idle: false, primary: job, secondary: music}};
   wait(30);
   compare(capsule.visualBounds.y, capsule.y - 4);
   compare(capsule.visualBounds.x, capsule.x - 18);
   compare(capsule.visualBounds.width, capsule.width + 36);
   compare(capsule.clip, false);
   const notch = findChild(capsule, "connectedCompactNotch");
   verify(notch.visible);
   compare(notch.bodyWidth, capsule.width);
   mouseClick(capsule, capsule.width - 15, capsule.height / 2);
   compare(spy.signalArguments[0][0].type, "activate-compact");
   compare(spy.signalArguments[0][0].contextId, music.id);
   capsule.snapshot = {compact: {idle: true, primary: null, secondary: null}};
   verify(notch.visible);
   capsule.connected = false;
   compare(capsule.visualBounds.width, capsule.width);
   verify(!notch.visible);
  }
  function test_media_title_motion_contract() {
   Preferences.reducedMotion = false;
   const title = createTemporaryObject(titleComponent, capsule, {text: "A very long track title with enough words to overflow this small region", playing: true});
   compare(title.maximumWidth, 200);
   verify(title.overflowing);
   verify(title.scrolling, "playing overflow scrolls without hover");
   verify(!title.shimmerActive);
   wait(800);
   verify(title.scrollOffset > 0);
   title.playing = false;
   compare(title.scrollOffset, 0);
   verify(!title.shimmerActive);
   title.engaged = true;
   verify(title.scrolling, "hover can scroll paused media");
   title.engaged = false;
   title.text = "Short title";
   title.playing = true;
   verify(title.shimmerActive);
   Preferences.reducedMotion = true;
   title.playing = true; title.engaged = true;
   verify(!title.scrolling); verify(!title.shimmerActive);
  }
  function test_idle_host_hover_receives_pointer() {
   for (const mascot of ["pig", "dog"]) {
    Preferences.bar={mascotEnabled:true,mascot:mascot,height:44};
    mouseMove(idleRenderer,-100,-100);wait(30);compare(hostHover.hovered,false);
    mouseMove(idleRenderer,idleRenderer.width/2,idleRenderer.height/2);wait(350);
    verify(hostHover.hovered,"native host must retain hover over the actual idle mascot");
    hoverScene.hoverMode="none";wait(30);compare(hostHover.hovered,false);
    hoverScene.hoverMode="compact";
    mouseMove(idleRenderer,-100,-100);mouseMove(idleRenderer,idleRenderer.width/2,idleRenderer.height/2);wait(30);verify(hostHover.hovered);
    mouseMove(idleRenderer,-100,-100);wait(30);compare(hostHover.hovered,false);
   }
  }
  function test_idle_click() {
   capsule.snapshot = {compact: {idle: true, primary: null, secondary: null}};
   wait(30);
   mouseClick(capsule, capsule.width / 2, capsule.height / 2);
   compare(spy.count, 1);
   compare(spy.signalArguments[0][0].type, "activate-compact");
  }
  function test_primary_and_satellite() {
   capsule.snapshot = {compact: {idle: false, primary: job, secondary: music}};
   wait(30);
   mouseClick(capsule, capsule.width - 15, capsule.height / 2);
   compare(spy.count, 1);
   compare(spy.signalArguments[0][0].type, "activate-compact");
   compare(spy.signalArguments[0][0].contextId, "media:current");
   spy.clear();
   mouseClick(capsule, 35, capsule.height / 2);
   compare(spy.count, 1);
   compare(spy.signalArguments[0][0].type, "activate-compact");
  }
  function test_height_and_numeric_stability() {
   const recording = {id: "capture:recording", source: "capture", title: "REC", icon: "screen_record", occurredAt: Date.now() - 71000};
   capsule.snapshot = {compact: {idle: false, primary: recording, secondary: null}};
   wait(20);
   const oldWidth = capsule.width;
   capsule.now += 1000;
   compare(capsule.width, oldWidth);
   Metrics.barHeight = 64;
   compare(capsule.height, 56);
  }
  function test_dog_walk_and_style_bounds() {
   Preferences.bar = {mascotEnabled: true, mascot: "dog", height: 44};
   capsule.snapshot = {compact: {idle: true, primary: null, secondary: null}};
   Preferences.reducedMotion = false;
   wait(50);
   const dog = findChild(capsule, "pixelStageDog");
   verify(dog !== null);
   mouseMove(capsule, 5, capsule.height / 2); wait(50);
   compare(dog.hovered, false, "Curtain hover is not Dog hover");
   dog.cycleTime = 0;
   wait(250); verify(dog.walkProgress > 0 && dog.walkProgress < 0.25);
   tryVerify(() => dog.walkProgress === 1, 2500);
   verify(!dog.walkingBack);
   dog.cycleTime = 8300;
   dog.hovered = true;
   compare(dog.currentAction, "idle", "Hover must not freeze a halfway turn");
   verify(dog.reactionPending);
   dog.hovered = false;
   dog.reactionPending = false;
   dog.cycleTime = 8250; wait(30); verify(dog.turnScale < 1);
   wait(450); verify(dog.walkingBack && dog.walkProgress < 1);
   dog.cycleTime = 11000; wait(30); compare(dog.walkProgress, 0);
   dog.cycleTime = 11980; wait(150); verify(!dog.walkingBack && dog.walkProgress > 0);
   for (const connected of [false, true]) {
    capsule.connected = connected;
    for (const height of [40, 64]) {
     Metrics.barHeight = height; wait(30);
     compare(capsule.clip, false, "Paws must not be clipped in either style");
     compare(dog.height, height - 8);
    }
   }
   capsule.connected = false;
   Preferences.bar = {mascotEnabled: true, mascot: "pig", height: 44};
  }
  function test_dog_showcase_actions() {
   Preferences.bar = {mascotEnabled: true, mascot: "dog", height: 44};
   capsule.snapshot = {compact: {idle: true, primary: null, secondary: null}};
   Preferences.reducedMotion = false; wait(30);
   const dog = findChild(capsule, "pixelStageDog");
   verify(typeof dog.toggleWalkLoop === "function", "Existing showcase API remains usable");
   dog.toggleWalkLoop(); compare(dog.autoWalkLoop, false); compare(dog.walkState, "front");
   for (const pair of [["doWave", "wave"], ["doFeed", "feed"], ["doPet", "pet"], ["doBark", "bark"], ["toggleCurtains", "curtain"]]) {
    dog[pair[0]](); compare(dog.currentAction, pair[1]);
    wait(100); verify(dog.actionTime > 0);
    dog.actionTime = 2080; tryCompare(dog, "currentAction", "idle", 300);
   }
   dog.peekHovered = true; verify(dog.currentAction !== "idle");
   Preferences.reducedMotion = true; compare(dog.currentAction, "idle");
   Preferences.bar = {mascotEnabled: true, mascot: "pig", height: 44};
  }
  function test_idle_hover_never_opens_activity_preview() {
   for (const mascot of ["dog", "pig"]) {
    Preferences.bar = {mascotEnabled: true, mascot: mascot, height: 44};
    capsule.snapshot = {compact: {idle: true, primary: null, secondary: null}};
    mouseMove(capsule, -100, -100); wait(30); previewSpy.clear();
    mouseMove(capsule, capsule.width / 2, capsule.height / 2); wait(400);
    verify(!previewSpy.signalArguments.some(args => args[0].type === "preview-enter"), "Idle mascot must not request Focus Today preview");
   }
   capsule.snapshot = {compact: {idle: false, primary: music, secondary: null}};
   wait(30);
   verify(previewSpy.signalArguments.some(args => args[0].type === "preview-enter" && args[0].contextId === music.id), "Activity appearing beneath pointer gains preview");
   previewSpy.clear();
   capsule.snapshot = {compact: {idle: true, primary: null, secondary: null}};
   wait(30);
   verify(previewSpy.signalArguments.some(args => args[0].type === "preview-leave"), "Returning to idle cancels pending preview");
  }
  function test_dog_hover_and_lifecycle() {
   capsule.snapshot = {compact: {idle: true, primary: null, secondary: null}};
   Preferences.bar = {mascotEnabled: true, mascot: "dog", height: 44};
   Preferences.reducedMotion = false;
   wait(250);
   const dog = findChild(capsule, "pixelStageDog");
   verify(dog !== null, "Selected Dog must load");
   const oldWidth = capsule.width;
   mouseMove(capsule, capsule.width / 2, capsule.height / 2);
   tryVerify(() => dog.currentAction !== "idle", 3000, "hover=" + dog.hovered + " cycle=" + dog.cycleTime + " paused=" + dog.paused);
   const first = dog.lastReaction;
   wait(2600);
   compare(dog.currentAction, "idle");
   wait(300);
   compare(dog.lastReaction, first, "Holding hover must not repeat");
   mouseMove(capsule, -100, -100); wait(30);
   mouseMove(capsule, capsule.width / 2, capsule.height / 2);
   tryVerify(() => dog.currentAction !== "idle", 3000, "hover=" + dog.hovered + " cycle=" + dog.cycleTime + " paused=" + dog.paused);
   verify(dog.lastReaction !== first, "Next hover chooses another action");
   compare(capsule.width, oldWidth);
   spy.clear(); mouseClick(capsule, capsule.width / 2, capsule.height / 2);
   compare(spy.count, 1); compare(spy.signalArguments[0][0].type, "activate-compact");
   Preferences.reducedMotion = true;
   wait(30);
   compare(dog.currentAction, "idle"); compare(dog.walkProgress, 1);
   const phase = dog.cycleTime; wait(100); compare(dog.cycleTime, phase);
   Preferences.bar = {mascotEnabled: false, mascot: "dog", height: 44}; wait(30);
   verify(findChild(capsule, "pixelStageDog") === null, "Hidden Dog unloads");
   Preferences.bar = {mascotEnabled: true, mascot: "pig", height: 44};
  }
  function test_idle_hover_does_not_resize() {
   capsule.snapshot = {compact: {idle: true, primary: null, secondary: null}};
   Preferences.reducedMotion = false;
   wait(250);
   const oldWidth = capsule.width;
   const mascot = capsule.children.find(item => item.awake !== undefined);
   verify(mascot !== undefined);
   compare(mascot.awake, false);
   mouseMove(capsule, capsule.width / 2, capsule.height / 2);
   wait(200);
   compare(mascot.awake, true);
   verify(mascot.reaction >= 0 && mascot.reaction < 3);
   compare(capsule.width, oldWidth);
   compare(spy.count, 0);
   mouseMove(capsule, -100, -100);
   wait(250);
   compare(mascot.awake, false);
   compare(capsule.width, oldWidth);
  }
 }
}'''.replace('__HOST_HOVER__', hover_handler))
    env = dict(os.environ, QT_QPA_PLATFORM='offscreen', QML_IMPORT_PATH=str(base))
    result = subprocess.run(['/usr/lib/qt6/bin/qmltestrunner', '-input', str(base), '-import', str(base)], env=env)
    raise SystemExit(result.returncode)
