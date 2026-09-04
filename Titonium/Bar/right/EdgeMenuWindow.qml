pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Titonium.Core.Runtime
import qs.Titonium.Core.Surfaces
import qs.Titonium.Theme

PanelWindow {
    id: window
    required property ShellScreen screenModel
    property bool styleActive: true
    readonly property bool connectedSurfaceForScreen:
        RightPillCoordinator.connectedSurfacePresented
        && RightPillCoordinator.connectedScreen === window.screenModel
    readonly property bool ownsConnectedSurface: window.styleActive
        && window.connectedSurfaceForScreen
    readonly property bool ownsMenu: window.styleActive && (
        RightPillCoordinator.ownerScreenName === window.screenModel.name
        || window.ownsConnectedSurface)
    readonly property bool wantsInteractiveFocus: window.ownsMenu
    readonly property string logicalFocusOwnerId: !window.wantsInteractiveFocus ? ""
        : RightPillCoordinator.ownerScreenName === window.screenModel.name
            ? "edge-menu:" + window.screenModel.name + ":menu:"
                + RightPillCoordinator.menuSource
            : "edge-menu:" + window.screenModel.name + ":surface:"
                + RightPillCoordinator.connectedOwnerId
    property string focusOwnerId: ""
    property string diagnosticFocusOwnerId: ""
    readonly property bool effectiveInteractiveFocus: window.wantsInteractiveFocus
        && FocusArbiter.granted(window.focusOwnerId)

    function syncInteractiveFocus(): void {
        if (window.wantsInteractiveFocus && window.logicalFocusOwnerId)
            window.focusOwnerId = window.logicalFocusOwnerId;
        if (window.focusOwnerId)
            FocusArbiter.request(window.focusOwnerId, window.wantsInteractiveFocus);
    }
    readonly property bool dismissing: window.styleActive
        && RightPillCoordinator.exitingScreenName === window.screenModel.name
    readonly property real compactY: BarVisibilityState.revealed || window.ownsMenu
        ? 0 : -Metrics.barHeight + 2

    screen: window.screenModel
    visible: window.styleActive
    color: "transparent"
    aboveWindows: true
    exclusiveZone: 0
    WlrLayershell.namespace: "titonium-edge-menu"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: window.ownsMenu
        && FocusArbiter.granted(window.focusOwnerId)
        ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    anchors { top: true; bottom: true; left: true; right: true }
    mask: Region {
        Region { item: activeInputRegion }
        Region { item: dismissingInputRegion }
    }

    Item { id: activeInputRegion; width: window.ownsMenu ? window.width : 0; height: window.ownsMenu ? window.height : 0 }
    Item {
        id: dismissingInputRegion
        visible: window.dismissing
        x: Math.min(surface.activeBranch.x, surface.presentedRightCompactX); y: 0
        width: visible ? Math.max(surface.activeBranch.x + surface.activeBranch.width,
            surface.presentedLeftCompactWidth) - x : 0
        height: visible ? surface.activeBranch.y + surface.activeBranch.height : 0
    }

    EdgeMenuSurface {
        id: surface
        anchors.fill: parent
        screenModel: window.screenModel
        compactY: window.compactY
    }

    onStyleActiveChanged: {
        if (window.styleActive)
            return;
        if (RightPillCoordinator.ownerScreenName === window.screenModel.name)
            RightPillCoordinator.close();
        if (window.connectedSurfaceForScreen)
            RightPillCoordinator.forceCloseConnectedSurface();
        if (RightPillCoordinator.exitingScreenName === window.screenModel.name)
            RightPillCoordinator.finishClose(window.screenModel.name);
    }

    onWantsInteractiveFocusChanged: window.syncInteractiveFocus()
    onLogicalFocusOwnerIdChanged: window.syncInteractiveFocus()
    onEffectiveInteractiveFocusChanged: {
        if (window.effectiveInteractiveFocus) {
            window.diagnosticFocusOwnerId = window.focusOwnerId;
            FocusDiagnostics.observe(window.diagnosticFocusOwnerId, true,
                { mode: "open", focusPolicy: "exclusive" });
        } else if (window.diagnosticFocusOwnerId) {
            FocusDiagnostics.observe(window.diagnosticFocusOwnerId, false,
                { mode: "closed", focusPolicy: "exclusive" });
            window.diagnosticFocusOwnerId = "";
        }
    }
    Component.onCompleted: window.syncInteractiveFocus()

    Component.onDestruction: {
        if (window.focusOwnerId) {
            FocusArbiter.withdraw(window.focusOwnerId);
            if (window.diagnosticFocusOwnerId)
                FocusDiagnostics.observe(window.diagnosticFocusOwnerId, false,
                    { mode: "destroyed" });
        }
        if (RightPillCoordinator.connectedSurfacePresented
                && RightPillCoordinator.connectedScreen === window.screenModel)
            RightPillCoordinator.releaseConnectedSurface(
                RightPillCoordinator.connectedOwnerId,
                RightPillCoordinator.connectedGeneration,
                RightPillCoordinator.connectedDescriptor,
                RightPillCoordinator.connectedScreen);
    }
}
