#!/usr/bin/env python3
"""Reject recording actions from retired sessions using the real capture adapter."""
import os, subprocess, tempfile
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='titonium-capture-session-') as tmp:
    base = Path(tmp)
    def put(path, content):
        target = base / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(content)
    def singleton(module, name, body):
        folder = module.replace('.', '/')
        put(folder + '/qmldir', 'module ' + module + '\nsingleton ' + name + ' 1.0 ' + name + '.qml\n')
        put(folder + '/' + name + '.qml', 'pragma Singleton\nimport QtQuick\nQtObject {' + body + '}')
    singleton('qs.Titonium.Services.Capture', 'ScreenRecordService', 'property bool recording:true; property double startedAt:100; property real elapsedSeconds:0; property bool canStop:true; property int calls:0; function stopRecording() {calls++;return true;}')
    cap=base/'qs/Titonium/Services/Capture'
    with (cap/'qmldir').open('a') as f: f.write('singleton CaptureFeedbackService 1.0 CaptureFeedbackService.qml\n')
    put('qs/Titonium/Services/Capture/CaptureFeedbackService.qml','pragma Singleton\nimport QtQuick\nQtObject {property var contexts:[]}')
    singleton('qs.Titonium.Services.Audio','AudioService','property var captureStreams:[]')
    singleton('qs.Titonium.Core.Runtime','I18n','function tr(key) {return key;}')
    put('CaptureCenterAdapter.qml',(ROOT/'Titonium/Services/Center/adapters/CaptureCenterAdapter.qml').read_text())
    put('tst_session.qml','''import QtQuick
import QtTest
import qs.Titonium.Services.Capture
TestCase {
 name:"RecordingSession"
 CaptureCenterAdapter {id:adapter}
 function test_retired_session_cannot_stop_replacement() {
  const oldId=adapter.recordingContexts[0].id;
  compare(oldId,"capture:recording:100");
  compare(adapter.recordingActions[0].contextId,oldId);
  ScreenRecordService.startedAt=200;
  compare(adapter.recordingContexts[0].id,"capture:recording:200");
  verify(!adapter.dispatch("capture.stop",oldId,"").accepted);
  compare(ScreenRecordService.calls,0);
  verify(adapter.dispatch("capture.stop",adapter.recordingContexts[0].id,"").accepted);
  compare(ScreenRecordService.calls,1);
 }
}''')
    result=subprocess.run(['/usr/lib/qt6/bin/qmltestrunner','-input',str(base),'-import',str(base)],env={**os.environ,'QT_QPA_PLATFORM':'offscreen','QT_QUICK_BACKEND':'software'})
    raise SystemExit(result.returncode)
