pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Bar.widgets
import qs.Titonium.Shared as Shared
import qs.Titonium.Theme
import "../notch/BarLayout.js" as BarLayout

Item {
    id: root

    required property var screen
    readonly property alias leftHitbox: startIsland
    readonly property alias centerHitbox: centerGroup
    readonly property alias notificationHitbox: notificationSurface
    readonly property alias rightHitbox: endIsland
    readonly property bool hovered: barHover.hovered
    signal centerRequested(var screen)
    signal sourceRequested(var screen, string intent)
    readonly property var optionalPlan: BarLayout.optionalVisibility(
        root.width,
        startIsland.implicitWidth,
        centerGroup.implicitWidth,
        endIsland.preferredWidth,
        Metrics.barSpacing)

    ClassicStartIsland {
        id: startIsland
        x: Metrics.barPadding
        anchors.verticalCenter: parent.verticalCenter
        screen: root.screen
    }

    ClassicCenterGroup {
        id: centerGroup
        x: BarLayout.centerX(root.width, centerGroup.width)
        anchors.verticalCenter: parent.verticalCenter
        screen: root.screen
        onNotchRequested: screen => root.centerRequested(screen)
        onSourceRequested: (screen, intent) => root.sourceRequested(screen, intent)
    }

    Item {
        id: notificationSurface
        x: centerGroup.x + centerGroup.width + Metrics.spacingSmall
        anchors.verticalCenter: parent.verticalCenter
        visible: notificationBell.visible
        implicitWidth: visible ? notificationBell.width + Metrics.spacingXSmall * 2 : 0
        implicitHeight: Metrics.widgetHeight

        Shared.Surface {
            anchors.fill: parent
            tone: "elevated"
            radius: Metrics.radiusLarge
        }

        NotificationBell {
            id: notificationBell
            anchors.centerIn: parent
            screen: root.screen
        }
    }

    ClassicEndIsland {
        id: endIsland
        x: root.width - width - Metrics.barPadding
        anchors.verticalCenter: parent.verticalCenter
        screen: root.screen
        showConnectivityDiagnostics: root.optionalPlan.showConnectivityDiagnostics
    }

    HoverHandler { id: barHover }
}
