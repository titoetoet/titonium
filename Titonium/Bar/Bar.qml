pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Bar.islands
import qs.Titonium.Theme
import "notch/BarLayout.js" as BarLayout

Item {
    id: root
    required property var screen
    readonly property alias startHitbox: startIsland
    readonly property alias centerHitbox: centerIsland
    readonly property alias endHitbox: endIsland
    readonly property var optionalPlan: BarLayout.optionalVisibility(
        root.width,
        startIsland.implicitWidth,
        centerIsland.implicitWidth,
        endIsland.preferredWidth,
        Metrics.barSpacing)

    StartIsland {
        id: startIsland
        x: Metrics.barPadding
        anchors.verticalCenter: parent.verticalCenter
        screen: root.screen
    }

    CenterIsland {
        id: centerIsland
        x: BarLayout.centerX(root.width, width)
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
}
