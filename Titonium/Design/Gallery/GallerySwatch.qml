pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Design

Item {
    id: root

    property color swatchColor: "transparent"
    property string label: ""

    implicitWidth: 112
    implicitHeight: 72

    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 44
        radius: Metrics.radiusSmall
        color: root.swatchColor
        border.width: Metrics.borderWidth
        border.color: Theme.border
    }

    Text {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        text: root.label
        color: Theme.textSecondary
        font.family: Typography.family
        font.pixelSize: Typography.captionSize
        renderType: Text.NativeRendering
    }
}
