pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Titonium.Services.AgentApproval
import qs.Titonium.Bar.notch
import qs.Titonium.Theme

PanelWindow {
    id: window
    required property ShellScreen screenModel
    readonly property real popupTop: Metrics.barHeight + Metrics.barSpacing
    readonly property bool ownsApproval: AgentApprovalService.hasPending
        && AgentApprovalService.popupScreenName === window.screenModel.name
        && !CenterNotchCoordinator.handlesAgentApproval

    readonly property bool isFileChange: AgentApprovalService.currentIsFileChange

    screen: window.screenModel
    visible: window.ownsApproval
    color: "transparent"
    implicitWidth: window.isFileChange ? (380 + Metrics.barPadding * 2) : 660
    implicitHeight: window.popupTop + (window.isFileChange ? 180 : 340)
    aboveWindows: true
    exclusiveZone: 0
    WlrLayershell.namespace: "titonium-agent-approval"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: (!window.isFileChange && window.ownsApproval)
        ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    anchors {
        top: true
        right: window.isFileChange
        left: false
        bottom: false
    }
    mask: Region { Region { item: cardLoader } }

    Loader {
        id: cardLoader
        width: window.isFileChange ? 380 : 640
        height: window.isFileChange ? cardLoader.implicitHeight : 320
        anchors.top: parent.top
        anchors.right: window.isFileChange ? parent.right : undefined
        anchors.horizontalCenter: window.isFileChange ? undefined : parent.horizontalCenter
        anchors.topMargin: window.popupTop
        anchors.rightMargin: window.isFileChange ? Metrics.barPadding : 0
        active: window.ownsApproval
        sourceComponent: window.isFileChange ? toastComponent : modalComponent
    }

    Component {
        id: toastComponent
        AgentApprovalToastCard {}
    }

    Component {
        id: modalComponent
        AgentApprovalCard {}
    }
}
