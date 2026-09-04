pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Services.Center

QtObject {
    id: root
    readonly property var contexts: Object.freeze(CenterJobService.jobs.map(item => Object.freeze({
        id: "job:" + item.id, source: "job", kind: "job", title: item.label,
        subtitle: "", icon: "work", tone: item.importance === "important" ? "warning" : "normal",
        attention: "ambient", progress: Math.max(0, Math.min(1, item.percent / 100)),
        occurredAt: item.changedAt || 0, expiresAt: 0,
        details: Object.freeze({ importance: item.importance }),
        actionIds: Object.freeze(["job.clear"])
    })))
    readonly property var indicators: Object.freeze([Object.freeze({
        id: "jobs", icon: "work", accessibleName: "Active jobs", tone: "normal",
        active: CenterJobService.activeCount > 0
    })])
    readonly property var actions: Object.freeze(root.contexts.map(item => Object.freeze({
        id: "job.clear", contextId: item.id, role: "destructive", label: "Clear",
        icon: "close", enabled: true
    })))
    function dispatch(actionId: string, contextId: string, idempotencyKey: string): var {
        if (actionId !== "job.clear" || contextId.indexOf("job:") !== 0)
            return root.result(false, "stale", "unknown-action");
        const accepted = CenterJobService.clear(contextId.slice("job:".length)) === "ok";
        return root.result(accepted, accepted ? "completed" : "stale", "");
    }
    function result(accepted: bool, status: string, reason: string): var {
        return Object.freeze({ accepted: accepted, status: status, reason: reason,
            closePolicy: accepted ? "compact" : "keep" });
    }
}
