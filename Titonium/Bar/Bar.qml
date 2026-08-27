pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Bar.islands
import qs.Titonium.Theme
import "notch/BarLayout.js" as BarLayout

Item {
    id: root
    required property var screen
    readonly property alias startHitbox: startIsland
    readonly property alias centerHitbox: centerGroup
    readonly property alias endHitbox: endIsland
    readonly property bool hovered: barHover.hovered
    readonly property var optionalPlan: BarLayout.optionalVisibility(
        root.width,
        startIsland.implicitWidth,
        centerGroup.implicitWidth,
        endIsland.preferredWidth,
        Metrics.barSpacing)

    StartIsland {
        id: startIsland
        x: Metrics.barPadding
        anchors.verticalCenter: parent.verticalCenter
        screen: root.screen
    }

    CenterGroup {
        id: centerGroup
        x: BarLayout.centerX(root.width, centerGroup.width)
        anchors.verticalCenter: parent.verticalCenter
        screen: root.screen
    }

    EndIsland {
        id: endIsland
        x: root.width - width - Metrics.barPadding
        anchors.verticalCenter: parent.verticalCenter
        screen: root.screen
        showConnectivityDiagnostics: root.optionalPlan.showConnectivityDiagnostics
    }

    HoverHandler { id: barHover }
}
