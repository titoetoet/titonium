pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Titonium.Design

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
        rows: root.orientation === Qt.Horizontal ? 1 : Math.max(1, (root.nodes || []).length)
        columns: root.orientation === Qt.Horizontal ? Math.max(1, (root.nodes || []).length) : 1
        rowSpacing: root.spacing
        columnSpacing: root.spacing

        Repeater {
            model: root.nodes || []

            NodeHost {
                required property var modelData
                Layout.preferredWidth: implicitWidth
                Layout.preferredHeight: implicitHeight
                node: modelData
                screen: root.screen
                context: root.context
            }
        }
    }
}
