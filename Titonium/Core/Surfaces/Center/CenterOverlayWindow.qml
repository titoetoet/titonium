pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Titonium.Bar.center

PanelWindow {
    id: window
    required property ShellScreen screenModel
    required property var snapshot
    required property var viewState
    required property var profile
    readonly property bool ownsOverlay: window.viewState.ownerScreenName === window.screenModel.name
        && (window.viewState.mode === "banner" || window.viewState.mode === "expanded")
    readonly property bool dismissing: window.viewState.exitingScreenName === window.screenModel.name

    screen: window.screenModel
    visible: window.ownsOverlay || window.dismissing
    color: "transparent"
    aboveWindows: true
    exclusiveZone: 0
    WlrLayershell.namespace: "titonium-center-overlay"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: window.ownsOverlay
        && window.viewState.focusPolicy === "exclusive"
        ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    anchors { top: true; bottom: true; left: true; right: true }
    mask: Region {
        Region { item: overlayInput }
        Region { item: dismissingInput }
    }

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
                CenterSurfaceController.dispatch({ type: "request-mode", mode: "compact" });
        }
    }
    CenterRenderer {
        id: renderer
        anchors.fill: parent
        snapshot: window.snapshot
        viewState: window.viewState
        profile: window.profile
        onIntentRequested: intent => CenterSurfaceController.dispatch(intent)
        onTransitionFinished: generation => {
            CenterSurfaceController.dispatch({ type: "transition-finished", generation: generation });
            if (window.dismissing)
                CenterSurfaceController.finishClose(window.screenModel.name, generation);
        }
        Keys.onEscapePressed: CenterSurfaceController.dispatch({ type: "request-mode", mode: "compact" })
    }
}
