pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: root
    required property ShellScreen screenModel
    screen: root.screenModel
    color: "transparent"
    implicitHeight: 40
    exclusiveZone: 40
    aboveWindows: true
    WlrLayershell.namespace: "titonium-menubar"
    WlrLayershell.layer: WlrLayer.Top
    anchors { top: true; left: true; right: true }
    mask: Region {
        Region { item: bar.startHitbox }
        Region { item: bar.centerHitbox }
        Region { item: bar.endHitbox }
    }

    Bar {
        id: bar
        anchors.fill: parent
        screen: root.screenModel
    }
}
