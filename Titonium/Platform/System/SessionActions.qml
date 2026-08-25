pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Hyprland
import Quickshell.Io
import qs.Titonium.Foundation

QtObject {
    id: root

    property string activeAction: ""
    property string lastError: ""
    readonly property bool busy: actionProcess.running
    readonly property var supportedActions: ["shutdown", "restart", "sleep", "hibernate", "logout"]

    function commandFor(action: string): var {
        const commands = {
            "shutdown": ["systemctl", "poweroff"],
            "restart": ["systemctl", "reboot"],
            "sleep": ["systemctl", "suspend"],
            "hibernate": ["systemctl", "hibernate"]
        };
        return commands[action] || [];
    }

    function executeConfirmed(action: string): bool {
        if (root.busy || root.supportedActions.indexOf(action) < 0)
            return false;
        root.lastError = "";
        root.activeAction = action;
        if (action === "logout") {
            Hyprland.dispatch("exit");
            root.activeAction = "";
            return true;
        }
        const command = root.commandFor(action);
        if (command.length === 0)
            return false;
        actionProcess.command = command;
        actionProcess.running = true;
        return true;
    }

    property Process actionProcess: Process {
        running: false

        onExited: exitCode => {
            if (exitCode !== 0) {
                root.lastError = root.activeAction + " failed with exit code " + exitCode;
                Logger.warn("session", root.lastError);
            }
            root.activeAction = "";
        }
    }
}
