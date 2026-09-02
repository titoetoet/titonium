pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Titonium.Services.AgentApproval
import qs.Titonium.Theme

PanelWindow {
    id: window
    required property ShellScreen screenModel
    readonly property real popupTop: Metrics.barHeight + Metrics.barSpacing
    readonly property bool ownsApproval: AgentApprovalService.hasPending
        && AgentApprovalService.popupScreenName === window.screenModel.name

    screen: window.screenModel
    visible: window.ownsApproval
    color: "transparent"
    implicitWidth: 660
    implicitHeight: window.popupTop + 340
    aboveWindows: true
    exclusiveZone: 0
    WlrLayershell.namespace: "titonium-agent-approval"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: window.ownsApproval
        ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    anchors { top: true; left: false; right: false; bottom: false }
    mask: Region { Region { item: cardLoader } }

    Loader {
        id: cardLoader
        width: 640
        height: 320
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: window.popupTop
        active: window.ownsApproval
        sourceComponent: AgentApprovalCard {}
    }
}
