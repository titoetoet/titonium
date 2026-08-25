pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Design
import qs.Titonium.Design.Controls as Controls

Item {
    id: root

    required property var node
    required property var screen
    required property var context

    readonly property int padding: root.node.padding === undefined ? Metrics.spacingXSmall : root.node.padding
    readonly property int orientation: root.node.orientation === "vertical" ? Qt.Vertical : Qt.Horizontal

    implicitWidth: content.implicitWidth + root.padding * 2
    implicitHeight: content.implicitHeight + root.padding * 2

    Controls.Surface {
        anchors.fill: parent
        outlined: false
        radius: Metrics.radiusSmall
        tone: "elevated"
    }

    LayoutRenderer {
        id: content
        anchors.centerIn: parent
        nodes: root.node.children || []
        screen: root.screen
        context: root.context
        orientation: root.orientation
    }
}
