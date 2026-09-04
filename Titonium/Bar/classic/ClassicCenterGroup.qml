pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Theme

Item {
    id: root

    required property var screen
    implicitWidth: 220
        + Metrics.spacingLarge * 2
    implicitHeight: Metrics.widgetHeight
}
