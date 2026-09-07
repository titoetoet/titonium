pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Services.Center
import qs.Titonium.Services.SystemMonitor
import qs.Titonium.Services.Mpris
import qs.Titonium.Services.MediaSpectrum
import qs.Titonium.Core.Runtime
import qs.Titonium.Theme
import "CenterSurfaceState.js" as CenterSurfaceState
import "CenterPreviewRules.js" as PreviewRules
import "ExpandedNavigation.js" as ExpandedNavigation

QtObject {
    id: root

    readonly property bool mediaDetailsVisible: root.mode === "expanded" && !!root.ownerScreenName
        // Demand must not depend on playback details: starting/stopping the queue
        // reader changes those details and would re-enter this binding.
        && root.expandedTab === "dashboard"
    property Binding mediaDetailsDemand: Binding {
        target: MprisService
        property: "detailsActive"
        value: root.mediaDetailsVisible
    }

    property Binding visualizationDemand: Binding {
        target: MediaSpectrumService
        property: "enabled"
        value: !Motion.reduced && ((root.mediaDetailsVisible && MprisService.playing)
            || (root.mode === "compact" && root.ownerScreenName !== "" && BarVisibilityState.revealed
            && [CenterDomain.presentationSnapshot.compact.primary, CenterDomain.presentationSnapshot.compact.secondary].some(
                item => item?.source === "media" && item.details?.playing === true)))
    }

    readonly property bool monitoringVisible: root.mode === "expanded" && !!root.ownerScreenName
        && root.expandedTab === "monitoring"
    onMonitoringVisibleChanged: {
        if (root.monitoringVisible) SystemMonitorService.start();
        else SystemMonitorService.stop();
    }

    property var preview: PreviewRules.initial()
    property var heldPreviewContext: null
    property var pendingPreviewPresentation: null
    property int previewGeneration: 0
    readonly property string expandedTab: root.internalState.expandedTab
    onModeChanged: {
        if (root.mode !== "banner" && root.mode !== "compact") root.clearPreview();
        if (root.mode === "compact") root.heldPreviewContext = null;
    }

    function clearPreview(): void {
        previewTimer.stop();
        root.preview = PreviewRules.initial();
        root.heldPreviewContext = null;
        root.pendingPreviewPresentation = null;
    }
    function previewDeadlineIntent(type: string): var {
        return { type: type, generation: root.generation,
            contextId: root.selectedContextId, deadline: root.internalState.deadlineToken };
    }
    function schedulePreview(): void {
        previewTimer.stop();
        const due = root.preview.openAt || root.preview.closeAt;
        if (due <= 0) return;
        root.previewGeneration = root.generation;
        previewTimer.interval = Math.max(1, due - Date.now());
        previewTimer.start();
    }
    function updatePreview(intent: var): bool {
        if (root.mode !== "compact" && root.mode !== "banner") return false;
        const region = String(intent.region || "banner");
        if (intent.type === "preview-enter") {
            // Empty compact hover must never revive the previously selected context.
            if (root.mode === "compact" && !intent.contextId) return false;
            root.preview = PreviewRules.enter(root.preview, region,
                String(intent.contextId || root.selectedContextId), Date.now(), root.mode === "compact");
            if (root.mode === "banner") {
                if (!root.heldPreviewContext)
                    root.heldPreviewContext = CenterSurfaceState.contextById(CenterDomain.snapshot, root.selectedContextId);
                root.dispatch(root.previewDeadlineIntent("pause-timeout"));
            }
        } else {
            root.preview = PreviewRules.leave(root.preview, region, Date.now());
        }
        root.schedulePreview();
        return true;
    }
    property Timer previewTimer: Timer {
        repeat: false
        onTriggered: {
            if (root.previewGeneration !== root.generation) { root.clearPreview(); return; }
            const action = PreviewRules.due(root.preview, Date.now());
            if (!action) { root.schedulePreview(); return; }
            if (action === "open" && root.mode === "compact" && root.automaticPresentationAvailable) {
                const contextId = root.preview.contextId;
                root.preview = Object.assign({}, root.preview, { openAt: 0 });
                root.dispatch({ type: "present", contextId: contextId,
                    requestedMode: "banner", presentationOwner: "hover", timeoutMs: 0 });
            } else if (action === "close") {
                root.preview = PreviewRules.initial();
                root.heldPreviewContext = null;
                if (root.mode === "banner" && root.presentationOwner === "hover")
                    root.dispatch({ type: "request-mode", mode: "compact" });
                else if (root.mode === "banner")
                    root.dispatch(root.previewDeadlineIntent("resume-timeout"));
                if (root.pendingPreviewPresentation) {
                    const request = root.pendingPreviewPresentation;
                    root.pendingPreviewPresentation = null;
                    root.requestPresentation(request);
                }
            }
        }
    }

    signal surfaceRequested(var request)
    signal navigationRequested(var request)

    property var internalState: CenterSurfaceState.initialState()
    property bool automaticPresentationAvailable: false
    property int scheduledDeadlineGeneration: 0
    property string scheduledDeadlineContextId: ""
    property double scheduledDeadline: 0
    readonly property string ownerScreenName: root.internalState.ownerScreenName
    readonly property string exitingScreenName: root.internalState.exitingScreenName
    readonly property string mode: root.internalState.mode
    readonly property string selectedContextId: root.internalState.selectedContextId
    readonly property string presentationOwner: root.internalState.presentationOwner
    readonly property string destination: root.internalState.destination
    readonly property real dragProgress: root.internalState.dragProgress
    readonly property bool active: root.mode === "banner" || root.mode === "expanded"
    readonly property bool automaticPresentationEligible:
        root.automaticPresentationAvailable
        && CenterSurfaceState.automaticPresentationEligible(
            root.internalState, CenterDomain.snapshot)
    readonly property int generation: root.internalState.generation
    readonly property var viewState: Object.freeze({
        generation: root.generation,
        ownerScreenName: root.ownerScreenName,
        exitingScreenName: root.exitingScreenName,
        mode: root.mode,
        selectedContextId: root.selectedContextId,
        presentationOwner: root.presentationOwner,
        destination: root.destination,
        expandedTab: root.expandedTab,
        previewContext: root.mode === "banner" ? root.heldPreviewContext : null,
        dragProgress: root.dragProgress,
        focusPolicy: root.internalState.focusPolicy,
        dismissalPolicy: root.internalState.dismissalPolicy,
        deadline: root.internalState.deadline,
        deadlineToken: root.internalState.deadlineToken,
    })

    onSelectedContextIdChanged: CenterDomain.selectCaptureContext(root.active ? root.selectedContextId : "")
    onActiveChanged: CenterDomain.selectCaptureContext(root.active ? root.selectedContextId : "")

    function replaceState(next: var): bool {
        if (next === root.internalState)
            return false;
        root.internalState = next;
        root.rescheduleDeadline();
        return true;
    }

    function syncPresentationEligibility(): bool {
        return CenterDomain.setPresentationEligible(root.automaticPresentationEligible);
    }

    function completeActivePresentation(contextId: string, now: double): var {
        const result = CenterDomain.completePresentation(contextId);
        if (result.accepted)
            root.replaceState(CenterSurfaceState.applyPresentationResult(
                root.internalState, CenterDomain.snapshot, result, now));
        return result;
    }

    function dispatch(intent: var): var {
        if (!intent || typeof intent !== "object")
            return false;
        if (intent.type === "preview-enter" || intent.type === "preview-leave")
            return root.updatePreview(intent);
        if (intent.type === "select-tab") {
            if (root.mode !== "expanded") return false;
            return root.replaceState(CenterSurfaceState.transition(root.internalState,
                CenterDomain.snapshot, intent, Date.now()));
        }
        if (intent.type === "request-mode" && intent.mode === "expanded") {
            const context = CenterSurfaceState.contextById(CenterDomain.snapshot, root.selectedContextId);
            const route = ExpandedNavigation.route(context, root.expandedTab);
            root.replaceState(CenterSurfaceState.transition(root.internalState, CenterDomain.snapshot,
                { type: "select-tab", tab: route.tab }, Date.now()));
        }
        if (intent.type === "media-seek") {
            return root.mediaDetailsVisible && intent.contextId === "media:current"
                && MprisService.seekTo(String(intent.identity || ""), Number(intent.trackToken), Number(intent.fraction));
        }
        if (intent.type === "compact-volume") {
            const compact = CenterDomain.presentationSnapshot.compact;
            const context = [compact.primary, compact.secondary].find(item => item?.id === intent.contextId);
            return root.mode === "compact" && context?.source === "media"
                && MprisService.adjustVolume(String(intent.identity || ""), Number(intent.delta));
        }
        if (intent.type === "compact-privacy-action") {
            const context = CenterDomain.snapshot.contexts.find(item => item.id === intent.contextId);
            if (root.mode !== "compact" || context?.source !== "capture"
                    || context.occurredAt !== intent.occurredAt)
                return false;
            return CenterDomain.dispatch({ type: "invoke-action", contextId: context.id,
                actionId: intent.actionId });
        }
        if (intent.type === "activate-compact" || intent.type === "activate-preview") {
            const compact = CenterDomain.presentationSnapshot.compact;
            const contextId = String(intent.contextId || (root.mode === "banner"
                ? root.selectedContextId : compact.primary?.id) || "");
            const context = CenterSurfaceState.contextById(CenterDomain.snapshot, contextId);
            const retained = root.mode === "banner" && root.heldPreviewContext?.id === contextId
                ? root.heldPreviewContext : null;
            if (contextId && !context && !retained) return false;
            return root.dispatch({ type: "request-open", mode: "expanded",
                contextId: context ? contextId : "",
                tab: ExpandedNavigation.route(context || retained, root.expandedTab).tab,
                screenName: root.ownerScreenName });
        }
        if (intent.type === "set-presentation-available") {
            const available = intent.available === true;
            if (available === root.automaticPresentationAvailable)
                return false;
            root.automaticPresentationAvailable = available;
            return true;
        }
        if (intent.type === "request-open") {
            if (intent.mode === "expanded" && !intent.contextId) {
                root.replaceState(CenterSurfaceState.nextState(root.internalState,
                    { selectedContextId: "" }, false));
            }
            root.surfaceRequested(Object.freeze({
                type: "acquire-surface", owner: "center",
                screenName: String(intent.screenName || ""),
                focusPolicy: String(intent.focusPolicy || "none"),
                mode: String(intent.mode || "compact"),
                contextId: String(intent.contextId || ""),
                presentationOwner: "user",
                destination: intent.mode === "expanded"
                    ? (intent.tab || ExpandedNavigation.route(CenterSurfaceState.contextById(CenterDomain.snapshot, intent.contextId), root.expandedTab).tab)
                    : String(intent.destination || "overview"),
                timeoutMs: Math.max(0, Number(intent.timeoutMs) || 0)
            }));
            return true;
        }
        if (intent.type === "navigate") {
            root.navigationRequested(Object.freeze({
                type: "navigate", destination: String(intent.destination || ""),
                contextId: String(intent.contextId || root.selectedContextId)
            }));
            return true;
        }
        if (intent.type === "invoke-action") {
            const result = CenterDomain.dispatch(intent);
            root.replaceState(CenterSurfaceState.applyPresentationResult(
                root.internalState, CenterDomain.snapshot, result, Date.now()));
            return result;
        }
        if (intent.type === "user-dismiss-presentation") {
            if (!CenterSurfaceState.timedPresentationMatches(root.internalState, intent))
                return false;
            const now = Date.now();
            const result = root.completeActivePresentation(intent.contextId, now);
            if (result.accepted)
                return result;
            return root.replaceState(CenterSurfaceState.transition(
                root.internalState, CenterDomain.snapshot,
                { type: "request-mode", mode: "compact" }, now));
        }
        if (intent.type === "pause-timeout") {
            const now = Date.now();
            if (CenterSurfaceState.deadlineMatches(root.internalState, intent, now)) {
                const result = root.completeActivePresentation(intent.contextId, now);
                if (result.accepted)
                    return result;
                return root.replaceState(CenterSurfaceState.transition(
                    root.internalState, CenterDomain.snapshot,
                    Object.assign({}, intent, { type: "timeout" }), now));
            }
            return root.replaceState(CenterSurfaceState.pauseDeadline(
                root.internalState, intent, now));
        }
        if (intent.type === "resume-timeout") {
            return root.replaceState(CenterSurfaceState.resumeDeadline(
                root.internalState, intent, Date.now()));
        }
        if (intent.type === "timeout") {
            const now = Date.now();
            if (!CenterSurfaceState.deadlineMatches(root.internalState, intent, now)) {
                // A one-shot callback can arrive before the absolute deadline.
                // Keep that deadline armed without reviving stale or paused work.
                if (CenterSurfaceState.timedPresentationMatches(root.internalState, intent)
                        && root.internalState.deadline === root.internalState.deadlineToken
                        && root.internalState.deadline > now)
                    root.rescheduleDeadline();
                return false;
            }
            const result = root.completeActivePresentation(intent.contextId, now);
            if (result.accepted)
                return result;
            return root.replaceState(CenterSurfaceState.transition(
                root.internalState, CenterDomain.snapshot, intent, now));
        }
        const changed = root.replaceState(CenterSurfaceState.transition(
            root.internalState, CenterDomain.snapshot, intent, Date.now()));
        if (changed && intent.type === "present") {
            root.heldPreviewContext = root.preview.regions.length > 0
                ? CenterSurfaceState.contextById(CenterDomain.snapshot, root.selectedContextId) : null;
            if (root.preview.regions.length > 0)
                root.dispatch(root.previewDeadlineIntent("pause-timeout"));
            // Keep a pending leave grace tied to the accepted presentation generation.
            root.schedulePreview();
        }
        return changed;
    }

    function finishClose(screenName: string, generation: int): bool {
        return root.dispatch({ type: "finish-close", screenName: screenName,
            generation: generation });
    }

    function rescheduleDeadline(): void {
        deadlineTimer.stop();
        root.scheduledDeadlineGeneration = 0;
        root.scheduledDeadlineContextId = "";
        root.scheduledDeadline = 0;
        if (root.internalState.deadline <= 0)
            return;
        root.scheduledDeadlineGeneration = root.internalState.generation;
        root.scheduledDeadlineContextId = root.internalState.selectedContextId;
        root.scheduledDeadline = root.internalState.deadline;
        const remaining = root.internalState.deadline - Date.now();
        if (remaining <= 0) {
            const intent = root.scheduledDeadlineIntent();
            Qt.callLater(() => root.dispatch(intent));
            return;
        }
        deadlineTimer.interval = Math.max(1, Math.min(2147483647, remaining));
        deadlineTimer.start();
    }

    function scheduledDeadlineIntent(): var {
        return Object.freeze({
            type: "timeout",
            generation: root.scheduledDeadlineGeneration,
            contextId: root.scheduledDeadlineContextId,
            deadline: root.scheduledDeadline,
        });
    }

    property Timer deadlineTimer: Timer {
        repeat: false
        onTriggered: root.dispatch(root.scheduledDeadlineIntent())
    }

    function requestPresentation(request: var): void {
        const incoming = CenterSurfaceState.contextById(CenterDomain.snapshot, request.contextId);
        // A delayed preview may have ended while the pointer remained inside.
        if (!incoming) return;
        const critical = incoming.attention === "blocking" || request.focusPolicy === "exclusive"
            || String(request.ownerId || request.id || "").indexOf("notification-critical") === 0;
        if (critical) root.pendingPreviewPresentation = null;
        const current = CenterSurfaceState.contextById(CenterDomain.snapshot, root.selectedContextId);
        if (!critical && root.mode === "banner"
                && (current?.attention === "blocking" || root.internalState.focusPolicy === "exclusive"))
            return;
        if (root.mode === "banner" && root.preview.regions.length > 0
                && root.selectedContextId !== request.contextId && !critical) {
            root.pendingPreviewPresentation = request;
            return;
        }

        const presentationOwner = String(request.ownerId || request.id || "attention");
        if (request.acquisitionPolicy === "non-preemptive") {
            if (!root.automaticPresentationEligible)
                return;
            if (root.mode === "banner" && root.presentationOwner === presentationOwner
                    && root.ownerScreenName) {
                root.dispatch({
                    type: "present",
                    contextId: request.contextId,
                    requestedMode: "banner",
                    timeoutMs: request.timeoutMs,
                    focusPolicy: request.focusPolicy,
                    presentationOwner: presentationOwner,
                    acquisitionPolicy: request.acquisitionPolicy,
                });
                return;
            }
        }
        root.surfaceRequested(Object.freeze({
            type: "acquire-surface", owner: "center", screenName: "",
            focusPolicy: request.focusPolicy, mode: request.requestedMode,
            contextId: request.contextId, destination: "overview",
            timeoutMs: request.timeoutMs,
            presentationOwner: presentationOwner,
            acquisitionPolicy: request.acquisitionPolicy,
        }));
    }

    property Connections domainConnection: Connections {
        target: CenterDomain
        function onSnapshotChanged(): void {
            root.dispatch({ type: "snapshot-changed" });
        }
        function onPresentationRequested(request: var): void { root.requestPresentation(request); }
        function onPresentationEnded(request: var): void {
            const pending = root.pendingPreviewPresentation;
            if (pending && pending.contextId === request.contextId
                    && (!request.id || !pending.id || pending.id === request.id))
                root.pendingPreviewPresentation = null;
            if (request.ownerId !== root.presentationOwner || root.mode !== "banner")
                return;
            root.replaceState(CenterSurfaceState.transition(root.internalState,
                CenterDomain.snapshot, { type: "request-mode", mode: "compact" },
                Date.now()));
        }
    }

    onAutomaticPresentationEligibleChanged: root.syncPresentationEligibility()
    Component.onCompleted: root.syncPresentationEligibility()
}
