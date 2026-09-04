pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Services.Notifications

QtObject {
    id: root
    readonly property var contexts: Object.freeze(NotificationService.notifications.map(item => {
        const contextId = "notification:" + item.id;
        return Object.freeze({
            id: contextId, source: "notification", kind: "notification",
            title: item.summary || item.body || "Notification", subtitle: item.appName || "",
            icon: item.appIcon || "notifications", tone: item.urgency >= 2 ? "critical" : "normal",
            attention: item.urgency >= 2 ? "transient" : "ambient", progress: null,
            occurredAt: item.createdAt || 0, expiresAt: 0,
            details: Object.freeze({ notificationId: item.id, body: item.body || "" }),
            actionIds: Object.freeze(["notification.dismiss"])
        });
    }))
    readonly property var indicators: Object.freeze([Object.freeze({
        id: "notification:unread", icon: "notifications", accessibleName: "Unread notifications",
        tone: "normal", active: NotificationService.hasUnread
    })])
    readonly property var actions: Object.freeze(root.contexts.map(item => Object.freeze({
        id: "notification.dismiss", contextId: item.id, role: "destructive",
        label: "Dismiss", icon: "close", enabled: true
    })))
    function dispatch(actionId: string, contextId: string, idempotencyKey: string): var {
        if (actionId !== "notification.dismiss" || contextId.indexOf("notification:") !== 0)
            return root.result(false, "stale", "unknown-action");
        const notificationId = Number(contextId.slice("notification:".length));
        const accepted = NotificationService.dismiss(notificationId);
        return root.result(accepted, accepted ? "completed" : "stale", "");
    }
    function result(accepted: bool, status: string, reason: string): var {
        return Object.freeze({ accepted: accepted, status: status, reason: reason,
            closePolicy: accepted ? "compact" : "keep" });
    }
}
