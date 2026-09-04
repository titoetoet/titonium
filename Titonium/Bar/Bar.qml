pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Bar.islands
import qs.Titonium.Bar.right
import qs.Titonium.Theme
import "notch/BarLayout.js" as BarLayout

Item {
    id: root
    required property var screen
    readonly property bool hovered: barHover.hovered
    readonly property alias leftHitbox: leftReservation
    readonly property alias rightHitbox: rightReservation
    readonly property var optionalPlan: BarLayout.optionalVisibility(
        root.width,
        leftReservation.preferredWidth,
        centerGroup.implicitWidth,
        rightReservation.preferredWidth,
        Metrics.barSpacing)

    Item {
        id: leftReservation
        readonly property real preferredWidth: RightPillCoordinator.leftCompactWidth
        width: preferredWidth
        height: Metrics.widgetHeight
        x: 0
        anchors.top: parent.top

        StartIsland {
            anchors.left: parent.left
            width: Math.max(0, parent.width - 16)
            height: Metrics.widgetHeight
            screen: root.screen
        }
    }

    Item {
        id: centerGroup
        implicitWidth: 220
        width: implicitWidth
        implicitHeight: Metrics.barHeight
        x: BarLayout.centerX(root.width, centerGroup.width)
        anchors.top: parent.top
        height: parent.height
    }

    Item {
        id: rightReservation
        readonly property real preferredWidth: RightPillCoordinator.compactWidth
        width: preferredWidth
        height: Metrics.widgetHeight
        x: root.width - width
        anchors.top: parent.top

        EndIsland {
            anchors.right: parent.right
            width: Math.max(0, parent.width - 16)
            height: Metrics.widgetHeight
            screen: root.screen
        }
    }

    HoverHandler { id: barHover }
}
