pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Titonium.Bar.center
import qs.Titonium.Core.Surfaces
import "CenterSurfacePresentationRules.js" as PresentationRules

PanelWindow {
    id: window
    required property ShellScreen screenModel
    required property var snapshot
    required property var viewState
    required property var profile
    readonly property bool ownsOverlay: window.viewState.ownerScreenName === window.screenModel.name
        && (window.viewState.mode === "banner" || window.viewState.mode === "expanded")
    readonly property bool dismissing: window.viewState.exitingScreenName === window.screenModel.name
    readonly property rect visualBounds: renderer.visualBounds
    readonly property string focusOwnerId: "center:" + window.screenModel.name
    property string focusLease: ""
    readonly property bool wantsInteractiveFocus: window.ownsOverlay
        && window.viewState.focusPolicy === "exclusive"
    readonly property bool effectiveInteractiveFocus: window.wantsInteractiveFocus
        && FocusArbiter.granted(window.focusOwnerId, window.focusLease)
    property string lastClassicOwnerScreenName: ""
    property int lastClassicOwnerGeneration: 0
    property int completedClassicExitGeneration: 0
    readonly property bool classicTransitionPending:
        window.profile.id === "classic"
        && PresentationRules.compactExitPending(window.viewState,
            window.screenModel.name, window.lastClassicOwnerScreenName,
            window.lastClassicOwnerGeneration, window.completedClassicExitGeneration)
    readonly property bool classicTransitionOwner:
        PresentationRules.transitionOwner(window.viewState, window.screenModel.name)
        || window.classicTransitionPending

    function refreshInputMask(): void {
        inputMask.changed();
    }

    function closeIntent(): var {
        if (window.viewState.mode === "banner"
                && window.viewState.dismissalPolicy === "timed") {
            return Object.freeze({
                type: "user-dismiss-presentation",
                generation: window.viewState.generation,
                contextId: window.viewState.selectedContextId,
                deadline: window.viewState.deadlineToken,
            });
        }
        return Object.freeze({ type: "request-mode", mode: "compact" });
    }

    onWantsInteractiveFocusChanged: {
        if (window.focusLease)
            FocusArbiter.request(window.focusOwnerId, window.focusLease,
                window.wantsInteractiveFocus);
    }
    onEffectiveInteractiveFocusChanged: FocusDiagnostics.observe(
        window.focusOwnerId, window.focusLease, window.effectiveInteractiveFocus, {
            mode: window.viewState.mode, generation: window.viewState.generation,
            focusPolicy: window.viewState.focusPolicy
        })
    Component.onCompleted: {
        window.focusLease = FocusArbiter.newLease("center");
        FocusArbiter.request(window.focusOwnerId, window.focusLease,
            window.wantsInteractiveFocus);
    }

    screen: window.screenModel
    visible: window.ownsOverlay || window.dismissing || window.classicTransitionPending
    color: "transparent"
    aboveWindows: true
    exclusiveZone: 0
    WlrLayershell.namespace: "titonium-center-overlay"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: window.wantsInteractiveFocus
        && FocusArbiter.granted(window.focusOwnerId, window.focusLease)
        ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    anchors { top: true; bottom: true; left: true; right: true }
    mask: Region {
        id: inputMask
        Region { item: overlayInput }
        Region { item: dismissingInput }
    }

    onOwnsOverlayChanged: window.refreshInputMask()
    onViewStateChanged: {
        if (window.profile.id === "classic" && window.ownsOverlay
                && window.viewState.ownerScreenName === window.screenModel.name) {
            window.lastClassicOwnerScreenName = window.screenModel.name;
            window.lastClassicOwnerGeneration = window.viewState.generation;
            window.completedClassicExitGeneration = 0;
        }
    }
    onDismissingChanged: window.refreshInputMask()
    onVisualBoundsChanged: window.refreshInputMask()

    Item {
        id: overlayInput
        width: window.ownsOverlay ? window.width : 0
        height: window.ownsOverlay ? window.height : 0
    }
    Item {
        id: dismissingInput
        x: renderer.visualBounds.x
        y: renderer.visualBounds.y
        width: window.dismissing ? renderer.visualBounds.width : 0
        height: window.dismissing ? renderer.visualBounds.height : 0
    }
    TapHandler {
        enabled: window.ownsOverlay
        onTapped: eventPoint => {
            const bounds = renderer.visualBounds;
            const point = eventPoint.position;
            if (point.x < bounds.x || point.x > bounds.x + bounds.width
                    || point.y < bounds.y || point.y > bounds.y + bounds.height)
                CenterSurfaceController.dispatch(window.closeIntent());
        }
    }
    CenterRenderer {
        id: renderer
        anchors.fill: parent
        snapshot: window.snapshot
        viewState: window.viewState
        profile: window.profile
        transitionOwner: window.classicTransitionOwner
        presentationActive: window.ownsOverlay || window.dismissing
            || window.classicTransitionPending
        onIntentRequested: intent => CenterSurfaceController.dispatch(intent)
        onTransitionFinished: generation => {
            if (window.classicTransitionPending
                    && generation === window.viewState.generation) {
                window.completedClassicExitGeneration = generation;
                window.lastClassicOwnerScreenName = "";
                window.lastClassicOwnerGeneration = 0;
            }
            CenterSurfaceController.dispatch({ type: "transition-finished", generation: generation });
            if (window.dismissing)
                CenterSurfaceController.finishClose(window.screenModel.name, generation);
        }
        Keys.onEscapePressed: CenterSurfaceController.dispatch(window.closeIntent())
    }

    Component.onDestruction: {
        FocusArbiter.withdraw(window.focusOwnerId, window.focusLease);
        FocusDiagnostics.observe(window.focusOwnerId, window.focusLease, false,
            { mode: "destroyed" });
    }
}
