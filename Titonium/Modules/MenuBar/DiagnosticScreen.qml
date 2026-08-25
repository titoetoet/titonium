pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Composition
import qs.Titonium.Design

WidgetBase {
    id: root

    implicitWidth: label.implicitWidth + Metrics.spacingSmall * 2
    implicitHeight: Metrics.controlHeightSmall

    Text {
        id: label
        anchors.centerIn: parent
        text: root.screen.name + " · " + root.screen.devicePixelRatio.toFixed(2) + "×"
        color: Theme.textSecondary
        font.family: Typography.family
        font.pixelSize: Typography.captionSize
        renderType: Text.NativeRendering
    }
}
