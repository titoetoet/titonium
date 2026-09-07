pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io
import qs.Titonium.Core.Runtime
import qs.Titonium.Services.Center

QtObject {
    id: root
    readonly property bool recording: root.running
    readonly property real elapsedSeconds: root.recording && root.startedAt > 0
        ? Math.max(0, (root.now - root.startedAt) / 1000) : 0
    property var recorderSessions: []
    readonly property bool canStop: root.recording && root.recorderSessions.length > 0 && !stopProcess.running
    function stopRecording(): bool {
        if (!root.canStop) return false;
        stopProcess.command = ["python3", Qt.resolvedUrl("recorder_control.py").toString().replace("file://", ""),
            "stop", JSON.stringify(root.recorderSessions)];
        stopProcess.running = true;
        return true;
    }
    property Process stopProcess: Process {
        onExited: root.probe.running = true
    }
    property bool running: false
    property double startedAt: 0
    property double now: Date.now()

    function applySessions(next: var): void {
        const added = next.some(item => !root.recorderSessions.some(old => old.pid === item.pid && old.start === item.start));
        root.recorderSessions = next;
        if (added) root.startedAt = Date.now();
        root.sync(next.length ? 0 : 1);
    }

    function sync(code: int): void {
        const next = code === 0;
        if (next === root.running)
            return;
        root.running = next;
        root.startedAt = next ? Date.now() : 0;
        CenterAttentionService.setIndicator(
            "screen-recording", next ? "screen_record" : "screen_record",
            I18n.tr("capture.screen_recording"), next);
        CenterAttentionService.publish({
            id: "capture:recording", source: "capture",
            kind: next ? "recording_started" : "recording_stopped",
            title: I18n.tr(next ? "capture.recording_started" : "capture.recording_stopped"),
            icon: next ? "screen_record" : "stop_circle"
        });
    }

    property Process probe: Process {
        command: ["python3", Qt.resolvedUrl("recorder_control.py").toString().replace("file://", "")]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const next = JSON.parse(text);
                    root.applySessions(next);
                } catch (_) { root.recorderSessions = []; root.sync(1); }
            }
        }
        running: true
        onExited: code => {
            if (code !== 0) { root.recorderSessions = []; root.sync(1); }
            root.poll.running = true;
        }
    }
    property Timer poll: Timer {
        interval: 1000
        repeat: false
        onTriggered: {
            root.now = Date.now();
            root.probe.running = true;
        }
    }

    function activate(): void {
        root.probe.running = true;
    }
}
