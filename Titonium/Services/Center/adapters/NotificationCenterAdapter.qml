pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Services.Notifications
import "NotificationCenterRules.js" as NotificationCenterRules

QtObject {
    id: root

    readonly property var currentCritical: NotificationCoordinator.currentCritical
    readonly property var context: NotificationCenterRules.context(root.currentCritical)
    readonly property var contexts: Object.freeze(root.context ? [root.context] : [])
    readonly property var indicators: Object.freeze([Object.freeze({
        id: "notification:unread",
        icon: "notifications",
        accessibleName: "Unread notifications",
        tone: "normal",
        active: NotificationCoordinator.hasUnread,
    })])
    readonly property var actions: root.context
        ? NotificationCenterRules.capabilities(root.currentCritical, root.context.id)
        : Object.freeze([])
    readonly property var presentation:
        NotificationCenterRules.presentation(root.currentCritical)

    function dispatch(actionId: string, contextId: string,
            idempotencyKey: string): var {
        const intent = NotificationCenterRules.actionIntent(actionId, contextId);
        if (!intent || !root.currentCritical || intent.key !== root.currentCritical.key)
            return root.result(false, "stale", "unknown-action");
        const accepted = intent.kind === "dismiss"
            ? NotificationCoordinator.dismiss(intent.key)
            : NotificationCoordinator.action(intent.key, intent.actionId);
        return root.result(accepted, accepted ? "completed" : "stale",
            accepted ? "" : "unavailable-action");
    }

    function setPresentationEligible(eligible: bool): bool {
        let changed = false;
        if (!eligible)
            changed = NotificationCoordinator.pauseCritical() || changed;
        changed = NotificationCoordinator.setCriticalPresentationEligible(eligible) || changed;
        if (eligible)
            changed = NotificationCoordinator.resumeCritical() || changed;
        return changed;
    }

    function pausePresentation(contextId: string): bool {
        const intent = NotificationCenterRules.actionIntent(
            "notification.dismiss", contextId);
        if (!intent || !root.currentCritical || intent.key !== root.currentCritical.key)
            return false;
        return NotificationCoordinator.pauseCritical();
    }

    function resumePresentation(contextId: string): bool {
        const intent = NotificationCenterRules.actionIntent(
            "notification.dismiss", contextId);
        if (!intent || !root.currentCritical || intent.key !== root.currentCritical.key)
            return false;
        return NotificationCoordinator.resumeCritical();
    }

    function completePresentation(contextId: string): var {
        const intent = NotificationCenterRules.actionIntent(
            "notification.dismiss", contextId);
        if (!intent || !root.currentCritical || intent.key !== root.currentCritical.key)
            return root.result(false, "stale", "missing-presentation");
        const accepted = NotificationCoordinator.completeCritical(intent.key);
        return root.result(accepted, accepted ? "completed" : "stale",
            accepted ? "" : "missing-presentation");
    }

    function result(accepted: bool, status: string, reason: string): var {
        return Object.freeze({
            accepted: accepted,
            status: status,
            reason: reason,
            closePolicy: accepted && !NotificationCoordinator.currentCritical
                ? "compact" : "keep",
        });
    }
}
