pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Services.Center.adapters as Adapters
import "CenterDomainRules.js" as CenterDomainRules

QtObject {
    id: root

    signal presentationRequested(var request)
    signal presentationEnded(var request)

    property var storedSnapshot: null
    property string activeNotificationPresentationId: ""
    property string activeNotificationContextId: ""
    readonly property var rawProjection: ({
        contexts: capture.contexts.concat(media.contexts, notifications.contexts,
            approval.contexts, focus.contexts, timers.contexts, jobs.contexts),
        indicators: capture.indicators.concat(media.indicators, notifications.indicators,
            approval.indicators, focus.indicators, timers.indicators, jobs.indicators),
        actions: capture.actions.concat(media.actions, notifications.actions,
            approval.actions, focus.actions, timers.actions, jobs.actions)
    })
    readonly property var snapshot: root.storedSnapshot || CenterDomainRules.snapshot(
        null, root.rawProjection, Date.now())

    function rebuild(): void {
        root.storedSnapshot = CenterDomainRules.snapshot(
            root.storedSnapshot, root.rawProjection, Date.now());
    }

    function dispatch(intent: var): var {
        return dispatcher.dispatch(root.snapshot, intent);
    }

    function setPresentationEligible(eligible: bool): bool {
        const previousPresentationId = String(
            root.notifications.presentation?.id || "");
        const changed = root.notifications.setPresentationEligible(eligible);
        if (changed && eligible) {
            root.rebuild();
            const resumedPresentationId = String(
                root.notifications.presentation?.id || "");
            root.syncNotificationPresentation(
                previousPresentationId === resumedPresentationId);
        }
        return changed;
    }

    function adapterForPresentation(contextId: string): var {
        const context = root.snapshot.contexts.find(item => item.id === contextId);
        return context && context.source === "notification" ? root.notifications : null;
    }

    function pausePresentation(contextId: string): bool {
        const adapter = root.adapterForPresentation(contextId);
        return adapter ? adapter.pausePresentation(contextId) : false;
    }

    function resumePresentation(contextId: string): bool {
        const adapter = root.adapterForPresentation(contextId);
        return adapter ? adapter.resumePresentation(contextId) : false;
    }

    function completePresentation(contextId: string): var {
        const adapter = root.adapterForPresentation(contextId);
        return adapter ? adapter.completePresentation(contextId) : Object.freeze({
            accepted: false,
            status: "stale",
            reason: "missing-presentation",
            closePolicy: "keep",
        });
    }

    function syncNotificationPresentation(force: bool): void {
        const presentation = root.notifications.presentation;
        const nextId = String(presentation?.id || "");
        if (!force && nextId === root.activeNotificationPresentationId)
            return;
        const previousId = root.activeNotificationPresentationId;
        const previousContextId = root.activeNotificationContextId;
        root.activeNotificationPresentationId = nextId;
        root.activeNotificationContextId = String(presentation?.contextId || "");
        if (presentation) {
            root.presentationRequested(presentation);
            return;
        }
        if (previousId)
            root.presentationEnded(Object.freeze({
                id: previousId,
                source: "notification",
                contextId: previousContextId,
            }));
    }

    function contextIdForPresentation(presentation: var): string {
        if (!presentation)
            return "";
        const exact = root.snapshot.contexts.find(item => item.id === presentation.id);
        if (exact)
            return exact.id;
        const source = String(presentation.source || "");
        const matching = root.snapshot.contexts.find(item => item.source === source);
        return matching ? matching.id : "";
    }

    function publishCurrentPresentation(): void {
        const presentation = CenterAttentionService.presentation;
        const contextId = root.contextIdForPresentation(presentation);
        if (!presentation || !contextId)
            return;
        root.presentationRequested(Object.freeze({
            id: String(presentation.id || contextId) + ":presentation",
            source: String(presentation.source || "attention"),
            contextId: contextId,
            requestedMode: "banner",
            attention: presentation.source === "agent" ? "blocking" : "transient",
            timeoutMs: presentation.source === "agent" ? 0 : Math.max(0,
                Number(presentation.expiresAt || 0) - Date.now()),
            focusPolicy: presentation.source === "agent" ? "exclusive" : "none"
        }));
    }

    property Adapters.CaptureCenterAdapter capture: Adapters.CaptureCenterAdapter {}
    property Adapters.MediaCenterAdapter media: Adapters.MediaCenterAdapter {}
    property Adapters.NotificationCenterAdapter notifications: Adapters.NotificationCenterAdapter {}
    property Adapters.AgentApprovalCenterAdapter approval: Adapters.AgentApprovalCenterAdapter {}
    property Adapters.FocusCenterAdapter focus: Adapters.FocusCenterAdapter {}
    property Adapters.TimerCenterAdapter timers: Adapters.TimerCenterAdapter {}
    property Adapters.JobCenterAdapter jobs: Adapters.JobCenterAdapter {}

    property CenterActionDispatcher dispatcher: CenterActionDispatcher {
        id: dispatcher
        routes: Object.freeze({
            capture: root.capture, media: root.media, notification: root.notifications,
            agent: root.approval, focus: root.focus, timer: root.timers, job: root.jobs
        })
    }

    property Connections attentionConnection: Connections {
        target: CenterAttentionService
        function onPresentationChanged(): void {
            root.rebuild();
            root.publishCurrentPresentation();
        }
    }

    property Connections notificationConnection: Connections {
        target: root.notifications
        function onPresentationChanged(): void {
            root.rebuild();
            root.syncNotificationPresentation(false);
        }
    }

    onRawProjectionChanged: root.rebuild()
    Component.onCompleted: {
        root.rebuild();
        root.syncNotificationPresentation(false);
    }
}
