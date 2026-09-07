pragma ComponentBehavior: Bound
import QtQuick
import qs.Titonium.Shared.styles
Item {
    id: root
    required property var paint
    required property var geometry
    required property var motion
    PaintTransition {
        id: stateTransition
        objectName: "styleStateTransition"
        targetValue: root.paint.stateLayerOpacity
        motion: root.motion
    }
    objectName: "modern-flatPaint"
    PaintShape {
        id: body
        anchors.fill: parent
        geometry: root.geometry
        color: root.paint.fill
        border.color: root.paint.outline
        border.width: root.paint.borderStrength > 0 ? Math.min(1, root.paint.borderStrength) : 0
    }
    PaintShape {
        objectName: "flatStateLayer"
        anchors.fill: parent; geometry: root.geometry
        color: root.paint.foreground; opacity: stateTransition.value * .45
    }
}
