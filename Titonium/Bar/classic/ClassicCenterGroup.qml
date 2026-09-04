pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Theme
import "../notch/BarLayout.js" as BarLayout

Item {
    id: root

    required property var screen
    implicitWidth: BarLayout.symmetricCenterReservation(220,
        52 + Metrics.spacingSmall)
    implicitHeight: Metrics.widgetHeight
}
