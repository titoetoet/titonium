pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Theme

Item {
    id: root

    required property var screen
    signal notchRequested(var screen)

    implicitWidth: centerIsland.implicitWidth
    implicitHeight: Metrics.controlHeight

    CenterIsland {
        id: centerIsland
        anchors.centerIn: parent
        screen: root.screen
        onNotchRequested: screen => root.notchRequested(screen)
    }
}
