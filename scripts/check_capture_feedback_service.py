#!/usr/bin/env python3
"""Run actual feedback singleton against native-boundary signal fakes."""
import os, subprocess, tempfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='titonium-feedback-service-') as tmp:
    base=Path(tmp)
    def put(path,text):
        p=base/path;p.parent.mkdir(parents=True,exist_ok=True);p.write_text(text)
    put('Quickshell/qmldir','module Quickshell\nsingleton Quickshell 1.0 Quickshell.qml\n')
    put('Quickshell/Quickshell.qml','pragma Singleton\nimport QtQuick\nQtObject { function env(key) {return "/home/test";} }')
    cap='qs/Titonium/Services/Capture/'
    put(cap+'qmldir','module qs.Titonium.Services.Capture\nsingleton CaptureFeedbackService 1.0 CaptureFeedbackService.qml\nsingleton ScreenRecordService 1.0 ScreenRecordService.qml\n')
    for file in ['CaptureFeedbackService.qml','CaptureFeedbackRules.js']:
        (base/cap/file).symlink_to(ROOT/'Titonium/Services/Capture'/file)
    put(cap+'ScreenRecordService.qml','pragma Singleton\nimport QtQuick\nQtObject { property bool recording: false; property double startedAt: 0 }')
    put('qs/Titonium/Services/Notifications/qmldir','module qs.Titonium.Services.Notifications\nsingleton NotificationService 1.0 NotificationService.qml\n')
    put('qs/Titonium/Services/Notifications/NotificationService.qml','pragma Singleton\nimport QtQuick\nQtObject {signal descriptorPublished(var descriptor)}')
    put('qs/Titonium/Core/Runtime/qmldir','module qs.Titonium.Core.Runtime\nsingleton I18n 1.0 I18n.qml\n')
    put('qs/Titonium/Core/Runtime/I18n.qml','pragma Singleton\nimport QtQuick\nQtObject {function tr(key) {return key;}}')
    put('tst_feedback.qml','''import QtQuick
import QtTest
import qs.Titonium.Services.Capture
import qs.Titonium.Services.Notifications
TestCase {
 name: "CaptureFeedbackService"
 function init() { ScreenRecordService.recording=false; wait(20); CaptureFeedbackService.select(""); }
 function test_events_expiry_and_retention() {
  NotificationService.descriptorPublished({key:"first",summary:"Screenshot saved",body:"/home/test/Pictures/Screenshots/one.png"});
  const first=CaptureFeedbackService.feedback;
  verify(first!==null);
  CaptureFeedbackService.select(first.contextId);
  NotificationService.descriptorPublished({key:"second",summary:"Screenshot saved",body:"/home/test/Pictures/Screenshots/two.png"});
  compare(CaptureFeedbackService.contexts.length,2);
  tryCompare(CaptureFeedbackService,"feedback",null,6500);
  compare(CaptureFeedbackService.contexts.length,1);
  compare(CaptureFeedbackService.contexts[0].details.imageUrl,"file:///home/test/Pictures/Screenshots/one.png");
  CaptureFeedbackService.select("");
  compare(CaptureFeedbackService.contexts.length,0);
 }
 function test_recording_does_not_reannounce_updates() {
  ScreenRecordService.startedAt=123;
  ScreenRecordService.recording=true;
  wait(30);
  const expiry=CaptureFeedbackService.feedback.expiresAt;
  CaptureFeedbackService.syncRecording();
  compare(CaptureFeedbackService.feedback.expiresAt,expiry);
  ScreenRecordService.recording=false;
  tryCompare(CaptureFeedbackService,"feedback",null);
 }
}''')
    result=subprocess.run(['/usr/lib/qt6/bin/qmltestrunner','-input',str(base),'-import',str(base)],env={**os.environ,'QT_QPA_PLATFORM':'offscreen','QT_QUICK_BACKEND':'software'})
    raise SystemExit(result.returncode)
