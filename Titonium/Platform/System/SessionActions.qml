pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Hyprland
import Quickshell.Io
import qs.Titonium.Foundation
import "SessionActionLifecycle.js" as SessionActionLifecycle

QtObject {
    id: root

    property var lifecycleState: SessionActionLifecycle.idle()
    property string lastError: ""
    readonly property string activeAction: root.lifecycleState.phase === "accepted"
        ? "" : root.lifecycleState.action
    readonly property bool busy: root.lifecycleState.action.length > 0 || actionProcess.running
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
        root.lifecycleState = SessionActionLifecycle.begin(action);
        if (action === "logout") {
            try {
                Hyprland.dispatch("exit");
                root.commitTransition(SessionActionLifecycle.exited(root.lifecycleState, 0));
                return true;
            } catch (error) {
                root.commitTransition(SessionActionLifecycle.exited(root.lifecycleState, 1));
                return false;
            }
        }
        const command = root.commandFor(action);
        if (command.length === 0) {
            root.lastError = "session.error.unknown";
            root.lifecycleState = SessionActionLifecycle.idle();
            return false;
        }
        actionProcess.command = command;
        actionProcess.running = true;
        return true;
    }

    function commitTransition(result: var): void {
        if (!result)
            return;
        root.lifecycleState = result.state;
        if (result.effect === "accepted") {
            root.lockStartupGate.stop();
            root.lastError = "";
            root.actionStarted(result.action);
        } else if (result.effect === "failed") {
            root.lockStartupGate.stop();
            root.lastError = result.error;
            Logger.warn("session", result.action + ": " + result.error);
            root.actionFailed(result.action, result.error);
        }
    }

    property Timer lockStartupGate: Timer {
        interval: 500
        repeat: false
        running: false
        onTriggered: root.commitTransition(SessionActionLifecycle.settled(root.lifecycleState))
    }

    property Process actionProcess: Process {
        running: false

        onStarted: {
            root.commitTransition(SessionActionLifecycle.started(root.lifecycleState));
            if (root.lifecycleState.kind === "lock" && root.lifecycleState.phase === "settling")
                root.lockStartupGate.restart();
        }

        onExited: exitCode => root.commitTransition(
            SessionActionLifecycle.exited(root.lifecycleState, exitCode))

        onRunningChanged: {
            if (!running)
                root.commitTransition(SessionActionLifecycle.stopped(root.lifecycleState));
        }
    }
}
