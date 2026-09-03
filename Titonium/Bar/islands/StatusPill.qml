pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Bar.widgets
import qs.Titonium.Theme

Item {
    id: root
    required property var screen
    property real menuAnchorOffset: 0

    implicitWidth: statusRow.implicitWidth + Metrics.spacingXSmall * 2
    implicitHeight: Metrics.widgetHeight
    readonly property real menuAnchorX: statusRow.x + inputMethod.x
    readonly property real menuAnchorWidth: inputMethod.width

    Row {
        id: statusRow
        anchors.centerIn: parent
        spacing: Metrics.spacingXSmall

        InputMethod {
            id: inputMethod
            screen: root.screen
            menuAnchorOffset: root.menuAnchorOffset
        }
    }
}
