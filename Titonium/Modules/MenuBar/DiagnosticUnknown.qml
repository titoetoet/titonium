pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Composition
import qs.Titonium.Design
import qs.Titonium.Foundation

WidgetBase {
    id: root

    implicitWidth: label.implicitWidth + Metrics.spacingSmall * 2
    implicitHeight: Metrics.controlHeightSmall

    Component.onCompleted: Logger.warn(
        "composition",
        "unknown widget type: " + (root.node.widgetType || root.node.type || "node")
    )

    Rectangle {
        anchors.fill: parent
        radius: Metrics.radiusSmall
        color: Qt.alpha(Theme.warning, 0.16)
        border.width: 1
        border.color: Theme.warning
    }

    Text {
        id: label
        anchors.centerIn: parent
        text: "Unknown: " + (root.node.widgetType || root.node.type || "node")
        color: Theme.warning
        font.family: Typography.family
        font.pixelSize: Typography.captionSize
        renderType: Text.NativeRendering
    }
}
