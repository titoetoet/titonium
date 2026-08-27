pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Bar.widgets
import qs.Titonium.Theme
import qs.Titonium.Shared as Shared

Item {
    id: root
    required property var screen

    implicitWidth: workspaces.implicitWidth + Metrics.spacingXSmall * 2
    implicitHeight: Metrics.widgetHeight

    Shared.Surface {
        anchors.fill: parent
        tone: "elevated"
        radius: Metrics.radiusLarge
    }

    Workspaces {
        id: workspaces
        anchors.centerIn: parent
        screen: root.screen
        count: 5
    }
}
