pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Core.Runtime
import "CenterActivityRules.js" as CenterActivityRules

QtObject {
    id: root

    property var activityState: CenterActivityRules.initialState()
    property var projectedPresentation: null
    property double scheduledAt: 0

    readonly property var presentation: root.projectedPresentation
    readonly property bool hasActivity: root.presentation !== null
    readonly property bool showingFocus: root.activityState.showingFocus
    readonly property int activeCount: root.activityState.activities.length

    property Timer rotationTimer: Timer {
        id: rotationTimer
        repeat: false
        onTriggered: root.advance()
    }

    function titleFor(activity: var, now: double): string {
        if (activity.source === "timer") {
            const minutes = CenterActivityRules.remainingMinutes(activity.deadline, now);
            const key = minutes < 1
                ? "menubar.center.activity.timer_under_minute"
                : "menubar.center.activity.timer_minutes";
            return I18n.tr(key, {
                "label": activity.label,
                "minutes": minutes
            });
        }
        return I18n.tr("menubar.center.activity.job_progress", {
            "label": activity.label,
            "percent": Math.round(activity.progress)
        });
    }

    function refreshPresentation(now: double): void {
        const activity = CenterActivityRules.current(root.activityState);
        if (activity === null) {
            root.projectedPresentation = null;
            return;
        }
        root.projectedPresentation = Object.freeze({
            "id": activity.id,
            "source": activity.source,
            "icon": activity.icon,
            "title": root.titleFor(activity, now),
            "progress": activity.progress
        });
    }

    function reschedule(): void {
        root.rotationTimer.stop();
        root.scheduledAt = 0;
        if (root.activeCount === 0 || CenterAttentionService.hasTransient)
            return;

        const delay = root.showingFocus ? 10000 : 6000;
        root.rotationTimer.interval = delay;
        root.scheduledAt = Date.now() + delay;
        root.rotationTimer.start();
    }

    function upsert(descriptor: var): bool {
        const previousCount = root.activeCount;
        const previousId = root.activityState.currentId;
        const previousFocus = root.showingFocus;
        const nextState = CenterActivityRules.upsert(
            root.activityState, descriptor, Date.now());
        if (nextState === root.activityState)
            return false;

        root.activityState = nextState;
        root.refreshPresentation(Date.now());
        if (previousCount === 0 || previousId !== nextState.currentId
                || previousFocus !== nextState.showingFocus)
            root.reschedule();
        return true;
    }

    function remove(activityId: string): bool {
        const previousId = root.activityState.currentId;
        const previousFocus = root.showingFocus;
        const nextState = CenterActivityRules.remove(root.activityState, activityId);
        if (nextState === root.activityState)
            return false;

        root.activityState = nextState;
        root.refreshPresentation(Date.now());
        if (root.activeCount === 0 || previousId !== nextState.currentId
                || previousFocus !== nextState.showingFocus)
            root.reschedule();
        return true;
    }

    function advance(): void {
        if (CenterAttentionService.hasTransient) {
            root.reschedule();
            return;
        }
        const nextState = CenterActivityRules.advance(root.activityState);
        if (nextState !== root.activityState)
            root.activityState = nextState;
        root.refreshPresentation(Date.now());
        root.reschedule();
    }

    function snapshot(): string {
        return JSON.stringify({
            activeCount: root.activeCount,
            showingFocus: root.showingFocus,
            currentId: root.activityState.currentId,
            presentation: root.presentation,
            activities: root.activityState.activities,
            scheduledAt: root.scheduledAt,
            suspended: CenterAttentionService.hasTransient
        });
    }

    function activate(): void {}

    property Connections attentionConnections: Connections {
        target: CenterAttentionService

        function onHasTransientChanged(): void {
            if (CenterAttentionService.hasTransient) {
                root.rotationTimer.stop();
                root.scheduledAt = 0;
                return;
            }
            root.refreshPresentation(Date.now());
            root.reschedule();
        }
    }
}
