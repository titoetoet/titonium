pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Titonium.Core.Runtime
import qs.Titonium.Bar.center
import "CenterSurfacePresentationRules.js" as PresentationRules

PanelWindow {
    id: window
    readonly property bool pointerHovered: window.visible && compactHover.hovered
    required property ShellScreen screenModel
    required property var snapshot
    required property var viewState
    required property var profile
    readonly property bool ownsCompact: window.viewState.ownerScreenName === window.screenModel.name
        && window.viewState.mode === "compact"
    readonly property var windowPlan: PresentationRules.windowPlan(
        window.profile.id, window.viewState, window.screenModel.name, BarVisibilityState.revealed)
    readonly property rect interactiveBounds: renderer.interactiveBounds

    function refreshInputMask(): void {
        inputMask.changed();
    }

    screen: window.screenModel
    visible: window.windowPlan.compactMapped
    color: "transparent"
    aboveWindows: true
    exclusiveZone: 0
    WlrLayershell.namespace: "titonium-center-compact"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    anchors { top: true; bottom: true; left: true; right: true }
    mask: Region {
        id: inputMask
        Region { item: inputRegion }
    }

    onWindowPlanChanged: window.refreshInputMask()
    onOwnsCompactChanged: window.refreshInputMask()
    onInteractiveBoundsChanged: window.refreshInputMask()

    Item {
        id: inputRegion
        HoverHandler { id: compactHover; parent: renderer; enabled: window.windowPlan.presentationActive }
        x: renderer.interactiveBounds.x
        y: renderer.interactiveBounds.y
        width: window.ownsCompact && window.windowPlan.presentationActive
            ? renderer.interactiveBounds.width : 0
        height: window.ownsCompact && window.windowPlan.presentationActive
            ? renderer.interactiveBounds.height : 0
    }
    CenterRenderer {
        id: renderer
        visible: window.windowPlan.presentationActive
        anchors.fill: parent
        snapshot: window.snapshot
        viewState: window.viewState
        profile: window.profile
        transitionOwner: false
        presentationActive: window.windowPlan.presentationActive
        onIntentRequested: intent => CenterSurfaceController.dispatch(intent)
        onTransitionFinished: generation => CenterSurfaceController.dispatch({
            type: "transition-finished", generation: generation })
    }
}
