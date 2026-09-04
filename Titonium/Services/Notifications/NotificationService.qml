pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import qs.Titonium.Core.Runtime
import "NotificationRules.js" as NotificationRules

Singleton {
    id: root

    signal descriptorPublished(var descriptor)
    signal descriptorRetired(string key, string reason)

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
        const state = NotificationRules.warningState(root.operationWarningCounts,
            category, root.operationWarningLimit);
        root.operationWarningCounts = state.counts;
        if (!state.warn)
            return;
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
        const known = root.projectedNotifications.some(item => item.key === key);
        const nativeNotification = nativeTargets.byKey[key];
        let dismissed = false;
        if (!nativeNotification) {
            root.warnOperation("dismiss.stale", "ignored dismissal for stale notification");
        } else {
            try {
                nativeNotification.dismiss();
                dismissed = true;
            } catch (failure) {
                root.warnOperation("dismiss.failure", "native notification dismissal failed");
            }
        }
        if (root.nativeTargetCurrent(key, nativeNotification)
                || root.projectedNotifications.some(item => item.key === key))
            root.retireNativeNotification(key, NotificationCloseReason.Dismissed);
        return known || dismissed;
    }

    function dismissAll(): int {
        const keys = root.projectedNotifications.map(item => item.key);
        for (let index = 0; index < keys.length; index++)
            root.dismiss(keys[index]);
        nativeTargets.byKey = Object.freeze({});
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
            if (NotificationRules.actionIdentifier(source[index]) === actionId) {
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
        if (nativeTargets.byKey[key] === notification)
            return;
        const next = Object.assign({}, nativeTargets.byKey);
        next[key] = notification;
        nativeTargets.byKey = Object.freeze(next);
        root.watchNativeNotification(key, notification);
    }

    function removeNativeTarget(key: string): void {
        if (!nativeTargets.byKey[key])
            return;
        const next = Object.assign({}, nativeTargets.byKey);
        delete next[key];
        nativeTargets.byKey = Object.freeze(next);
    }

    function nativeTargetCurrent(key: string, notification: var): bool {
        return !!notification && nativeTargets.byKey[key] === notification;
    }

    function retireNativeNotification(key: string, reason: var): void {
        const lifecycleReason = NotificationRules.closeReason(reason);
        const state = NotificationRules.retireState({
            notifications: root.projectedNotifications,
            unreadKeys: root.unreadKeys,
            toastKeys: root.toastKeys,
        }, key, lifecycleReason);
        root.projectedNotifications = state.notifications;
        root.unreadKeys = state.unreadKeys;
        root.toastKeys = state.toastKeys;
        root.removeNativeTarget(key);
        root.descriptorRetired(key, lifecycleReason);
    }

    function refreshNativeNotification(notification: var): void {
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
        const state = NotificationRules.refreshState({
            notifications: root.projectedNotifications,
            unreadKeys: root.unreadKeys,
            toastKeys: root.toastKeys,
        }, item, root.toastsEnabled);
        root.projectedNotifications = state.notifications;
        root.unreadKeys = state.unreadKeys;
        root.toastKeys = state.toastKeys;
        root.retainNativeTarget(item.key, notification);
        root.descriptorPublished(item);
    }

    function watchNativeNotification(key: string, notification: var): void {
        const refresh = () => root.refreshNativeNotification(notification);
        notification.appNameChanged.connect(refresh);
        notification.appIconChanged.connect(refresh);
        notification.summaryChanged.connect(refresh);
        notification.bodyChanged.connect(refresh);
        notification.urgencyChanged.connect(refresh);
        notification.desktopEntryChanged.connect(refresh);
        notification.actionsChanged.connect(refresh);
        notification.closed.connect(reason => {
            if (!root.nativeTargetCurrent(key, notification))
                return;
            root.retireNativeNotification(key, reason);
        });
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
            root.refreshNativeNotification(notification);
        }
    }
}
