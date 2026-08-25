pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Titonium.Design

PanelWindow {
    id: root

    required property ShellScreen screenModel

    screen: root.screenModel
    color: "transparent"
    implicitWidth: root.screenModel.width
    implicitHeight: root.screenModel.height
    mask: Region {}
    aboveWindows: false

    WlrLayershell.namespace: "titonium-frame"
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.exclusionMode: ExclusionMode.Ignore

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    Rectangle {
        anchors.fill: parent
        color: "transparent"
        radius: FrameModel.cornerRadius
        border.width: FrameModel.thickness
        border.color: Qt.alpha(Theme.borderStrong, FrameModel.opacity)
    }
}
