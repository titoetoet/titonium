pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Titonium.Design

Item {
    id: root

    required property var nodes
    required property var screen
    required property var context
    property int orientation: Qt.Horizontal
    property int spacing: Metrics.spacingSmall

    implicitWidth: layout.implicitWidth
    implicitHeight: layout.implicitHeight
    width: root.implicitWidth
    height: root.implicitHeight

    GridLayout {
        id: layout
        anchors.fill: parent
        flow: root.orientation === Qt.Horizontal ? GridLayout.LeftToRight : GridLayout.TopToBottom
        rows: root.orientation === Qt.Horizontal ? 1 : 0
        columns: root.orientation === Qt.Horizontal ? 0 : 1
        rowSpacing: root.spacing
        columnSpacing: root.spacing

        Repeater {
            model: root.nodes || []

            NodeHost {
                required property var modelData
                node: modelData
                screen: root.screen
                context: root.context
            }
        }
    }
}
