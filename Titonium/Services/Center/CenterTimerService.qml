pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Core.Runtime
import "CenterTimerRules.js" as CenterTimerRules

QtObject {
    id: root

    signal notificationPublished(var notification)
    signal notificationRetired(string key, string reason)

    property var timerState: CenterTimerRules.initialState()
    property double scheduledAt: 0

    readonly property var timers: root.timerState.map(timer => Object.freeze({
        id: timer.id,
        label: timer.label,
        deadline: timer.deadline
    }))
    readonly property int activeCount: root.timerState.length

    property Timer milestoneTimer: Timer {
        id: milestoneTimer
        repeat: false
        onTriggered: root.processDue()
    }

    function eventTitle(event: var): string {
        const params = { "label": event.label };
        if (event.kind === "timer_five_minutes")
            return I18n.tr("menubar.center.timer.five_minutes", params);
        if (event.kind === "timer_one_minute")
            return I18n.tr("menubar.center.timer.one_minute", params);
        return I18n.tr("menubar.center.timer.finished", params);
    }

    function publishEvent(event: var): void {
        const publishedEvent = Object.freeze(Object.assign({}, event, {
            "title": root.eventTitle(event)
        }));
        if (event.kind === "timer_finished")
            root.notificationPublished(publishedEvent);
        else
            CenterAttentionService.publish(publishedEvent);
    }

    function syncIndicator(active: bool): void {
        CenterAttentionService.setIndicator(
            "timer",
            "timer",
            I18n.tr("menubar.center.indicator.timer"),
            active
        );
    }

    function syncActivity(timer: var, now: double): void {
        if (!timer)
            return;
        CenterActivityService.upsert({
            "id": "timer:" + timer.id,
            "source": "timer",
            "label": timer.label,
            "icon": "timer",
            "importance": "normal",
            "progress": -1,
            "deadline": timer.deadline,
            "updatedAt": now
        });
    }

    function removeActivity(id: string): void {
        CenterActivityService.remove("timer:" + id.trim());
    }

    function removeMissingActivities(previousState: var, nextState: var): void {
        for (let previousIndex = 0; previousIndex < previousState.length;
                previousIndex++) {
            const previous = previousState[previousIndex];
            let found = false;
            for (let nextIndex = 0; nextIndex < nextState.length; nextIndex++) {
                if (nextState[nextIndex].id === previous.id) {
                    found = true;
                    break;
                }
            }
            if (!found)
                root.removeActivity(previous.id);
        }
    }

    function timerById(state: var, id: string): var {
        const normalizedId = id.trim();
        for (let index = 0; index < state.length; index++) {
            if (state[index].id === normalizedId)
                return state[index];
        }
        return null;
    }

    function replaceState(nextState: var): void {
        root.timerState = nextState;
        root.syncIndicator(nextState.length > 0);
        root.reschedule();
    }

    function start(id: string, durationSeconds: int, label: string): bool {
        const now = Date.now();
        const nextState = CenterTimerRules.start(
            root.timerState, id, durationSeconds, label, now);
        if (nextState === root.timerState)
            return false;
        CenterAttentionService.clear("timer:" + id.trim());
        root.replaceState(nextState);
        root.syncActivity(root.timerById(nextState, id), now);
        return true;
    }

    function cancel(id: string): bool {
        const nextState = CenterTimerRules.cancel(root.timerState, id);
        const stateChanged = nextState !== root.timerState;
        const eventCleared = CenterAttentionService.clear("timer:" + id.trim());
        root.removeActivity(id);
        if (stateChanged)
            root.replaceState(nextState);
        return stateChanged || eventCleared;
    }

    function acknowledge(id: string): bool {
        const normalizedId = id.trim();
        const acknowledged = CenterAttentionService.acknowledge("timer:" + normalizedId);
        if (normalizedId)
            root.notificationRetired("internal:timer_finished:" + normalizedId, "acknowledged");
        return acknowledged;
    }

    function reschedule(): void {
        root.milestoneTimer.stop();
        root.scheduledAt = 0;

        const now = Date.now();
        const request = CenterTimerRules.nextWake(root.timerState, now);
        if (request === null)
            return;
        if (request.delay <= 0) {
            root.processDue();
            return;
        }

        root.scheduledAt = request.at;
        root.milestoneTimer.interval = Math.max(
            1, Math.min(2147483647, request.delay));
        root.milestoneTimer.start();
    }

    function processDue(): void {
        const previousState = root.timerState;
        const now = Date.now();
        const result = CenterTimerRules.advance(previousState, now);
        root.timerState = result.next;
        root.syncIndicator(result.next.length > 0);
        root.removeMissingActivities(previousState, result.next);
        result.events.forEach(event => root.publishEvent(event));
        root.reschedule();
    }

    function snapshot(): string {
        return JSON.stringify({
            activeCount: root.activeCount,
            timers: root.timers,
            scheduledAt: root.scheduledAt
        });
    }

    // App calls this to pin the session-only timer service to shell lifetime.
    function activate(): void {}
}
