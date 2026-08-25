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
    property bool processStarted: false
    readonly property bool busy: root.activeAction.length > 0 || actionProcess.running
    readonly property var supportedActions: ["lock", "sleep", "hibernate", "restart", "shutdown", "logout"]

    signal actionStarted(string action)
    signal actionFailed(string action, string error)

    function commandFor(action: string): var {
        const commands = {
            "lock": ["hyprlock"],
            "shutdown": ["systemctl", "poweroff"],
            "restart": ["systemctl", "reboot"],
            "sleep": ["systemctl", "suspend"],
            "hibernate": ["systemctl", "hibernate"]
        };
        return commands[action] || [];
    }

    function executeConfirmed(action: string): bool {
        if (root.busy) {
            root.lastError = "session.error.busy";
            return false;
        }
        if (root.supportedActions.indexOf(action) < 0) {
            root.lastError = "session.error.unknown";
            return false;
        }
        root.lastError = "";
        root.activeAction = action;
        if (action === "logout") {
            Hyprland.dispatch("exit");
            root.activeAction = "";
            root.actionStarted(action);
            return true;
        }
        const command = root.commandFor(action);
        if (command.length === 0) {
            root.lastError = "session.error.unknown";
            root.activeAction = "";
            return false;
        }
        root.processStarted = false;
        actionProcess.command = command;
        actionProcess.running = true;
        return true;
    }

    function failActiveAction(error: string): void {
        const action = root.activeAction;
        if (action.length === 0)
            return;
        root.lastError = error;
        root.activeAction = "";
        root.processStarted = false;
        Logger.warn("session", action + ": " + error);
        root.actionFailed(action, error);
    }

    property Process actionProcess: Process {
        running: false

        onStarted: {
            const action = root.activeAction;
            root.processStarted = true;
            root.activeAction = "";
            root.actionStarted(action);
        }

        onExited: exitCode => {
            if (!root.processStarted && root.activeAction.length > 0)
                root.failActiveAction("session.error.start_failed");
            root.processStarted = false;
        }

        onRunningChanged: {
            if (!running && !root.processStarted && root.activeAction.length > 0)
                root.failActiveAction("session.error.start_failed");
        }
    }
}
