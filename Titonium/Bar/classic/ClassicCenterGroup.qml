pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Bar.islands
import qs.Titonium.Shared as Shared
import qs.Titonium.Theme

Item {
    id: root

    required property var screen
    readonly property alias centerHitbox: centerSurface
    signal notchRequested(var screen)
    signal sourceRequested(var screen, string intent)
    implicitWidth: centerIsland.implicitWidth + Metrics.spacingLarge * 2
    implicitHeight: Metrics.widgetHeight

    Item {
        id: centerSurface
        anchors.fill: parent

        Shared.Surface {
            anchors.fill: parent
            tone: "elevated"
            radius: Metrics.radiusLarge
        }

        CenterIsland {
            id: centerIsland
            anchors.centerIn: parent
            screen: root.screen
            onNotchRequested: screen => root.notchRequested(screen)
            onSourceRequested: (screen, intent) => root.sourceRequested(screen, intent)
        }
    }
}
