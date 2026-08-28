pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Core.Runtime
import "CenterTimerRules.js" as CenterTimerRules

QtObject {
    id: root

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
        CenterAttentionService.publish(Object.assign({}, event, {
            "title": root.eventTitle(event)
        }));
    }

    function syncIndicator(active: bool): void {
        CenterAttentionService.setIndicator(
            "timer",
            "timer",
            I18n.tr("menubar.center.indicator.timer"),
            active
        );
    }

    function replaceState(nextState: var): void {
        root.timerState = nextState;
        root.syncIndicator(nextState.length > 0);
        root.reschedule();
    }

    function start(id: string, durationSeconds: int, label: string): bool {
        const nextState = CenterTimerRules.start(
            root.timerState, id, durationSeconds, label, Date.now());
        if (nextState === root.timerState)
            return false;
        CenterAttentionService.clear("timer:" + id.trim());
        root.replaceState(nextState);
        return true;
    }

    function cancel(id: string): bool {
        const nextState = CenterTimerRules.cancel(root.timerState, id);
        const stateChanged = nextState !== root.timerState;
        const eventCleared = CenterAttentionService.clear("timer:" + id.trim());
        if (stateChanged)
            root.replaceState(nextState);
        return stateChanged || eventCleared;
    }

    function acknowledge(id: string): bool {
        return CenterAttentionService.acknowledge("timer:" + id.trim());
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
        const result = CenterTimerRules.advance(root.timerState, Date.now());
        root.timerState = result.next;
        root.syncIndicator(result.next.length > 0);
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
