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
    property bool running: false
    property double startedAt: 0
    property double now: Date.now()

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
        command: ["pidof", "wf-recorder"]
        running: true
        onExited: code => {
            root.sync(code);
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
