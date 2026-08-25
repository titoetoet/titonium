pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Design
import qs.Titonium.Design.Controls as Controls

Item {
    id: root

    required property var node
    required property var screen
    required property var context

    readonly property int padding: Metrics.spacingSmall

    implicitWidth: content.implicitWidth + root.padding * 2
    implicitHeight: content.implicitHeight + root.padding * 2

    Controls.Panel {
        anchors.fill: parent
        padding: 0
        radius: Metrics.radiusMedium
    }

    LayoutRenderer {
        id: content
        anchors.centerIn: parent
        nodes: root.node.child ? [root.node.child] : []
        screen: root.screen
        context: root.context
        orientation: root.node.orientation === "vertical" ? Qt.Vertical : Qt.Horizontal
    }
}
