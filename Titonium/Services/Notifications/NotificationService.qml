pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import qs.Titonium.Core.Runtime
import "NotificationRules.js" as NotificationRules

Singleton {
    id: root

    property var projectedNotifications: Object.freeze([])
    property var toastIds: Object.freeze([])
    property var unreadIds: Object.freeze([])
    property var operationWarningCounts: ({})

    readonly property var notifications: root.projectedNotifications
    readonly property var toastNotifications: {
        const result = [];
        for (let idIndex = 0; idIndex < root.toastIds.length; idIndex++) {
            for (let itemIndex = 0; itemIndex < root.projectedNotifications.length; itemIndex++) {
                const item = root.projectedNotifications[itemIndex];
                if (item.id === root.toastIds[idIndex]) {
                    result.push(item);
                    break;
                }
            }
        }
        return Object.freeze(result);
    }
    readonly property int unreadCount: NotificationRules.unreadCount(root.unreadIds)
    readonly property bool hasUnread: root.unreadCount > 0
    readonly property int operationWarningLimit: 3
    readonly property bool toastsEnabled:
        Preferences.notifications.toastsEnabled !== false

    onToastsEnabledChanged: {
        if (!root.toastsEnabled && root.toastIds.length > 0)
            root.toastIds = Object.freeze([]);
    }

    function warnOperation(category: string, message: string): void {
        const count = root.operationWarningCounts[category] || 0;
        if (count >= root.operationWarningLimit)
            return;
        root.operationWarningCounts[category] = count + 1;
        Logger.warn("notifications", message);
    }

    function markAllRead(): bool {
        root.unreadIds = Object.freeze([]);
        return true;
    }

    function expireToast(id: int): bool {
        if (!root.toastIds.includes(id))
            return false;
        root.toastIds = NotificationRules.removeId(root.toastIds, id);
        return true;
    }

    function dismiss(id: int): bool {
        let nativeNotification = null;
        const source = server.trackedNotifications.values || [];
        for (let index = 0; index < source.length; index++) {
            const candidate = source[index];
            if (candidate?.id === id && candidate?.lastGeneration === true) {
                nativeNotification = candidate;
                break;
            }
        }

        let dismissed = false;
        if (nativeNotification) {
            try {
                nativeNotification.dismiss();
                dismissed = true;
            } catch (failure) {
                root.warnOperation("dismiss.failure", "native notification dismissal failed");
            }
        } else {
            root.warnOperation("dismiss.stale", "ignored dismissal for stale notification");
        }

        root.projectedNotifications = NotificationRules.removeId(
            root.projectedNotifications, id);
        root.toastIds = NotificationRules.removeId(root.toastIds, id);
        root.unreadIds = NotificationRules.removeId(root.unreadIds, id);
        return dismissed;
    }

    NotificationServer {
        id: server
        keepOnReload: true
        persistenceSupported: true
        bodySupported: true
        bodyMarkupSupported: false
        bodyHyperlinksSupported: false
        bodyImagesSupported: false
        actionsSupported: false
        actionIconsSupported: false
        imageSupported: false
        inlineReplySupported: false

        onNotification: notification => {
            notification.tracked = true;
            const item = NotificationRules.descriptor({
                id: notification.id,
                appName: notification.appName,
                appIcon: notification.appIcon,
                summary: notification.summary,
                body: notification.body,
                urgency: Number(notification.urgency),
            }, Date.now());
            if (!item) {
                root.warnOperation("projection.invalid", "ignored notification with invalid id");
                return;
            }
            root.projectedNotifications = NotificationRules.upsert(
                root.projectedNotifications, item, 100);
            if (root.toastsEnabled)
                root.toastIds = NotificationRules.addToast(root.toastIds, item.id, 3);
            root.unreadIds = NotificationRules.markUnread(root.unreadIds, item.id);
            notification.closed.connect(() => root.expireToast(item.id));
        }
    }
}
