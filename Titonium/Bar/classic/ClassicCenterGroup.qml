pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Bar.notch
import qs.Titonium.Theme

Item {
    id: root

    required property var screen
    implicitWidth: Math.max(180, Math.min(220, CenterNotchCoordinator.islandWidth))
        + Metrics.spacingLarge * 2
    implicitHeight: Metrics.widgetHeight
}
