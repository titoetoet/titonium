pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Services.Center
import "CenterSurfaceState.js" as CenterSurfaceState

QtObject {
    id: root

    signal surfaceRequested(var request)
    signal navigationRequested(var request)

    property var internalState: CenterSurfaceState.initialState()
    property bool automaticPresentationAvailable: false
    readonly property string ownerScreenName: root.internalState.ownerScreenName
    readonly property string exitingScreenName: root.internalState.exitingScreenName
    readonly property string mode: root.internalState.mode
    readonly property string selectedContextId: root.internalState.selectedContextId
    readonly property string presentationOwner: root.internalState.presentationOwner
    readonly property string destination: root.internalState.destination
    readonly property real dragProgress: root.internalState.dragProgress
    readonly property bool active: root.mode === "banner" || root.mode === "expanded"
    readonly property bool criticalPresentationEligible:
        root.automaticPresentationAvailable
        && CenterSurfaceState.automaticPresentationEligible(root.internalState)
    readonly property int generation: root.internalState.generation
    readonly property var viewState: Object.freeze({
        generation: root.generation,
        ownerScreenName: root.ownerScreenName,
        exitingScreenName: root.exitingScreenName,
        mode: root.mode,
        selectedContextId: root.selectedContextId,
        presentationOwner: root.presentationOwner,
        destination: root.destination,
        dragProgress: root.dragProgress,
        focusPolicy: root.internalState.focusPolicy,
        dismissalPolicy: root.internalState.dismissalPolicy,
        deadline: root.internalState.deadline
    })

    function replaceState(next: var): bool {
        if (next === root.internalState)
            return false;
        root.internalState = next;
        root.rescheduleDeadline();
        return true;
    }

    function syncPresentationEligibility(): bool {
        return CenterDomain.setPresentationEligible(root.criticalPresentationEligible);
    }

    function dispatch(intent: var): var {
        if (!intent || typeof intent !== "object")
            return false;
        if (intent.type === "set-presentation-available") {
            const available = intent.available === true;
            if (available === root.automaticPresentationAvailable)
                return false;
            root.automaticPresentationAvailable = available;
            return true;
        }
        if (intent.type === "request-open") {
            root.surfaceRequested(Object.freeze({
                type: "acquire-surface", owner: "center",
                screenName: String(intent.screenName || ""),
                focusPolicy: String(intent.focusPolicy || "none"),
                mode: String(intent.mode || "compact"),
                contextId: String(intent.contextId || ""),
                presentationOwner: "user",
                destination: String(intent.destination || "overview"),
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
        if (intent.type === "pause-timeout") {
            const domainChanged = CenterDomain.pausePresentation(root.selectedContextId);
            const stateChanged = root.replaceState(CenterSurfaceState.pauseDeadline(
                root.internalState, Date.now()));
            return domainChanged || stateChanged;
        }
        if (intent.type === "resume-timeout") {
            const domainChanged = CenterDomain.resumePresentation(root.selectedContextId);
            const stateChanged = root.replaceState(CenterSurfaceState.resumeDeadline(
                root.internalState, Date.now()));
            return domainChanged || stateChanged;
        }
        if (intent.type === "timeout" && root.presentationOwner === "notification"
                && root.mode === "banner" && root.internalState.deadline > 0
                && Date.now() >= root.internalState.deadline) {
            const result = CenterDomain.completePresentation(root.selectedContextId);
            root.replaceState(CenterSurfaceState.applyPresentationResult(
                root.internalState, CenterDomain.snapshot, result, Date.now()));
            return result;
        }
        return root.replaceState(CenterSurfaceState.transition(
            root.internalState, CenterDomain.snapshot, intent, Date.now()));
    }

    function finishClose(screenName: string, generation: int): bool {
        return root.dispatch({ type: "finish-close", screenName: screenName,
            generation: generation });
    }

    function rescheduleDeadline(): void {
        deadlineTimer.stop();
        if (root.internalState.deadline <= 0)
            return;
        const remaining = root.internalState.deadline - Date.now();
        if (remaining <= 0) {
            Qt.callLater(() => root.dispatch({ type: "timeout", generation: root.generation }));
            return;
        }
        deadlineTimer.interval = Math.max(1, Math.min(2147483647, remaining));
        deadlineTimer.start();
    }

    property Timer deadlineTimer: Timer {
        repeat: false
        onTriggered: root.dispatch({ type: "timeout", generation: root.generation })
    }

    property Connections domainConnection: Connections {
        target: CenterDomain
        function onSnapshotChanged(): void {
            root.dispatch({ type: "snapshot-changed" });
        }
        function onPresentationRequested(request: var): void {
            const presentationOwner = String(request.source || "attention");
            if (presentationOwner === "notification") {
                if (!root.criticalPresentationEligible)
                    return;
                if (root.mode === "banner" && root.presentationOwner === "notification"
                        && root.ownerScreenName) {
                    root.dispatch({
                        type: "present",
                        contextId: request.contextId,
                        requestedMode: "banner",
                        timeoutMs: request.timeoutMs,
                        focusPolicy: request.focusPolicy,
                        presentationOwner: presentationOwner,
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
            }));
        }
        function onPresentationEnded(request: var): void {
            if (request.source !== root.presentationOwner || root.mode !== "banner")
                return;
            root.replaceState(CenterSurfaceState.transition(root.internalState,
                CenterDomain.snapshot, { type: "request-mode", mode: "compact" },
                Date.now()));
        }
    }

    onCriticalPresentationEligibleChanged: root.syncPresentationEligibility()
    Component.onCompleted: root.syncPresentationEligibility()
}
