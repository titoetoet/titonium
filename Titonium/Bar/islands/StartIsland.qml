pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Bar.widgets
import qs.Titonium.Bar.right
import qs.Titonium.Theme

Item {
    id: root
    required property var screen
    property real menuAnchorOffset: 0

    implicitWidth: startRow.implicitWidth + Metrics.spacingXSmall * 2
    implicitHeight: Metrics.widgetHeight
    readonly property real menuAnchorX: startRow.x + activeWindow.x
        + activeWindow.menuAnchorX
    readonly property real menuAnchorWidth: activeWindow.menuAnchorWidth
    onImplicitWidthChanged: RightPillCoordinator.setCompactWidth("left", root.implicitWidth + 16)
    Component.onCompleted: RightPillCoordinator.setCompactWidth("left", root.implicitWidth + 16)

    Row {
        id: startRow
        anchors.verticalCenter: parent.verticalCenter
        x: Metrics.spacingXSmall
        spacing: Metrics.spacingXSmall

        ArchLogo {}

        Workspaces {
            id: workspaces
            screen: root.screen
        }

        ActiveWindowPill {
            id: activeWindow
            screen: root.screen
            menuAnchorOffset: root.menuAnchorOffset
        }
    }
}
