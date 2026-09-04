pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Services.AgentApproval

QtObject {
    id: root
    readonly property var approval: AgentApprovalService.current
    readonly property string contextId: root.approval
        ? "agent:" + root.approval.requestId : ""
    readonly property var actionIds: Object.freeze([
        "agent.deny", "agent.ask", "agent.allow-session", "agent.allow-once"
    ])
    readonly property var contexts: !root.approval ? Object.freeze([]) : Object.freeze([Object.freeze({
        id: root.contextId, source: "agent", kind: "approval-required",
        title: root.approval.summary || root.approval.command || "Approval required",
        subtitle: root.approval.title || root.approval.source || "", icon: "smart_toy",
        tone: "warning", attention: "blocking", progress: null,
        occurredAt: root.approval.createdAt || 0, expiresAt: 0,
        details: Object.freeze({ command: root.approval.command || "" }), actionIds: root.actionIds
    })])
    readonly property var indicators: Object.freeze([])
    readonly property var actions: !root.approval ? Object.freeze([]) : Object.freeze([
        root.capability("agent.deny", "destructive", "Deny", "close"),
        root.capability("agent.ask", "secondary", "Ask", "help"),
        root.capability("agent.allow-session", "secondary", "Allow session", "verified"),
        root.capability("agent.allow-once", "primary", "Allow once", "check")
    ])
    function capability(id: string, role: string, label: string, icon: string): var {
        return Object.freeze({ id: id, contextId: root.contextId, role: role,
            label: label, icon: icon, enabled: true });
    }
    function dispatch(actionId: string, contextId: string, idempotencyKey: string): var {
        if (!root.approval || contextId !== root.contextId)
            return root.result(false, "stale", "missing-context");
        const decisions = Object.freeze({
            "agent.deny": "deny", "agent.ask": "ask",
            "agent.allow-session": "allow_session", "agent.allow-once": "allow_once"
        });
        if (!decisions[actionId])
            return root.result(false, "stale", "unknown-action");
        const accepted = AgentApprovalService.decide(root.approval.requestId, decisions[actionId]);
        return root.result(accepted, accepted ? "completed" : "stale", "");
    }
    function result(accepted: bool, status: string, reason: string): var {
        return Object.freeze({ accepted: accepted, status: status, reason: reason,
            closePolicy: accepted ? "compact" : "keep" });
    }
}
