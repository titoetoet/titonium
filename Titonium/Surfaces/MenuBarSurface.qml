pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Titonium.Design
import Titonium.Modules.MenuBar

PanelWindow {
    id: root

    required property ShellScreen screenModel

    screen: root.screenModel
    color: "transparent"
    implicitHeight: Metrics.barHeight
    exclusiveZone: Metrics.barHeight
    aboveWindows: true
    WlrLayershell.namespace: "titonium-menubar"
    WlrLayershell.layer: WlrLayer.Top

    anchors {
        top: true
        left: true
        right: true
    }

    MenuBar {
        anchors.fill: parent
        screenModel: root.screenModel
    }
}
