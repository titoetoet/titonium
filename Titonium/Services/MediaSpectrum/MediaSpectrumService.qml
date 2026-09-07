pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Io
import qs.Titonium.Services.Audio

QtObject {
    id: root
    property bool enabled: false
    property var levels: [0, 0, 0, 0]
    property var spectrum: []
    readonly property string monitorName: AudioService.outputMonitorName
    property bool restartPending: false
    function launch(): void {
        root.restartPending = false;
        root.levels = [0, 0, 0, 0];
        root.spectrum = [];
        if (!root.enabled || !root.monitorName) return;
        capture.command = ["python3", Qt.resolvedUrl("spectrum.py").toString().replace("file://", ""), root.monitorName];
        capture.running = true;
    }
    function synchronize(): void {
        root.levels = [0, 0, 0, 0];
        root.spectrum = [];
        root.restartPending = root.enabled && !!root.monitorName;
        if (capture.running) capture.running = false;
        else root.launch();
    }
    onEnabledChanged: root.synchronize()
    onMonitorNameChanged: root.synchronize()
    property Process capture: Process {
        id: capture
        stdout: SplitParser {
            onRead: line => {
                try {
                    const frame = JSON.parse(line);
                    const values = Array.isArray(frame) ? frame : frame.bands;
                    if (root.enabled && !root.restartPending && Array.isArray(values)
                            && values.length === 4 && values.every(v => Number.isFinite(v) && v >= 0 && v <= 1)) {
                        root.levels = values;
                        root.spectrum = Array.isArray(frame.spectrum) && frame.spectrum.length === 24
                            && frame.spectrum.every(v => Number.isFinite(v) && v >= 0 && v <= 1)
                            ? frame.spectrum : [];
                    }
                } catch (_) {
                    root.levels = [0, 0, 0, 0];
                    root.spectrum = [];
                }
            }
        }
        onExited: {
            root.levels = [0, 0, 0, 0];
            root.spectrum = [];
            if (root.restartPending) root.launch();
        }
    }
}
