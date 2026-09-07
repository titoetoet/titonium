pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Titonium.Core.Runtime
import qs.Titonium.Bar.center
import qs.Titonium.Core.Surfaces
import "CenterSurfacePresentationRules.js" as PresentationRules

PanelWindow {
    id: window
    readonly property bool pointerHovered: window.visible && compactHover.hovered
    required property ShellScreen screenModel
    required property var snapshot
    required property var viewState
    required property var profile
    readonly property bool ownsOverlay: window.viewState.ownerScreenName === window.screenModel.name
        && (window.viewState.mode === "banner" || window.viewState.mode === "expanded")
    readonly property bool dismissing: window.viewState.exitingScreenName === window.screenModel.name
    readonly property var windowPlan: PresentationRules.windowPlan(
        window.profile.id, window.viewState, window.screenModel.name, BarVisibilityState.revealed)
    readonly property rect visualBounds: renderer.visualBounds
    readonly property string focusOwnerId: "center:" + window.screenModel.name
    property string focusLease: ""
    readonly property bool wantsInteractiveFocus: window.windowPlan.focusActive
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
    readonly property string effectiveInputMode: window.classicTransitionPending
        ? "painted" : window.windowPlan.inputMode

    function refreshInputMask(): void {
        inputMask.changed();
    }

    function captureClassicOpenOwner(): void {
        const owner = PresentationRules.classicOpenOwner(
            window.profile.id, window.viewState, window.screenModel.name);
        if (!owner)
            return;
        window.lastClassicOwnerScreenName = owner.screenName;
        window.lastClassicOwnerGeneration = owner.generation;
        window.completedClassicExitGeneration = 0;
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
        window.captureClassicOpenOwner();
    }

    screen: window.screenModel
    visible: window.windowPlan.overlayMapped
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
        Region { item: compactInput }
        Region { item: dismissingInput }
    }

    onOwnsOverlayChanged: {
        window.refreshInputMask();
        window.captureClassicOpenOwner();
    }
    onProfileChanged: window.captureClassicOpenOwner()
    onViewStateChanged: {
        window.captureClassicOpenOwner();
    }
    onDismissingChanged: window.refreshInputMask()
    onEffectiveInputModeChanged: window.refreshInputMask()
    onVisualBoundsChanged: window.refreshInputMask()

    Item {
        id: overlayInput
        width: window.effectiveInputMode === "fullscreen" ? window.width : 0
        height: window.effectiveInputMode === "fullscreen" ? window.height : 0
    }
    Item {
        id: compactInput
        HoverHandler { id: compactHover; parent: renderer; enabled: window.effectiveInputMode === "compact" }
        x: renderer.interactiveBounds.x
        y: renderer.interactiveBounds.y
        width: window.effectiveInputMode === "compact"
            ? renderer.interactiveBounds.width : 0
        height: window.effectiveInputMode === "compact"
            ? renderer.interactiveBounds.height : 0
    }
    Item {
        id: dismissingInput
        x: renderer.visualBounds.x
        y: renderer.visualBounds.y
        width: window.effectiveInputMode === "painted"
            ? renderer.visualBounds.width : 0
        height: window.effectiveInputMode === "painted"
            ? renderer.visualBounds.height : 0
    }
    TapHandler {
        enabled: window.windowPlan.popupActive
        onTapped: eventPoint => {
            const bounds = renderer.popupVisualBounds;
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
        presentationActive: window.profile.id === "classic"
            ? (window.windowPlan.presentationActive || window.classicTransitionPending)
            : (window.profile.id === "connected" ? window.windowPlan.presentationActive
                : (window.ownsOverlay || window.dismissing))
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
