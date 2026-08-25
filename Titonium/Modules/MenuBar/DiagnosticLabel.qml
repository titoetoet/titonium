pragma ComponentBehavior: Bound

import QtQuick
import Titonium.Composition
import Titonium.Design
import Titonium.Foundation

WidgetBase {
    id: root

    implicitWidth: label.implicitWidth + Metrics.spacingSmall * 2
    implicitHeight: Metrics.controlHeightSmall

    Text {
        id: label
        anchors.centerIn: parent
        text: root.node.props?.textKey ? I18n.tr(root.node.props.textKey) : (root.node.label || root.node.id)
        color: Theme.textPrimary
        font.family: Typography.family
        font.pixelSize: Typography.labelSize
        renderType: Text.NativeRendering
    }
}
