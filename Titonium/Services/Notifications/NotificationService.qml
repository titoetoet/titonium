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
    property var toastKeys: Object.freeze([])
    property var unreadKeys: Object.freeze([])
    property var operationWarningCounts: ({})

    readonly property var notifications: root.projectedNotifications
    readonly property var toastNotifications: {
        const result = [];
        for (let keyIndex = 0; keyIndex < root.toastKeys.length; keyIndex++) {
            for (let itemIndex = 0; itemIndex < root.projectedNotifications.length; itemIndex++) {
                const item = root.projectedNotifications[itemIndex];
                if (item.key === root.toastKeys[keyIndex]) {
                    result.push(item);
                    break;
                }
            }
        }
        return Object.freeze(result);
    }
    readonly property int unreadCount: NotificationRules.unreadCount(root.unreadKeys)
    readonly property bool hasUnread: root.unreadCount > 0
    readonly property int operationWarningLimit: 3
    readonly property bool toastsEnabled:
        Preferences.notifications.toastsEnabled !== false

    onToastsEnabledChanged: {
        if (!root.toastsEnabled && root.toastKeys.length > 0)
            root.toastKeys = Object.freeze([]);
    }

    function warnOperation(category: string, message: string): void {
        const count = root.operationWarningCounts[category] || 0;
        if (count >= root.operationWarningLimit)
            return;
        root.operationWarningCounts[category] = count + 1;
        Logger.warn("notifications", message);
    }

    function markAllRead(): bool {
        root.unreadKeys = Object.freeze([]);
        return true;
    }

    function expireToast(key: string): bool {
        if (!root.toastKeys.includes(key))
            return false;
        root.toastKeys = NotificationRules.removeKey(root.toastKeys, key);
        return true;
    }

    function dismiss(key: string): bool {
        const nativeNotification = nativeTargets.byKey[key];
        if (!nativeNotification) {
            root.warnOperation("dismiss.stale", "ignored dismissal for stale notification");
            return false;
        }
        try {
            nativeNotification.dismiss();
        } catch (failure) {
            root.warnOperation("dismiss.failure", "native notification dismissal failed");
            return false;
        }
        root.projectedNotifications = NotificationRules.removeKey(
            root.projectedNotifications, key);
        root.toastKeys = NotificationRules.removeKey(root.toastKeys, key);
        root.unreadKeys = NotificationRules.removeKey(root.unreadKeys, key);
        root.removeNativeTarget(key);
        return true;
    }

    function dismissAll(): int {
        const keys = root.projectedNotifications.map(item => item.key);
        for (let index = 0; index < keys.length; index++)
            root.dismiss(keys[index]);
        return keys.length;
    }

    function invokeAction(key: string, actionId: string): bool {
        const nativeNotification = nativeTargets.byKey[key];
        if (!nativeNotification) {
            root.warnOperation("action.stale", "ignored action for stale notification");
            return false;
        }
        const source = nativeNotification.actions || [];
        let nativeAction = null;
        for (let index = 0; index < source.length; index++) {
            if (String(source[index]?.identifier || "") === actionId) {
                nativeAction = source[index];
                break;
            }
        }
        if (!nativeAction) {
            root.warnOperation("action.missing", "ignored missing notification action");
            return false;
        }
        try {
            nativeAction.invoke();
            return true;
        } catch (failure) {
            root.warnOperation("action.failure", "native notification action failed");
            return false;
        }
    }

    function retainNativeTarget(key: string, notification: var): void {
        const next = Object.assign({}, nativeTargets.byKey);
        next[key] = notification;
        nativeTargets.byKey = Object.freeze(next);
    }

    function removeNativeTarget(key: string): void {
        if (!nativeTargets.byKey[key])
            return;
        const next = Object.assign({}, nativeTargets.byKey);
        delete next[key];
        nativeTargets.byKey = Object.freeze(next);
    }

    QtObject {
        id: nativeTargets
        property var byKey: Object.freeze({})
    }

    NotificationServer {
        id: server
        keepOnReload: true
        persistenceSupported: true
        bodySupported: true
        bodyMarkupSupported: false
        bodyHyperlinksSupported: false
        bodyImagesSupported: false
        actionsSupported: true
        actionIconsSupported: false
        imageSupported: false
        inlineReplySupported: false

        onNotification: notification => {
            notification.tracked = true;
            const now = Date.now();
            const item = NotificationRules.descriptor({
                id: notification.id,
                appName: notification.appName,
                appIcon: notification.appIcon,
                appId: notification.desktopEntry,
                summary: notification.summary,
                body: notification.body,
                urgency: Number(notification.urgency),
                actions: NotificationRules.nativeActions(notification),
            }, now);
            if (!item) {
                root.warnOperation("projection.invalid", "ignored notification with invalid id");
                return;
            }
            root.projectedNotifications = NotificationRules.upsert(
                root.projectedNotifications, item, 100);
            root.unreadKeys = NotificationRules.markUnread(root.unreadKeys, item.key);
            if (item.route === "toast" && root.toastsEnabled)
                root.toastKeys = NotificationRules.addToast(root.toastKeys, item.key, 3);
            root.retainNativeTarget(item.key, notification);
            notification.closed.connect(() => {
                root.expireToast(item.key);
                root.removeNativeTarget(item.key);
            });
        }
    }
}
