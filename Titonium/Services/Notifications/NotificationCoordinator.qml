pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Core.Runtime
import "NotificationRules.js" as NotificationRules
import "NotificationCoordinatorRules.js" as CoordinatorRules

QtObject {
    id: root

    property var coordinatorState: CoordinatorRules.initialState()
    property int deadlineGeneration: 0
    property string scheduledCriticalKey: ""
    property int scheduledCriticalGeneration: 0
    property double scheduledCriticalDeadline: 0

    readonly property var history: root.coordinatorState.history
    readonly property var toasts: root.valuesForKeys(root.coordinatorState.toastKeys)
    readonly property var unread: root.valuesForKeys(root.coordinatorState.unreadKeys)
    readonly property int unreadCount: root.coordinatorState.unreadKeys.length
    readonly property bool hasUnread: root.unreadCount > 0
    readonly property var currentCritical: root.coordinatorState.currentCritical
    readonly property int criticalQueueCount: root.coordinatorState.criticalQueue.length

    function valuesForKeys(keys: var): var {
        const result = [];
        for (let keyIndex = 0; keyIndex < keys.length; keyIndex++) {
            for (let itemIndex = 0; itemIndex < root.history.length; itemIndex++) {
                if (root.history[itemIndex].key === keys[keyIndex]) {
                    result.push(root.history[itemIndex]);
                    break;
                }
            }
        }
        return Object.freeze(result);
    }

    function syncDeadlineTimer(): void {
        criticalDeadline.stop();
        root.deadlineGeneration += 1;
        root.scheduledCriticalKey = "";
        root.scheduledCriticalGeneration = root.deadlineGeneration;
        root.scheduledCriticalDeadline = 0;
        if (!root.currentCritical || root.coordinatorState.paused
                || root.coordinatorState.deadlineAt <= 0)
            return;
        root.scheduledCriticalKey = root.currentCritical.key;
        root.scheduledCriticalGeneration = root.deadlineGeneration;
        root.scheduledCriticalDeadline = root.coordinatorState.deadlineAt;
        criticalDeadline.interval = Math.max(1,
            root.scheduledCriticalDeadline - Date.now());
        criticalDeadline.start();
    }

    function handleCriticalDeadline(key: string, generation: int,
            deadline: double, now: double): bool {
        if (!CoordinatorRules.deadlineMatches(root.coordinatorState,
                key, generation, root.deadlineGeneration, deadline, now)) {
            if (root.currentCritical && !root.coordinatorState.paused)
                root.syncDeadlineTimer();
            return false;
        }
        return root.completeCritical(key);
    }

    function applyState(next: var): bool {
        if (next === root.coordinatorState)
            return false;
        root.coordinatorState = next;
        root.syncDeadlineTimer();
        return true;
    }

    function publish(descriptor: var): bool {
        const resolved = NotificationRules.resolvePolicy(
            descriptor, Preferences.effectiveState);
        return root.applyState(CoordinatorRules.publish(
            root.coordinatorState, resolved, Date.now(),
            root.coordinatorState.presentationEligible,
            Preferences.notifications.toastsEnabled !== false));
    }

    function publishInternal(event: var): bool {
        if (!event || ["job_failed", "job_requires_action", "timer_finished"]
                .indexOf(event.kind) < 0)
            return false;
        const sourcePrefix = event.source === "timer" ? "timer:" : "job:";
        const eventId = typeof event.id === "string"
            && event.id.indexOf(sourcePrefix) === 0
            ? event.id.slice(sourcePrefix.length).trim() : "";
        if (!eventId)
            return false;
        const receivedAt = Number.isFinite(event.createdAt) ? event.createdAt : Date.now();
        const descriptor = NotificationRules.descriptor({
            source: "internal",
            key: "internal:" + event.kind + ":" + eventId,
            kind: event.kind,
            appName: "Titonium",
            appIcon: event.icon || (event.source === "timer" ? "timer" : "work"),
            summary: event.title || event.label,
            body: "",
            urgency: 2,
            category: event.source === "timer" ? "timer" : "job",
            actions: [],
        }, receivedAt);
        return descriptor ? root.publish(descriptor) : false;
    }

    function read(key: string): bool {
        return root.applyState(CoordinatorRules.read(root.coordinatorState, key));
    }

    function markAllRead(): bool {
        return root.read("");
    }

    function dismiss(key: string): bool {
        const known = root.history.some(item => item.key === key);
        let nativeAccepted = false;
        if (key.indexOf("native:") === 0)
            nativeAccepted = NotificationService.dismiss(key);
        const changed = root.applyState(CoordinatorRules.dismiss(
            root.coordinatorState, key, Date.now()));
        return known || nativeAccepted || changed;
    }

    function dismissAll(): int {
        const keys = root.history.map(item => item.key);
        let dismissed = 0;
        for (let index = 0; index < keys.length; index++) {
            if (root.dismiss(keys[index]))
                dismissed += 1;
        }
        return dismissed;
    }

    function retire(key: string, reason: string): bool {
        return root.applyState(CoordinatorRules.retire(
            root.coordinatorState, key, reason, Date.now()));
    }

    function action(key: string, actionId: string): bool {
        if (key.indexOf("native:") !== 0
                || !NotificationService.invokeAction(key, actionId))
            return false;
        let next = CoordinatorRules.read(root.coordinatorState, key);
        if (next.currentCritical && next.currentCritical.key === key)
            next = CoordinatorRules.complete(next, key, Date.now(),
                Preferences.notifications.keepCriticalUnread !== false);
        root.applyState(next);
        return true;
    }

    function expireToast(key: string): bool {
        if (!root.coordinatorState.toastKeys.includes(key))
            return false;
        const next = Object.freeze(Object.assign({}, root.coordinatorState, {
            toastKeys: NotificationRules.removeKey(root.coordinatorState.toastKeys, key),
        }));
        return root.applyState(next);
    }

    function pauseCritical(): bool {
        return root.applyState(CoordinatorRules.pause(
            root.coordinatorState, Date.now()));
    }

    function resumeCritical(): bool {
        return root.applyState(CoordinatorRules.resume(
            root.coordinatorState, Date.now()));
    }

    function completeCritical(key: string): bool {
        return root.applyState(CoordinatorRules.complete(
            root.coordinatorState, key, Date.now(),
            Preferences.notifications.keepCriticalUnread !== false));
    }

    function setCriticalPresentationEligible(eligible: bool): bool {
        return root.applyState(CoordinatorRules.setPresentationEligible(
            root.coordinatorState, eligible, Date.now()));
    }

    function reclassify(): bool {
        const resolver = descriptor => NotificationRules.resolvePolicy(
            descriptor, Preferences.effectiveState);
        return root.applyState(CoordinatorRules.reclassify(
            root.coordinatorState, Preferences.effectiveState, Date.now(), resolver,
            Preferences.notifications.toastsEnabled !== false));
    }

    property Timer criticalDeadline: Timer {
        id: criticalDeadline
        repeat: false
        onTriggered: {
            const key = root.scheduledCriticalKey;
            const generation = root.scheduledCriticalGeneration;
            const deadline = root.scheduledCriticalDeadline;
            root.handleCriticalDeadline(key, generation, deadline, Date.now());
        }
    }

    property Connections preferencesConnection: Connections {
        target: Preferences
        function onNotificationsChanged(): void { root.reclassify(); }
    }
}
