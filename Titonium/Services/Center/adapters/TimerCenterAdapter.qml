pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Services.Center

QtObject {
    id: root
    readonly property var contexts: Object.freeze(CenterTimerService.timers.map(item => Object.freeze({
        id: "timer:" + item.id, source: "timer", kind: "countdown", title: item.label,
        subtitle: "", icon: "timer", tone: "normal", attention: "ambient", progress: null,
        occurredAt: 0, expiresAt: item.deadline, details: Object.freeze({ deadline: item.deadline }),
        actionIds: Object.freeze(["timer.cancel"])
    })))
    readonly property var indicators: Object.freeze([Object.freeze({
        id: "timer", icon: "timer", accessibleName: "Active timer", tone: "normal",
        active: CenterTimerService.activeCount > 0
    })])
    readonly property var actions: Object.freeze(root.contexts.map(item => Object.freeze({
        id: "timer.cancel", contextId: item.id, role: "destructive", label: "Cancel",
        icon: "close", enabled: true
    })))
    function dispatch(actionId: string, contextId: string, idempotencyKey: string): var {
        if (actionId !== "timer.cancel" || contextId.indexOf("timer:") !== 0)
            return root.result(false, "stale", "unknown-action");
        const accepted = CenterTimerService.cancel(contextId.slice("timer:".length));
        return root.result(accepted, accepted ? "completed" : "stale", "");
    }
    function result(accepted: bool, status: string, reason: string): var {
        return Object.freeze({ accepted: accepted, status: status, reason: reason,
            closePolicy: accepted ? "compact" : "keep" });
    }
}
