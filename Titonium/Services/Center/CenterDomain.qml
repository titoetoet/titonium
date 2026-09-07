pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Services.Center.adapters as Adapters
import qs.Titonium.Services.Capture
import "../Capture/CaptureFeedbackRules.js" as CaptureFeedbackRules
import "CenterDomainRules.js" as CenterDomainRules
import "CompactActivityRules.js" as CompactActivityRules

QtObject {
    id: root

    signal presentationRequested(var request)
    signal presentationEnded(var request)

    property var storedSnapshot: CenterDomainRules.snapshot(null, {}, 0)
    property var compactSelection: CompactActivityRules.reconcile(null, [])
    readonly property var presentationSnapshot: Object.freeze(Object.assign({}, root.snapshot, {
        compact: CaptureFeedbackRules.project(root.compactSelection, root.snapshot.contexts,
            CaptureFeedbackService.feedback)
    }))

    function selectCaptureContext(contextId: string): void { CaptureFeedbackService.select(contextId); }
    property string activePresentationId: ""
    property string activePresentationOwnerId: ""
    property string activePresentationContextId: ""
    readonly property var rawProjection: ({
        contexts: capture.contexts.concat(media.contexts, notifications.contexts,
            approval.contexts, focus.contexts, timers.contexts, jobs.contexts),
        indicators: capture.indicators.concat(media.indicators, notifications.indicators,
            approval.indicators, focus.indicators, timers.indicators, jobs.indicators),
        actions: capture.actions.concat(media.actions, notifications.actions,
            approval.actions, focus.actions, timers.actions, jobs.actions)
    })
    readonly property var snapshot: root.storedSnapshot

    function rebuild(): void {
        root.storedSnapshot = CenterDomainRules.snapshot(
            root.storedSnapshot, root.rawProjection, Date.now());
        root.compactSelection = CompactActivityRules.reconcile(
            root.compactSelection, root.storedSnapshot.contexts);
    }

    function dispatch(intent: var): var {
        return dispatcher.dispatch(root.snapshot, intent);
    }

    function setPresentationEligible(eligible: bool): bool {
        let changed = false;
        const adapters = [root.notifications];
        for (let index = 0; index < adapters.length; index++) {
            const adapter = adapters[index];
            const previousPresentationId = String(adapter.presentation?.id || "");
            const adapterChanged = adapter.setPresentationEligible(eligible);
            changed = adapterChanged || changed;
            if (adapterChanged && eligible) {
                root.rebuild();
                const resumedPresentationId = String(adapter.presentation?.id || "");
                root.syncAdapterPresentation(adapter,
                    previousPresentationId === resumedPresentationId);
            }
        }
        return changed;
    }

    function adapterForContext(contextId: string): var {
        const context = root.snapshot.contexts.find(item => item.id === contextId);
        return context ? dispatcher.routes[context.source] : null;
    }

    function completePresentation(contextId: string): var {
        const adapter = root.adapterForContext(contextId);
        return adapter && typeof adapter.completePresentation === "function"
            ? adapter.completePresentation(contextId) : Object.freeze({
            accepted: false,
            status: "stale",
            reason: "missing-presentation",
            closePolicy: "keep",
        });
    }

    function syncAdapterPresentation(adapter: var, force: bool): void {
        const presentation = adapter?.presentation || null;
        const nextId = String(presentation?.id || "");
        if (!force && nextId === root.activePresentationId)
            return;
        const previousId = root.activePresentationId;
        const previousOwnerId = root.activePresentationOwnerId;
        const previousContextId = root.activePresentationContextId;
        root.activePresentationId = nextId;
        root.activePresentationOwnerId = String(presentation?.ownerId || "");
        root.activePresentationContextId = String(presentation?.contextId || "");
        if (presentation) {
            root.presentationRequested(presentation);
            return;
        }
        if (previousId)
            root.presentationEnded(Object.freeze({
                id: previousId,
                ownerId: previousOwnerId,
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
        if (!presentation || !contextId
                || (presentation.source === "capture" && ["recording_started", "screenshot_saved"].includes(presentation.kind)))
            return;
        root.presentationRequested(Object.freeze({
            id: String(presentation.id || contextId) + ":presentation",
            ownerId: String(presentation.source || "attention"),
            acquisitionPolicy: "preemptive",
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

    property Connections automaticPresentationConnection: Connections {
        target: root.notifications
        function onPresentationChanged(): void {
            root.rebuild();
            root.syncAdapterPresentation(root.notifications, false);
        }
    }

    onRawProjectionChanged: root.rebuild()
    Component.onCompleted: {
        root.rebuild();
        root.syncAdapterPresentation(root.notifications, false);
    }
}
