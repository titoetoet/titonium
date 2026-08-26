pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Theme
import qs.Titonium.Shared as Shared
import "widgets"

Item {
    id: root
    required property var screen

    Shared.Surface {
        anchors.fill: parent
        tone: "background"
        radius: 0
        outlined: false
    }

    Row {
        anchors.left: parent.left
        anchors.leftMargin: Metrics.barPadding
        anchors.verticalCenter: parent.verticalCenter
        spacing: Metrics.barSpacing
        Workspaces { screen: root.screen; count: 5 }
    }

    Row {
        anchors.right: parent.right
        anchors.rightMargin: Metrics.barPadding
        anchors.verticalCenter: parent.verticalCenter
        spacing: Metrics.barSpacing
        InputMethod { screen: root.screen }
        Clock { screen: root.screen }
    }
}
