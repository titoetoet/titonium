pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Bar.widgets
import qs.Titonium.Theme
import qs.Titonium.Shared as Shared

Item {
    id: root
    required property var screen

    implicitWidth: statusRow.implicitWidth + Metrics.spacingXSmall * 2
    implicitHeight: Metrics.widgetHeight

    Shared.Surface {
        anchors.fill: parent
        tone: "elevated"
        radius: Metrics.radiusSmall
    }

    Row {
        id: statusRow
        anchors.centerIn: parent
        spacing: Metrics.spacingXSmall

        InputMethod { screen: root.screen }
    }
}
