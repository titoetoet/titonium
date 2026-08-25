pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io
import qs.Titonium.Foundation

QtObject {
    id: root

    property bool loaded: false
    property bool probed: false
    property string detail: "probing"

    // One-shot capability discovery only. It never installs, loads, configures or
    // reloads a compositor plugin and it has no timer/retry loop.
    property Process probe: Process {
        command: ["hyprctl", "plugin", "list"]
        running: true

        stdout: StdioCollector {
            id: output
        }

        onExited: exitCode => {
            const text = output.text || "";
            root.loaded = exitCode === 0 && /hyprglass/i.test(text) && !/no plugins loaded/i.test(text);
            root.probed = true;
            root.detail = root.loaded ? "loaded" : "unavailable";
            Logger.info("hyprglass", "native capability " + root.detail + "; fallback remains available");
        }
    }
}
