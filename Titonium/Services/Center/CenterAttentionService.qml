pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import "CenterAttentionRules.js" as CenterAttentionRules

QtObject {
    id: root

    property var arbiterState: CenterAttentionRules.initialState()
    property var indicatorState: Object.freeze([])
    property string scheduledId: ""
    property int scheduledGeneration: -1

    readonly property var presentation: root.arbiterState.current
    readonly property var indicators: root.indicatorState
    readonly property bool hasTransient: root.presentation !== null

    property Timer expiryTimer: Timer {
        id: expiryTimer
        repeat: false
        onTriggered: root.expireCurrent()
    }

    function applyState(nextState: var): bool {
        if (nextState === root.arbiterState)
            return false;

        root.arbiterState = nextState;
        root.rescheduleExpiry();
        return true;
    }

    function publish(event: var): bool {
        return root.applyState(CenterAttentionRules.publish(root.arbiterState, event, Date.now()));
    }

    function acknowledge(eventId: string): bool {
        return root.applyState(CenterAttentionRules.acknowledge(root.arbiterState, eventId, Date.now()));
    }

    function clear(eventId: string): bool {
        return root.applyState(CenterAttentionRules.clear(root.arbiterState, eventId, Date.now()));
    }

    function clearSource(source: string): bool {
        return root.applyState(CenterAttentionRules.clearSource(root.arbiterState, source, Date.now()));
    }

    function setIndicator(id: string, icon: string, accessibleName: string, active: bool): bool {
        const nextIndicators = CenterAttentionRules.setIndicator(root.indicatorState, {
            id: id,
            active: active,
            icon: icon,
            accessibleName: accessibleName
        });

        if (nextIndicators === root.indicatorState)
            return false;

        root.indicatorState = nextIndicators;
        return true;
    }

    function rescheduleExpiry(): void {
        root.expiryTimer.stop();
        root.scheduledId = "";
        root.scheduledGeneration = -1;

        const current = root.arbiterState.current;
        if (current === null || current.expiresAt <= 0)
            return;

        const now = Date.now();
        if (current.expiresAt <= now) {
            root.applyState(CenterAttentionRules.expire(root.arbiterState, current.id, current.generation, now));
            return;
        }

        root.scheduledId = current.id;
        root.scheduledGeneration = current.generation;
        root.expiryTimer.interval = Math.max(1, current.expiresAt - now);
        root.expiryTimer.start();
    }

    function expireCurrent(): void {
        const nextState = CenterAttentionRules.expire(
            root.arbiterState,
            root.scheduledId,
            root.scheduledGeneration,
            Date.now()
        );

        if (!root.applyState(nextState))
            root.rescheduleExpiry();
    }

    function snapshot(): string {
        return JSON.stringify({
            transient: root.hasTransient,
            current: root.presentation,
            pendingCount: root.arbiterState.pending.length,
            indicators: root.indicators
        });
    }
}
